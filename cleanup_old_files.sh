#!/bin/bash

echo "🧹 清理 Logseq 同步資料夾中的舊文件..."
echo "================================================"

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$REPO_DIR" || exit

# 創建備份目錄（以防萬一）
BACKUP_DIR="$REPO_DIR/cleanup_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 備份目錄: $BACKUP_DIR"
echo ""

# 分類要清理的文件
echo "🗂️ 要清理的文件分類："
echo ""

# 1. 舊的同步腳本（保留當前使用的）
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

for script in "${OLD_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "   - $script"
        cp "$script" "$BACKUP_DIR/" 2>/dev/null
    fi
done
echo ""

# 2. 舊的 plist 文件
echo "📋 舊的 plist 文件:"
OLD_PLISTS=(
    "com.user.logseq.autostart.plist"
    "com.user.logseq.unified.plist"
)

for plist in "${OLD_PLISTS[@]}"; do
    if [ -f "$plist" ]; then
        echo "   - $plist"
        cp "$plist" "$BACKUP_DIR/" 2>/dev/null
    fi
done
echo ""

# 3. 設置和清理腳本
echo "🔧 設置和清理腳本:"
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

for script in "${SETUP_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "   - $script"
        cp "$script" "$BACKUP_DIR/" 2>/dev/null
    fi
done
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

for log in "${OLD_LOGS[@]}"; do
    if [ -f "$log" ]; then
        echo "   - $log"
        cp "$log" "$BACKUP_DIR/" 2>/dev/null
    fi
done
echo ""

# 5. 測試和臨時文件
echo "🧪 測試和臨時文件:"
TEST_FILES=(
    "test_auto_sync.txt"
    "tmp_rovodev_system_recovery_guide.md"
    "alternative_side_by_side.md"
)

for file in "${TEST_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   - $file"
        cp "$file" "$BACKUP_DIR/" 2>/dev/null
    fi
done
echo ""

# 6. README 文件（保留主要的，清理多餘的）
echo "📖 多餘的 README 文件:"
EXTRA_READMES=(
    "README_CRITICAL_LESSONS.md"
    "README_LOGSEQ_AUTOSTART.md"
)

for readme in "${EXTRA_READMES[@]}"; do
    if [ -f "$readme" ]; then
        echo "   - $readme"
        cp "$readme" "$BACKUP_DIR/" 2>/dev/null
    fi
done
echo ""

# 保留的重要文件
echo "✅ 保留的重要文件:"
KEEP_FILES=(
    "logseq_sync_optimized.sh"  # 當前使用的腳本
    "sync_optimized.log"        # 當前的日誌
    ".sync_lock"               # 進程鎖文件
    ".last_sync"               # 同步標記文件
    ".gitignore"               # Git 配置
    "README.md"                # 主要說明文件
)

for file in "${KEEP_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file"
    fi
done
echo ""

# 詢問是否執行清理
echo "================================================"
echo "🤔 要執行清理嗎？"
echo ""
echo "將會刪除上述列出的文件，但已備份到:"
echo "$BACKUP_DIR"
echo ""
echo "保留的文件將繼續支持你的工業級同步系統。"
echo ""
read -p "確定要執行清理嗎？(y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🗑️ 開始清理..."
    
    # 執行清理
    ALL_TO_DELETE=(
        "${OLD_SCRIPTS[@]}"
        "${OLD_PLISTS[@]}"
        "${SETUP_SCRIPTS[@]}"
        "${OLD_LOGS[@]}"
        "${TEST_FILES[@]}"
        "${EXTRA_READMES[@]}"
    )
    
    deleted_count=0
    for file in "${ALL_TO_DELETE[@]}"; do
        if [ -f "$file" ]; then
            rm "$file"
            echo "   🗑️ 已刪除: $file"
            deleted_count=$((deleted_count + 1))
        fi
    done
    
    echo ""
    echo "✅ 清理完成！"
    echo "   📊 刪除了 $deleted_count 個文件"
    echo "   💾 備份保存在: $BACKUP_DIR"
    echo ""
    echo "🎯 現在你的資料夾只保留:"
    echo "   • 工業級同步腳本: logseq_sync_optimized.sh"
    echo "   • 當前日誌: sync_optimized.log"
    echo "   • Logseq 數據: journals/, pages/, logseq/ 等"
    echo "   • Git 配置和其他必要文件"
    echo ""
    echo "🚀 你的同步系統現在更加簡潔高效！"
    
else
    echo ""
    echo "❌ 取消清理"
    echo "💡 如果以後想清理，再次運行此腳本即可"
    rm -rf "$BACKUP_DIR"  # 刪除空的備份目錄
fi

echo ""
echo "📊 當前資料夾內容:"
ls -la | grep -E "^-.*\.(sh|log|plist|md)$" | wc -l | xargs echo "   腳本和配置文件數量:"
echo "   主要目錄: journals/, pages/, logseq/, assets/"