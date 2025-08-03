#!/bin/bash

echo "🧹 開始清理和優化 Logseq 同步設置..."

# 停止所有相關進程
echo "停止現有服務..."
launchctl unload /Users/mac/Library/LaunchAgents/com.logseq.sync.plist 2>/dev/null
pkill -f "logseq_sync.sh" 2>/dev/null

# 刪除重複的 plist
echo "清理重複的 plist 文件..."
rm -f /Users/mac/Library/LaunchAgents/com.logseq.sync.plist

# 確保 logseq_unified.sh 有執行權限
chmod +x /Users/mac/Documents/Sync-Logseq/logseq_unified.sh

# 重新載入原有的 autostart 服務
echo "重新載入統一同步服務..."
launchctl unload /Users/mac/Library/LaunchAgents/com.user.logseq.autostart.plist 2>/dev/null
launchctl load /Users/mac/Library/LaunchAgents/com.user.logseq.autostart.plist

echo "✅ 清理完成！"
echo ""
echo "現在你只有一個統一的同步系統："
echo "- LaunchAgent: com.user.logseq.autostart"
echo "- 腳本: logseq_unified.sh"
echo "- 功能: 守護進程 + 自動重啟 + 智能同步"
echo ""
echo "查看狀態："
echo "./logseq_unified.sh status"