#!/bin/bash

echo "🔧 重新創建正確的 plist..."

# 先卸載可能存在的服務
launchctl unload /Users/mac/Library/LaunchAgents/com.logseq.sync.plist 2>/dev/null

# 刪除舊的 plist
rm -f /Users/mac/Library/LaunchAgents/com.logseq.sync.plist

# 創建新的正確 plist
cat > /Users/mac/Library/LaunchAgents/com.logseq.sync.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.logseq.sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/mac/Documents/Sync-Logseq/logseq_sync_simple.sh</string>
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
    <integer>10</integer>
</dict>
</plist>
EOF

echo "✅ plist 已創建"

# 檢查語法
echo "🔍 檢查 plist 語法..."
plutil -lint /Users/mac/Library/LaunchAgents/com.logseq.sync.plist

if [ $? -eq 0 ]; then
    echo "✅ plist 語法正確"
    
    # 載入服務
    echo "🚀 載入服務..."
    launchctl load /Users/mac/Library/LaunchAgents/com.logseq.sync.plist
    
    if [ $? -eq 0 ]; then
        echo "✅ 服務載入成功"
        
        # 等待幾秒後檢查狀態
        sleep 3
        echo "📊 檢查服務狀態..."
        launchctl list | grep logseq
        
        echo "📊 檢查進程..."
        ps aux | grep logseq_sync | grep -v grep
        
    else
        echo "❌ 服務載入失敗"
    fi
else
    echo "❌ plist 語法錯誤"
fi