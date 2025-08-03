#!/bin/bash

echo "🔍 檢查 Logseq 同步資料夾中可清理的文件"
echo "============================================"
echo "⚠️  這個腳本只會羅列文件，不會刪除任何東西"
echo "📂 檢查目錄: /Users/mac/Documents/Sync-Logseq"
echo ""

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$REPO_DIR" || exit

echo "📊 當前目錄內容統計:"
echo "   總文件數: $(find . -type f | wc -l)"
echo "   總目錄數: $(find . -type d | wc -l)"
echo ""

# 分類檢查文件
echo "🗂️ 文件分類檢查結果:"
echo ""

# 1. 舊的同步腳本
echo "📜 舊的同步腳本 (建議刪除):"
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
for script in "${OLD_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "   🗑️ $script ($(ls -lh "$script" | awk '{print $5}'))"
        script_count=$((script_count + 1))
    fi
done
echo "   📊 找到 $script_count 個舊腳本文件"
echo ""

# 2. 舊的 plist 文件
echo "📋 舊的 plist 文件 (建議刪除):"
OLD_PLISTS=(
    "com.user.logseq.autostart.plist"
    "com.user.logseq.unified.plist"
)

plist_count=0
for plist in "${OLD_PLISTS[@]}"; do
    if [ -f "$plist" ]; then
        echo "   🗑️ $plist ($(ls -lh "$plist" | awk '{print $5}'))"
        plist_count=$((plist_count + 1))
    fi
done
echo "   📊 找到 $plist_count 個舊 plist 文件"
echo ""

# 3. 設置和清理腳本
echo "🔧 一次性設置腳本 (建議刪除):"
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
)

setup_count=0
for script in "${SETUP_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "   🗑️ $script ($(ls -lh "$script" | awk '{print $5}'))"
        setup_count=$((setup_count + 1))
    fi
done
echo "   📊 找到 $setup_count 個設置腳本文件"
echo ""

# 4. 舊的日誌文件
echo "📊 舊的日誌文件 (建議刪除):"
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
total_log_size=0
for log in "${OLD_LOGS[@]}"; do
    if [ -f "$log" ]; then
        size=$(ls -lh "$log" | awk '{print $5}')
        echo "   🗑️ $log ($size)"
        log_count=$((log_count + 1))
        # 計算總大小（簡化版）
        size_bytes=$(stat -f%z "$log" 2>/dev/null || stat -c%s "$log" 2>/dev/null || echo 0)
        total_log_size=$((total_log_size + size_bytes))
    fi
done
echo "   📊 找到 $log_count 個舊日誌文件，總大小約 $((total_log_size / 1024))KB"
echo ""

# 5. 測試和臨時文件
echo "🧪 測試和臨時文件 (建議刪除):"
TEST_FILES=(
    "test_auto_sync.txt"
    "tmp_rovodev_system_recovery_guide.md"
    "alternative_side_by_side.md"
)

test_count=0
for file in "${TEST_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   🗑️ $file ($(ls -lh "$file" | awk '{print $5}'))"
        test_count=$((test_count + 1))
    fi
done
echo "   📊 找到 $test_count 個測試文件"
echo ""

# 6. 多餘的 README 文件
echo "📖 多餘的 README 文件 (建議刪除):"
EXTRA_READMES=(
    "README_CRITICAL_LESSONS.md"
    "README_LOGSEQ_AUTOSTART.md"
)

readme_count=0
for readme in "${EXTRA_READMES[@]}"; do
    if [ -f "$readme" ]; then
        echo "   🗑️ $readme ($(ls -lh "$readme" | awk '{print $5}'))"
        readme_count=$((readme_count + 1))
    fi
done
echo "   📊 找到 $readme_count 個多餘的 README 文件"
echo ""

# 計算總計
total_to_delete=$((script_count + plist_count + setup_count + log_count + test_count + readme_count))

echo "============================================"
echo "📊 清理統計總結:"
echo "   🗑️ 建議刪除的文件總數: $total_to_delete"
echo "   📂 這些文件都在: /Users/mac/Documents/Sync-Logseq/"
echo "   ⚠️  不會觸及系統級文件或其他目錄"
echo ""

# 保留的重要文件
echo "✅ 將會保留的重要文件:"
KEEP_FILES=(
    "logseq_sync_optimized.sh"
    "sync_optimized.log"
    ".sync_lock"
    ".last_sync"
    ".gitignore"
    "README.md"
)

keep_count=0
for file in "${KEEP_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file ($(ls -lh "$file" | awk '{print $5}'))"
        keep_count=$((keep_count + 1))
    fi
done

echo ""
echo "✅ Logseq 數據目錄 (完全保留):"
LOGSEQ_DIRS=("journals" "pages" "logseq" "assets" "draws" "whiteboards" "public" "src" "docs" "scripts")
for dir in "${LOGSEQ_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        file_count=$(find "$dir" -type f | wc -l)
        echo "   📁 $dir/ (包含 $file_count 個文件)"
    fi
done

echo ""
echo "============================================"
echo "🔒 安全確認:"
echo "   ✅ 只操作 /Users/mac/Documents/Sync-Logseq/ 目錄"
echo "   ✅ 不會觸及系統文件"
echo "   ✅ 不會觸及 Logseq 數據"
echo "   ✅ 不會觸及 Git 倉庫核心文件"
echo "   ✅ 當前同步腳本和日誌會保留"
echo ""
echo "💡 如果你確認這個清理列表沒問題，"
echo "   可以運行 cleanup_old_files.sh 執行實際清理"