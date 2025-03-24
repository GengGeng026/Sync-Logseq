#!/bin/bash

# 進入 Logseq 目錄
cd /Users/mac/Documents/Sync-Logseq

# 設置日誌文件
LOG_FILE="/Users/mac/Documents/Sync-Logseq/sync_log.txt"

# 監聽 Logseq 目錄內的變化
fswatch -o --exclude ".git" /Users/mac/Documents/Sync-Logseq | while read -r change; do
    echo "Sync started at $(date)" >> $LOG_FILE

    # 拉取最新變更
    echo "Pulling changes..." >> $LOG_FILE
    git pull --rebase origin main >> $LOG_FILE 2>&1 || {
        echo "Pull failed. Branch may have diverged. Attempting merge..." >> $LOG_FILE
        git pull --strategy recursive --strategy-option theirs origin main >> $LOG_FILE 2>&1 || {
            echo "Auto-merge failed. Manual intervention required." >> $LOG_FILE
            exit 1
        }
    }

    # 如果有變更，則提交並推送
    git add -A
    if ! git diff --cached --quiet; then
        echo "Changes detected, committing..." >> $LOG_FILE
        git commit -m "Auto-sync: $(date)" >> $LOG_FILE 2>&1
        echo "Pushing changes..." >> $LOG_FILE
        git push origin main >> $LOG_FILE 2>&1
    else
        echo "No changes detected" >> $LOG_FILE
    fi

    # 新增步驟：檢查本地是否 ahead，若是則推送
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main)
    if [ "$LOCAL" != "$REMOTE" ]; then
        echo "Local branch ahead, pushing remaining commits..." >> $LOG_FILE
        git push origin main >> $LOG_FILE 2>&1
    fi

    echo "Sync completed at $(date)" >> $LOG_FILE
done
