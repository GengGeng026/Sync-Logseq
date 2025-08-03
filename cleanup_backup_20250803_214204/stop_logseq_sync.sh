#!/bin/bash
# 停止 Logseq 同步服務的腳本

echo "$(date): 停止 Logseq 自動同步服務..."

# 停止所有相關進程
pkill -f logseq_sync.sh
pkill -f fswatch

# 等待進程完全停止
sleep 2

# 檢查是否成功停止
if ! pgrep -f "logseq_sync.sh" > /dev/null; then
    echo "$(date): Logseq 自動同步服務已停止"
else
    echo "$(date): 強制停止殘留進程..."
    pkill -9 -f logseq_sync.sh
    pkill -9 -f fswatch
fi