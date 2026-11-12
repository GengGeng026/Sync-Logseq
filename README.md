# Logseq 工業級自動同步系統 - 最終指南

以下內容為基於當前目錄與實際可運行配置的最終落地版說明，確保「任何全新機器」都能按本文逐步實現相同的自動流。

> **狀態**：✅ 雙端對齊運行（Mac + Android Termux），Git LFS 接管錄音  
> **最後更新**：2026-11-13  
> **系統架構**：Mac LaunchAgent 定時/監聽同步 + 手機 Termux 腳本 + Tasker 事件觸發 + FolderSync 錄音落地 + Git LFS 大檔接管  
> **倉庫**：GitHub `GengGeng026/Sync-Logseq`，分支 `main`
>
> 本文檔是災難重建與排障依據：設備丟失/重裝時，按附錄 D（Mac）、附錄 F（手機端）、附錄 H（對齊與衝突處理）逐步恢復。

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
launchctl list com.logseq.sync.v2

# 檢查進程狀態
ps aux | grep logseq_sync_optimized | grep -v grep

# 查看日誌
cat sync.log
cat error.log
```

## 🏗️ 系統架構

### 核心組件

1. **LaunchAgent**: `~/Library/LaunchAgents/com.logseq.sync.v2.plist`
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

**文件位置**: `~/Library/LaunchAgents/com.logseq.sync.v2.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.logseq.sync.v2</string>
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
cp com.logseq.sync.v2.plist ~/Library/LaunchAgents/

# 加載服務
launchctl load ~/Library/LaunchAgents/com.logseq.sync.v2.plist
```

### 2. 確保腳本權限
```bash
chmod +x logseq_sync_optimized.sh
```

### 3. 驗證運行狀態
```bash
# 檢查服務狀態
launchctl list com.logseq.sync.v2

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
   launchctl unload ~/Library/LaunchAgents/com.logseq.sync.v2.plist
   launchctl load ~/Library/LaunchAgents/com.logseq.sync.v2.plist
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

## ⚠️ 血淋淋的災難性教訓

> **警告**：以下是真實發生的災難性事件記錄，必須永遠銘記！

### 💀 災難事件：差點刪除整個系統

**時間**：開發過程中  
**事件**：AI 助手生成的 `cleanup_workspace.sh` 腳本包含致命代碼  
**後果**：差點執行 `rm -rf ~` 刪除整個用戶目錄

#### 🔥 致命代碼片段
```bash
# 災難性的第 56-59 行代碼
if [ -d "~" ]; then
    rm -rf ~        # 這行代碼會刪除整個用戶主目錄！
    echo "已刪除錯誤的 ~ 目錄"
fi
```

#### 💥 災難性分析
- **原意**：檢查是否存在名為 `~` 的目錄
- **實際效果**：`rm -rf ~` 會展開為 `rm -rf /Users/mac/`
- **潛在損失**：整個用戶目錄及所有數據

#### 🚨 立即建議（當時的緊急措施）
1. **停止所有操作** - 避免覆蓋已刪除的數據
2. **專注數據恢復** - 繼續使用 Disk Drill
3. **檢查 Time Machine** - 如果有備份
4. **避免寫入磁盤** - 減少數據被覆蓋的風險

#### 🛡️ 我的深刻教訓
這是我作為 AI 助手犯下的最嚴重錯誤。我應該：
- 更仔細地檢查腳本邏輯
- 使用更安全的路徑處理
- 在執行前進行充分測試

**我對造成的損失深表歉意。你的數據恢復是現在的最高優先級。**

### 🔒 永久安全措施

#### 1. 代碼審查檢查清單
- [ ] **路徑檢查**：確保所有路徑都是絕對路徑且正確
- [ ] **危險命令檢查**：搜索 `rm -rf`、`rm -r`、`>/dev/null` 等
- [ ] **變數展開檢查**：確認 `~`、`$HOME` 等變數正確使用
- [ ] **測試環境**：先在安全環境中測試所有腳本

#### 2. 腳本安全原則
```bash
# ✅ 安全的做法
TARGET_DIR="/specific/safe/path"
if [ -d "$TARGET_DIR" ] && [ "$TARGET_DIR" != "/" ] && [ "$TARGET_DIR" != "$HOME" ]; then
    rm -rf "$TARGET_DIR"
fi

# ❌ 危險的做法
rm -rf ~        # 永遠不要這樣做！
rm -rf $HOME    # 同樣危險！
rm -rf /        # 系統級災難！
```

#### 3. 備份策略
- **Time Machine**：每小時自動備份
- **Git 倉庫**：重要代碼雙重備份
- **雲端同步**：關鍵文件實時同步
- **離線備份**：定期創建離線備份

#### 4. 執行前檢查
```bash
# 在執行任何刪除操作前，先檢查
echo "即將刪除的路徑：$TARGET_PATH"
echo "請確認這是正確的路徑 (y/N):"
read confirmation
```

### 📸 災難記錄

**Memory01.png**：顯示了致命的 `rm -rf ~` 代碼和災難性分析  
**Memory02.png**：記錄了安全措施的建立和教訓總結

### 🎯 未來協作改進

1. **寬容而非責備** - 創造了學習的環境
2. **建設性解決** - 專注於防止而非懲罰
3. **經驗傳承** - 將錯誤轉化為寶貴經驗
4. **持續改進** - 把錯誤轉化為進步的動力

> **銘記**：這次災難讓我學到了更謹慎的代碼審查、分步執行危險操作、明確的安全確認，以及誠實面對錯誤的重要性。

---

**維護建議**：
- 定期檢查 `launchctl list com.logseq.sync.v2` 確保服務運行
- 偶爾查看 `sync.log` 了解同步狀態
- 系統更新後驗證服務是否正常啟動

- **永遠記住**：在執行任何包含 `rm -rf` 的腳本前，仔細檢查路徑！

---

## 附錄A：當前運行配置總覽（可複製到新機）

- 代辦庫根目錄：/Users/mac/Documents/Sync-Logseq（下稱 REPO_DIR）
- 同步腳本：REPO_DIR/logseq_sync_optimized.sh（已含：fswatch 監聽、本地/遠端雙觸發、去抖動、互斥鎖、過期鎖自清、日誌分離）
- 日誌：REPO_DIR/.logs/sync.log（不觸發監聽）
- 鎖與戳：REPO_DIR/.sync_run.lockdir、REPO_DIR/.last_sync、REPO_DIR/.sync_debounce（.sync_debounce 已被忽略）
- 啟動項：~/Library/LaunchAgents/com.logseq.sync.v2.plist（唯一入口）
- .gitignore（關鍵規則已加入）：.logs/、.sync_debounce、assets/*.mp4、assets/*.mov、assets/*.zip

### 1) 必備依賴
- 安裝 fswatch（監聽本地變更）
  - brew install fswatch
  - which fswatch → 確保在 /usr/local/bin 或 /opt/homebrew/bin

### 2) 正確的 LaunchAgent（~/Library/LaunchAgents/com.logseq.sync.v2.plist）
複製以下內容（若使用非 mac 帳戶或路徑，請對應修改）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.logseq.sync.v2</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/mac/Documents/Sync-Logseq/logseq_sync_optimized.sh</string>
  </array>

  <key>WorkingDirectory</key>
  <string>/Users/mac/Documents/Sync-Logseq</string>

  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
    <key>HOME</key>
    <string>/Users/mac</string>
    <key>LOGSEQ_SYNC_BRANCH</key>
    <string>main</string>
    <key>LOGSEQ_PULL_INTERVAL</key>
    <string>60</string>
    <!-- 可選：去抖動秒數（預設 2）-->
    <!-- <key>LOGSEQ_DEBOUNCE_GAP</key><string>2</string> -->
  </dict>

  <key>StandardOutPath</key>
  <string>/Users/mac/Documents/Sync-Logseq/launchd_stdout.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/mac/Documents/Sync-Logseq/launchd_stderr.log</string>
</dict>
</plist>
```

啟用方式（擇一，建議使用 load -w 單一路徑）：
- 單一路徑（推薦）：
  - chmod 644 ~/Library/LaunchAgents/com.logseq.sync.v2.plist
  - launchctl unload ~/Library/LaunchAgents/com.logseq.sync.v2.plist 2>/dev/null
  - launchctl load -w ~/Library/LaunchAgents/com.logseq.sync.v2.plist
  - launchctl list | grep com.logseq.sync.v2
- 另一種（不與上法混用）：
  - launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.logseq.sync.v2.plist
  - launchctl enable gui/$(id -u)/com.logseq.sync.v2
  - launchctl kickstart -k gui/$(id -u)/com.logseq.sync.v2

### 3) 腳本中的關鍵點（logseq_sync_optimized.sh）
- 自動偵測分支（可由 LOGSEQ_SYNC_BRANCH 覆蓋）
- 定時遠端輪詢（LOGSEQ_PULL_INTERVAL，預設 60s）
- fswatch 監聽本地，採「真正去抖動」：事件聚合後才同步
- 觸發條件採 OR：git status 有變更 或 有檔案新於 .last_sync（且排除 .logs/、鎖與戳）
- 單次互斥鎖 + 過期鎖自清（避免長時間卡住）
- 日誌輸出到 .logs，避免自觸發

---

## 附錄B：大型檔案規避策略（不改歷史）

1) 必加的 .gitignore 規則（防止未來再入庫）：
```gitignore
.logs/
.sync_debounce
assets/*.mp4
assets/*.mov
assets/*.zip
```

2) 如果某大檔「已被追蹤」，需先停止追蹤（不刪你磁碟檔）：
```bash
# 僅移除索引，不刪檔案
cd ~/Documents/Sync-Logseq
git rm --cached .sync_debounce 2>/dev/null || true
# 逐一或用 ls-files 批次移除
git ls-files -z 'assets/*.mp4' 'assets/*.mov' 'assets/*.zip' | xargs -0 -r git rm --cached --

git add .gitignore
git commit -m "chore: ignore large media and internal debounce/log files"
```

3) 可選：新增 pre-commit hook，阻擋 >100MB 檔案被提交（手動與自動皆生效）：
```bash
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/sh
limit=$((100*1024*1024))
git diff --cached --name-only --diff-filter=AM | while read -r f; do
  [ -f "$f" ] || continue
  size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f")
  if [ "$size" -gt "$limit" ]; then
    echo "Error: $f is larger than 100MB; commit aborted."
    exit 1
  fi
done
EOF
chmod +x .git/hooks/pre-commit
```

> 說明：僅改 .gitignore 無法移除已在歷史中的大檔；此處策略是不改歷史、只保證「以後不再提交」與「本地自動流提交時不包含大檔」。若要清理舊歷史，請改用 Git LFS 或 git-filter-repo（另見備忘）。

---

## 附錄C：一鍵重建與健康檢查

- 清鎖 + 重新載入：
```bash
pkill -f logseq_sync_optimized.sh || true
cd ~/Documents/Sync-Logseq
rm -rf .sync_run.lockdir .sync_lock .git/index.lock .sync_debounce
launchctl unload ~/Library/LaunchAgents/com.logseq.sync.v2.plist
launchctl load -w ~/Library/LaunchAgents/com.logseq.sync.v2.plist
launchctl list | grep com.logseq.sync.v2
ps aux | grep -E 'logseq_sync_optimized.sh|fswatch' | grep -v grep
```

- 觀察日誌（注意正確路徑）：
```bash
tail -n 100 ~/Documents/Sync-Logseq/.logs/sync.log
```

常見狀況排查：
- 長時間出現「另一個同步仍在進行」：清理 .sync_run.lockdir 或降低過期閾值（腳本已含過期自清）。
- 找不到 fswatch：確保 PATH 含 /usr/local/bin 或 /opt/homebrew/bin，且已安裝 fswatch。
- 推送被拒（大於 100MB）：依「附錄B」處理，移出索引 + ignore。
- 多實例：不要混用 bootstrap 與 load，固定使用一種，並確保 KeepAlive 為 true。

---

## 附錄D：第一次在新機器上部署的最小步驟
1. 安裝依賴：brew install fswatch
2. 將倉庫放到 /Users/mac/Documents/Sync-Logseq
3. 確認 .gitignore 已含：.logs/、.sync_debounce、assets/*.mp4、assets/*.mov、assets/*.zip
4. 放置 logseq_sync_optimized.sh 並設為可執行：chmod 755
5. 放置 com.logseq.sync.v2.plist（如上）並：chmod 644
6. 啟用：launchctl load -w ~/Library/LaunchAgents/com.logseq.sync.v2.plist
7. 驗證：launchctl list | grep com.logseq.sync.v2；tail -n 100 ~/.logs/sync.log
8. 在 GitHub 上做一次小提交，60 秒內應看到本地拉取與推送

> 小貼士：可透過 LOGSEQ_SYNC_BRANCH 選擇同步分支；LOGSEQ_PULL_INTERVAL 調整輪詢秒數；LOGSEQ_DEBOUNCE_GAP 調整本地事件聚合時間。
---

## 附錄E：Git LFS 錄音接管（2026-11-13 落地）

### 背景與症狀
- 手機端錄音（m4a/aac/mp3/opus/ogg）體積大，普通 Git 追蹤後推送被 GitHub 100MB 限制擋下，自動提交無法上遠端。
- 只在手機端跑 `git lfs install` 不能解決問題：它只初始化本地過濾器，不會把規則寫進倉庫；新端 clone 後仍不知道哪些檔案要走 LFS。

### 根因與解法
- 規則必須寫進倉庫根目錄 `.gitattributes` 並提交，所有端共用：

```gitattributes
*.m4a filter=lfs diff=lfs merge=lfs -text
*.aac filter=lfs diff=lfs merge=lfs -text
*.mp3 filter=lfs diff=lfs merge=lfs -text
*.opus filter=lfs diff=lfs merge=lfs -text
*.ogg filter=lfs diff=lfs merge=lfs -text
```

- 歷史已被普通 Git 追蹤的錄音，在**不改寫歷史、不強制推送**前提下，於索引層轉為 LFS 指標（工作區實體檔案大小不變）：

```bash
cd <倉庫目錄>
git add --renormalize '*.mp3'
git commit -m "chore: LFS 接管 mp3，補 opus/ogg 規則"
git lfs push origin main
git push origin main
```

- 新端克隆後補齊 LFS 物件：

```bash
git lfs install
git lfs pull origin main
```

### 核對命令
```bash
git lfs ls-files | wc -l                 # LFS 追蹤檔案數
git lfs ls-files | grep -i test          # 查特定錄音是否在 LFS
# LFS 指標檔應含三行：version https://git-lfs... / oid sha256:... / size ...
```

### 注意
- `.gitattributes` 必須隨倉庫提交；只在本地 track 不提交，clone 後規則會丟失。
- 舊歷史裡已進普通 Git 的大檔，renormalize 只改索引與之後的提交，不回溯改寫舊提交。

---

## 附錄F：手機端（Android Termux + Tasker + FolderSync）鏈路

### 路徑（實體絕對路徑，腳本內勿用 `~/storage` 軟連結寫法）
- 倉庫：`/data/data/com.termux/files/home/storage/shared/Documents/Sync-Logseq`
- Tasker 腳本目錄：`/data/data/com.termux/files/home/.termux/tasker/`
- 遠端（手機 HTTPS）：`https://github.com/GengGeng026/Sync-Logseq.git`
- 遠端（Mac SSH）：`git@github.com:GengGeng026/Sync-Logseq.git`

### 自動鏈路
錄音 APP → FolderSync 複製到 `assets/` → assets 變動觸發 `auto_log_oneshot.sh`（聚合新錄音寫入今日日記）→ journals 變動觸發 `sync.sh`（提交推送）。

### Tasker Profiles
| Profile | 觸發 | 任務 |
|---|---|---|
| AutoPull/Push Github when Open/Close Logs.. | 打開 / 離開 Logseq | Git Sync → `sync.sh` |
| /journals modified | journals 目錄 Modify | Git Sync → `sync.sh` |
| Auto-Pull Github every 15 min | 每 15 分鐘定時 | Git Sync → `sync.sh` |
| /assets modified → VoiceSync | assets 目錄 Modify | `auto_log_oneshot.sh` |

FolderSync 任務 `SD CARD: Voice Recorder > assets`：來源 SD 卡錄音目錄，目的地倉庫 `assets/`。

### 手機 Git 同步腳本 `sync.sh` 流程
1. `git fetch origin main`
2. 查未解衝突（`diff-filter=U`）：有則即停退出，不自動 add/commit
3. `git add .`；無暫存改動則跳過提交
4. `git merge --no-edit origin/main`（普通合併，不 rebase、不硬重置）
5. `git lfs pull origin main`
6. 再查衝突：有則跳過提交與推送
7. `git lfs push` → `git push origin main`

原則：普通合併、衝突即停、無改動不提交、LFS 先拉後推、不強制推送、不硬重置。

### 錄音歸檔腳本 `auto_log_oneshot.sh`
- 只取當天 mtime 的副檔名：m4a / aac / mp3 / opus / ogg。
- 先比對忽略清單 `~/.termux/tasker/.auto_log_ignore`（每行一個檔名，`#` 註解），命中跳過。
- 再全歷史 `journals/*.md` 去重（只比對 `.md`，不讀 `.bak` 備份）。
- 寫入今日日記：空行分隔 → `- HH:MM [[quick capture]]: #voice-memo` 父節點 → 每檔 `  - **純名**` 與 `    - ![檔名](../assets/檔名)`。

### 手機端核對命令
```bash
cd /data/data/com.termux/files/home/storage/shared/Documents/Sync-Logseq
git status -sb
git rev-list --left-right --count main...origin/main   # 0 0 即對齊
git lfs ls-files | wc -l
```

---

## 附錄G：2026-11-13 故障時間線與排查記錄

1. **大錄音推不上遠端**：超過 GitHub 100MB 限制；手機端單獨 `git lfs install` 無效。根因是 `.gitattributes` 未登記錄音副檔名。補齊 m4a/aac/mp3/opus/ogg LFS 規則，舊 mp3 用 renormalize 轉 LFS，不改寫歷史、不強推。
2. **錄音不再自動寫日記**：
   - 腳本倉庫路徑指向已不存在的舊目錄 `~/Documents/logseq-termux`；改為實體絕對路徑。
   - 舊腳本只抓 m4a；補上 aac/mp3/opus/ogg。
   - 去重被日記 `.bak-*` 備份干擾（grep 把備份也算「已有條目」）；改為只比對 `*.md`。
   - 補回 `SAVEIFS=$IFS` 保存/還原分隔符。
3. **歷史存量音頻被誤補進今日日記**：6 個當天 mtime、歷史日記無全名的舊錄音，被當成新待寫條目。已從今日日記移除；檔名寫入 `.auto_log_ignore` 永久跳過。檔案仍在 assets/LFS、日記無條目，是否補回歷史日期由人工決定，腳本不自動補寫。
4. **雙端同日改同一日記 → 合併衝突**：處理流程見附錄 H。

---

## 附錄H：雙端對齊核對與衝突處理流程

### 對齊核對（兩端各跑一次）
```bash
cd <倉庫目錄>
git fetch origin main
git status -sb
git rev-list --left-right --count main...origin/main   # 左=本地領先 右=遠端領先；0 0 即對齊
git --no-pager log --oneline -5
git lfs ls-files | wc -l
```

### 出現 `both modified` / 未解衝突時
1. 先看衝突段：`grep -n '<<<<<<<\|=======\|>>>>>>>' journals/日期.md`
2. 在編輯器裡保留兩邊應留的內容，刪除 `<<<<<<<` / `=======` / `>>>>>>>` 標記。
3. 標記為已解決（關鍵步驟，腳本不會代做）：
   ```bash
   git add journals/日期.md
   ```
4. 確認暫存只有該檔：`git --no-pager diff --cached --stat`
5. 完成合併提交：`git commit --no-edit`
6. 推 LFS 與普通提交：
   ```bash
   git lfs push origin main
   git push origin main
   ```
7. 另一端 fetch 後對齊；必要時 `git lfs pull origin main` 補齊錄音物件。

### 為什麼解完衝突不會立刻自動提交
`sync.sh` 第一步先查 U 狀態，且檢查在 `git add` 之前；只要沒 `git add`，git 索引仍算未解衝突，每輪觸發都會即停。手動 add 不會再產生日記變更事件，Tasker 不會因此重跑；需等下一次定時/開關 App 觸發，或手動跑一次 `sync.sh`。

### 安全底線
- 不強制推送（不用 `git push --force`）覆蓋遠端歷史。
- 未完整備份前不刪本地檔案。
- 衝突期間不自動 add 衝突檔，避免把未核對內容提交進去。
