import os
import re
import requests

NOTION_API_KEY = os.getenv("NOTION_API_KEY")
NOTION_LOGSEQ_MIRROR_DATABASE_URL = os.getenv("NOTION_LOGSEQ_MIRROR_DATABASE_URL")


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

    headers = {
        "Authorization": f"Bearer {NOTION_API_KEY}",
        "Notion-Version": "2022-06-28",
    }

    response = requests.get(
        f"https://api.notion.com/v1/databases/{database_id}",
        headers=headers,
        timeout=30,
    )

    print("HTTP status:", response.status_code)
    print("Response body:")
    print(response.text)


if __name__ == "__main__":
    main()
