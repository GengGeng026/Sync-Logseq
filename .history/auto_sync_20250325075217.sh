#!/bin/sh

# 設置日誌文件
LOG_FILE="/Users/mac/Documents/Sync-Logseq/sync_log.txt"

# 記錄腳本啟動
echo "=== Simple sync started at $(date) ===" >> $LOG_FILE
echo "User: $(whoami)" >> $LOG_FILE

# 進入工作目錄
cd /Users/mac/Documents/Sync-Logseq || exit 1
echo "Working directory: $(pwd)" >> $LOG_FILE

# Git 操作
git add -A
git commit -m "Auto-sync: $(date)" >> $LOG_FILE 2>&1
git push origin main >> $LOG_FILE 2>&1

echo "=== Simple sync completed at $(date) ===" >> $LOG_FILE