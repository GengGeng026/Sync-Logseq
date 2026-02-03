#!/usr/bin/env bash

# --- 設定 ---
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_DIR="$REPO_DIR/.logs"
LOG_FILE="$LOG_DIR/sync.log"
LAST_SYNC_TS="$REPO_DIR/.last_sync"
RUN_LOCK="$REPO_DIR/.sync_run.lockdir"
DEBOUNCE_FILE="$REPO_DIR/.sync_debounce"
GIT_INDEX_LOCK="$REPO_DIR/.git/index.lock"

# --- 可透過 launchd plist 環境變數調整的參數 ---
PULL_INTERVAL="${LOGSEQ_PULL_INTERVAL:-15}"      # 定時輪詢間隔 (秒)
DEBOUNCE_GAP="${LOGSEQ_DEBOUNCE_GAP:-2}"        # 檔案變更去抖動間隔 (秒)
MAX_FILE_SIZE="${LOGSEQ_MAX_FILE_SIZE:-100000000}" # 忽略的大檔案閾值 (100MB)
GIT_TIMEOUT="${LOGSEQ_GIT_TIMEOUT:-30}"         # Git 操作超時時間 (秒)
MAX_LOCK_AGE="${LOGSEQ_MAX_LOCK_AGE:-120}"      # Git index.lock 最大存活時間 (秒)

# --- 初始化 ---
mkdir -p "$LOG_DIR"
touch "$LAST_SYNC_TS"

# --- 函數 ---
log() {
    # 自動加上時間戳並寫入日誌
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "$LOG_FILE"
}

manage_log_size() {
    # 自動修剪日誌，只保留最新的 1000 行
    local file="$1"
    local max_lines="${2:-1000}"
    if [ -f "$file" ] && [ "$(wc -l < "$file")" -gt "$max_lines" ]; then
        log "日誌已超過 $max_lines 行，進行修剪..."
        tail -n "$max_lines" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    fi
}

# 清理卡住的 Git index.lock
cleanup_git_lock() {
    if [ -f "$GIT_INDEX_LOCK" ]; then
        local now lock_mtime lock_age
        now=$(date +%s)
        lock_mtime=$(stat -f %m "$GIT_INDEX_LOCK" 2>/dev/null || echo 0)
        lock_age=$((now - lock_mtime))
        
        if [ "$lock_age" -gt "$MAX_LOCK_AGE" ]; then
            log "🧹 偵測到過期的 Git index.lock (age=${lock_age}s)，自動清除"
            rm -f "$GIT_INDEX_LOCK"
            return 0
        else
            log "⏳ Git index.lock 存在但未過期 (age=${lock_age}s)，等待中..."
            return 1
        fi
    fi
    return 0
}

# 智能重試機制
retry_with_cleanup() {
    local cmd="$1"
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if eval "$cmd" >> "$LOG_FILE" 2>&1; then
            return 0
        fi
        
        # 檢查是否是 index.lock 問題
        if grep -q "index.lock" "$LOG_FILE" 2>/dev/null; then
            retry_count=$((retry_count + 1))
            log "⚠️ 嘗試 $retry_count/$max_retries: Git 操作失敗，檢查 index.lock..."
            
            if cleanup_git_lock; then
                log "🔄 已清理 index.lock，重試中..."
                sleep 2
                continue
            else
                log "⏸️ index.lock 仍在使用中，等待 5 秒..."
                sleep 5
            fi
        else
            # 非 lock 相關錯誤，直接失敗
            return 1
        fi
    done
    
    log "❌ 重試 $max_retries 次後仍失敗"
    return 1
}

# --- 主邏輯 ---
cd "$REPO_DIR" || exit 1

# 啟動時清理：確保沒有因上次異常中斷而殘留的鎖
rmdir "$RUN_LOCK" 2>/dev/null || true
cleanup_git_lock
manage_log_size "$LOG_FILE"

# 分支自偵測 (可由 LOGSEQ_SYNC_BRANCH 環境變數覆蓋)
BRANCH="${LOGSEQ_SYNC_BRANCH:-$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's#origin/##')}"
[ -z "$BRANCH" ] && BRANCH="main"
log "🚀 同步服務啟動。監控分支: $BRANCH"

# 函數：列出超過大小限制的檔案
list_large_files() {
    git ls-files -m -o --exclude-standard -z | while IFS= read -r -d '' f; do
        [ ! -f "$f" ] && continue
        local size
        size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null)
        [ "${size:-0}" -gt "$MAX_FILE_SIZE" ] && printf '%s\0' "$f"
    done
}

# 核心同步函數
sync_repo() {
    # 使用目錄作為互斥鎖，防止多個同步任務同時執行
    if ! mkdir "$RUN_LOCK" 2>/dev/null; then
        if [ -d "$RUN_LOCK" ]; then
            local now m_ts age
            now=$(date +%s)
            m_ts=$(stat -f %m "$RUN_LOCK" 2>/dev/null || echo 0)
            age=$((now - m_ts))
            # 如果鎖已存在超過 45 秒，視為過期鎖並嘗試清除
            if [ "$age" -gt 45 ]; then
                log "🧹 偵測到過期鎖 (age=${age}s)，嘗試清除"
                rmdir "$RUN_LOCK" 2>/dev/null && mkdir "$RUN_LOCK" 2>/dev/null || { log "⏳ 清除鎖失敗，仍有同步在進行，略過本次"; return 0; }
            else
                log "⏳ 另一個同步仍在進行 (${age}s)，略過本次"
                return 0
            fi
        else
            log "⏳ 另一個同步仍在進行，略過本次"
            return 0
        fi
    fi
    # 確保函數結束時自動解鎖
    trap 'rmdir "$RUN_LOCK" 2>/dev/null || true' RETURN

    log "🎯 [核心同步] 開始..."
    
    # 清理可能存在的舊 lock（在任何 Git 操作前）
    cleanup_git_lock
    
    # 使用智能重試機制執行 checkout
    if ! retry_with_cleanup "git checkout '$BRANCH'"; then
        # 如果分支不存在，创建它
        cleanup_git_lock  # 再次确保没有锁
        git checkout -B "$BRANCH" >> "$LOG_FILE" 2>&1
    fi
    
    # Fetch with retry
    if ! retry_with_cleanup "timeout '$GIT_TIMEOUT' git fetch origin"; then
        log "⚠️ Fetch 超時或失敗"
    fi

    local local_head remote_head
    local_head=$(git rev-parse HEAD 2>/dev/null || echo "N/A")
    remote_head=$(timeout "$GIT_TIMEOUT" git ls-remote origin -h "refs/heads/$BRANCH" | cut -f1)

    log "🧭 本地 HEAD: ${local_head:0:12}, 遠端 HEAD: ${remote_head:0:12}"

    # 只有當遠端有更新時才執行 pull
    if [ -n "$remote_head" ] && [ "$local_head" != "$remote_head" ]; then
        # 使用 rebase 策略並帶重試機制
        if retry_with_cleanup "timeout '$GIT_TIMEOUT' git pull origin '$BRANCH' --rebase --autostash"; then
            log "📥 成功拉取遠端更新"
        else
            log "⚠️ 拉取失敗或超時，執行 hard reset 到 origin/$BRANCH"
            cleanup_git_lock  # 確保 reset 前沒有 lock
            retry_with_cleanup "timeout '$GIT_TIMEOUT' git fetch --all"
            retry_with_cleanup "timeout '$GIT_TIMEOUT' git reset --hard 'origin/$BRANCH'"
        fi
    else
        log "✅ 本地已是最新，無需拉取"
    fi

    # 使用重試機制執行 add
    retry_with_cleanup "git add -A"

    # 檢查並取消暫存過大的檔案
    local large_files
    large_files=$(list_large_files)
    if [ -n "$large_files" ]; then
        printf '%s' "$large_files" | xargs -0 -I{} git reset -q HEAD -- "{}"
        log "⛔ 跳過超大檔案: $(printf '%s' "$large_files" | tr '\0' ' ')"
    fi

    # 只有在有實際變更時才 commit 和 push
    if ! git diff --cached --quiet; then
        if retry_with_cleanup "git commit -m 'Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')'"; then
            log "📝 本地變更已提交"
            if retry_with_cleanup "timeout '$GIT_TIMEOUT' git push origin '$BRANCH'"; then
                log "📤 成功推送至遠端"
            else
                log "⚠️ 推送失敗或超時"
            fi
        fi
    else
        log "ℹ️ 無本地變更，無需提交"
    fi

    touch "$LAST_SYNC_TS"
    log "✅ [核心同步] 完成"
}

# 檔案系統監控 (需要 fswatch)
watch_filesystem() {
    if ! command -v fswatch >/dev/null 2>&1; then
        log "⚠️ 未安裝 fswatch，將僅使用定時輪詢"
        return 0
    fi
    log "👁️ 啟動 fswatch 檔案監控..."
    fswatch -r -l 2 "$REPO_DIR" \
        --exclude="\.git/" \
        --exclude="\.logs/.*" \
        --exclude="\.sync_run\.lockdir" \
        --exclude="\.last_sync" \
        --exclude="\.sync_debounce" \
        --event Updated --event Created --event Removed \
    | while read -r event; do
        local now
        now=$(date +%s)
        echo "$now" > "$DEBOUNCE_FILE"
        (
            sleep "$DEBOUNCE_GAP"
            local last_event_ts
            last_event_ts=$(cat "$DEBOUNCE_FILE" 2>/dev/null || echo 0)
            # 透過比對時間戳實現去抖動
            if [ "${last_event_ts:-0}" -eq "$now" ]; then
                log "📁 偵測到檔案變更，觸發同步"
                sync_repo
            fi
        ) &
    done
}

# 遠端輪詢
poll_remote() {
    while true; do
        sleep "$PULL_INTERVAL"
        log "⏱️ 執行定時遠端檢查..."
        sync_repo
    done
}

# --- 啟動並行任務 ---
watch_filesystem &
poll_remote &
wait
