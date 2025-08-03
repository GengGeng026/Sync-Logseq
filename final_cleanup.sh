#!/bin/bash

echo "🧹 最終清理：移除所有不需要的舊文件"
echo "========================================"

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$REPO_DIR" || exit

# 創建備份目錄
BACKUP_DIR="$REPO_DIR/cleanup_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 備份目錄: $BACKUP_DIR"
echo ""

echo "🗂️ 要清理的文件分類："
echo ""

# 1. 舊的同步腳本
echo "📜 舊的同步腳本:"
OLD_SCRIPTS=(
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
)

script_count=0
script_size=0
for script in "${OLD_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        size=$(stat -f%z "$script" 2>/dev/null || stat -c%s "$script" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "   🗑️ $script (${size_kb}KB)"
        script_count=$((script_count + 1))
        script_size=$((script_size + size))
    fi
done
echo "   📊 找到 $script_count 個舊腳本，共 $((script_size / 1024))KB"
echo ""

# 2. 舊的 plist 文件
echo "📋 舊的 plist 文件:"
OLD_PLISTS=(
    "com.user.logseq.autostart.plist"
    "com.user.logseq.unified.plist"
)

plist_count=0
plist_size=0
for plist in "${OLD_PLISTS[@]}"; do
    if [ -f "$plist" ]; then
        size=$(stat -f%z "$plist" 2>/dev/null || stat -c%s "$plist" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "   🗑️ $plist (${size_kb}KB)"
        plist_count=$((plist_count + 1))
        plist_size=$((plist_size + size))
    fi
done
echo "   📊 找到 $plist_count 個舊 plist，共 $((plist_size / 1024))KB"
echo ""

# 3. 設置和清理腳本
echo "🔧 一次性設置腳本:"
SETUP_SCRIPTS=(
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
    "list_files_to_clean.sh"
    "cleanup_old_files.sh"
    "update_readme.sh"
    "clean_old_docs.sh"
)

setup_count=0
setup_size=0
for script in "${SETUP_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        size=$(stat -f%z "$script" 2>/dev/null || stat -c%s "$script" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "   🗑️ $script (${size_kb}KB)"
        setup_count=$((setup_count + 1))
        setup_size=$((setup_size + size))
    fi
done
echo "   📊 找到 $setup_count 個設置腳本，共 $((setup_size / 1024))KB"
echo ""

# 4. 舊的日誌文件
echo "📊 舊的日誌文件:"
OLD_LOGS=(
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
)

log_count=0
log_size=0
for log in "${OLD_LOGS[@]}"; do
    if [ -f "$log" ]; then
        size=$(stat -f%z "$log" 2>/dev/null || stat -c%s "$log" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "   🗑️ $log (${size_kb}KB)"
        log_count=$((log_count + 1))
        log_size=$((log_size + size))
    fi
done
echo "   📊 找到 $log_count 個舊日誌，共 $((log_size / 1024))KB"
echo ""

# 5. 測試和臨時文件
echo "🧪 測試和臨時文件:"
TEST_FILES=(
    "test_auto_sync.txt"
    "tmp_rovodev_system_recovery_guide.md"
    "alternative_side_by_side.md"
)

test_count=0
test_size=0
for file in "${TEST_FILES[@]}"; do
    if [ -f "$file" ]; then
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "   🗑️ $file (${size_kb}KB)"
        test_count=$((test_count + 1))
        test_size=$((test_size + size))
    fi
done
echo "   📊 找到 $test_count 個測試文件，共 $((test_size / 1024))KB"
echo ""

# 計算總計
total_files=$((script_count + plist_count + setup_count + log_count + test_count))
total_size=$((script_size + plist_size + setup_size + log_size + test_size))

echo "========================================"
echo "📊 清理統計總結:"
echo "   🗑️ 總文件數: $total_files"
echo "   💾 總大小: $((total_size / 1024))KB"
echo "   📂 備份位置: $BACKUP_DIR"
echo ""

# 保留的重要文件
echo "✅ 將會保留的重要文件:"
KEEP_FILES=(
    "README.md"
    "README_OLD.md"
    "logseq_sync_optimized.sh"
    "sync_optimized.log"
    ".sync_lock"
    ".last_sync"
    ".gitignore"
)

for file in "${KEEP_FILES[@]}"; do
    if [ -f "$file" ]; then
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "   ✅ $file (${size_kb}KB)"
    fi
done

echo ""
echo "✅ Logseq 數據目錄 (完全保留):"
LOGSEQ_DIRS=("journals" "pages" "logseq" "assets" "draws" "whiteboards" "public" "src" "scripts")
for dir in "${LOGSEQ_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        file_count=$(find "$dir" -type f | wc -l)
        echo "   📁 $dir/ (包含 $file_count 個文件)"
    fi
done

echo ""
echo "========================================"
echo "🤔 確認執行最終清理嗎？"
echo ""
echo "這將會："
echo "   1. 備份所有要刪除的文件到 $BACKUP_DIR"
echo "   2. 刪除 $total_files 個舊文件"
echo "   3. 釋放 $((total_size / 1024))KB 空間"
echo "   4. 保留所有重要文件和 Logseq 數據"
echo ""
read -p "確定要執行最終清理嗎？(y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🗑️ 開始最終清理..."
    
    # 備份並刪除所有文件
    ALL_TO_DELETE=(
        "${OLD_SCRIPTS[@]}"
        "${OLD_PLISTS[@]}"
        "${SETUP_SCRIPTS[@]}"
        "${OLD_LOGS[@]}"
        "${TEST_FILES[@]}"
    )
    
    deleted_count=0
    for file in "${ALL_TO_DELETE[@]}"; do
        if [ -f "$file" ]; then
            # 備份
            cp "$file" "$BACKUP_DIR/" 2>/dev/null
            # 刪除
            rm "$file"
            echo "   🗑️ 已刪除: $file"
            deleted_count=$((deleted_count + 1))
        fi
    done
    
    echo ""
    echo "✅ 最終清理完成！"
    echo "   📊 刪除了 $deleted_count 個文件"
    echo "   💾 釋放了 $((total_size / 1024))KB 空間"
    echo "   💾 備份保存在: $BACKUP_DIR"
    echo ""
    echo "🎯 你的 Logseq 同步系統現在極其簡潔："
    echo "   📄 README.md - 完整指南"
    echo "   📄 README_OLD.md - 備份"
    echo "   🚀 logseq_sync_optimized.sh - 工業級同步腳本"
    echo "   📊 sync_optimized.log - 運行日誌"
    echo "   🔒 .sync_lock - 進程鎖定"
    echo "   ⏰ .last_sync - 同步標記"
    echo "   📁 journals/, pages/, logseq/ - 你的筆記數據"
    echo ""
    echo "🎉 完美！一個真正專業、簡潔的工業級系統！"
    
else
    echo ""
    echo "❌ 取消清理"
    echo "💡 如果以後想清理，再次運行此腳本即可"
    rm -rf "$BACKUP_DIR"  # 刪除空的備份目錄
fi

echo ""
echo "📊 清理後的文件統計:"
echo "   配置文件: $(ls -1 *.sh *.md 2>/dev/null | wc -l)"
echo "   Logseq 數據: $(find journals pages logseq -type f 2>/dev/null | wc -l) 個文件"