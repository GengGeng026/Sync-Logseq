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
  # 清除 Git lock
  find .git -name "*.lock" -delete 2>/dev/null

  # 切到 main (可改成你的分支)
  git checkout main >> "$LOG_FILE" 2>&1

  # 將本地未暫存變更自動提交
  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1
    log "📝 本地變更已提交"
  fi

  # 拉取遠端，若失敗則硬重置
  if git pull origin main --no-edit >> "$LOG_FILE" 2>&1; then
    log "📥 成功拉取遠端"
  else
    log "⚠️ 拉取失敗，執行硬重置"
    git fetch --all >> "$LOG_FILE" 2>&1
    git reset --hard origin/main >> "$LOG_FILE" 2>&1
  fi

  # 推送
  if git push origin main >> "$LOG_FILE" 2>&1; then
    log "📤 成功推送遠端"
  else
    log "⚠️ 推送失敗"
  fi

  # 更新最後同步時間
  date +%s > "$LAST_SYNC_TS"
  log "✅ 同步完成"
}

# 初始化日誌輪替
manage_log_size "$LOG_FILE" 512 500
log "🚀 啟動同步服務"

# 先執行一次
sync_repo
touch "$LAST_SYNC_TS"

# 檔案變更監控（即時觸發）
fswatch -r "$REPO_DIR" \
  --exclude="\.git/" \
  --exclude="\.log$" \
  --exclude="\.lock$" \
  --latency=2 | while read -r ev; do
    sleep 2
    # 只在上次同步後有新變更時才觸發
    if [ -n "$(find "$REPO_DIR" -newer "$LAST_SYNC_TS" | head -1)" ]; then
      sync_repo
    fi
  done &

# 週期檢查（備用）
while true; do
  sleep "$PULL_INTERVAL"
  sync_repo
done
