#!/bin/bash
# 測試自動啟動功能

echo "=== 測試 Logseq 自動啟動功能 ==="

# 1. 停止現有服務
echo "1. 停止現有服務..."
./stop_logseq_sync.sh

# 2. 等待進程完全停止
sleep 3

# 3. 檢查是否已停止
echo "2. 檢查服務狀態..."
if pgrep -f "logseq_sync.sh" > /dev/null; then
    echo "❌ 服務仍在運行"
    exit 1
else
    echo "✅ 服務已停止"
fi

# 4. 模擬重啟後的自動啟動
echo "3. 模擬自動啟動..."
source ~/.zshrc

# 5. 等待啟動
sleep 35

# 6. 檢查是否自動啟動成功
echo "4. 檢查自動啟動結果..."
if pgrep -f "logseq_sync.sh" > /dev/null; then
    echo "✅ 自動啟動成功！"
    echo "運行中的進程："
    ps aux | grep -E "(logseq_sync|fswatch)" | grep -v grep
else
    echo "❌ 自動啟動失敗"
    echo "檢查日誌："
    tail -10 ~/.logseq_autostart.log 2>/dev/null || echo "無日誌文件"
fi