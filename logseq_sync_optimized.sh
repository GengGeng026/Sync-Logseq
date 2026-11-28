#!/usr/bin/env bash

# --- 設定 ---
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_DIR="$REPO_DIR/.logs"
LOG_FILE="$LOG_DIR/sync.log"
LAST_SYNC_TS="$REPO_DIR/.last_sync"
RUN_LOCK="$REPO_DIR/.sync_run.lockdir"
DEBOUNCE_FILE="$REPO_DIR/.sync_debounce_v2"
GIT_INDEX_LOCK="$REPO_DIR/.git/index.lock"

# --- 可透過 launchd plist 環境變數調整的參數 ---
PULL_INTERVAL="${LOGSEQ_PULL_INTERVAL:-15}"      # 定時輪詢間隔 (秒)
DEBOUNCE_GAP="${LOGSEQ_DEBOUNCE_GAP:-2}"        # 檔案變更去抖動間隔 (秒)
MAX_FILE_SIZE="${LOGSEQ_MAX_FILE_SIZE:-100000000}" # 忽略的大檔案閾值 (100MB)
GIT_TIMEOUT="${LOGSEQ_GIT_TIMEOUT:-30}"         # Git 操作超時時間 (秒)
MAX_LOCK_AGE="${LOGSEQ_MAX_LOCK_AGE:-300}"      # Git index.lock 最大存活時間 (秒)
QUIET_GAP="${LOGSEQ_QUIET_GAP:-15}"             # 本機改動靜置多久後才提交 (秒)，避免編輯中途被搶提交

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

# 偵測目前是否有 git / git-lfs 子進程正在運作（避免誤刪正在使用的 index.lock）
git_busy() {
    pgrep -f 'git[[:space:]]+(fetch|merge|pull|push|commit|rebase|lfs|add|checkout|status|diff|rev-parse|reset)' >/dev/null 2>&1
}

# 清理卡住的 Git index.lock（先確認無 git 進程在跑，再按年齡判斷是否過期）
cleanup_git_lock() {
    if [ -f "$GIT_INDEX_LOCK" ]; then
        if git_busy; then
            log "⏳ Git 進程正在運作，index.lock 保留中，不清除"
            return 1
        fi
        local now lock_mtime lock_age
        now=$(date +%s)
        lock_mtime=$(stat -f %m "$GIT_INDEX_LOCK" 2>/dev/null || echo 0)
        lock_age=$((now - lock_mtime))

        if [ "$lock_age" -gt "$MAX_LOCK_AGE" ]; then
            log "🧹 偵測到過期的 Git index.lock (age=${lock_age}s，無 Git 進程)，自動清除"
            rm -f "$GIT_INDEX_LOCK"
            return 0
        else
            log "⏳ Git index.lock 存在但未過期 (age=${lock_age}s)，等待中..."
            return 1
        fi
    fi
    return 0
}

# 清理卡住的 rebase（防止孤兒狀態殘留）
cleanup_stale_rebase() {
    if [ -d "$REPO_DIR/.git/rebase-merge" ] || [ -d "$REPO_DIR/.git/rebase-apply" ]; then
        log "🧹 偵測到卡住的 rebase，自動 abort 並清除狀態目錄"
        git rebase --abort 2>/dev/null || true
        rm -rf "$REPO_DIR/.git/rebase-merge" "$REPO_DIR/.git/rebase-apply" 2>/dev/null || true
    fi
}

# 智能重試機制：只把「本次指令」的輸出拿來判斷是否為 index.lock，避免被歷史日誌誤導
retry_with_cleanup() {
    local cmd="$1"
    local max_retries=3
    local retry_count=0
    local out

    while [ $retry_count -lt $max_retries ]; do
        out=$(eval "$cmd" 2>&1)
        echo "$out" >> "$LOG_FILE"
        if [ $? -eq 0 ]; then
            return 0
        fi

        # 只檢查本次輸出是否為 index.lock 問題
        if echo "$out" | grep -q "index.lock"; then
            retry_count=$((retry_count + 1))
            log "⚠️ 嘗試 $retry_count/$max_retries: Git 操作遇到 index.lock..."

            if cleanup_git_lock; then
                log "🔄 已清理 index.lock，重試中..."
                sleep 2
                continue
            else
                log "⏳ index.lock 仍在使用中，等待 5 秒..."
                sleep 5
            fi
        else
            # 非 lock 相關錯誤（如本地改動擋住 merge、衝突），不重試清鎖
            log "⚠️ Git 操作失敗（非鎖定問題），不重試清鎖"
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
cleanup_stale_rebase
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

# 衝突檢查：標記已被清空的文件自動暫存；仍含衝突標記則返回 1，要求暫停
# 用戶只需在編輯器裡刪掉衝突標記並保存，無需手動 git add
stage_resolved_conflicts() {
    local f remaining
    remaining=""
    while IFS= read -r -d '' f; do
        if [ -f "$f" ] && grep -qE '^(<{7}|>{7})[[:space:]]' "$f"; then
            remaining="$remaining $f"
        else
            git add -- "$f" 2>/dev/null && log "✅ 衝突標記已清除，自動暫存: $f"
        fi
    done < <(git diff --name-only --diff-filter=U -z)

    if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
        log "⛔ 仍有未解決衝突:${remaining}，暫停自動同步，等待手動修復"
        return 1
    fi
    log "✅ 衝突已全部解決"
    return 0
}

# merge 前：把「已靜置夠久」的本地改動先提交，避免未提交改動擋住 merge
# 仍在編輯中的檔案本輪不動，等下一輪靜置後再合併
commit_settled_changes() {
    local changed newest_mtime now quiet_age large_files

    changed=$(git ls-files -m -o --exclude-standard)
    [ -z "$changed" ] && return 0

    # 静置檢查：最新改動若仍在編輯保護期內，本輪不提交、不 merge
    newest_mtime=$(git ls-files -m -o --exclude-standard -z | xargs -0 stat -f %m 2>/dev/null | sort -n | tail -1)
    if [ -n "$newest_mtime" ]; then
        now=$(date +%s)
        quiet_age=$((now - newest_mtime))
        if [ "$quiet_age" -lt "$QUIET_GAP" ]; then
            log "⏳ 尚有檔案仍在編輯中 (${quiet_age}s < ${QUIET_GAP}s)，本輪先不提交、不合併，待靜置後下一輪處理"
            return 1
        fi
    fi

    retry_with_cleanup "git add -A"

    # 檢查並取消暫存過大的檔案
    large_files=$(list_large_files)
    if [ -n "$large_files" ]; then
        printf '%s' "$large_files" | xargs -0 -I{} git reset -q HEAD -- "{}"
        log "⛔ 跳過超大檔案: $(printf '%s' "$large_files" | tr '\0' ' ')"
    fi

    if ! git diff --cached --quiet; then
        if retry_with_cleanup "git commit -m 'Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')'"; then
            log "📝 本地已靜置變更已提交（merge 前）"
        else
            log "⚠️ 本地變更提交失敗，保留工作區不動"
            return 1
        fi
    fi
    return 0
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
    cleanup_stale_rebase

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

    # 预检：若已處於衝突態，先看標記是否已被用戶清空；未解決則本輪直接暫停，不 merge、不提交
    if ! stage_resolved_conflicts; then
        touch "$LAST_SYNC_TS"
        return 0
    fi

    # merge 前：先把已靜置好的本地改動提交，避免未提交改動擋住 merge
    if ! commit_settled_changes; then
        touch "$LAST_SYNC_TS"
        return 0
    fi

    local local_head remote_head
    local_head=$(git rev-parse HEAD 2>/dev/null || echo "N/A")
    remote_head=$(timeout "$GIT_TIMEOUT" git ls-remote origin -h "refs/heads/$BRANCH" | cut -f1)

    log "🧭 本地 HEAD: ${local_head:0:12}, 遠端 HEAD: ${remote_head:0:12}"

    # 只有當遠端有更新時才執行合併（普通 merge；不 rebase、不硬重置覆蓋本地）
    if [ -n "$remote_head" ] && [ "$local_head" != "$remote_head" ]; then
        if retry_with_cleanup "timeout '$GIT_TIMEOUT' git merge --no-edit 'origin/$BRANCH'"; then
            log "📥 已合併遠端更新"
            # 合併成功後拉取 LFS 物件
            retry_with_cleanup "timeout '$GIT_TIMEOUT' git lfs pull origin '$BRANCH'" || log "⚠️ LFS pull 失敗，保留本地狀態"
        else
            # 區分「衝突」與「其他失敗」：衝突保留標記供手動解，其餘保留工作區不動（不 reset、不強推）
            if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
                log "⚠️ 合併發生衝突，衝突標記已保留；請在 Logseq 中逐段解決並儲存，解決前暫停自動提交與推送"
            else
                log "⚠️ 拉取或合併失敗，保留本地工作區不動（不 reset、不強推）；本地未提交改動待靜置後下一輪重試"
            fi
            cleanup_stale_rebase
            touch "$LAST_SYNC_TS"
            return 0
        fi
    else
        log "✅ 本地已是最新，無需拉取"
    fi

    # merge 後再次確認衝突是否都已解決；未解決則暫停，不進入自動提交
    if ! stage_resolved_conflicts; then
        touch "$LAST_SYNC_TS"
        return 0
    fi

    # 編輯靜置檢查：改動文件若最近 QUIET_GAP 秒內仍被修改，本輪先不提交，留待下一輪
    local newest_mtime now quiet_age
    newest_mtime=$(git ls-files -m -o --exclude-standard -z | xargs -0 stat -f %m 2>/dev/null | sort -n | tail -1)
    if [ -n "$newest_mtime" ]; then
        now=$(date +%s)
        quiet_age=$((now - newest_mtime))
        if [ "$quiet_age" -lt "$QUIET_GAP" ]; then
            log "⏳ 檔案仍在編輯中 (${quiet_age}s < ${QUIET_GAP}s)，靜置後下一輪再提交"
            touch "$LAST_SYNC_TS"
            return 0
        fi
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
            # 先傳 LFS 物件，再傳提交（不強制推送）
            retry_with_cleanup "timeout '$GIT_TIMEOUT' git lfs push origin '$BRANCH'" || log "⚠️ LFS push 失敗"
            if retry_with_cleanup "timeout '$GIT_TIMEOUT' git push origin '$BRANCH'"; then
                log "📤 成功推送至遠端"
            else
                log "⚠️ 推送失敗或超時（不強制推送）"
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
