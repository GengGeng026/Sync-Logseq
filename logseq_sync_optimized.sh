#!/bin/bash
# 最終版 Logseq 同步腳本 - 日誌、鎖檔、自動重啟支援

### 參數設定 ###
REPO_DIR="$HOME/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/sync_optimized.log"
LOCK_FILE="$REPO_DIR/.sync_lock"
LAST_SYNC_TS="$REPO_DIR/.last_sync"
PULL_INTERVAL=300   # 5 分鐘

### 日誌輪換 ###
manage_log_size() {
  local log_file="$1" max_kb="${2:-512}" keep_lines="${3:-500}"
  [ ! -f "$log_file" ] && return
  local size_kb=$(( $(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null) / 1024 ))
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
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
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

  if git pull origin main --no-edit >> "$LOG_FILE" 2>&1; then
    log "📥 成功拉取遠端"
  else
    log "⚠️ 拉取失敗，執行硬重置"
    git fetch --all >> "$LOG_FILE" 2>&1
    git reset --hard origin/main >> "$LOG_FILE" 2>&1
  fi

  if git push origin main >> "$LOG_FILE" 2>&1; then
    log "📤 成功推送遠端"
  else
    log "⚠️ 推送失敗"
  fi

  date +%s > "$LAST_SYNC_TS"
  log "✅ 同步完成"
}

# 初始化日誌輪替
manage_log_size "$LOG_FILE" 512 500
log "🚀 啟動同步服務"

# 建立 .last_sync 檔（若不存在）
[ -f "$LAST_SYNC_TS" ] || touch "$LAST_SYNC_TS"

needs_pull() {
  git fetch origin main >> "$LOG_FILE" 2>&1
  LOCAL_HASH=$(git rev-parse HEAD)
  REMOTE_HASH=$(git rev-parse origin/main)
  if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
    log "🌐 偵測到遠端有更新（$REMOTE_HASH ≠ $LOCAL_HASH）"
    return 0
  else
    return 1
  fi
}

# 初始同步
sync_repo() {
  log "🎯 開始同步"

  find .git -name "*.lock" -delete 2>/dev/null
  git checkout main >> "$LOG_FILE" 2>&1

  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1
    log "📝 本地變更已提交"
  fi

  if needs_pull; then
    if git pull origin main --no-edit >> "$LOG_FILE" 2>&1; then
      log "📥 成功拉取遠端"
    else
      log "⚠️ 拉取失敗，執行硬重置"
      git reset --hard origin/main >> "$LOG_FILE" 2>&1
    fi
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


# 檔案變更監控（即時觸發）
log "👀 啓動 fswatch 檔案監控..."
fswatch -r "$REPO_DIR" \
  --exclude="\.git/" \
  --exclude="\.log$" \
  --exclude="\.lock$" \
  --exclude="\.tmp$" \
  --latency=2 \
  --one-per-batch | while read -r ev; do
    log "📁 檢測到變更: $ev"
    sleep 2
    if [ -n "$(find "$REPO_DIR" -newer "$LAST_SYNC_TS" | head -1)" ]; then
      sync_repo
    fi
  done &

# 週期檢查（備用機制）
while true; do
  sleep "$PULL_INTERVAL"
  log "⏰ 執行定期同步"
  sync_repo
done
