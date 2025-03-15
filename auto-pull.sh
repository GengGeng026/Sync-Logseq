#!/bin/bash
REPO_DIR="#!/bin/bash
REPO_DIR="/Users/mac/Documents/Sync-Logseq""
cd "$REPO_DIR"
while true; do
    # 監控 Logseq 資料夾內任一檔案的修改
    fswatch -1 "$REPO_DIR"
    echo "Detected change, running git pull..."
    git pull origin main
done

