#!/bin/bash

echo "🔧 更新到優化版同步腳本..."

# 1. 停止當前服務
launchctl unload /Users/mac/Library/LaunchAgents/com.logseq.sync.plist
pkill -f "logseq_sync"
rm -f /Users/mac/Documents/Sync-Logseq/.sync_lock

# 2. 更新 plist 使用優化版腳本
cat > /Users/mac/Library/LaunchAgents/com.logseq.sync.plist << 'EOF'
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

# 3. 設置權限
chmod +x /Users/mac/Documents/Sync-Logseq/logseq_sync_optimized.sh

# 4. 重新載入服務
launchctl load /Users/mac/Library/LaunchAgents/com.logseq.sync.plist

sleep 3

echo "✅ 更新完成！"
echo ""
echo "🚀 優化改進："
echo "   • 更快的文件變更檢測（2秒延遲）"
echo "   • 持續監控模式，避免重啟延遲"
echo "   • 智能 debounce 防止頻繁同步"
echo "   • 5分鐘定期檢查作為備用"
echo ""
echo "檢查狀態："
launchctl list | grep logseq
ps aux | grep logseq_sync | grep -v grep