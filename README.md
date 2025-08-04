# Logseq 工業級自動同步系統 - 最終指南

> **狀態**：✅ 工業級穩定運行 (健康度 7/7)  
> **最後更新**：2025-08-03  
> **系統架構**：單一 LaunchAgent + 優化同步腳本 + 自動恢復機制

## 🎯 系統概述

這是一個經過多次迭代和實戰驗證的 Logseq 自動同步系統，能夠：
- 🔄 **真正的自動恢復**：系統重啟、進程崩潰後自動重啟
- 📤 **智能同步**：實時文件監控 + Git 自動同步
- 🛡️ **工業級穩定**：進程鎖定 + 錯誤處理 + 日誌管理
- 🚀 **快速響應**：2秒延遲，持續監控模式

## 📊 當前運行狀態

```bash
# 檢查系統狀態
./logseq_sync_optimized.sh status

# 預期輸出：
# 🎯 系統健康度: 7/7
# ✅ 單一 plist 文件
# ✅ 單一同步進程  
# ✅ KeepAlive 已啟用
# ✅ 自動重啟測試通過
```

## 🏗️ 核心架構

### 最終架構（推薦）
```
單一 LaunchAgent 系統
├── ~/Library/LaunchAgents/com.logseq.sync.plist  # 唯一的 plist 配置
├── logseq_sync_optimized.sh                    # 優化的同步腳本
├── sync_optimized.log                          # 統一日誌
└── .sync_lock                                  # 進程鎖定機制
```

### 關鍵特性
- **KeepAlive: true** - 進程崩潰自動重啟
- **RunAtLoad: true** - 系統重啟自動啟動  
- **進程鎖定機制** - 防止重複運行
- **持續監控模式** - fswatch 避免重啟延遲
- **智能 debounce** - 2秒延遲防止頻繁同步

## 🚨 關鍵經驗教訓

### 💔 災難性事件記錄 (2025-07-22)

**災難代碼**：
```bash
if [ -d "~" ]; then
    rm -rf ~           # 這行代碼刪除了整個用戶主目錄！
fi
```

**核心教訓**：
1. **路徑安全原則**：永遠不要使用 `rm -rf ~` 或其他不確定的通配符。
2. **腳本審查**：AI 生成的腳本需要人工審查，尤其涉及刪除和系統修改。
3. **備份策略**：執行危險操作前必須備份所有重要數據。
4. **分步執行**：將複雜操作分解為安全的小步驟，每步都驗證。

### 🔧 技術演進關鍵突破

#### 1. SSH 認證持久化（基礎）
- 解決重啟後認證失效問題，確保系統重啟後認證依然有效。

#### 2. 多進程問題解決
- 統一腳本架構，單一入口，多模式。
- 進程鎖定機制防止重複運行。
- 精確進程檢測避免誤殺其他進程。

#### 3. 文件監控精確化
- **關鍵改進**：排除 `.git` 目錄，使用 `fswatch` 持續監控模式，並設置 `latency` 避免頻繁觸發。

#### 4. 系統重啟恢復機制
- 演進歷程：從多腳本到統一腳本，再到 LaunchAgent 實現系統級自動恢復，並通過進程鎖定和優化響應提高穩定性。

## 🛠️ 實戰部署指南

### 快速部署（如果需要從頭設置）
```bash
# 1. 停止舊服務並清理
launchctl unload ~/Library/LaunchAgents/com.logseq.sync.plist 2>/dev/null
pkill -f "logseq_sync" 2>/dev/null
rm -f ~/.sync_lock

# 2. 創建 logseq_sync_optimized.sh 腳本（如果不存在或要更新）
# （此步驟假設腳本已由之前的步驟創建）
# cat > logseq_sync_optimized.sh << 'EOF'

#!/bin/bash
# Logseq Git 同步腳本：支援 fswatch + 定時遠端 HEAD 比對

### 設定區 ###
REPO_DIR="$HOME/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/sync_optimized.log"
LOCK_FILE="$REPO_DIR/.sync_lock"
LAST_SYNC_TS="$REPO_DIR/.last_sync"
PULL_INTERVAL=300  # 每五分鐘主動拉一次

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

# 賦予權限
chmod +x logseq_sync_optimized.sh

# 3. 創建或更新 LaunchAgent plist
cat > ~/Library/LaunchAgents/com.logseq.sync.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.logseq.sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/mac/Documents/Sync-Logseq/logseq_sync_optimized.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>/Users/mac/Documents/Sync-Logseq</string>
    <key>StandardOutPath</key>
    <string>/Users/mac/Documents/Sync-Logseq/launchd.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/mac/Documents/Sync-Logseq/launchd_error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
        <key>HOME</key>
        <string>/Users/mac</string>
    </dict>
    <key>ThrottleInterval</key>
    <integer>5</integer>
</dict>
</plist>
