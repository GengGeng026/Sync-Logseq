#!/bin/bash
# 文件名: logseq_sync.sh
# 保存位置: /Users/mac/Documents/Sync-Logseq/logseq_sync.sh

# 設置工作目錄和日誌文件
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/sync_log.txt"
cd "$REPO_DIR" || exit

# 清理鎖定文件（如果存在）
cleanup() {
  find .git -name "*.lock" -delete 2>/dev/null
}

# 同步功能
sync_repo() {
  echo "$(date): 開始同步..." >> "$LOG_FILE"
  
  # 清理任何潛在的鎖定文件
  cleanup
  
  # 同步策略：先拉取，如有衝突則重置再拉取
  pull_output=$(git pull origin main 2>&1)
  pull_status=$?
  
  if [ $pull_status -ne 0 ]; then
    echo "$(date): 拉取失敗，嘗試恢復..." >> "$LOG_FILE"
    git reset --hard HEAD
    git pull origin main >> "$LOG_FILE" 2>&1
  else
    # 只在輸出不是"Already up to date"時記錄
    if [ "$pull_output" != "Already up to date." ]; then
      echo "$(date): $pull_output" >> "$LOG_FILE"
    fi
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

# 主循環
while true; do
  sync_repo
  sleep 15  # 每15秒同步一次
done
