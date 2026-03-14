import json
import os
import re

import requests

NOTION_API_KEY = os.getenv("NOTION_API_KEY")
NOTION_LOGSEQ_MIRROR_DATABASE_URL = os.getenv("NOTION_LOGSEQ_MIRROR_DATABASE_URL")
NOTION_VERSION = "2022-06-28"


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

    if "Mirror Title" in properties:
        mirror_title = get_title_text(properties["Mirror Title"].get("title", []))

    if "Source Path" in properties:
        source_path = get_rich_text_text(properties["Source Path"].get("rich_text", []))

    if "Sync Status" in properties:
        status_obj = properties["Sync Status"].get("status") or {}
        sync_status = status_obj.get("name", "")

    return {
        "url": row.get("url", ""),
        "Mirror Title": mirror_title,
        "Source Path": source_path,
        "Sync Status": sync_status,
    }


def main():
    if not NOTION_API_KEY:
        print("NOTION_API_KEY is missing")
        return

    if not NOTION_LOGSEQ_MIRROR_DATABASE_URL:
        print("NOTION_LOGSEQ_MIRROR_DATABASE_URL is missing")
        return

    print("NOTION_API_KEY is available")
    print("NOTION_LOGSEQ_MIRROR_DATABASE_URL is available")

    database_id = extract_notion_id_from_url(NOTION_LOGSEQ_MIRROR_DATABASE_URL)
    print("Parsed database ID:", database_id)

    headers = get_headers()

    database_response = requests.get(
        f"https://api.notion.com/v1/databases/{database_id}",
        headers=headers,
        timeout=30,
    )

    print("Database read HTTP status:", database_response.status_code)
    if database_response.status_code != 200:
        print("Database read response body:")
        print(database_response.text)
        return

    database_payload = database_response.json()
    database_title = get_title_text(database_payload.get("title", []))
    print("Resolved database title:", database_title)

    query_response = requests.post(
        f"https://api.notion.com/v1/databases/{database_id}/query",
        headers=headers,
        json={"page_size": 5},
        timeout=30,
    )

    print("Database query HTTP status:", query_response.status_code)
    if query_response.status_code != 200:
        print("Database query response body:")
        print(query_response.text)
        return

    query_payload = query_response.json()
    results = query_payload.get("results", [])
    print("Rows returned:", len(results))

    summaries = [summarize_row(row) for row in results]
    print("Row summaries:")
    print(json.dumps(summaries, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
