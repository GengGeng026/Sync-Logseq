#!/bin/bash

# 設置日誌文件
LOG_FILE="/Users/mac/Documents/Sync-Logseq/sync_log.txt"
LOCKFILE="/tmp/auto_sync.lock"

# 確保只有一個腳本實例運行
if [ -e "$LOCKFILE" ] && kill -0 $(cat "$LOCKFILE") 2>/dev/null; then
    echo "已有另一個實例在運行" >> $LOG_FILE
    exit 1
fi
echo $$ > "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT

# 進入目錄
cd /Users/mac/Documents/Sync-Logseq

sync_repo() {
    echo "==== 開始同步 $(date) ====" >> $LOG_FILE
    
    # 1. 首先保存本地修改
    git add -A >> $LOG_FILE 2>&1
    if ! git diff --staged --quiet; then
        echo "保存本地修改" >> $LOG_FILE
        git commit -m "Auto-save: $(date)" >> $LOG_FILE 2>&1
    fi
    
    # 2. 獲取遠程更新
    echo "獲取遠程更新" >> $LOG_FILE
    git fetch origin >> $LOG_FILE 2>&1
    
    # 3. 重置為遠程狀態 (遠程優先策略)
    echo "重置到遠程狀態" >> $LOG_FILE
    git reset --soft origin/main >> $LOG_FILE 2>&1
    
    # 4. 如果有變更，提交並推送
    if ! git diff --staged --quiet; then
        echo "提交本地變更" >> $LOG_FILE
        git commit -m "Mac 自動同步: $(date)" >> $LOG_FILE 2>&1
        echo "推送變更" >> $LOG_FILE
        git push origin main >> $LOG_FILE 2>&1
    else
        echo "沒有需要同步的變更" >> $LOG_FILE
    fi
    
    echo "==== 同步完成 $(date) ====" >> $LOG_FILE
}

# 執行初次同步
sync_repo

# 循環檢查
while true; do
    sleep 60
    sync_repo
done
