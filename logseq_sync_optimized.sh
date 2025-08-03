#!/bin/bash
# 最終版 Logseq 同步腳本 - 自動啟動、自動監聽、日誌、鎖檔、重置支援

### 參數設定 ###
REPO_DIR="$HOME/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/sync_optimized.log"
LOCK_FILE="$REPO_DIR/.sync_lock"
LAST_SYNC_TS="$REPO_DIR/.last_sync"
PULL_INTERVAL=300  # 每 5 分鐘備援同步

### 日誌輪替 ###
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
    echo "$(date): 日誌已輪替，保留最後 $keep_lines 行" >> "$log_file"
  fi
}

### 鎖檔機制 ###
if [ -f "$LOCK_FILE" ]; then
  pid=$(cat "$LOCK_FILE")
  if kill -0 "$pid" 2>/dev/null; then
    exit 0
  else
    rm -f "$LOCK_FILE"
  fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"; exit' EXIT INT TERM

### 環境與工作目錄 ###
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"
cd "$REPO_DIR" || exit 1

### 日誌記錄函數 ###
log() { echo "$(date '+%Y-%m-%d %H:%M:%S'): [PID:$$] $1" >> "$LOG_FILE"; }

### 同步函數 ###
sync_repo() {
  log "🎯 開始同步"

  find .git -name "*.lock" -delete 2>/dev/null
  git checkout main >> "$LOG_FILE" 2>&1

  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1
    log "📝 本地變更已提交"
  fi

  git fetch origin main >> "$LOG_FILE" 2>&1
  LOCAL_HASH=$(git rev-parse HEAD)
  REMOTE_HASH=$(git rev-parse origin/main)

  if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
    log "📥 偵測到遠端有更新，執行 reset --hard"
    git reset --hard origin/main >> "$LOG_FILE" 2>&1
  else
    log "🚫 無遠端更新，略過 pull"
  fi

  if git push origin main >> "$LOG_FILE" 2>&1; then
    log "📤 成功推送遠端"
  else
    log "⚠️ 推送失敗"
  fi

  date +%s > "$LAST_SYNC_TS"
  log "✅ 同步完成"
}

### 啟動紀錄 ###
manage_log_size "$LOG_FILE" 512 500
log "🚀 啟動同步服務"
sync_repo
touch "$LAST_SYNC_TS"

### fswatch 檔案監控 ###
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
  done &

### 備援輪詢 ###
while true; do
  sleep "$PULL_INTERVAL"
  log "⏰ 定期檢查"
  sync_repo
done
