import os

def mask(value: str, keep: int = 12) -> str:
    if not value:
        return ""
    if len(value) <= keep:
        return value
    return value[:keep] + "..."

def main():
    notion_api_key = os.getenv("NOTION_API_KEY")
    notion_database_url = os.getenv("NOTION_LOGSEQ_MIRROR_DATABASE_URL")

    if notion_api_key:
        print("NOTION_API_KEY is available")
        print("NOTION_API_KEY preview:", mask(notion_api_key))
    else:
        print("NOTION_API_KEY is missing")

    if notion_database_url:
        print("NOTION_LOGSEQ_MIRROR_DATABASE_URL is available")
        print("NOTION_LOGSEQ_MIRROR_DATABASE_URL preview:", mask(notion_database_url, keep=60))
    else:
        print("NOTION_LOGSEQ_MIRROR_DATABASE_URL is missing")

if __name__ == "__main__":
    main()
