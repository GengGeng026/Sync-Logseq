#!/bin/bash

echo "📝 簡化並更新 README.md..."
echo "=========================================="

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$REPO_DIR" || exit

# 1. 備份現有的 README.md
if [ -f "README.md" ]; then
    cp "README.md" "README_OLD_FINAL_BACKUP.md"
    echo "   💾 已備份 README.md 到 README_OLD_FINAL_BACKUP.md"
else
    echo "   ℹ️ README.md 不存在，將創建新文件"
fi

# 2. 創建全新的、簡化後的 README.md
cat > README.md << 'EOF'
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
# # 腳本內容... (請確保已是最新的優化版)
# EOF
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
EOF

# 4. 載入服務
launchctl load ~/Library/LaunchAgents/com.logseq.sync.plist

# 5. 驗證運行
sleep 5
ps aux | grep logseq_sync_optimized | grep -v grep
launchctl list | grep logseq
```

### 故障排除指南

#### 常見問題解決
```bash
# 1. 服務無響應
launchctl unload ~/Library/LaunchAgents/com.logseq.sync.plist
pkill -f "logseq_sync_optimized"
rm -f .sync_lock
launchctl load ~/Library/LaunchAgents/com.logseq.sync.plist

# 2. 檢查進程狀態
ps aux | grep logseq_sync_optimized | grep -v grep | wc -l  # 應該是 1

# 3. 查看日誌
tail -20 sync_optimized.log

# 4. 測試自動重啟
current_pid=$(ps aux | grep logseq_sync_optimized.sh | grep -v grep | awk '{print $2}')
kill $current_pid
sleep 10
ps aux | grep logseq_sync_optimized | grep -v grep  # 應該有新的 PID
```

#### 診斷命令
```bash
# 檢查 LaunchAgent 詳細狀態
launchctl print gui/$(id -u)/com.logseq.sync

# 檢查文件權限
ls -la logseq_sync_optimized.sh .sync_lock

# 檢查 Git 遠程連接
git remote -v
ssh -T git@github.com
```

## 📋 同步方案演進總結

### 核心設計原則
1. **單一責任**：一個腳本，專注同步與管理。
2. **防禦性編程**：內建錯誤處理和容錯機制。
3. **可觀測性**：詳細日誌和狀態監控。
4. **自恢復能力**：通過 LaunchAgent 和腳本內置邏輯實現自動重啟。

## 🔍 技術細節

### 日誌管理
- 自動輪換：`sync_optimized.log` 會自動限制大小並輪換，確保不會超載。
- `.gitignore`：已更新並推送到遠程，確保所有日誌文件不會被 Git 追蹤。

### 智能衝突處理
- 腳本內置了衝突檢測和處理邏輯，旨在自動解決常見的合併衝突。

### 進程管理
- **單一進程**：通過 `.sync_lock` 文件確保只有一個 `logseq_sync_optimized.sh` 實例運行。
- **精確檢測**：使用 `pgrep` 精確匹配進程名稱。

### 性能優化
- **Debounce 機制**：2秒延遲，避免文件頻繁變更觸發過多同步。
- **持續監控**：`fswatch` 持續監控，避免每次同步後重新啟動監控的延遲。

## ⚠️ 重要警戒事項

### 避免的錯誤
1. **多重同步**：只保留一個自動同步方案（目前已實現）。
2. **路徑問題**：所有腳本內的路徑都應使用絕對路徑。
3. **權限問題**：確保腳本有執行權限 (`chmod +x`)。
4. **環境變數**：LaunchAgent 中必須設置 `PATH` 和 `HOME`。

### 安全檢查清單
- [ ] 所有 `rm -rf` 指令都使用絕對路徑或明確的相對路徑。
- [ ] 危險操作前有確認提示（已在清理腳本中實現）。
- [ ] 重要數據有備份（建議定期使用 Time Machine 或其他方式）。
- [ ] 腳本經過人工審查。
- [ ] 將複雜操作分解為安全的小步驟。

## 🎉 成功指標

### 完美運行狀態
當系統正常運行時，你會看到：
```
🏆 系統健康度: 7/7

✅ 單一 plist 文件
✅ 單一同步進程
✅ 進程鎖定機制
✅ KeepAlive 已啟用
✅ 服務正在運行
✅ 日誌記錄正常
✅ 腳本進程運行中

🛡️ 自動恢復能力：
   • 系統重啟後自動啟動 ✅
   • 進程崩潰後自動重啟 ✅
   • 文件變更自動同步 ✅
   • 單一進程避免衝突 ✅
   • 進程鎖定防止重複 ✅
```

### 驗證測試
1. **重啟測試**：系統重啟後自動恢復。
2. **崩潰測試**：kill 進程後自動重啟。
3. **同步測試**：文件變更 2 秒內同步。
4. **衝突測試**：自動處理 Git 衝突。

## 📚 學習要點

1. **系統性思考** > 單點修復
2. **認證是基礎** > 功能優化
3. **精確控制** > 粗糙實現
4. **防禦性編程** > 樂觀假設
5. **可維護性** > 功能堆疊

## 🔗 相關資源

- [Logseq Git Sync 101](https://github.com/CharlesChiuGit/Logseq-Git-Sync-101)
- [Better Logseq Git Sync](https://github.com/JasonYao/better-logseq-git-sync)
- [macOS LaunchAgent 指南](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)

---

## 🏁 最終總結

這個系統經過了從災難性失敗到工業級穩定的完整演進，每一次迭代都解決了實際問題：

- **災難教訓** → 安全意識和審查機制
- **SSH 問題** → 認證持久化基礎
- **多進程衝突** → 統一架構和鎖定機制  
- **監控精確性** → 文件監控優化
- **系統恢復** → LaunchAgent 和自動重啟
- **響應速度** → 持續監控和 debounce 優化

**最終成果**：一個真正「設置一次，永遠運行」的工業級自動同步系統。

---

**記錄者**：Geng & AI Assistant  
**適用環境**：macOS + Logseq + GitHub  
**維護建議**：每次重建前仔細閱讀此文檔，特別是災難教訓部分
EOF

echo "✅ 已創建 README.md"

# 3. 刪除不再需要的舊文檔和目錄
echo "🗑️ 清理舊文檔和目錄..."

# 舊的 README 文件
OLD_READMES=(
    "README_CRITICAL_LESSONS.md"
    "README_LOGSEQ_AUTOSTART.md"
    "README_UNIFIED.md"
)

for doc in "${OLD_READMES[@]}"; do
    if [ -f "$doc" ]; then
        rm "$doc"
        echo "   ✅ 已刪除: $doc"
    fi
done

# docs/ 目錄（如果只包含已整合的文件）
if [ -d "docs" ]; then
    # 檢查 docs/ 目錄下是否還有其他文件，除了我們已整合的兩個
    remaining_docs_files=$(find docs -type f | grep -v -E "(Logseq同步方案演進記錄\.md|README_improved_sync\.md)" | wc -l)
    if [ "$remaining_docs_files" -eq 0 ]; then
        rmdir docs 2>/dev/null # 嘗試刪除空目錄
        if [ $? -eq 0 ]; then
            echo "   ✅ 已刪除空的 docs/ 目錄"
        else
            echo "   ℹ️ docs/ 目錄不為空，跳過刪除"
        fi
    else
        echo "   ℹ️ docs/ 目錄下仍有其他文件，跳過刪除"
    fi
fi

echo ""
echo "✅ 文檔簡化與更新完成！"
echo ""
echo "現在你的 README.md 是最簡潔和最新的版本。"
