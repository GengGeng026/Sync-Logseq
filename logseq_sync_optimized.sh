#!/bin/bash
# 一次性同步腳本：執行後立刻退出，不做任何長駐監控

# 變更如下兩個變數為你的實際目錄
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/sync_optimized.log"

# 進入同步資料夾
cd "$REPO_DIR" || exit 1

# 記錄開始時間
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚀 開始同步" >> "$LOG_FILE" 2>&1

# 執行 Git 操作
git pull --rebase >> "$LOG_FILE" 2>&1
git push       >> "$LOG_FILE" 2>&1

# 記錄結束時間
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 同步完成" >> "$LOG_FILE" 2>&1
