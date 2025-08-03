# 🎯 Logseq 自動復活系統 - 關鍵技能與邏輯指南

> **目的**: 記錄實現自動復活功能的核心技能和邏輯，確保每次都能理解並重建系統

## 🏆 成功實現的核心技能

### 1. **統一腳本架構設計** 🎨

#### **問題**: 三個腳本管理複雜
- `logseq_daemon.sh` (守護進程)
- `start_logseq_sync.sh` (啟動腳本)  
- `logseq_sync.sh` (同步腳本)

#### **解決方案**: 單一統一腳本
```bash
logseq_unified.sh
├── daemon 模式    # 守護進程功能
├── sync 模式      # 同步服務功能
├── start 模式     # 智能啟動功能
├── stop 模式      # 停止所有服務
└── status 模式    # 狀態監控功能
```

#### **關鍵技能**:
- **模式切換**: 使用命令行參數控制腳本行為
- **功能整合**: 將多個腳本的功能合併到單一文件
- **狀態管理**: 統一的進程檢查和控制邏輯

### 2. **自動復活機制設計** 🛡️

#### **四層保障架構**:
```
Layer 4: LaunchAgent (系統級)
    ↓
Layer 3: 守護進程 (應用級)
    ↓
Layer 2: 同步服務 (功能級)
    ↓
Layer 1: 文件監控 (操作級)
```

#### **關鍵邏輯**:
```bash
# 守護進程核心邏輯
while true; do
    if ! is_sync_running; then
        cleanup_zombies()
        restart_sync_service()
        verify_restart()
    fi
    sleep 30  # 檢查間隔
done
```

#### **技能要點**:
- **進程檢測**: `pgrep -f "pattern"` 精確匹配進程
- **自動重啟**: 檢測失敗 → 清理 → 重啟 → 驗證
- **故障恢復**: 清理鎖定文件和殭屍進程

### 3. **LaunchAgent 配置精髓** 🚀

#### **關鍵配置項**:
```xml
<key>RunAtLoad</key>
<true/>                    <!-- 開機自動啟動 -->

<key>KeepAlive</key>
<true/>                    <!-- 進程死掉自動重啟 -->

<key>EnvironmentVariables</key>
<dict>
    <key>PATH</key>
    <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
</dict>                    <!-- 確保命令可找到 -->
```

#### **技能要點**:
- **路徑設置**: 確保 git, fswatch 等命令可執行
- **工作目錄**: 指定正確的 WorkingDirectory
- **日誌重定向**: StandardOutPath 和 StandardErrorPath

### 4. **智能進程管理** 🧠

#### **進程檢測邏輯**:
```bash
# 檢查守護進程
is_daemon_running() {
    pgrep -f "logseq_unified.sh.*daemon" > /dev/null
}

# 檢查同步服務
is_sync_running() {
    pgrep -f "logseq_unified.sh.*sync" > /dev/null
}

# 檢查文件監控
is_fswatch_running() {
    pgrep -f "fswatch.*Sync-Logseq" > /dev/null
}
```

#### **技能要點**:
- **精確匹配**: 使用特定模式避免誤殺其他進程
- **狀態檢查**: 多層次的服務狀態監控
- **清理機制**: 安全地停止和清理相關進程

### 5. **錯誤處理與恢復** 🔧

#### **清理函數**:
```bash
cleanup() {
    # 清理 Git 鎖定文件
    find "$REPO_DIR/.git" -name "*.lock" -delete 2>/dev/null
    
    # 清理殭屍進程
    pkill -f "fswatch.*Sync-Logseq" 2>/dev/null || true
}
```

#### **日誌管理**:
```bash
rotate_logs() {
    if [ "$size" -gt 524288 ]; then  # 512KB
        tail -500 "$LOG_FILE" > "${LOG_FILE}.tmp"
        mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
}
```

#### **技能要點**:
- **安全清理**: 避免影響其他系統進程
- **日誌輪換**: 防止日誌文件過大
- **錯誤容忍**: 使用 `|| true` 避免腳本中斷

## 🔄 實現自動復活的關鍵邏輯

### **邏輯流程圖**:
```
系統開機
    ↓
LaunchAgent 啟動
    ↓
執行 logseq_unified.sh start
    ↓
檢查是否已有守護進程
    ↓ (無)
啟動守護進程 (daemon 模式)
    ↓
守護進程每30秒檢查同步服務
    ↓ (服務停止)
清理殭屍進程
    ↓
重啟同步服務 (sync 模式)
    ↓
同步服務啟動文件監控
    ↓
fswatch 監控文件變化
    ↓
觸發 Git 同步操作
    ↓
回到守護進程檢查循環
```

### **關鍵決策點**:

1. **智能啟動邏輯**:
   ```bash
   if is_daemon_running; then
       echo "守護進程已在運行"
   else
       nohup "$0" daemon > /dev/null 2>&1 &
   fi
   ```

2. **服務恢復邏輯**:
   ```bash
   if ! is_sync_running; then
       cleanup()
       sleep 2
       nohup "$0" sync > /dev/null 2>&1 &
       sleep 5
       verify_restart()
   fi
   ```

3. **狀態監控邏輯**:
   ```bash
   # 多維度狀態檢查
   daemon_status = is_daemon_running() ? "✅" : "❌"
   sync_status = is_sync_running() ? "✅" : "❌"  
   fswatch_status = is_fswatch_running() ? "✅" : "❌"
   ```

## 🎯 重建系統的關鍵步驟

### **步驟 1: 創建統一腳本**
```bash
# 1. 設計模式切換邏輯
case "${1:-start}" in
    "daemon") daemon_mode ;;
    "sync") sync_mode ;;
    "start") smart_start ;;
    "stop") stop_all ;;
    "status") show_status ;;
esac

# 2. 實現各個功能模式
# 3. 添加進程檢測函數
# 4. 實現清理和恢復機制
```

### **步驟 2: 配置 LaunchAgent**
```bash
# 1. 創建 plist 文件
# 2. 設置正確的路徑和環境變數
# 3. 配置 RunAtLoad 和 KeepAlive
# 4. 安裝到 ~/Library/LaunchAgents/
```

### **步驟 3: 測試和驗證**
```bash
# 1. 手動測試各個模式
./logseq_unified.sh start
./logseq_unified.sh status
./logseq_unified.sh stop

# 2. 測試 LaunchAgent
launchctl load ~/Library/LaunchAgents/com.user.logseq.unified.plist

# 3. 測試重啟恢復
sudo reboot
```

## 🧠 核心設計原則

### **1. 單一責任與模式分離**
- 每個模式專注單一功能
- 通過參數控制行為
- 避免功能耦合

### **2. 防禦性編程**
- 所有外部命令都有錯誤處理
- 使用 `|| true` 防止腳本中斷
- 路徑和變數都有驗證

### **3. 可觀測性**
- 詳細的日誌記錄
- 清晰的狀態顯示
- 便於調試的信息輸出

### **4. 自恢復能力**
- 多層次的監控機制
- 自動清理和重啟
- 故障隔離和恢復

## 🎉 成功指標與驗證

### **系統正常運行時的狀態**:
```
=== Logseq 同步服務狀態 ===
🛡️ 守護進程: ✅ 運行中
🔄 同步服務: ✅ 運行中  
👁️ 文件監控: ✅ 運行中
📤 Git 同步: ✅ 正常推送
```

### **重啟測試驗證**:
1. 重啟系統
2. 等待 30 秒
3. 檢查服務狀態
4. 確認所有服務自動恢復

## 📚 學習要點總結

1. **架構設計**: 統一腳本 > 多腳本架構
2. **自動復活**: 多層保障 > 單點依賴
3. **進程管理**: 精確匹配 > 模糊匹配
4. **錯誤處理**: 防禦性編程 > 樂觀假設
5. **可維護性**: 單一入口 > 分散管理

## 🔧 實際部署的關鍵命令

### **遷移到統一腳本**:
```bash
# 1. 停止舊服務
launchctl unload ~/Library/LaunchAgents/com.user.logseq.autostart.plist

# 2. 備份舊腳本
mkdir -p backup_old_scripts
mv logseq_daemon.sh start_logseq_sync.sh backup_old_scripts/

# 3. 部署新系統
cp com.user.logseq.unified.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.logseq.unified.plist

# 4. 驗證運行
./logseq_unified.sh status
```

### **日常維護命令**:
```bash
# 檢查狀態
./logseq_unified.sh status

# 重啟服務
./logseq_unified.sh restart

# 查看日誌
tail -f logseq_unified.log

# 檢查 LaunchAgent
launchctl list | grep logseq
```

## 🚨 關鍵警戒事項

### **避免的錯誤**:
1. **路徑問題**: 確保所有路徑都是絕對路徑
2. **權限問題**: 確保腳本有執行權限 (`chmod +x`)
3. **環境變數**: LaunchAgent 中必須設置 PATH
4. **進程匹配**: 使用精確的 pgrep 模式避免誤殺

### **調試技巧**:
1. **分步測試**: 先手動測試各個模式
2. **日誌分析**: 查看詳細日誌找出問題
3. **進程檢查**: 使用 `ps aux` 確認進程狀態
4. **LaunchAgent 調試**: 使用 `launchctl print` 查看詳細信息

---

**記錄日期**: 2025年8月3日  
**成功實現**: 從 3 腳本架構 → 1 統一腳本  
**核心成就**: 真正的自動復活，重啟後無需任何手動干預  
**適用場景**: macOS + Logseq + GitHub 同步系統  
**維護者**: 每次重建時請仔細閱讀此文檔