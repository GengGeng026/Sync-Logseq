#!/bin/bash
# Logseq Git 同步腳本：支援 fswatch + 定時遠端 HEAD 比對

### 設定區 ###
REPO_DIR="$HOME/Documents/Sync-Logseq"
LOG_DIR="$REPO_DIR/.logs"
LOG_FILE="$LOG_DIR/sync.log"
LOCK_FILE="$REPO_DIR/.sync_lock"
LAST_SYNC_TS="$REPO_DIR/.last_sync"
PULL_INTERVAL="${LOGSEQ_PULL_INTERVAL:-60}"  # 每五分鐘主動拉一次

export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"
cd "$REPO_DIR" || exit 1

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

### 核心同步 ###
sync_repo() {
  # Re-entrancy guard to avoid concurrent git operations (with stale lock recovery)
  local RUN_LOCK="$REPO_DIR/.sync_run.lockdir"
  if ! mkdir "$RUN_LOCK" 2>/dev/null; then
    # If lock exists, check if it's stale (>180s)
    if [ -d "$RUN_LOCK" ]; then
      local now_ts=$(date +%s)
      local m_ts=$(stat -f %m "$RUN_LOCK" 2>/dev/null || echo 0)
      local age=$(( now_ts - m_ts ))
      if [ "$age" -gt 180 ]; then
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
  # Ensure lock is always released
  cleanup_run_lock() { rmdir "$RUN_LOCK" 2>/dev/null || true; }
  trap cleanup_run_lock RETURN
  log "🎯 開始同步"
  find .git -name "*.lock" -delete 2>/dev/null
  git checkout "$BRANCH" >> "$LOG_FILE" 2>&1

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

  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1
    log "📝 本地變更已提交"
  fi

  if git push origin "$BRANCH" >> "$LOG_FILE" 2>&1; then
    log "📤 成功推送遠端"
  else
    log "⚠️ 推送失敗"
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
    --latency=2 | while read -r ev; do
      sleep 2
      if [ -n "$(find "$REPO_DIR" -newer "$LAST_SYNC_TS" | head -1)" ]; then
        log "📁 檢測到變化: $ev"
        sync_repo
      fi
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
