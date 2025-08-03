#!/bin/bash
# Logseq 守護進程 - 確保同步服務永遠運行

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/daemon.log"
SYNC_SCRIPT="$REPO_DIR/logseq_sync.sh"

cd "$REPO_DIR" || exit 1

# 守護進程主循環
while true; do
    # 檢查同步腳本是否在運行
    if ! pgrep -f "logseq_sync.sh" > /dev/null; then
        echo "$(date): 🔄 檢測到同步服務停止，正在重啟..." >> "$LOG_FILE"
        
        # 清理可能的殭屍進程
        pkill -f "fswatch.*Sync-Logseq" 2>/dev/null || true
        
        # 等待一下確保清理完成
        sleep 2
        
        # 重啟同步服務
        nohup "$SYNC_SCRIPT" > /dev/null 2>&1 &
        
        # 等待確認啟動
        sleep 5
        
        if pgrep -f "logseq_sync.sh" > /dev/null; then
            echo "$(date): ✅ 同步服務已重啟" >> "$LOG_FILE"
        else
            echo "$(date): ❌ 同步服務重啟失敗" >> "$LOG_FILE"
        fi
    fi
    
    # 每30秒檢查一次
    sleep 30
done