import os
import requests

NOTION_API_KEY = os.getenv("NOTION_API_KEY")

def main():
    if not NOTION_API_KEY:
        print("NOTION_API_KEY is missing")
        return

    print("NOTION_API_KEY is available")

    headers = {
        "Authorization": f"Bearer {NOTION_API_KEY}",
        "Notion-Version": "2022-06-28",
    }

    response = requests.get(
        "https://api.notion.com/v1/users/me",
        headers=headers,
        timeout=30,
    )

    print("HTTP status:", response.status_code)
    print("Response body:")
    print(response.text)

if __name__ == "__main__":
    main()
