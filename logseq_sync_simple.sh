#!/bin/bash
# 簡化版 Logseq 同步腳本 - 單進程解決方案
# 避免多進程衝突

# 設置環境
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/sync_simple.log"
cd "$REPO_DIR" || exit

# 日誌函數
log() {
    echo "$(date): $1" >> "$LOG_FILE"
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
        log "⚠️ 拉取失敗，可能有衝突"
        # 簡單的衝突處理：保留本地版本
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

# 主循環 - 只有一個進程
log "🎯 啟動簡化同步服務..."

# 初始同步
sync_repo

# 使用 fswatch 監控文件變更（單一進程）
log "👀 開始監控文件變更..."
fswatch -r "$REPO_DIR" \
    --exclude="\.git/" \
    --exclude="\.log$" \
    --exclude="\.tmp$" \
    --latency=5 \
    --one-per-batch | while read -r event; do
    
    log "📁 檢測到文件變更: $event"
    sync_repo
done