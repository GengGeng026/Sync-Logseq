import hashlib
import json
import os
import re
import time
from datetime import datetime, timezone
from pathlib import Path

import requests

NOTION_API_KEY = os.getenv("NOTION_API_KEY")
NOTION_LOGSEQ_MIRROR_DATABASE_URL = os.getenv("NOTION_LOGSEQ_MIRROR_DATABASE_URL")
NOTION_VERSION = "2022-06-28"
JOURNALS_DIR = Path("journals")
JOURNAL_FILE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}\.md$")
RICH_TEXT_CHUNK_SIZE = 1900
BLOCK_CHUNK_SIZE = 100
MAX_RETRIES = 3
RETRY_BACKOFF = 2


# ---------------------------------------------------------------------------
# HTTP helper with retry + rate-limit handling
# ---------------------------------------------------------------------------

def request_with_retry(method, url, **kwargs):
    """HTTP request wrapper with exponential backoff and 429 handling."""
    kwargs.setdefault("timeout", 30)
    for attempt in range(MAX_RETRIES):
        try:
            response = method(url, **kwargs)
            if response.status_code == 429:
                retry_after = int(
                    response.headers.get("Retry-After", RETRY_BACKOFF * (attempt + 1))
                )
                print(f"  Rate limited. Retrying after {retry_after}s...")
                time.sleep(retry_after)
                continue
            response.raise_for_status()
            return response
        except requests.exceptions.RequestException as exc:
            if attempt < MAX_RETRIES - 1:
                wait = RETRY_BACKOFF * (2 ** attempt)
                print(f"  Request error: {exc}. Retrying in {wait}s...")
                time.sleep(wait)
            else:
                raise
    raise RuntimeError(f"Failed after {MAX_RETRIES} retries: {url}")


# ---------------------------------------------------------------------------
# Notion ID helpers
# ---------------------------------------------------------------------------

def normalize_notion_id(raw_id: str) -> str:
    raw_id = raw_id.replace("-", "").lower()
    if len(raw_id) != 32:
        raise ValueError(f"Unexpected Notion ID length: {raw_id}")
    return (
        f"{raw_id[0:8]}-"
        f"{raw_id[8:12]}-"
        f"{raw_id[12:16]}-"
        f"{raw_id[16:20]}-"
        f"{raw_id[20:32]}"
    )


def extract_notion_id_from_url(url: str) -> str:
    match = re.search(r"([0-9a-fA-F]{32})", url)
    if not match:
        raise ValueError("Could not find a 32-character Notion ID in the database URL")
    return normalize_notion_id(match.group(1))


# ---------------------------------------------------------------------------
# Notion API helpers
# ---------------------------------------------------------------------------

def get_headers() -> dict:
    return {
        "Authorization": f"Bearer {NOTION_API_KEY}",
        "Notion-Version": NOTION_VERSION,
        "Content-Type": "application/json",
    }


def get_title_text(title_items: list) -> str:
    return "".join(item.get("plain_text", "") for item in title_items)


def get_rich_text_text(rich_text_items: list) -> str:
    return "".join(item.get("plain_text", "") for item in rich_text_items)


def summarize_row(row: dict) -> dict:
    properties = row.get("properties", {})

    mirror_title = ""
    source_path = ""
    sync_status = ""
    content_hash = ""

    if "Mirror Title" in properties:
        mirror_title = get_title_text(properties["Mirror Title"].get("title", []))
    if "Source Path" in properties:
        source_path = get_rich_text_text(properties["Source Path"].get("rich_text", []))
    if "Sync Status" in properties:
        status_obj = properties["Sync Status"].get("status") or {}
        sync_status = status_obj.get("name", "")
    if "Content Hash" in properties:
        content_hash = get_rich_text_text(properties["Content Hash"].get("rich_text", []))

    return {
        "id": row.get("id", ""),
        "url": row.get("url", ""),
        "Mirror Title": mirror_title,
        "Source Path": source_path,
        "Sync Status": sync_status,
        "Content Hash": content_hash,
    }


# ---------------------------------------------------------------------------
# Journal file helpers
# ---------------------------------------------------------------------------

def get_all_journal_files() -> list[Path]:
    """Return all date-named journal markdown files, sorted ascending."""
    if not JOURNALS_DIR.exists():
        raise FileNotFoundError("journals directory does not exist in the repository checkout")

    candidates = sorted(
        path for path in JOURNALS_DIR.iterdir()
        if path.is_file() and JOURNAL_FILE_RE.match(path.name)
    )

    if not candidates:
        raise FileNotFoundError("No date-named journal markdown files were found in journals/")

    return candidates


def build_source_path(journal_file: Path) -> str:
    return f"repo:journals/{journal_file.name}"


def build_mirror_title(date_str: str) -> str:
    return f"Logseq Mirror｜{date_str}"


def build_original_title(date_str: str) -> str:
    dt = datetime.strptime(date_str, "%Y-%m-%d")
    weekday = dt.strftime("%a").lower()
    return f"{weekday}, {dt.strftime('%d-%m-%Y')}"


def normalize_journal_text(raw_text: str) -> str:
    text = raw_text.replace("\r\n", "\n").replace("\r", "\n")
    normalized_lines = []
    for line in text.split("\n"):
        if line.strip() == "-":
            normalized_lines.append("")
        else:
            normalized_lines.append(line)
    while normalized_lines and normalized_lines[-1] == "":
        normalized_lines.pop()
    return "\n".join(normalized_lines)


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


# ---------------------------------------------------------------------------
# Notion content builders
# ---------------------------------------------------------------------------

def chunk_text(text: str, size: int = RICH_TEXT_CHUNK_SIZE) -> list[str]:
    if text == "":
        return [""]
    return [text[i:i + size] for i in range(0, len(text), size)]


def rich_text_payload(text: str) -> list[dict]:
    if text == "":
        return []
    return [
        {
            "type": "text",
            "text": {
                "content": chunk,
            },
        }
        for chunk in chunk_text(text)
    ]


def line_to_block(line: str) -> dict | None:
    if line == "":
        return None

    if line.startswith("- "):
        text = line[2:]
        return {
            "object": "block",
            "type": "bulleted_list_item",
            "bulleted_list_item": {
                "rich_text": rich_text_payload(text),
            },
        }

    return {
        "object": "block",
        "type": "paragraph",
        "paragraph": {
            "rich_text": rich_text_payload(line),
        },
    }


def journal_text_to_blocks(text: str) -> list[dict]:
    blocks = []
    for line in text.split("\n"):
        block = line_to_block(line)
        if block is not None:
            blocks.append(block)
    return blocks


# ---------------------------------------------------------------------------
# Notion CRUD (all using request_with_retry)
# ---------------------------------------------------------------------------

def notion_get_database(database_id: str, headers: dict) -> dict:
    base = "https://api.notion.com/v1/databases"
    resp = request_with_retry(
        requests.get,
        f"{base}/{database_id}",
        headers=headers,
    )
    return resp.json()


def notion_query_by_source_path(database_id: str, headers: dict, source_path: str) -> list[dict]:
    base = "https://api.notion.com/v1/databases"
    payload = {
        "page_size": 10,
        "filter": {
            "property": "Source Path",
            "rich_text": {
                "equals": source_path,
            },
        },
    }
    resp = request_with_retry(
        requests.post,
        f"{base}/{database_id}/query",
        headers=headers,
        json=payload,
    )
    return resp.json().get("results", [])


def build_page_properties(
    date_str: str,
    source_path: str,
    original_title: str,
    content_hash: str,
    sync_status: str,
    mirror_page_url: str | None,
) -> dict:
    now_iso = (
        datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )

    return {
        "Mirror Title": {
            "title": [
                {
                    "type": "text",
                    "text": {
                        "content": build_mirror_title(date_str),
                    },
                }
            ]
        },
        "Original Title": {
            "rich_text": [
                {
                    "type": "text",
                    "text": {
                        "content": original_title,
                    },
                }
            ]
        },
        "Source Path": {
            "rich_text": [
                {
                    "type": "text",
                    "text": {
                        "content": source_path,
                    },
                }
            ]
        },
        "Content Hash": {
            "rich_text": [
                {
                    "type": "text",
                    "text": {
                        "content": content_hash,
                    },
                }
            ]
        },
        "Sync Status": {
            "status": {
                "name": sync_status,
            }
        },
        "Journal Date": {
            "date": {
                "start": date_str,
            }
        },
        "Last Synced At": {
            "date": {
                "start": now_iso,
            }
        },
        "Mirror Page URL": {
            "url": mirror_page_url,
        },
    }


def notion_update_page_properties(page_id: str, headers: dict, properties: dict) -> dict:
    base = "https://api.notion.com/v1/pages"
    resp = request_with_retry(
        requests.patch,
        f"{base}/{page_id}",
        headers=headers,
        json={"properties": properties},
    )
    return resp.json()


def notion_create_page(
    database_id: str, headers: dict, properties: dict, children: list[dict]
) -> dict:
    payload = {
        "parent": {"database_id": database_id},
        "properties": properties,
        "children": children[:BLOCK_CHUNK_SIZE],
    }

    resp = request_with_retry(
        requests.post,
        "https://api.notion.com/v1/pages",
        headers=headers,
        json=payload,
    )
    page = resp.json()

    remaining_children = children[BLOCK_CHUNK_SIZE:]
    if remaining_children:
        notion_append_children(page["id"], headers, remaining_children)

    return page


def notion_list_children(block_id: str, headers: dict) -> list[dict]:
    base = "https://api.notion.com/v1/blocks"
    all_results = []
    start_cursor = None

    while True:
        params = {"page_size": 100}
        if start_cursor:
            params["start_cursor"] = start_cursor

        resp = request_with_retry(
            requests.get,
            f"{base}/{block_id}/children",
            headers=headers,
            params=params,
        )
        payload = resp.json()
        all_results.extend(payload.get("results", []))

        if not payload.get("has_more"):
            break

        start_cursor = payload.get("next_cursor")

    return all_results


def notion_archive_block(block_id: str, headers: dict) -> None:
    base = "https://api.notion.com/v1/blocks"
    request_with_retry(
        requests.delete,
        f"{base}/{block_id}",
        headers=headers,
    )


def notion_replace_children(page_id: str, headers: dict, children: list[dict]) -> None:
    existing_children = notion_list_children(page_id, headers)
    for child in existing_children:
        try:
            notion_archive_block(child["id"], headers)
        except Exception as exc:
            print(f"  Warning: could not delete block {child['id']}: {exc}")

    if children:
        notion_append_children(page_id, headers, children)


def notion_append_children(block_id: str, headers: dict, children: list[dict]) -> None:
    base = "https://api.notion.com/v1/blocks"
    for i in range(0, len(children), BLOCK_CHUNK_SIZE):
        chunk = children[i : i + BLOCK_CHUNK_SIZE]
        request_with_retry(
            requests.patch,
            f"{base}/{block_id}/children",
            headers=headers,
            json={"children": chunk},
        )


# ---------------------------------------------------------------------------
# Per-file sync logic
# ---------------------------------------------------------------------------

def sync_one_journal(
    journal_file: Path,
    database_id: str,
    headers: dict,
) -> str:
    """Sync a single journal file. Returns 'created', 'updated', or 'skipped'."""
    date_str = journal_file.stem
    source_path = build_source_path(journal_file)
    original_title = build_original_title(date_str)

    raw_text = journal_file.read_text(encoding="utf-8")
    normalized_text = normalize_journal_text(raw_text)
    content_hash = sha256_text(normalized_text)
    blocks = journal_text_to_blocks(normalized_text)

    matched_rows = notion_query_by_source_path(database_id, headers, source_path)

    if len(matched_rows) > 1:
        raise RuntimeError(
            f"More than one row matched Source Path '{source_path}'"
        )

    # --- CREATE path ---
    if len(matched_rows) == 0:
        print(f"  Creating new mirror page...")
        initial_props = build_page_properties(
            date_str=date_str,
            source_path=source_path,
            original_title=original_title,
            content_hash=content_hash,
            sync_status="Syncing",
            mirror_page_url=None,
        )
        created_page = notion_create_page(database_id, headers, initial_props, blocks)
        final_props = build_page_properties(
            date_str=date_str,
            source_path=source_path,
            original_title=original_title,
            content_hash=content_hash,
            sync_status="Synced",
            mirror_page_url=created_page.get("url"),
        )
        notion_update_page_properties(created_page["id"], headers, final_props)
        print(f"  Created: {created_page.get('url')}")
        return "created"

    # --- UPDATE path ---
    matched_row = matched_rows[0]
    row_summary = summarize_row(matched_row)
    page_id = matched_row["id"]
    page_url = matched_row.get("url")
    existing_hash = row_summary.get("Content Hash", "")

    if existing_hash == content_hash:
        print(f"  Hash unchanged — skipped.")
        return "skipped"

    print(f"  Hash changed — updating...")
    syncing_props = build_page_properties(
        date_str=date_str,
        source_path=source_path,
        original_title=original_title,
        content_hash=content_hash,
        sync_status="Syncing",
        mirror_page_url=page_url,
    )
    notion_update_page_properties(page_id, headers, syncing_props)
    notion_replace_children(page_id, headers, blocks)

    final_props = build_page_properties(
        date_str=date_str,
        source_path=source_path,
        original_title=original_title,
        content_hash=content_hash,
        sync_status="Synced",
        mirror_page_url=page_url,
    )
    notion_update_page_properties(page_id, headers, final_props)
    print(f"  Updated: {page_url}")
    return "updated"


def mark_error(database_id: str, headers: dict, journal_file: Path) -> None:
    """Best-effort: set Sync Status to Error for the matched row."""
    try:
        source_path = build_source_path(journal_file)
        matched = notion_query_by_source_path(database_id, headers, source_path)
        if matched:
            page_id = matched[0]["id"]
            notion_update_page_properties(
                page_id,
                headers,
                {"Sync Status": {"status": {"name": "Error"}}},
            )
    except Exception:
        pass  # best-effort; don't mask the original error


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    if not NOTION_API_KEY:
        print("NOTION_API_KEY is missing")
        return

    if not NOTION_LOGSEQ_MIRROR_DATABASE_URL:
        print("NOTION_LOGSEQ_MIRROR_DATABASE_URL is missing")
        return

    headers = get_headers()
    database_id = extract_notion_id_from_url(NOTION_LOGSEQ_MIRROR_DATABASE_URL)
    db_payload = notion_get_database(database_id, headers)
    db_title = get_title_text(db_payload.get("title", []))
    print(f"Database: {db_title}")

    changed_files_env = os.getenv("CHANGED_FILES", "").strip().rstrip(",")
    if changed_files_env:
        journal_files = [
            Path(f) for f in changed_files_env.split(",")
            if f.strip() and JOURNAL_FILE_RE.match(Path(f.strip()).name)
        ]
        journal_files.sort()
        print(f"Running in incremental mode: {len(journal_files)} changed file(s).\n")
    else:
        journal_files = get_all_journal_files()
        print(f"Running in full-scan mode: {len(journal_files)} file(s).\n")

    results = {"created": 0, "updated": 0, "skipped": 0, "error": 0}

    for jf in journal_files:
        print(f"[{jf.name}]")
        try:
            status = sync_one_journal(jf, database_id, headers)
            results[status] += 1
        except Exception as exc:
            print(f"  ERROR: {exc}")
            results["error"] += 1
            mark_error(database_id, headers, jf)

    print("\n" + "=" * 40)
    print("Sync complete.")
    print(f"  Created : {results['created']}")
    print(f"  Updated : {results['updated']}")
    print(f"  Skipped : {results['skipped']}")
    print(f"  Errors  : {results['error']}")
    print("=" * 40)

    if results["error"] > 0:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
