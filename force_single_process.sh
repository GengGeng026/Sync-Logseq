#!/bin/bash

echo "🚨 強制清理並確保單一 Logseq 同步進程..."
echo "=============================================="

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$REPO_DIR" || exit

# 1. 停止並卸載 LaunchAgent 服務
echo "🔄 停止並卸載 LaunchAgent 服務..."
launchctl unload ~/Library/LaunchAgents/com.logseq.sync.plist 2>/dev/null

# 2. 強制殺死所有 logseq_sync_optimized.sh 進程
echo "🔪 強制殺死所有 logseq_sync_optimized.sh 進程..."
pkill -9 -f "logseq_sync_optimized.sh" 2>/dev/null || true

# 3. 刪除進程鎖文件 (以防萬一)
echo "🗑️ 刪除進程鎖文件..."
rm -f "$REPO_DIR/.sync_lock"

# 4. 等待幾秒，確保所有進程完全停止
echo "⏳ 等待 5 秒確保進程停止..."
sleep 5

# 5. 重新載入 LaunchAgent 服務
echo "🚀 重新載入 LaunchAgent 服務..."
launchctl load ~/Library/LaunchAgents/com.logseq.sync.plist

# 6. 等待幾秒，讓服務有時間啟動
echo "⏳ 等待 5 秒讓服務啟動..."
sleep 5

# 7. 驗證進程狀態
echo "📊 驗證進程狀態："
process_count=$(ps aux | grep logseq_sync_optimized.sh | grep -v grep | wc -l)

if [ "$process_count" -eq 1 ]; then
    echo "✅ 成功！現在只有一個 logseq_sync_optimized.sh 進程在運行。"
    echo "   進程詳情："
    ps aux | grep logseq_sync_optimized.sh | grep -v grep
else
    echo "❌ 警告：仍有 $process_count 個進程在運行。可能需要手動檢查。"
    echo "   進程詳情："
    ps aux | grep logseq_sync_optimized.sh | grep -v grep
fi

# 8. 檢查 LaunchAgent 狀態
echo ""
echo "📊 檢查 LaunchAgent 狀態："
launchctl list | grep com.logseq.sync

echo ""
echo "=============================================="
echo "✅ 強制清理和單一進程設置完成！"
echo ""
echo "你的 Logseq 自動同步系統現在應該是穩定且單一運行的。"
echo "下次重啟系統後也會保持單一進程運行。"
