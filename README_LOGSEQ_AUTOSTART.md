# Logseq 自動同步服務配置

## 🎯 解決方案概述

已配置 Logseq 同步服務在系統重啟後自動啟動，並在意外中斷後自動重啟，確保 100% 可靠的後台同步。

## 🏗️ 架構設計

```
LaunchAgent → 守護進程 → 同步腳本 → fswatch 監控
     ↓           ↓           ↓           ↓
  系統啟動    進程監控    Git 同步    文件變化
```

## 📁 相關文件

- `~/Library/LaunchAgents/com.user.logseq.autostart.plist` - macOS 自動啟動配置
- `~/Documents/Sync-Logseq/logseq_daemon.sh` - 守護進程（監控同步服務）
- `~/Documents/Sync-Logseq/logseq_sync.sh` - 實際同步腳本
- `~/Documents/Sync-Logseq/manage_logseq_sync.sh` - 管理工具

## 🛠️ 管理命令

```bash
# 查看狀態
logseq-sync status

# 啟動服務
logseq-sync start

# 停止服務
logseq-sync stop

# 重啟服務
logseq-sync restart

# 查看日誌
logseq-sync log

# 測試啟動
logseq-sync test
```

## 🔧 工作原理

### 三層保護機制：

1. **LaunchAgent 層**：系統重啟時自動啟動守護進程
2. **守護進程層**：每30秒檢查同步腳本是否運行，如停止則自動重啟
3. **同步腳本層**：使用 fswatch 監控文件變化，執行 Git 同步

### 自動恢復流程：

```
意外中斷 → 守護進程檢測 → 清理殭屍進程 → 重啟同步腳本 → 恢復監控
```

## 📊 狀態監控

- **LaunchAgent PID**: 顯示系統級服務狀態
- **守護進程**: 監控進程是否運行
- **同步腳本**: 檢查實際同步服務
- **進程數量**: 避免重複啟動

## 🔍 故障排除

如果同步服務不工作：

1. 檢查狀態：`logseq-sync status`
2. 查看日誌：`logseq-sync log`
3. 重啟服務：`logseq-sync restart`
4. 手動測試：`logseq-sync test`

## ✅ 驗證測試

重啟系統後應該看到：
- LaunchAgent 有正確的 PID
- 守護進程在運行
- 同步腳本在運行
- 文件變化能自動同步到 Git

## 🚨 重要特性

- **100% 自動恢復**：無論何種原因中斷都會自動重啟
- **防止重複啟動**：智能檢測避免多個實例
- **清理殭屍進程**：重啟前清理可能的殘留進程
- **詳細日誌記錄**：便於問題診斷和監控