#!/bin/bash
# 簡化日誌系統 - 只保留 2 個日誌文件，每個最多 100 行

echo "🧹 簡化 Logseq 日誌系統..."

SYNC_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$SYNC_DIR" || exit 1

# 1. 停止當前服務
echo "1. 停止當前服務..."
launchctl unload ~/Library/LaunchAgents/com.logseq.sync.plist

# 2. 清理所有現有日誌文件
echo "2. 清理現有日誌文件..."
rm -f *.log *.log.*

# 3. 創建簡化的日誌管理器
echo "3. 創建簡化的日誌管理器..."
cat > simple_log_manager.sh << 'EOF'
#!/bin/bash
# 簡化日誌管理器 - 只保留最後 100 行，不創建備份

trim_log() {
    local log_file="$1"
    local max_lines="${2:-100}"
    
    if [ -f "$log_file" ]; then
        local current_lines=$(wc -l < "$log_file")
        if [ "$current_lines" -gt "$max_lines" ]; then
            # 只保留最後 100 行，直接覆蓋
            tail -"$max_lines" "$log_file" > "${log_file}.tmp"
            mv "${log_file}.tmp" "$log_file"
            echo "$(date '+%H:%M:%S'): 日誌已修剪至 $max_lines 行" >> "$log_file"
        fi
    fi
}

# 修剪兩個日誌文件
trim_log "sync.log" 100
trim_log "error.log" 100
EOF

chmod +x simple_log_manager.sh

# 4. 修改主同步腳本，使用簡化日誌
echo "4. 修改同步腳本使用簡化日誌..."
cp logseq_sync_optimized.sh logseq_sync_optimized.sh.backup

# 創建簡化版本的同步腳本
cat > logseq_sync_simple.sh << 'EOF'
#!/bin/bash

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
SYNC_LOG="$REPO_DIR/sync.log"
ERROR_LOG="$REPO_DIR/error.log"
LOCK_FILE="$REPO_DIR/.sync_lock"

cd "$REPO_DIR" || exit 1

# 簡化日誌函數
log_info() {
    echo "$(date '+%m-%d %H:%M:%S'): $1" >> "$SYNC_LOG"
    ./simple_log_manager.sh  # 每次寫入後檢查行數
}

log_error() {
    echo "$(date '+%m-%d %H:%M:%S'): ERROR: $1" >> "$ERROR_LOG"
    ./simple_log_manager.sh  # 每次寫入後檢查行數
}

# 進程鎖定
if [ -f "$LOCK_FILE" ]; then
    if kill -0 "$(cat "$LOCK_FILE")" 2>/dev/null; then
        exit 0
    else
        rm -f "$LOCK_FILE"
    fi
fi
echo $$ > "$LOCK_FILE"

# 清理函數
cleanup() {
    rm -f "$LOCK_FILE"
    exit 0
}
trap cleanup EXIT INT TERM

log_info "=== 同步服務啟動 ==="

# Git 同步函數
sync_git() {
    if [ -d .git ]; then
        git add . >/dev/null 2>&1
        if git diff --cached --quiet; then
            return 0
        fi
        
        if git commit -m "Auto sync $(date '+%m-%d %H:%M')" >/dev/null 2>&1; then
            if git push >/dev/null 2>&1; then
                log_info "✅ 推送成功"
            else
                log_error "推送失敗"
                git pull --rebase >/dev/null 2>&1 && git push >/dev/null 2>&1
            fi
        fi
    fi
}

# 文件監控
log_info "🔍 開始文件監控..."
fswatch -0 --event Created --event Updated --event Removed \
    --exclude='\.git/' --exclude='\.log' --exclude='\.lock' \
    . | while IFS= read -r -d '' file; do
    
    log_info "📝 檔案變更: $(basename "$file")"
    sleep 2
    sync_git
done
EOF

chmod +x logseq_sync_simple.sh

# 5. 更新 LaunchAgent 配置
echo "5. 更新 LaunchAgent 配置..."
cat > ~/Library/LaunchAgents/com.logseq.sync.plist << 'EOF'
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
    <string>/Users/mac/Documents/Sync-Logseq/sync.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/mac/Documents/Sync-Logseq/error.log</string>
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

# 6. 重新啟動服務
echo "6. 重新啟動服務..."
launchctl load ~/Library/LaunchAgents/com.logseq.sync.plist

sleep 5

# 7. 檢查結果
echo ""
echo "🎉 簡化完成！"
echo ""
echo "📊 新的日誌系統："
echo "   📄 sync.log - 同步活動日誌 (最多 100 行)"
echo "   📄 error.log - 錯誤日誌 (最多 100 行)"
echo ""
echo "✅ 特點："
echo "   - 只有 2 個日誌文件"
echo "   - 每個文件最多 100 行"
echo "   - 超過時直接覆蓋，不創建備份"
echo "   - 自動修剪機制"
echo ""
echo "🔧 當前狀態："
if launchctl list com.logseq.sync >/dev/null 2>&1; then
    echo "   ✅ 服務正在運行"
    ls -la *.log 2>/dev/null || echo "   📄 日誌文件將在活動時創建"
else
    echo "   ❌ 服務啟動失敗"
fi