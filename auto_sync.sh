#!/bin/bash

# 进入 Sync-Logseq 目录
cd /Users/mac/Documents/Sync-Logseq

# 设置日志文件
LOG_FILE="/Users/mac/Documents/Sync-Logseq/sync_log.txt"

# 无限循环，每 15 秒检查一次
while true; do
    # 输出当前时间，记录同步开始时间
    echo "Sync started at $(date)" >> $LOG_FILE

    # 拉取远程仓库的更新
    echo "Pulling changes..." >> $LOG_FILE
    git pull origin main >> $LOG_FILE 2>&1

    # 添加所有新变更
    git add .

    # 检查是否有更新，并提交
    commit_message=$(git status --porcelain)
    if [ -n "$commit_message" ]; then
        echo "Changes detected, committing..." >> $LOG_FILE
        git commit -m "Auto-sync: $(date)" >> $LOG_FILE 2>&1
        git push origin main >> $LOG_FILE 2>&1
    else
        echo "No changes detected" >> $LOG_FILE
    fi

    # 输出同步完成时间
    echo "Sync completed at $(date)" >> $LOG_FILE

    # 暂停 15 秒
    sleep 60
done

