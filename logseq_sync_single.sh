#!/bin/bash
# 嚴格單進程 Logseq 同步腳本

LOCK_FILE="/Users/mac/Documents/Sync-Logseq/.sync_lock"
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/sync_single.log"

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

# 同步函數
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
log "🎯 啟動單進程同步服務 (PID: $$)"
sync_repo

# 監控循環
log "👀 開始監控文件變更..."
while true; do
    if timeout 60 fswatch -1 "$REPO_DIR" --exclude="\.git/" --exclude="\.log$" > /dev/null 2>&1; then
        log "📁 檢測到文件變更"
        sync_repo
    else
        log "⏰ 定期檢查"
        sync_repo
    fi
    sleep 1
done