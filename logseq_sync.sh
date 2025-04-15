#!/bin/bash
# 文件名: logseq_sync.sh
# 保存位置: /Users/mac/Documents/Sync-Logseq/logseq_sync.sh

# 設置工作目錄和日誌文件
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_FILE="/dev/null"  # 改為 /dev/null 而不是實際文件
cd "$REPO_DIR" || exit

# 清理鎖定文件（如果存在）
cleanup() {
  find .git -name "*.lock" -delete 2>/dev/null
}

# 日誌輪換
rotate_logs() {
  # 限制日誌大小為1MB
  for log_file in "$LOG_FILE" "$REPO_DIR/sync_stdout.log" "$REPO_DIR/sync_stderr.log"; do
    if [ -f "$log_file" ] && [ $(stat -f%z "$log_file") -gt 1048576 ]; then
      timestamp=$(date +"%Y%m%d_%H%M%S")
      mv "$log_file" "${log_file}.${timestamp}"
      touch "$log_file"
      # 只保留最近5個日誌文件
      ls -t "${log_file}."* | tail -n +6 | xargs rm -f 2>/dev/null
    fi
  done
}

# 同步功能
sync_repo() {
  echo "$(date): 開始同步..." >> "$LOG_FILE"
  
  # 清理任何潛在的鎖定文件
  cleanup
  
  # 檢查本地是否有未提交的更改
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "$(date): 本地有未提交的更改，請先提交或處理後再同步。" >> "$LOG_FILE"
    echo "$(date): 同步中止" >> "$LOG_FILE"
    exit 1
  fi
  
  # 沒有本地更改，安全拉取
  pull_output=$(git pull origin main 2>&1)
  pull_status=$?
  
  if [ $pull_status -ne 0 ]; then
    echo "$(date): 拉取失敗，請檢查網絡或遠端狀態。" >> "$LOG_FILE"
    echo "$pull_output" >> "$LOG_FILE"
    exit 1
  fi
  
  # 只有在拉取成功後才繼續執行後面的步驟
  # 只在輸出不是"Already up to date"時記錄
  if [ "$pull_output" != "Already up to date." ]; then
    echo "$(date): $pull_output" >> "$LOG_FILE"
  fi
  
  # 添加所有變更
  git add -A
  
  # 檢查是否有變更需要提交
  if ! git diff --cached --quiet; then
    echo "$(date): 發現變更，提交中..." >> "$LOG_FILE"
    git commit -m "Auto-sync: $(date)" >> "$LOG_FILE" 2>&1
    
    # 推送變更
    push_output=$(git push origin main 2>&1)
    if [ $? -ne 0 ]; then
      echo "$(date): 推送失敗: $push_output" >> "$LOG_FILE"
      cleanup
      git push origin main --force >> "$LOG_FILE" 2>&1
    fi
  else
    # 檢查本地是否領先遠端
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main 2>/dev/null)
    
    if [ "$LOCAL" != "$REMOTE" ]; then
      echo "$(date): 本地領先遠端，推送剩餘提交..." >> "$LOG_FILE"
      git push origin main >> "$LOG_FILE" 2>&1
    else
      echo "$(date): 沒有變更，無需同步" >> "$LOG_FILE"
    fi
  fi
  
  echo "$(date): 同步完成" >> "$LOG_FILE"
  echo "------------------------" >> "$LOG_FILE"
}

# 輪換日誌
rotate_logs

# 進行初始同步
sync_repo

# 監視文件變更
echo "$(date): 開始監視文件變更..." >> "$LOG_FILE"
fswatch -o --exclude ".git" "$REPO_DIR" | while read -r change; do
  # 記錄檢測到變更的時間
  change_time=$(date +%s)
  
  # 等待 5 秒
  sleep 5
  
  # 再次檢查最近修改時間，確保文件已停止修改
  latest_change=$(find "$REPO_DIR" -path '*/.git/*' -prune -o -type f -newer "$REPO_DIR/.last_sync" -print -quit 2>/dev/null)
  
  if [ -n "$latest_change" ]; then
    latest_change_time=$(stat -f %m "$latest_change")
    
    # 如果最近修改時間與檢測時間相差超過5秒，說明文件已穩定
    if [ $(( $change_time - $latest_change_time )) -gt 5 ]; then
      rotate_logs
      sync_repo
      touch "$REPO_DIR/.last_sync"
    fi
  fi
done

# 將 300 秒(5分鐘)改為 120 秒(2分鐘)，但增加變更檢測
if [ ! -f "$REPO_DIR/.last_sync" ] || [ $(( $(date +%s) - $(stat -f %m "$REPO_DIR/.last_sync") )) -gt 120 ]; then
  # 檢查是否有足夠的變更量
  changes_count=$(git status --porcelain | wc -l | tr -d ' ')
  if [ "$changes_count" -gt 2 ]; then  # 至少有3個文件變更才同步
    rotate_logs
    sync_repo
    touch "$REPO_DIR/.last_sync"
  fi
fi
