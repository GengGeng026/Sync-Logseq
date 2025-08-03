#!/bin/bash
# 優化版 Logseq 同步腳本 - 帶日誌管理

# 日誌管理函數
manage_log_size() {
    local log_file="$1"
    local max_size_kb="${2:-512}"
    local keep_lines="${3:-500}"
    
    if [ ! -f "$log_file" ]; then
        return 0
    fi
    
    local size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null)
    local size_kb=$((size / 1024))
    
    if [ "$size_kb" -gt "$max_size_kb" ]; then
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        cp "$log_file" "${log_file}.${timestamp}"
        tail -"$keep_lines" "$log_file" > "${log_file}.tmp"
        mv "${log_file}.tmp" "$log_file"
        ls -t "${log_file}".* 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null
        echo "$(date): 日誌已輪換，保留最後 $keep_lines 行" >> "$log_file"
    fi
}

# 優化版 Logseq 同步腳本 - 快速響應

LOCK_FILE="/Users/mac/Documents/Sync-Logseq/.sync_lock"
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/sync_optimized.log"

# 檢查鎖文件
if [ -f "$LOCK_FILE" ]; then
    lock_pid=$(cat "$LOCK_FILE")
    if kill -0 "$lock_pid" 2>/dev/null; then
        echo "$(date): 已有進程運行 (PID: $lock_pid)" >> "$LOG_FILE"
        exit 0
    else
        rm -f "$LOCK_FILE"
    fi
fi

# 創建鎖文件
echo $$ > "$LOCK_FILE"

# 清理函數
cleanup() {
    rm -f "$LOCK_FILE"
    pkill -P $$ 2>/dev/null  # 清理子進程
    exit 0
}

trap cleanup EXIT INT TERM

# 設置環境
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"
cd "$REPO_DIR" || exit

# 日誌函數
log() {
    echo "$(date): [PID:$$] $1" >> "$LOG_FILE"
}

# 優化的同步函數 - 添加 debounce
sync_repo() {
    log "🚀 開始同步..."
    
    find .git -name "*.lock" -delete 2>/dev/null
    git checkout main >> "$LOG_FILE" 2>&1
    git add -A
    
    if ! git diff --cached --quiet; then
        git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1
        log "📝 本地變更已提交"
    fi
    
    if git pull origin main --no-edit >> "$LOG_FILE" 2>&1; then
        log "📥 成功拉取遠端變更"
    else
        log "⚠️ 拉取失敗"
        git reset --hard HEAD >> "$LOG_FILE" 2>&1
    fi
    
    if git push origin main >> "$LOG_FILE" 2>&1; then
        log "📤 成功推送到遠端"
    else
        log "⚠️ 推送失敗"
    fi
    
    log "✅ 同步完成"
}

# 主程序
manage_log_size "$LOG_FILE" 512 500
log "🎯 啟動優化同步服務 (PID: $$)"
sync_repo

# 優化的監控循環 - 更快響應
log "👀 開始監控文件變更..."

# 使用持續監控模式，避免頻繁重啟 fswatch
fswatch -r "$REPO_DIR" \
    --exclude="\.git/" \
    --exclude="\.log$" \
    --exclude="\.lock$" \
    --exclude="\.tmp$" \
    --latency=2 \
    --one-per-batch | while read -r event; do
    
    log "📁 檢測到文件變更: $event"
    
    # Debounce: 等待2秒，避免頻繁同步
    sleep 2
    
    # 檢查是否有更多變更
    if [ -n "$(find "$REPO_DIR" -newer "$REPO_DIR/.last_sync" 2>/dev/null | head -1)" ]; then
        sync_repo
        touch "$REPO_DIR/.last_sync"
    fi
done &

# 定期檢查（每5分鐘）作為備用
while true; do
    sleep 300  # 5分鐘
    log "⏰ 定期檢查"
    sync_repo
done