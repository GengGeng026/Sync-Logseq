#!/bin/bash
# 嚴格單進程 Logseq 同步腳本
# 確保只有一個進程運行

# 進程鎖定機制
LOCK_FILE="/Users/mac/Documents/Sync-Logseq/.sync_lock"
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/sync_single.log"

# 檢查是否已有實例在運行
if [ -f "$LOCK_FILE" ]; then
    lock_pid=$(cat "$LOCK_FILE")
    if kill -0 "$lock_pid" 2>/dev/null; then
        echo "$(date): 已有同步進程在運行 (PID: $lock_pid)，退出" >> "$LOG_FILE"
        exit 0
    else
        # 清理無效的鎖文件
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

# 設置信號處理
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
    
    # 清理 Git 鎖定文件
    find .git -name "*.lock" -delete 2>/dev/null
    
    # 確保在 main 分支
    git checkout main >> "$LOG_FILE" 2>&1
    
    # 添加所有變更
    git add -A
    
    # 提交本地變更
    if ! git diff --cached --quiet; then
        git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1
        log "📝 本地變更已提交"
    fi
    
    # 拉取遠端變更
    if git pull origin main --no-edit >> "$LOG_FILE" 2>&1; then
        log "📥 成功拉取遠端變更"
    else
        log "⚠️ 拉取失敗，重置到本地版本"
        git reset --hard HEAD >> "$LOG_FILE" 2>&1
    fi
    
    # 推送到遠端
    if git push origin main >> "$LOG_FILE" 2>&1; then
        log "📤 成功推送到遠端"
    else
        log "⚠️ 推送失敗"
    fi
    
    log "✅ 同步完成"
    echo "------------------------" >> "$LOG_FILE"
}

# 主程序開始
log "🎯 啟動單進程同步服務 (PID: $$)..."

# 初始同步
sync_repo

# 文件監控循環
log "👀 開始監控文件變更..."

# 使用 fswatch，但確保是同步執行
while true; do
    # 使用 timeout 確保 fswatch 不會無限等待
    if timeout 60 fswatch -1 "$REPO_DIR" \
        --exclude="\.git/" \
        --exclude="\.log$" \
        --exclude="\.lock$" \
        --exclude="\.tmp$" > /dev/null 2>&1; then
        
        log "📁 檢測到文件變更"
        sync_repo
    else
        # 如果 fswatch 超時，進行一次定期同步
        log "⏰ 定期同步檢查"
        sync_repo
    fi
    
    # 短暫休息避免 CPU 過載
    sleep 1
done