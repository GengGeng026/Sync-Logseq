#!/bin/bash

# 設置日誌文件
LOG_FILE="/Users/mac/Documents/Sync-Logseq/sync_log.txt"

# 進入工作目錄
cd /Users/mac/Documents/Sync-Logseq

# 啟動確認
echo "=== Sync service started at $(date) ===" > $LOG_FILE
echo "Working directory: $(pwd)" >> $LOG_FILE
echo "User: $(whoami)" >> $LOG_FILE
echo "PATH: $PATH" >> $LOG_FILE

# 配置 Git 避免身份驗證提示
git config --local credential.helper store
git config --local user.name "Auto Sync"
git config --local user.email "auto-sync@example.com"

# 無限循環：每15秒執行一次同步
while true; do
    echo "=== Sync check at $(date) ===" >> $LOG_FILE
    
    # 1. 始終拉取遠程更新
    echo "Fetching origin" >> $LOG_FILE
    git fetch origin >> $LOG_FILE 2>&1
    
    # 2. 檢查是否落後於遠程
    if git status | grep -q "Your branch is behind"; then
        echo "本地分支落後於遠程，正在拉取..." >> $LOG_FILE
        git pull --no-edit origin main >> $LOG_FILE 2>&1
    else
        echo "本地和遠程分支同步，無需處理" >> $LOG_FILE
    fi
    
    # 3. 添加所有變更
    git add -A >> $LOG_FILE 2>&1
    
    # 4. 如果有變更，提交並推送
    if ! git diff --staged --quiet; then
        echo "=== 檢測到變更: $(git diff --staged --name-only | wc -l) ===" >> $LOG_FILE
        git commit -m "Auto-sync: $(date)" >> $LOG_FILE 2>&1
        
        echo "本地分支領先遠程，正在推送..." >> $LOG_FILE
        git push origin main >> $LOG_FILE 2>&1
    fi
    
    echo "=== Sync completed at $(date) ===" >> $LOG_FILE
    
    # 等待15秒
    sleep 15
done