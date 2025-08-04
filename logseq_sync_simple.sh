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
