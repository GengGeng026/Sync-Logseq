#!/bin/bash
# 等待系統完全啟動
sleep 5

# 檢查是否已經在運行
if pgrep -f "logseq_sync.sh" > /dev/null; then
    echo "$(date): Logseq sync 已經在運行中" >> "$HOME/.logseq_autostart.log"
    exit 0
fi

# 啟動 Logseq 同步服務
cd "/Users/mac/Documents/Sync-Logseq"
echo "$(date): 開始啟動 Logseq 同步服務..." >> "$HOME/.logseq_autostart.log"
./start_logseq_sync.sh >> "$HOME/.logseq_autostart.log" 2>&1
