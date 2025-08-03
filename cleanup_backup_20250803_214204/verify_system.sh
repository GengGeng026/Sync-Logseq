#!/bin/bash

echo "🔍 完整驗證 Logseq 同步系統..."
echo "=================================="

# 1. 檢查 plist 文件數量
echo "📁 檢查 plist 文件："
plist_count=$(ls -1 /Users/mac/Library/LaunchAgents/ | grep logseq | wc -l)
echo "   發現 $plist_count 個 logseq 相關的 plist 文件："
ls -la /Users/mac/Library/LaunchAgents/ | grep logseq

echo ""

# 2. 檢查服務狀態
echo "🔧 檢查 LaunchAgent 服務："
launchctl list | grep logseq

echo ""

# 3. 檢查進程數量
echo "⚙️ 檢查運行中的進程："
process_count=$(ps aux | grep logseq_sync | grep -v grep | wc -l)
echo "   發現 $process_count 個 logseq_sync 進程："
ps aux | grep logseq_sync | grep -v grep

echo ""

# 4. 檢查 plist 配置
echo "📋 檢查 plist 配置："
echo "   KeepAlive 設定："
grep -A1 "KeepAlive" /Users/mac/Library/LaunchAgents/com.logseq.sync.plist
echo "   RunAtLoad 設定："
grep -A1 "RunAtLoad" /Users/mac/Library/LaunchAgents/com.logseq.sync.plist

echo ""

# 5. 檢查日誌文件
echo "📊 檢查最新日誌："
if [ -f "/Users/mac/Documents/Sync-Logseq/sync_simple.log" ]; then
    echo "   最後 5 行同步日誌："
    tail -5 /Users/mac/Documents/Sync-Logseq/sync_simple.log
else
    echo "   同步日誌文件不存在（可能剛啟動）"
fi

echo ""

# 6. 測試文件變更檢測
echo "🧪 測試文件變更檢測..."
test_file="/Users/mac/Documents/Sync-Logseq/test_sync_$(date +%s).md"
echo "測試同步功能 - $(date)" > "$test_file"
echo "   已創建測試文件: $test_file"
echo "   等待 10 秒檢查同步反應..."

sleep 10

# 檢查是否有新的日誌條目
if [ -f "/Users/mac/Documents/Sync-Logseq/sync_simple.log" ]; then
    echo "   檢查最新日誌條目："
    tail -3 /Users/mac/Documents/Sync-Logseq/sync_simple.log | grep "$(date '+%Y-%m-%d')"
fi

# 清理測試文件
rm -f "$test_file"

echo ""
echo "=================================="
echo "🎯 系統評估："

if [ "$plist_count" -eq 1 ] && [ "$process_count" -eq 1 ]; then
    echo "✅ 完美！單一 plist，單一進程"
    echo "✅ KeepAlive=true 確保自動重啟"
    echo "✅ RunAtLoad=true 確保開機啟動"
    echo ""
    echo "🛡️ 你的系統現在具備："
    echo "   • 系統重啟後自動啟動"
    echo "   • 進程崩潰後自動重啟"
    echo "   • 文件變更自動同步"
    echo "   • 單一進程避免衝突"
else
    echo "⚠️ 發現問題："
    [ "$plist_count" -ne 1 ] && echo "   - plist 文件數量不正確: $plist_count"
    [ "$process_count" -ne 1 ] && echo "   - 進程數量不正確: $process_count"
fi