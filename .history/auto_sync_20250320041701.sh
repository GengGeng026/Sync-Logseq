#!/bin/bash

# 進入 Sync-Logseq 目錄
cd /Users/mac/Documents/Sync-Logseq

# 設置日誌文件
LOG_FILE="/Users/mac/Documents/Sync-Logseq/sync_log.txt"

# 監聽 Logseq 目錄內的變化，並每 60 秒檢查一次遠端變更
while true; do
    # 監測本地變更
    fswatch -o --exclude ".git" --exclude "journals" --exclude "logseq/bak" /Users/mac/Documents/Sync-Logseq | while read change; do
        echo "File change detected: $change" >> $LOG_FILE
    done &

    # **每 60 秒檢查 GitHub 是否有新的變更**
    while true; do
        echo "Checking for remote updates..." >> $LOG_FILE
        git fetch origin

        # **確保本地分支與遠端對齊**
        git rebase origin/main >> $LOG_FILE 2>&1

        # **如果遠端有更新，則自動拉取**
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse origin/main)

        if [ "$LOCAL" != "$REMOTE" ]; then
            echo "Remote changes detected, pulling updates..." >> $LOG_FILE
            git pull --rebase origin main >> $LOG_FILE 2>&1
        else
            echo "Already up to date." >> $LOG_FILE
        fi

        sleep 60  # 每 60 秒檢查一次
    done

done
