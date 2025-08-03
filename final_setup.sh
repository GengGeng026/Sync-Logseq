#!/bin/bash

echo "🎯 設置最終的單一 Logseq 同步服務..."

# 停止所有現有服務
echo "清理現有服務..."
launchctl unload /Users/mac/Library/LaunchAgents/com.user.logseq.autostart.plist 2>/dev/null
launchctl unload /Users/mac/Library/LaunchAgents/com.logseq.sync.plist 2>/dev/null
launchctl unload /Users/mac/Library/LaunchAgents/com.logseq.unified.plist 2>/dev/null

# 停止進程
pkill -f "logseq_sync.sh" 2>/dev/null
pkill -f "logseq_unified.sh" 2>/dev/null

sleep 3

# 刪除所有舊的 plist
rm -f /Users/mac/Library/LaunchAgents/com.user.logseq.autostart.plist
rm -f /Users/mac/Library/LaunchAgents/com.logseq.sync.plist
rm -f /Users/mac/Library/LaunchAgents/com.logseq.unified.plist

# 創建最終的單一 plist
cat > /Users/mac/Library/LaunchAgents/com.logseq.final.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.logseq.final</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/mac/Documents/Sync-Logseq/logseq_sync.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>/Users/mac/Documents/Sync-Logseq</string>
    <key>StandardOutPath</key>
    <string>/Users/mac/Documents/Sync-Logseq/final_sync.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/mac/Documents/Sync-Logseq/final_sync_error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
        <key>HOME</key>
        <string>/Users/mac</string>
    </dict>
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
EOF

# 確保腳本權限
chmod +x /Users/mac/Documents/Sync-Logseq/logseq_sync.sh

# 載入最終服務
launchctl load /Users/mac/Library/LaunchAgents/com.logseq.final.plist

sleep 3

echo "✅ 完成！現在你只有一個同步服務："
echo ""
echo "📁 Plist 文件: /Users/mac/Library/LaunchAgents/com.logseq.final.plist"
echo "🔧 腳本文件: /Users/mac/Documents/Sync-Logseq/logseq_sync.sh"
echo "📊 日誌文件: /Users/mac/Documents/Sync-Logseq/final_sync.log"
echo ""
echo "🎯 特性:"
echo "   ✅ KeepAlive: true (自動重啟)"
echo "   ✅ RunAtLoad: true (開機啟動)"
echo "   ✅ 智能衝突處理"
echo "   ✅ 文件變更監控"
echo ""
echo "檢查狀態: launchctl list | grep logseq"