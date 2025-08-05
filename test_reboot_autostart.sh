#!/bin/bash
# 重啟測試腳本 - 模擬系統重啟後的自動啟動

echo "=== 重啟自動啟動測試 ==="

# 1. 停止所有相關服務
echo "1. 停止所有 Logseq 同步服務..."
launchctl unload ~/Library/LaunchAgents/com.logseq.sync.plist 2>/dev/null
pkill -f logseq_sync
pkill -f fswatch
sleep 5

# 2. 檢查是否完全停止
echo "2. 檢查服務停止狀態..."
if pgrep -f "logseq_sync" > /dev/null; then
    echo "❌ 服務仍在運行，強制停止..."
    pkill -9 -f logseq_sync
    pkill -9 -f fswatch
    sleep 3
fi

if ! pgrep -f "logseq_sync" > /dev/null; then
    echo "✅ 所有服務已停止"
else
    echo "❌ 無法完全停止服務"
    exit 1
fi

# 3. 模擬重啟 - 重新加載 LaunchAgent
echo "3. 模擬系統重啟 - 重新加載 LaunchAgent..."
launchctl load ~/Library/LaunchAgents/com.logseq.sync.plist

# 4. 等待服務啟動
echo "4. 等待服務啟動（30秒）..."
sleep 30

# 5. 檢查自動啟動結果
echo "5. 檢查自動啟動結果..."
if pgrep -f "logseq_sync" > /dev/null && pgrep -f "fswatch" > /dev/null; then
    echo "✅ 自動啟動成功！"
    echo ""
    echo "運行中的進程："
    ps aux | grep -E "(logseq_sync|fswatch)" | grep -v grep
    echo ""
    echo "LaunchAgent 狀態："
    launchctl list com.logseq.sync
else
    echo "❌ 自動啟動失敗"
    echo ""
    echo "檢查錯誤日誌："
    tail -10 /Users/mac/Documents/Sync-Logseq/launchd_stderr.log
fi

echo ""
echo "=== 測試完成 ==="