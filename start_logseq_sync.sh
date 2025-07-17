#!/bin/bash
# 啟動 Logseq 同步服務的腳本

# 檢查是否已經在運行
if pgrep -f "logseq_sync.sh" > /dev/null; then
    echo "Logseq sync 已經在運行中"
    exit 0
fi

# 設置工作目錄
cd "/Users/mac/Documents/Sync-Logseq" || exit 1

# 啟動同步服務
echo "$(date): 啟動 Logseq 自動同步服務..."
nohup ./logseq_sync.sh > /dev/null 2>&1 &

# 等待一下確保啟動成功
sleep 2

# 檢查是否成功啟動
if pgrep -f "logseq_sync.sh" > /dev/null; then
    echo "$(date): Logseq 自動同步服務啟動成功"
    echo "$(date): fswatch 監聽進程: $(pgrep -f fswatch)"
else
    echo "$(date): Logseq 自動同步服務啟動失敗"
    exit 1
fi