#!/bin/bash

LOG_FILE="/Users/mac/Documents/Sync-Logseq/fetch_test.log"
echo "=== 開始 fetch 測試 $(date) ===" > $LOG_FILE

cd /Users/mac/Documents/Sync-Logseq || exit 1
echo "當前目錄: $(pwd)" >> $LOG_FILE
echo "Git狀態 (運行前): $(git status --porcelain)" >> $LOG_FILE

echo "執行: git remote -v" >> $LOG_FILE
git remote -v >> $LOG_FILE 2>&1

echo "執行: git fetch origin" >> $LOG_FILE
git fetch origin >> $LOG_FILE 2>&1
FETCH_RESULT=$?

echo "Fetch 結果碼: $FETCH_RESULT" >> $LOG_FILE
echo "Git狀態 (運行後): $(git status --porcelain)" >> $LOG_FILE

# 檢查是否有遠程變更
git rev-list HEAD..origin/main --count >> $LOG_FILE 2>&1

echo "=== 測試完成 $(date) ===" >> $LOG_FILE
EOL
