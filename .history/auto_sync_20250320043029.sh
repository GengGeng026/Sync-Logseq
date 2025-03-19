#!/bin/bash

# 進入 Logseq 目錄
cd /Users/mac/Documents/Sync-Logseq

# 設置日志文件
LOG_FILE="/Users/mac/Documents/Sync-Logseq/sync_log.txt"

# 監聽 Logseq 目錄內的變化
fswatch -o /Users/mac/Documents/Sync-Logseq | while read change; do
    echo "Sync started at $(date)" >> $LOG_FILE

    # 拉取最新變更
    echo "Pulling changes..." >> $LOG_FILE
    git pull origin main >> $LOG_FILE 2>&1

    # 如果有變更，則提交並推送
    git add -A
    if ! git diff --cached --quiet; then
        echo "Changes detected, committing..." >> $LOG_FILE
        git commit -m "Auto-sync: $(date)" >> $LOG_FILE 2>&1
        git push origin main >> $LOG_FILE 2>&1
    else
        echo "No changes detected" >> $LOG_FILE
    fi

    echo "Sync completed at $(date)" >> $LOG_FILE
done
