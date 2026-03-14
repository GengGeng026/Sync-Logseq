import os

def main():
    notion_api_key = os.getenv("NOTION_API_KEY")
    notion_database_url = os.getenv("NOTION_LOGSEQ_MIRROR_DATABASE_URL")

    if notion_api_key:
        print("NOTION_API_KEY is available")
    else:
        print("NOTION_API_KEY is missing")

    if notion_database_url:
        print("NOTION_LOGSEQ_MIRROR_DATABASE_URL is available")
    else:
        print("NOTION_LOGSEQ_MIRROR_DATABASE_URL is missing")

if __name__ == "__main__":
    main()
