#!/bin/bash

# 进入 Sync-Logseq 目录
cd /Users/mac/Documents/Sync-Logseq

# 输出当前时间，记录同步开始时间
echo "Sync started at $(date)" >> /Users/mac/Documents/Sync-Logseq/sync_log.txt

# 拉取远程仓库的更新
echo "Pulling changes..." >> /Users/mac/Documents/Sync-Logseq/sync_log.txt
git pull origin main >> /Users/mac/Documents/Sync-Logseq/sync_log.txt 2>&1

# 检查是否有更新，并提交
commit_message=$(git diff --staged --oneline)
if [ -n "$commit_message" ]; then
    echo "Changes detected, committing..." >> /Users/mac/Documents/Sync-Logseq/sync_log.txt
    git commit -m "Changes: $commit_message" >> /Users/mac/Documents/Sync-Logseq/sync_log.txt 2>&1
    git push origin main >> /Users/mac/Documents/Sync-Logseq/sync_log.txt 
2>&1
else
    echo "No changes detected" >> 
/Users/mac/Documents/Sync-Logseq/sync_log.txt
fi

# 输出同步完成时间
echo "Sync completed at $(date)" >> 
/Users/mac/Documents/Sync-Logseq/sync_log.txt

