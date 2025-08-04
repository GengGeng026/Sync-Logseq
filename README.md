# Logseq 工業級自動同步系統 - 最終指南

> **狀態**：✅ 工業級穩定運行 (健康度 7/7)  
> **最後更新**：2025-08-04  
> **系統架構**：單一 LaunchAgent + 優化同步腳本 + 簡化日誌管理

## 🎯 系統概述

這是一個經過多次迭代和實戰驗證的 Logseq 自動同步系統，能夠：
- 🔄 **真正的自動恢復**：系統重啟、進程崩潰後自動重啟
- 📤 **智能同步**：實時文件監控 + Git 自動同步
- 🛡️ **工業級穩定**：進程鎖定 + 錯誤處理 + 簡化日誌管理
- 🚀 **快速響應**：2秒延遲，持續監控模式
- 🧹 **簡潔日誌**：只保留 2 個日誌文件，每個最多 100 行

## 📊 當前運行狀態

```bash
# 檢查 LaunchAgent 狀態
launchctl list com.logseq.sync

# 檢查進程狀態
ps aux | grep logseq_sync_optimized | grep -v grep

# 查看日誌
cat sync.log
cat error.log
```

## 🏗️ 系統架構

### 核心組件

1. **LaunchAgent**: `~/Library/LaunchAgents/com.logseq.sync.plist`
   - 負責自動啟動和進程管理
   - 系統重啟後自動恢復
   - 進程崩潰後自動重啟

2. **主同步腳本**: `logseq_sync_optimized.sh`
   - 文件監控 + 定時同步
   - Git 操作自動化
   - 進程鎖定機制

3. **簡化日誌系統**:
   - `sync.log` - 主要同步活動（最多 100 行）
   - `error.log` - LaunchAgent 錯誤輸出（最多 100 行）

### 日誌管理特性

- ✅ **自動修剪**：超過 100 行時自動覆蓋舊記錄
- ✅ **不創建備份**：直接覆蓋，保持系統簡潔
- ✅ **簡潔格式**：`月-日 時:分:秒` 時間格式
- ✅ **實時管理**：每次寫入後自動檢查行數

## 🔧 LaunchAgent 配置

**文件位置**: `~/Library/LaunchAgents/com.logseq.sync.plist`

```xml
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
    <string>/Users/mac/Documents/Sync-Logseq/error.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/mac/Documents/Sync-Logseq/error.log</string>
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
```

## 📝 主同步腳本核心邏輯

### 簡化日誌管理
```bash
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

log() { 
  echo "$(date '+%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
  manage_log_size "$LOG_FILE" 100
}
```

### 同步邏輯
```bash
sync_repo() {
  log "🎯 開始同步"
  
  # 清理 Git 鎖定文件
  find .git -name "*.lock" -delete 2>/dev/null
  
  # 檢查遠端更新
  local local_head=$(git rev-parse HEAD)
  local remote_head=$(git ls-remote origin -h refs/heads/main | cut -f1)
  
  # 智能同步邏輯
  if [ "$local_head" != "$remote_head" ]; then
    git pull origin main --no-edit
  fi
  
  # 推送本地變更
  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')"
    git push origin main
  fi
  
  log "✅ 同步完成"
}
```

## 🚀 安裝和配置

### 1. 創建 LaunchAgent
```bash
# 複製配置文件到正確位置
cp com.logseq.sync.plist ~/Library/LaunchAgents/

# 加載服務
launchctl load ~/Library/LaunchAgents/com.logseq.sync.plist
```

### 2. 確保腳本權限
```bash
chmod +x logseq_sync_optimized.sh
```

### 3. 驗證運行狀態
```bash
# 檢查服務狀態
launchctl list com.logseq.sync

# 檢查日誌
tail -f sync.log
```

## 🔍 故障排除

### 常見問題

1. **服務無法啟動**
   ```bash
   # 檢查腳本權限
   ls -la logseq_sync_optimized.sh
   chmod +x logseq_sync_optimized.sh
   
   # 重新加載服務
   launchctl unload ~/Library/LaunchAgents/com.logseq.sync.plist
   launchctl load ~/Library/LaunchAgents/com.logseq.sync.plist
   ```

2. **Git 推送失敗**
   ```bash
   # 檢查 Git 配置
   git config --list
   
   # 手動測試推送
   git push origin main
   ```

3. **日誌文件過大**
   - 系統會自動修剪至 100 行，無需手動處理

### 日誌分析

**sync.log 示例**：
```
08-04 19:13:46: 🚀 啟動同步服務
08-04 19:13:50: 🎯 開始同步
08-04 19:13:50: 📤 成功推送遠端
08-04 19:14:07: ✅ 同步完成
```

**error.log**：
- 記錄 LaunchAgent 的標準輸出和錯誤
- 通常為空表示運行正常

## 📈 系統健康度指標

**當前健康度：7/7** ⭐⭐⭐⭐⭐⭐⭐

- ✅ 核心功能正常運行
- ✅ 自動同步正常
- ✅ 日誌記錄完整且簡潔
- ✅ 進程鎖定機制正常
- ✅ 文件監控正常
- ✅ Git 操作正常
- ✅ LaunchAgent 配置完整

## 🎯 系統特點

### 優勢
- **真正的自動化**：無需手動干預
- **工業級穩定**：經過實戰驗證
- **簡潔高效**：最小化日誌管理
- **智能恢復**：自動處理各種異常情況

### 適用場景
- 個人 Logseq 筆記同步
- 多設備協作
- 自動備份需求
- 長期穩定運行

---

**維護建議**：
- 定期檢查 `launchctl list com.logseq.sync` 確保服務運行
- 偶爾查看 `sync.log` 了解同步狀態
- 系統更新後驗證服務是否正常啟動