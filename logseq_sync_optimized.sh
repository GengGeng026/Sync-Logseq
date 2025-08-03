#!/bin/bash

DEBUG_LOG="/tmp/logseq_sync_debug.log"

log_debug() {
    echo "$(date '+%F %T') 🔍 $1" >> "$DEBUG_LOG"
}

log_debug "📂 腳本開始執行"

LOCK_FILE="/Users/mac/Documents/Sync-Logseq/.sync_lock"
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/sync_optimized.log"

# 設定 PATH
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"
log_debug "✅ 設定 PATH 成功：$PATH"

# 檢查鎖文件
if [ -f "$LOCK_FILE" ]; then
    lock_pid=$(cat "$LOCK_FILE")
    if kill -0 "$lock_pid" 2>/dev/null; then
        log_debug "⛔ 已有進程運行中 (PID: $lock_pid)"
        exit 0
    else
        rm -f "$LOCK_FILE"
        log_debug "🧹 清理無效鎖定文件"
    fi
fi

echo $$ > "$LOCK_FILE"
log_debug "🔒 建立鎖文件 (PID: $$)"

cleanup() {
    rm -f "$LOCK_FILE"
    pkill -P $$ 2>/dev/null
    log_debug "🧼 清理鎖文件與子進程"
    exit 0
}
trap cleanup EXIT INT TERM

# 切換目錄
cd "$REPO_DIR" || { log_debug "❌ 切換到 $REPO_DIR 失敗"; exit 1; }
log_debug "📁 成功切換目錄到 $REPO_DIR"

# 嘗試 Git 操作
log_debug "🚀 開始 Git 操作"

find .git -name "*.lock" -delete 2>/dev/null
git checkout main >> "$DEBUG_LOG" 2>&1 && log_debug "✅ git checkout 成功"

git add -A >> "$DEBUG_LOG" 2>&1 && log_debug "✅ git add 成功"

if ! git diff --cached --quiet; then
    git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')" >> "$DEBUG_LOG" 2>&1
    log_debug "📝 git commit 成功"
else
    log_debug "ℹ️ 無本地更動，不需 commit"
fi

if git pull origin main --no-edit >> "$DEBUG_LOG" 2>&1; then
    log_debug "📥 git pull 成功"
else
    log_debug "⚠️ git pull 失敗，嘗試 reset"
    git reset --hard HEAD >> "$DEBUG_LOG" 2>&1
fi

if git push origin main >> "$DEBUG_LOG" 2>&1; then
    log_debug "📤 git push 成功"
else
    log_debug "⚠️ git push 失敗"
fi

log_debug "✅ 同步程序完成"
