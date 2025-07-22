#!/bin/bash
# 安全的工作空間清理腳本 - 僅限於 /Users/mac/Documents/Sync-Logseq 目錄內

# 🛡️ 安全檢查：確保只在正確的目錄中運行
SAFE_DIR="/Users/mac/Documents/Sync-Logseq"
CURRENT_DIR="$(pwd)"

if [ "$CURRENT_DIR" != "$SAFE_DIR" ]; then
    echo "❌ 安全錯誤：此腳本只能在 $SAFE_DIR 中運行"
    echo "當前目錄：$CURRENT_DIR"
    exit 1
fi

echo "🛡️ 安全檢查通過：在正確目錄中運行"
echo "🧹 開始清理工作空間（僅限當前目錄）..."

# 確保自動流正在運行
if ! pgrep -f "logseq_sync.sh" > /dev/null; then
    echo "⚠️ 自動同步服務未運行，請先啟動服務"
    exit 1
fi

echo "✅ 自動同步服務正在運行，可以安全清理"

# 1. 清理臨時文件（僅限當前目錄）
echo "🗑️ 清理臨時文件..."
rm -f ./.DS_Store
rm -f ./COMMIT_EDITMSG*
rm -f ./.last_sync
rm -f ./tmp_code_*.bash
rm -f ./sync_stdout.log.20250720_124919  # 舊的輪換日誌
echo "已清理系統臨時文件"

# 2. 整理腳本文件到 scripts 目錄（安全移動）
echo "📁 整理腳本文件..."
mkdir -p ./scripts
[ -f "./daily_log_cleanup.sh" ] && mv ./daily_log_cleanup.sh ./scripts/
[ -f "./install_autostart.sh" ] && mv ./install_autostart.sh ./scripts/
[ -f "./optimize_logs.sh" ] && mv ./optimize_logs.sh ./scripts/
[ -f "./switch_to_improved_sync.sh" ] && mv ./switch_to_improved_sync.sh ./scripts/
[ -f "./test_conflict_resolution.sh" ] && mv ./test_conflict_resolution.sh ./scripts/
echo "已移動輔助腳本到 scripts/ 目錄"

# 3. 整理文檔到 docs 目錄
echo "📚 整理文檔文件..."
mkdir -p docs
mv README_improved_sync.md docs/
mv "Logseq同步方案演進記錄.md" docs/
echo "已移動文檔到 docs/ 目錄"

# 4. 清理不必要的目錄
echo "🗂️ 檢查可清理的目錄..."
if [ -d "public" ] && [ -z "$(ls -A public 2>/dev/null)" ]; then
    rm -rf public
    echo "已刪除空的 public 目錄"
fi

if [ -d "src" ] && [ -z "$(ls -A src 2>/dev/null)" ]; then
    rm -rf src
    echo "已刪除空的 src 目錄"
fi

if [ -d ".history" ]; then
    rm -rf .history
    echo "已刪除 .history 目錄"
fi

# ⚠️ 危險代碼已移除 - 曾經的 rm -rf ~ 指令會刪除整個用戶主目錄
# 這是一個重要的教訓：永遠不要在腳本中使用 rm -rf ~ 
# 如果需要刪除名為 "~" 的目錄，應該使用 rm -rf "./" 或完整路徑
echo "⚠️ 跳過危險的主目錄清理操作"

# 5. 保留必要文件的清單
echo ""
echo "📋 保留的核心文件："
echo "✅ logseq_sync.sh - 主同步腳本"
echo "✅ start_logseq_sync.sh - 啟動腳本"
echo "✅ stop_logseq_sync.sh - 停止腳本"
echo "✅ logseq_sync.sh.backup - 備份腳本"
echo "✅ sync_stdout.log - 主日誌"
echo "✅ sync_stderr.log - 錯誤日誌"
echo "✅ .gitignore - Git 配置"
echo "✅ README.md - 主說明文檔"

echo ""
echo "📁 保留的核心目錄："
echo "✅ logseq/ - Logseq 配置"
echo "✅ pages/ - 頁面內容"
echo "✅ journals/ - 日誌內容"
echo "✅ assets/ - 媒體文件"
echo "✅ draws/ - 繪圖文件"
echo "✅ whiteboards/ - 白板文件"
echo "✅ scripts/ - 輔助腳本"
echo "✅ docs/ - 文檔資料"

echo ""
echo "🎉 清理完成！工作空間現在更整潔了"