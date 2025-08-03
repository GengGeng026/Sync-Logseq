#!/bin/bash
# Logseq Git 同步腳本：支援 fswatch + 定時遠端 HEAD 比對

### 設定區 ###
REPO_DIR="$HOME/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/sync_optimized.log"
LOCK_FILE="$REPO_DIR/.sync_lock"
LAST_SYNC_TS="$REPO_DIR/.last_sync"
PULL_INTERVAL=30  # 每五分鐘主動拉一次

export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"
cd "$REPO_DIR" || exit 1

### Log 控制 ###
manage_log_size() {
  local log_file="$1" max_kb="${2:-512}" keep_lines="${3:-500}"
  [ ! -f "$log_file" ] && return
  local size_kb=$(( $(stat -f%z "$log_file") / 1024 ))
  if [ "$size_kb" -gt "$max_kb" ]; then
    local ts=$(date +"%Y%m%d_%H%M%S")
    cp "$log_file" "${log_file}.${ts}"
    tail -n "$keep_lines" "$log_file" > "${log_file}.tmp"
    mv "${log_file}.tmp" "$log_file"
    ls -t "${log_file}".* 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null
    echo "$(date): 日誌已輪替" >> "$log_file"
  fi
}
log() { echo "$(date '+%Y-%m-%d %H:%M:%S'): [PID:$$] $1" >> "$LOG_FILE"; }

### 鎖定機制 ###
if [ -f "$LOCK_FILE" ]; then
  pid=$(cat "$LOCK_FILE")
  if kill -0 "$pid" 2>/dev/null; then exit 0; else rm -f "$LOCK_FILE"; fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"; exit' EXIT INT TERM

### 核心同步 ###
sync_repo() {
  log "🎯 開始同步"
  find .git -name "*.lock" -delete 2>/dev/null
  git checkout main >> "$LOG_FILE" 2>&1

  local local_head=$(git rev-parse HEAD)
  local remote_head=$(git ls-remote origin -h refs/heads/main | cut -f1)
  log "🧭 本地 HEAD: $local_head"
  log "🌐 遠端 HEAD: $remote_head"

  if [ "$local_head" != "$remote_head" ]; then
    if git pull origin main --no-edit >> "$LOG_FILE" 2>&1; then
      log "📥 成功拉取遠端"
    else
      log "⚠️ 拉取失敗，執行 hard reset"
      git fetch --all >> "$LOG_FILE" 2>&1
      git reset --hard origin/main >> "$LOG_FILE" 2>&1
    fi
  else
    log "🚫 無遠端更新，略過 pull"
  fi

  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1
    log "📝 本地變更已提交"
  fi

  if git push origin main >> "$LOG_FILE" 2>&1; then
    log "📤 成功推送遠端"
  else
    log "⚠️ 推送失敗"
  fi

  date +%s > "$LAST_SYNC_TS"
  log "✅ 同步完成"
}

### 監控變更 ###
watch_filesystem() {
  fswatch -r "$REPO_DIR" \
    --exclude="\.git/" \
    --exclude="\.log$" \
    --exclude="\.lock$" \
    --latency=2 | while read -r ev; do
      sleep 2
      if [ -n "$(find "$REPO_DIR" -newer "$LAST_SYNC_TS" | head -1)" ]; then
        log "📁 檢測到變更: $ev"
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
manage_log_size "$LOG_FILE" 512 500
log "🚀 啟動同步服務"
sync_repo
touch "$LAST_SYNC_TS"

# 並行執行兩個 loop
watch_filesystem &
poll_remote &
wait
