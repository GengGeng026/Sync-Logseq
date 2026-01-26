#!/usr/bin/env bash

# --- 設定 ---
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_DIR="$REPO_DIR/.logs"
LOG_FILE="$LOG_DIR/sync.log"
LAST_SYNC_TS="$REPO_DIR/.last_sync"
RUN_LOCK="$REPO_DIR/.sync_run.lockdir"
DEBOUNCE_FILE="$REPO_DIR/.sync_debounce"

# --- 可透過 launchd plist 環境變數調整的參數 ---
PULL_INTERVAL="${LOGSEQ_PULL_INTERVAL:-15}"      # 定時輪詢間隔 (秒)
DEBOUNCE_GAP="${LOGSEQ_DEBOUNCE_GAP:-2}"        # 檔案變更去抖動間隔 (秒)
MAX_FILE_SIZE="${LOGSEQ_MAX_FILE_SIZE:-100000000}" # 忽略的大檔案閾值 (100MB)
GIT_TIMEOUT="${LOGSEQ_GIT_TIMEOUT:-30}"         # Git 操作超時時間 (秒)

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

# --- 主邏輯 ---
cd "$REPO_DIR" || exit 1

# 啟動時清理：確保沒有因上次異常中斷而殘留的鎖
rmdir "$RUN_LOCK" 2>/dev/null || true
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
    git checkout "$BRANCH" >> "$LOG_FILE" 2>&1 || git checkout -B "$BRANCH" >> "$LOG_FILE" 2>&1
    timeout "$GIT_TIMEOUT" git fetch origin >> "$LOG_FILE" 2>&1 || log "⚠️ Fetch 超時或失敗"

    local local_head remote_head
    local_head=$(git rev-parse HEAD 2>/dev/null || echo "N/A")
    remote_head=$(timeout "$GIT_TIMEOUT" git ls-remote origin -h "refs/heads/$BRANCH" | cut -f1)

    log "🧭 本地 HEAD: ${local_head:0:12}, 遠端 HEAD: ${remote_head:0:12}"

    # 只有當遠端有更新時才執行 pull
    if [ -n "$remote_head" ] && [ "$local_head" != "$remote_head" ]; then
        if timeout "$GIT_TIMEOUT" git pull origin "$BRANCH" --no-edit --autostash >> "$LOG_FILE" 2>&1; then
            log "📥 成功拉取遠端更新"
        else
            log "⚠️ 拉取失敗或超時，執行 hard reset 到 origin/$BRANCH"
            timeout "$GIT_TIMEOUT" git fetch --all >> "$LOG_FILE" 2>&1
            timeout "$GIT_TIMEOUT" git reset --hard "origin/$BRANCH" >> "$LOG_FILE" 2>&1
        fi
    else
        log "✅ 本地已是最新，無需拉取"
    fi

    git add -A

    # 檢查並取消暫存過大的檔案
    local large_files
    large_files=$(list_large_files)
    if [ -n "$large_files" ]; then
        printf '%s' "$large_files" | xargs -0 -I{} git reset -q HEAD -- "{}"
        log "⛔ 跳過超大檔案: $(printf '%s' "$large_files" | tr '\0' ' ')"
    fi

    # 只有在有實際變更時才 commit 和 push
    if ! git diff --cached --quiet; then
        if git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1; then
            log "📝 本地變更已提交"
            if timeout "$GIT_TIMEOUT" git push origin "$BRANCH" >> "$LOG_FILE" 2>&1; then
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
