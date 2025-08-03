#!/bin/bash

# Logseq 同步服務管理工具

PLIST_FILE="$HOME/Library/LaunchAgents/com.user.logseq.autostart.plist"
DAEMON_SCRIPT="$HOME/Documents/Sync-Logseq/logseq_daemon.sh"
SYNC_SCRIPT="$HOME/Documents/Sync-Logseq/logseq_sync.sh"

case "$1" in
    "start")
        echo "🚀 啟動 Logseq 同步服務..."
        launchctl bootstrap gui/$(id -u) "$PLIST_FILE" 2>/dev/null || echo "服務可能已在運行"
        echo "✅ 啟動完成"
        ;;
    "stop")
        echo "🛑 停止 Logseq 同步服務..."
        launchctl bootout gui/$(id -u) "$PLIST_FILE" 2>/dev/null || true
        pkill -f "logseq_daemon.sh" 2>/dev/null || true
        pkill -f "logseq_sync.sh" 2>/dev/null || true
        echo "✅ 停止完成"
        ;;
    "restart")
        echo "🔄 重啟 Logseq 同步服務..."
        $0 stop
        sleep 2
        $0 start
        ;;
    "status")
        echo "📊 Logseq 同步服務狀態："
        echo ""
        echo "LaunchAgent 狀態："
        launchctl list | grep logseq || echo "❌ LaunchAgent 未運行"
        echo ""
        echo "進程狀態："
        if pgrep -f "logseq_daemon.sh" > /dev/null; then
            echo "✅ 守護進程運行中"
        else
            echo "❌ 守護進程未運行"
        fi
        
        if pgrep -f "logseq_sync.sh" > /dev/null; then
            echo "✅ 同步腳本運行中"
            echo "進程數量: $(pgrep -f "logseq_sync.sh" | wc -l)"
        else
            echo "❌ 同步腳本未運行"
        fi
        ;;
    "log")
        echo "📋 查看同步日誌："
        tail -20 ~/Documents/Sync-Logseq/daemon.log 2>/dev/null || echo "無守護進程日誌"
        echo ""
        echo "同步服務日誌："
        tail -20 ~/Documents/Sync-Logseq/sync_stdout.log 2>/dev/null || echo "無同步日誌"
        ;;
    "test")
        echo "🧪 測試手動啟動同步..."
        cd ~/Documents/Sync-Logseq
        ./logseq_daemon.sh &
        echo "✅ 測試啟動完成"
        ;;
    *)
        echo "🛠️  Logseq 同步服務管理工具"
        echo ""
        echo "用法: $0 [命令]"
        echo ""
        echo "命令："
        echo "  start    - 啟動服務"
        echo "  stop     - 停止服務"
        echo "  restart  - 重啟服務"
        echo "  status   - 查看狀態"
        echo "  log      - 查看日誌"
        echo "  test     - 測試啟動"
        echo ""
        ;;
esac