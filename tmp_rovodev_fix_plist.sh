#!/bin/bash
# 修復 LaunchAgent plist 配置以符合 README.md 標準

echo "🔧 修復 Logseq LaunchAgent 配置..."

# 1. 停止當前服務
echo "1. 停止當前服務..."
launchctl unload ~/Library/LaunchAgents/com.logseq.sync.plist

# 2. 備份當前配置
echo "2. 備份當前配置..."
cp ~/Library/LaunchAgents/com.logseq.sync.plist ~/Library/LaunchAgents/com.logseq.sync.plist.backup

# 3. 創建符合 README.md 標準的新配置
echo "3. 創建新的標準配置..."
cat > ~/Library/LaunchAgents/com.logseq.sync.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.logseq.sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/mac/Documents/Sync-Logseq/logseq_sync_optimized.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>/Users/mac/Documents/Sync-Logseq</string>
    <key>StandardOutPath</key>
    <string>/Users/mac/Documents/Sync-Logseq/launchd.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/mac/Documents/Sync-Logseq/launchd_error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
        <key>HOME</key>
        <string>/Users/mac</string>
    </dict>
    <key>ThrottleInterval</key>
    <integer>5</integer>
</dict>
</plist>
EOF

# 4. 重新加載服務
echo "4. 重新加載服務..."
launchctl load ~/Library/LaunchAgents/com.logseq.sync.plist

# 5. 等待啟動
sleep 5

# 6. 檢查狀態
echo "5. 檢查服務狀態..."
if launchctl list com.logseq.sync > /dev/null 2>&1; then
    echo "✅ LaunchAgent 配置修復成功！"
    launchctl list com.logseq.sync
else
    echo "❌ LaunchAgent 啟動失敗"
    echo "恢復備份配置..."
    cp ~/Library/LaunchAgents/com.logseq.sync.plist.backup ~/Library/LaunchAgents/com.logseq.sync.plist
    launchctl load ~/Library/LaunchAgents/com.logseq.sync.plist
fi

echo ""
echo "📊 當前配置對比："
echo "新增的關鍵配置："
echo "  ✅ KeepAlive: true (自動重啟)"
echo "  ✅ WorkingDirectory (工作目錄)"
echo "  ✅ EnvironmentVariables (環境變數)"
echo "  ✅ ThrottleInterval: 5 (節流控制)"
echo "  ✅ 統一日誌路徑"