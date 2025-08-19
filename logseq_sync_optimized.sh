#!/bin/bash
# Logseq Git 同步腳本：支援 fswatch + 定時遠端 HEAD 比對
<<<<<<< HEAD

### 設定區 ###
REPO_DIR="$HOME/Documents/Sync-Logseq"
=======
# 已加入：自動取消 staged 超過 100MB 的檔案（不刪本機），
# 並在推送前僅檢查要推送的 commit 是否包含 >100MB blob（推薦）
# 且確保在 commit 失敗時不會誤推送

### 設定區 ###
REPO_DIR="$HOME/Documents/Sync-Logseq"
if [ -x "$REPO_DIR/scripts/install-hooks.sh" ]; then
  "$REPO_DIR/scripts/install-hooks.sh" >> "$LOG_FILE" 2>&1 || true
fi
>>>>>>> main
LOG_DIR="$REPO_DIR/.logs"
LOG_FILE="$LOG_DIR/sync.log"
LOCK_FILE="$REPO_DIR/.sync_lock"
LAST_SYNC_TS="$REPO_DIR/.last_sync"
<<<<<<< HEAD
PULL_INTERVAL="${LOGSEQ_PULL_INTERVAL:-60}"  # 每五分鐘主動拉一次

export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"
cd "$REPO_DIR" || exit 1
=======
PULL_INTERVAL="${LOGSEQ_PULL_INTERVAL:-15}"  # 每 PULL_INTERVAL 秒主動拉一次

export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"
cd "$REPO_DIR" || exit 1
# 啟動防呆：若殘留上一輪的同步鎖，啟動時嘗試清除
RUN_LOCK="$REPO_DIR/.sync_run.lockdir"
[ -d "$RUN_LOCK" ] && rmdir "$RUN_LOCK" 2>/dev/null || true

if [ -x "$REPO_DIR/scripts/install-hooks.sh" ]; then
  "$REPO_DIR/scripts/install-hooks.sh" >> "$LOG_FILE" 2>&1 || true
fi

>>>>>>> main

# Detect branch to sync (default to origin/HEAD, fallback to main)
BRANCH="${LOGSEQ_SYNC_BRANCH:-$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's#origin/##')}"
[ -z "$BRANCH" ] && BRANCH="main"
echo "$(date '+%m-%d %H:%M:%S'): Using branch: $BRANCH" >> "$LOG_FILE"

### 簡化日誌控制 ###
manage_log_size() {
  local log_file="$1" max_lines="${2:-100}"
  [ ! -f "$log_file" ] && return
  local current_lines=$(wc -l < "$log_file")
  if [ "$current_lines" -gt "$max_lines" ]; then
    tail -n "$max_lines" "$log_file" > "${log_file}.tmp"
    mv "${log_file}.tmp" "$log_file"
    echo "$(date '+%m-%d %H:%M:%S'): 日誌已修剪至 $max_lines 行" >> "$log_file"
  fi
}
log() { echo "$(date '+%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"; manage_log_size "$LOG_FILE" 100; }

### 鎖定機制 ###
if [ -f "$LOCK_FILE" ]; then
  pid=$(cat "$LOCK_FILE")
  if kill -0 "$pid" 2>/dev/null; then exit 0; else rm -f "$LOCK_FILE"; fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"; exit' EXIT INT TERM

<<<<<<< HEAD
=======
### 工具函式：判斷並取消 staged 的超大檔 ###
unstage_large_files_guard() {
  # 取消 staged 所有超過 limit 的檔案（不刪本機檔）
  local limit=$((100*1024*1024)) # 100MB
  local staged
  staged=$(git diff --cached --name-only --diff-filter=AM) || staged=""
  [ -z "$staged" ] && return 0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue
    size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo 0)
    if [ "$size" -gt "$limit" ]; then
      echo "$(date '+%m-%d %H:%M:%S'): Auto-sync: unstaging large file $f (size: $size bytes)" >> "$LOG_FILE"
      git reset -- "$f" >> "$LOG_FILE" 2>&1 || true
    fi
  done <<< "$staged"
}

# 檢查即將推送的 commits 中是否有超過 100MB 的 blob（只檢查 origin/BRANCH..HEAD 範圍）
commits_to_push_have_large_blob() {
  local branch_ref="${1:-$BRANCH}"
  # 確保 origin 有最新資訊
  git fetch origin "$branch_ref" --quiet 2>/dev/null || true
  # 找出要推的 commit 範圍（local 不在 remote 的 commits）
  local commit_range
  commit_range=$(git rev-list origin/"$branch_ref"..HEAD 2>/dev/null || true)
  [ -z "$commit_range" ] && return 1  # no commits to push => no large blobs in commits-to-push

  # 列出這些 commits 的 objects 並檢查 blob size
  git rev-list origin/"$branch_ref"..HEAD --objects 2>/dev/null \
    | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' 2>/dev/null \
    | awk '$1=="blob" && $3>104857600 {print $0}' | grep -q . 2>/dev/null
}

>>>>>>> main
### 核心同步 ###
sync_repo() {
  # Re-entrancy guard to avoid concurrent git operations (with stale lock recovery)
  local RUN_LOCK="$REPO_DIR/.sync_run.lockdir"
  if ! mkdir "$RUN_LOCK" 2>/dev/null; then
<<<<<<< HEAD
    # If lock exists, check if it's stale (>180s)
=======
>>>>>>> main
    if [ -d "$RUN_LOCK" ]; then
      local now_ts=$(date +%s)
      local m_ts=$(stat -f %m "$RUN_LOCK" 2>/dev/null || echo 0)
      local age=$(( now_ts - m_ts ))
<<<<<<< HEAD
      if [ "$age" -gt 180 ]; then
=======
      if [ "$age" -gt 45 ]; then
>>>>>>> main
        log "🧹 偵測到過期的同步鎖 (age=${age}s)，嘗試清除"
        rmdir "$RUN_LOCK" 2>/dev/null || true
        if ! mkdir "$RUN_LOCK" 2>/dev/null; then
          log "⏳ 仍有同步在進行，略過本次"
          return 0
        fi
      else
        log "⏳ 另一個同步仍在進行（${age}s），略過本次"
        return 0
      fi
    else
      log "⏳ 另一個同步仍在進行，略過本次"
      return 0
    fi
  fi
<<<<<<< HEAD
  # Ensure lock is always released
  cleanup_run_lock() { rmdir "$RUN_LOCK" 2>/dev/null || true; }
  trap cleanup_run_lock RETURN
  log "🎯 開始同步"
  find .git -name "*.lock" -delete 2>/dev/null
  git checkout "$BRANCH" >> "$LOG_FILE" 2>&1
=======
  cleanup_run_lock() { rmdir "$RUN_LOCK" 2>/dev/null || true; }
  trap cleanup_run_lock RETURN

  log "🎯 開始同步"
  find .git -name "*.lock" -delete 2>/dev/null
  git checkout "$BRANCH" >> "$LOG_FILE" 2>&1 || { log "⚠️ checkout $BRANCH 失敗"; return 1; }
>>>>>>> main

  local local_head=$(git rev-parse HEAD)
  local remote_head=$(git ls-remote origin -h "refs/heads/$BRANCH" | cut -f1)
  log "🧭 本地 HEAD: $local_head"
  log "🌐 遠端 HEAD: $remote_head"

  if [ "$local_head" != "$remote_head" ]; then
    if git pull origin "$BRANCH" --no-edit >> "$LOG_FILE" 2>&1; then
      log "📥 成功拉取遠端"
    else
      log "⚠️ 拉取失敗，執行 hard reset"
      git fetch --all >> "$LOG_FILE" 2>&1
      git reset --hard "origin/$BRANCH" >> "$LOG_FILE" 2>&1
    fi
  else
    log "🚫 無遠端更新，略過 pull"
  fi

<<<<<<< HEAD
  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1
    log "📝 本地變更已提交"
  fi

  if git push origin "$BRANCH" >> "$LOG_FILE" 2>&1; then
    log "📤 成功推送遠端"
  else
    log "⚠️ 推送失敗"
=======
  # Add everything first
  git add -A >> "$LOG_FILE" 2>&1 || true

  # Guard: unstage any staged file >100MB before commit
  unstage_large_files_guard

  # Try to commit; check exit code
  local commit_succeeded=false
  if git diff --cached --quiet; then
    log "ℹ️ no staged changes after guard, skipping commit"
    commit_succeeded=false
  else
    if git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1; then
      log "📝 本地變更已提交"
      commit_succeeded=true
    else
      log "🚫 commit 被中止（可能 pre-commit 阻擋或其他錯誤），跳過 push"
      # append last part of log to aid debugging
      tail -n 80 "$LOG_FILE" >> "$LOG_FILE"
      commit_succeeded=false
    fi
  fi

  # Only attempt push if commit succeeded
  if [ "$commit_succeeded" = true ]; then
    # Final safety: check only the commits that would be pushed (origin/BRANCH..HEAD)
    if commits_to_push_have_large_blob "$BRANCH"; then
      log "🚫 檢測到大檔在即將推送的 commits 中；跳過 push 以免被遠端拒絕"
    else
      if git push origin "$BRANCH" >> "$LOG_FILE" 2>&1; then
        log "📤 成功推送遠端"
      else
        log "⚠️ 推送失敗"
      fi
    fi
  else
    log "ℹ️ 未執行 push（commit 未成功或無需 commit）"
>>>>>>> main
  fi

  date +%s > "$LAST_SYNC_TS"
  log "✅ 同步完成"
}

### 監控變更 ###
watch_filesystem() {
  if ! command -v fswatch >/dev/null 2>&1; then
    log "⚠️ 未安裝 fswatch，將僅使用定時輪詢"
    return 0
  fi
  fswatch -r "$REPO_DIR" \
    --exclude="\.git/" \
    --exclude="\.log$" \
    --exclude="\.lock$" \
    --exclude="\.tmp$" \
    --exclude="\.logs/" \
    --exclude="\.sync_run\.lockdir$" \
    --exclude="\.last_sync$" \
<<<<<<< HEAD
    --latency=2 | while read -r ev; do
      sleep 2
      if [ -n "$(find "$REPO_DIR" -type f -newer "$LAST_SYNC_TS" \
        -not -path "$LOG_DIR/*" \
        -not -path "$REPO_DIR/.sync_run.lockdir*" \
        -not -name ".last_sync" | head -1)" ]; then
        log "📁 檢測到變化: $ev"
        sync_repo
      fi
=======
    --exclude="\.sync_debounce$" \
    --latency=2 | while read -r ev; do
      # 真正去抖動：只有在最近事件後靜默 2 秒才觸發
      now=$(date +%s)
      echo "$now" > "$REPO_DIR/.sync_debounce"
      ( sleep 2 \
        && last=$(cat "$REPO_DIR/.sync_debounce" 2>/dev/null || echo 0) \
        && [ "$last" -eq "$now" ] \
        && {
             if git -C "$REPO_DIR" status --porcelain | grep -q . \
                || find "$REPO_DIR" -type f -newer "$LAST_SYNC_TS" \
                     -not -path "$LOG_DIR/*" \
                     -not -path "$REPO_DIR/.sync_run.lockdir*" \
                     -not -name ".last_sync" \
                     -print -quit | grep -q .; then
               log "📁 檢測到版本變更，觸發同步: $ev"
               sync_repo
             fi
           } ) &
>>>>>>> main
    done
}

### 定時拉取 ###
poll_remote() {
  while true; do
    sleep "$PULL_INTERVAL"
    log "⏱ 進行定時遠端同步"
    sync_repo
  done
}

### 啟動 ###
mkdir -p "$LOG_DIR"
manage_log_size "$LOG_FILE" 100
log "🚀 啟動同步服務"
sync_repo
touch "$LAST_SYNC_TS"

# 並行執行兩個 loop
watch_filesystem &
poll_remote &
wait
