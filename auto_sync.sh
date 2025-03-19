#!/bin/bash

# 进入 Sync-Logseq 目录
cd /Users/mac/Documents/Sync-Logseq

# 设置日志文件
LOG_FILE="/Users/mac/Documents/Sync-Logseq/sync_log.txt"

# 監聽 Logseq 目錄內的變化
fswatch -o --exclude ".git" /Users/mac/Documents/Sync-Logseq | while read -r change; do
    # 输出当前时间，记录同步开始时间
    echo "Sync started at $(date)" >> $LOG_FILE

    # 等待 5 秒，防止頻繁觸發
    sleep 5


    # 檢查是否有遠端更新
    echo "Fetching remote changes..." >> $LOG_FILE
    git fetch origin main >> $LOG_FILE 2>&1

    # 檢查是否有本地未推送的變更
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse origin/main)
    BASE=$(git merge-base @ origin/main)

    if [ "$LOCAL" = "$REMOTE" ]; then
        echo "Already up to date" >> $LOG_FILE
    elif [ "$LOCAL" = "$BASE" ]; then
        echo "Local is behind, pulling updates..." >> $LOG_FILE
        git pull --rebase origin main >> $LOG_FILE 2>&1
    elif [ "$REMOTE" = "$BASE" ]; then
        echo "Local is ahead, pushing updates..." >> $LOG_FILE
        git push origin main >> $LOG_FILE 2>&1
    else
        echo "Local and remote have diverged, attempting auto-merge..." >> $LOG_FILE
        git pull --rebase origin main >> $LOG_FILE 2>&1 || git rebase 
--abort
    fi

    # 如果本地有變更，則提交並推送
    git add -A
    if ! git diff --cached --quiet; then
        echo "Changes detected, committing..." >> $LOG_FILE
        git commit -m "Auto-sync: $(date)" >> $LOG_FILE 2>&1
        git push origin main >> $LOG_FILE 2>&1
    else
        echo "No changes detected" >> $LOG_FILE
    fi

    # 输出同步完成时间
    echo "Sync completed at $(date)" >> $LOG_FILE
done

