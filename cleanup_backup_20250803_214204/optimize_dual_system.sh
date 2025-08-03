#!/bin/bash

echo "🔧 優化雙系統 Logseq 同步設置..."

# 1. 修改 com.user.logseq.autostart.plist 為監控模式
cat > /Users/mac/Library/LaunchAgents/com.user.logseq.autostart.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.logseq.autostart</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>cd /Users/mac/Documents/Sync-Logseq && ./logseq_unified.sh status > /dev/null 2>&1 && ./logseq_unified.sh start > /dev/null 2>&1</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>StandardOutPath</key>
    <string>/Users/mac/Documents/Sync-Logseq/monitor.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/mac/Documents/Sync-Logseq/monitor_error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
        <key>HOME</key>
        <string>/Users/mac</string>
    </dict>
    <key>WorkingDirectory</key>
    <string>/Users/mac/Documents/Sync-Logseq</string>
</dict>
</plist>
EOF

# 2. 創建主要的同步服務 plist
cat > /Users/mac/Library/LaunchAgents/com.logseq.sync.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.logseq.sync</string>
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
    <string>/Users/mac/Documents/Sync-Logseq/main_sync.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/mac/Documents/Sync-Logseq/main_sync_error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
    </dict>
</dict>
</plist>
EOF

echo "✅ 配置文件已更新"

# 3. 重新載入服務
echo "🔄 重新載入服務..."
launchctl unload /Users/mac/Library/LaunchAgents/com.user.logseq.autostart.plist 2>/dev/null
launchctl unload /Users/mac/Library/LaunchAgents/com.logseq.sync.plist 2>/dev/null

sleep 2

launchctl load /Users/mac/Library/LaunchAgents/com.logseq.sync.plist
launchctl load /Users/mac/Library/LaunchAgents/com.user.logseq.autostart.plist

echo "✅ 服務已重新載入"
echo ""
echo "🎯 新的雙重保護系統："
echo "1. com.logseq.sync - 主要同步服務 (KeepAlive=true)"
echo "2. com.user.logseq.autostart - 監控服務 (每5分鐘檢查一次)"
echo ""
echo "檢查狀態："
echo "launchctl list | grep logseq"