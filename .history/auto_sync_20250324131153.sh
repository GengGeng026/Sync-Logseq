#!/bin/bash

# 進入 Logseq 目錄
cd /Users/mac/Documents/Sync-Logseq

# 設置日誌文件
LOG_FILE="/Users/mac/Documents/Sync-Logseq/sync_log.txt"

# 首先檢查並推送任何已有的提交
echo "Initial check at $(date)" >> $LOG_FILE

# 更新遠程分支信息
git fetch origin >> $LOG_FILE 2>&1

# 檢查本地是否領先遠程
AHEAD=$(git rev-list --count origin/main..main)
if [ "$AHEAD" -gt 0 ]; then
    echo "Local branch ahead by $AHEAD commits, pushing..." >> $LOG_FILE
    git push origin main >> $LOG_FILE 2>&1
fi

# 監聽 Logseq 目錄內的變化
fswatch -o --exclude ".git" /Users/mac/Documents/Sync-Logseq | while read -r change; do
    echo "Sync started at $(date)" >> $LOG_FILE

    # 拉取最新變更
    echo "Pulling changes..." >> $LOG_FILE
    git pull --rebase origin main >> $LOG_FILE 2>&1 || {
        echo "Pull failed. Branch may have diverged. Attempting merge..." >> $LOG_FILE
        git pull --no-edit --strategy recursive --strategy-option theirs origin main >> $LOG_FILE 2>&1 || {
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

    # 檢查本地是否 ahead，若是則推送
    AHEAD=$(git rev-list --count origin/main..main)
    if [ "$AHEAD" -gt 0 ]; then
        echo "Local branch ahead by $AHEAD commits, pushing..." >> $LOG_FILE
        git push origin main >> $LOG_FILE 2>&1
    fi

    echo "Sync completed at $(date)" >> $LOG_FILE
done
