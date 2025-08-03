#!/bin/bash

echo "🛡️ 安全清理：只刪除確認的舊文件"
echo "===================================="

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$REPO_DIR" || exit

# 創建備份目錄
BACKUP_DIR="$REPO_DIR/cleanup_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 備份目錄: $BACKUP_DIR"
echo ""

echo "🔍 基於實際檢查結果，只清理以下確認的舊文件："
echo ""

# 基於你的 list_files_to_clean.sh 輸出，只清理確認的文件
CONFIRMED_OLD_FILES=(
    # 舊的同步腳本
    "logseq_sync.sh"
    "logseq_sync.sh.backup"
    "logseq_sync_simple.sh"
    "logseq_sync_single.sh"
    "logseq_unified.sh"
    "check_and_start.sh"
    "manage_logseq_sync.sh"
    "stop_logseq_sync.sh"
    "switch_to_fast_sync.sh"
    "smart_log_manager.sh"
    
    # 舊的 plist 文件
    "com.user.logseq.autostart.plist"
    "com.user.logseq.unified.plist"
    
    # 一次性設置腳本
    "cleanup_and_optimize.sh"
    "cleanup_workspace.sh"
    "create_correct_plist.sh"
    "create_single_plist.sh"
    "final_setup.sh"
    "final_verification.sh"
    "optimize_dual_system.sh"
    "update_to_optimized.sh"
    "verify_system.sh"
    "fix_conflict_markers.sh"
    
    # 舊的日誌文件
    "autostart.log"
    "autostart_error.log"
    "daemon.log"
    "launchagent_stderr.log"
    "launchagent_stdout.log"
    "launchagent_unified.log"
    "launchd.log"
    "launchd_error.log"
    "logseq_unified.log"
    "sync.error.log"
    "sync.log"
    "sync_simple.log"
    "sync_single.log"
    "sync_stdout.log"
    "sync_stdout.log.20250803_080616"
    "sync_stdout.log.20250803_081116"
    
    # 測試和臨時文件
    "test_auto_sync.txt"
    "tmp_rovodev_system_recovery_guide.md"
    "alternative_side_by_side.md"
    
    # 清理腳本自身（執行完後可以刪除）
    "list_files_to_clean.sh"
    "cleanup_old_files.sh"
    "update_readme.sh"
    "clean_old_docs.sh"
)

# 檢查並顯示要清理的文件
echo "📋 將要清理的文件："
total_size=0
existing_files=()

for file in "${CONFIRMED_OLD_FILES[@]}"; do
    if [ -f "$file" ]; then
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "   🗑️ $file (${size_kb}KB)"
        total_size=$((total_size + size))
        existing_files+=("$file")
    fi
done

echo ""
echo "📊 總共將釋放: $((total_size / 1024))KB 空間"
echo "📊 文件數量: ${#existing_files[@]}"
echo ""

echo "✅ 絕對不會觸及的重要內容："
echo "   📄 README.md, README_OLD.md - 文檔"
echo "   🚀 logseq_sync_optimized.sh - 當前同步腳本"
echo "   📊 sync_optimized.log - 當前日誌"
echo "   🔒 .sync_lock, .last_sync - 系統文件"
echo "   🔧 .gitignore - Git 配置"
echo ""
echo "   📁 journals/ - 你的日記 (231 個文件)"
echo "   📁 pages/ - 你的頁面 (55 個文件)"
echo "   📁 logseq/ - Logseq 配置 (84 個文件)"
echo "   📁 assets/ - 附件資源 (68 個文件)"
echo "   📁 draws/ - 繪圖文件 (1 個文件)"
echo "   📁 whiteboards/ - 白板文件 (1 個文件)"
echo "   📁 public/ - 公開文件 (6 個文件)"
echo "   📁 src/ - 源代碼 (8 個文件)"
echo "   📁 docs/ - 文檔目錄 (2 個文件) ⚠️ 可能是你的筆記"
echo "   📁 scripts/ - 腳本目錄 (5 個文件) ⚠️ 可能是你的筆記"
echo ""

echo "===================================="
echo "🤔 確認執行安全清理嗎？"
echo ""
echo "⚠️  重要說明："
echo "   • 只會刪除確認的舊文件（腳本、日誌、配置）"
echo "   • 所有 Logseq 數據目錄完全保留"
echo "   • docs/ 和 scripts/ 目錄完全保留"
echo "   • 刪除前會完整備份"
echo ""
read -p "確定要執行安全清理嗎？(y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🗑️ 開始安全清理..."
    
    deleted_count=0
    for file in "${existing_files[@]}"; do
        # 備份
        cp "$file" "$BACKUP_DIR/" 2>/dev/null
        # 刪除
        if rm "$file" 2>/dev/null; then
            echo "   ✅ 已刪除: $file"
            deleted_count=$((deleted_count + 1))
        else
            echo "   ❌ 刪除失敗: $file"
        fi
    done
    
    echo ""
    echo "✅ 安全清理完成！"
    echo "   📊 刪除了 $deleted_count 個文件"
    echo "   💾 釋放了 $((total_size / 1024))KB 空間"
    echo "   💾 備份保存在: $BACKUP_DIR"
    echo ""
    echo "🎯 你的系統現在非常簡潔且安全："
    echo "   📄 文檔: README.md + README_OLD.md"
    echo "   🚀 同步: logseq_sync_optimized.sh + sync_optimized.log"
    echo "   📁 數據: 所有 Logseq 目錄完整保留"
    echo ""
    echo "🛡️ 所有重要內容都得到完整保護！"
    
else
    echo ""
    echo "❌ 取消清理"
    echo "💡 你的謹慎是對的，安全第一！"
    rm -rf "$BACKUP_DIR"  # 刪除空的備份目錄
fi

echo ""
echo "📊 當前狀態："
echo "   配置文件: $(ls -1 *.sh *.md 2>/dev/null | wc -l)"
echo "   Logseq 數據目錄: $(ls -d */ 2>/dev/null | wc -l)"