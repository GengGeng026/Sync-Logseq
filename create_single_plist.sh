#!/bin/bash

echo "🎯 創建單一、穩定的 Logseq 同步服務..."

# 1. 停止並卸載所有現有服務
echo "停止現有服務..."
launchctl unload /Users/mac/Library/LaunchAgents/com.user.logseq.autostart.plist 2>/dev/null
launchctl unload /Users/mac/Library/LaunchAgents/com.logseq.sync.plist 2>/dev/null

# 停止相關進程
pkill -f "logseq_sync.sh" 2>/dev/null
pkill -f "logseq_unified.sh" 2>/dev/null

sleep 3

# 2. 刪除舊的 plist 文件
echo "清理舊配置..."
rm -f /Users/mac/Library/LaunchAgents/com.user.logseq.autostart.plist
rm -f /Users/mac/Library/LaunchAgents/com.logseq.sync.plist

# 3. 創建統一的 plist（使用更穩定的 logseq_sync.sh）
cat > /Users/mac/Library/LaunchAgents/com.logseq.unified.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.logseq.unified</string>
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
    <string>/Users/mac/Documents/Sync-Logseq/unified_sync.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/mac/Documents/Sync-Logseq/unified_sync_error.log</string>
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

# 4. 確保腳本有執行權限
chmod +x /Users/mac/Documents/Sync-Logseq/logseq_sync.sh

# 5. 載入新的統一服務
echo "載入新的統一同步服務..."
launchctl load /Users/mac/Library/LaunchAgents/com.logseq.unified.plist

sleep 3

echo "✅ 統一同步服務已創建並啟動！"
echo ""
echo "🎯 現在你只有一個 plist："
echo "   /Users/mac/Library/LaunchAgents/com.logseq.unified.plist"
echo ""
echo "🔧 特性："
echo "   ✅ KeepAlive: true (崩潰後自動重啟)"
echo "   ✅ RunAtLoad: true (開機自動啟動)"
echo "   ✅ ThrottleInterval: 10秒 (避免頻繁重啟)"
echo "   ✅ 完整的環境變數設定"
echo "   ✅ 專用的日誌文件"
echo ""
echo "檢查狀態："
echo "   launchctl list | grep logseq"
echo "   ps aux | grep logseq_sync"