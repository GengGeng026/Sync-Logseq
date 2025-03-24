#!/bin/bash

# 設置日誌文件
LOG_FILE="/Users/mac/Documents/Sync-Logseq/sync_log.txt"
echo "=== 腳本啟動於 $(date) ===" >> $LOG_FILE

# 進入 Logseq 目錄
cd /Users/mac/Documents/Sync-Logseq

# 同步函數 - 簡化版本
do_sync() {
    echo "--- 開始同步 $(date) ---" >> $LOG_FILE
    
    # 強制獲取最新的遠程信息
    git fetch --all --prune >> $LOG_FILE 2>&1
    
    # 提交任何本地變更
    git add -A >> $LOG_FILE 2>&1
    if ! git diff --cached --quiet; then
        echo "發現本地變更，提交中..." >> $LOG_FILE
        git commit -m "Auto-sync: $(date)" >> $LOG_FILE 2>&1
    fi
    
    # 檢查是否落後於遠程
    if git status | grep -q "Your branch is behind"; then
        echo "本地分支落後於遠程，拉取中..." >> $LOG_FILE
        git pull --no-edit origin main >> $LOG_FILE 2>&1
    fi
    
    # 檢查是否領先於遠程
    if git status | grep -q "Your branch is ahead"; then
        echo "本地分支領先遠程，推送中..." >> $LOG_FILE
        git push origin main >> $LOG_FILE 2>&1
    fi
    
    # 檢查是否分歧
    if git status | grep -q "diverged"; then
        echo "分支已分歧，嘗試合併..." >> $LOG_FILE
        git pull --no-edit origin main >> $LOG_FILE 2>&1
        git push origin main >> $LOG_FILE 2>&1
    fi
    
    echo "--- 同步完成 $(date) ---" >> $LOG_FILE
}

# 初始同步
do_sync

# 定期執行同步
while true; do
    sleep 30
    do_sync
done
