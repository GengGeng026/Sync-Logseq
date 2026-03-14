import os

def main():
    notion_api_key = os.getenv("NOTION_API_KEY")
    if notion_api_key:
        print("NOTION_API_KEY is available")
    else:
        print("NOTION_API_KEY is missing")

if __name__ == "__main__":
    main()
