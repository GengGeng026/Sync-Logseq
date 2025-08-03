#!/bin/bash

echo "✨ 最終潤色：刪除確認不需要的文件"
echo "===================================="

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$REPO_DIR" || exit

echo "🔍 檢查確認可以刪除的文件："
echo ""

# 確認可以刪除的項目
DEFINITELY_DELETE=(
    "safe_cleanup.sh"
    "final_cleanup.sh"
    "analyze_remaining.sh"
    "logseq_unified.log"
)

PROBABLY_DELETE_DIRS=(
    "backup_old_scripts"
    "cleanup_backup_20250803_214204"
    "~"
)

echo "📋 確認刪除的文件："
total_size=0
for file in "${DEFINITELY_DELETE[@]}"; do
    if [ -f "$file" ]; then
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "   🗑️ $file (${size_kb}KB)"
        total_size=$((total_size + size))
    fi
done

echo ""
echo "📁 確認刪除的目錄："
for dir in "${PROBABLY_DELETE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        file_count=$(find "$dir" -type f | wc -l)
        dir_size=$(du -sk "$dir" 2>/dev/null | cut -f1)
        echo "   🗑️ $dir/ ($file_count 個文件, ${dir_size}KB)"
        total_size=$((total_size + dir_size * 1024))
    fi
done

echo ""
echo "📊 總共將釋放: $((total_size / 1024))KB 空間"
echo ""

echo "❓ 需要你手動檢查的目錄："
MANUAL_CHECK=(
    "src"
    "scripts"
    "docs"
)

for dir in "${MANUAL_CHECK[@]}"; do
    if [ -d "$dir" ]; then
        file_count=$(find "$dir" -type f | wc -l)
        echo "   ❓ $dir/ ($file_count 個文件) - 可能是你的 Logseq 筆記"
        echo "      建議：ls $dir/ 查看內容後決定"
    fi
done

echo ""
echo "🖼️ 圖片文件："
if [ -f "Memory01.png" ] && [ -f "Memory02.png" ]; then
    echo "   🖼️ Memory01.png, Memory02.png - README 中的災難記錄圖片"
    echo "      建議：保留，這些是重要的經驗教訓記錄"
fi

echo ""
echo "=================================="
echo "🤔 執行自動清理嗎？"
echo ""
echo "將會刪除："
echo "   • 清理腳本 (safe_cleanup.sh, final_cleanup.sh 等)"
echo "   • 備份目錄 (backup_old_scripts, cleanup_backup_*)"
echo "   • 錯誤目錄 (~)"
echo "   • 舊日誌 (logseq_unified.log)"
echo ""
echo "不會觸及："
echo "   • src/, scripts/, docs/ 目錄（需要你手動檢查）"
echo "   • Memory*.png 圖片文件"
echo "   • 所有 Logseq 數據"
echo ""
read -p "確定執行自動清理嗎？(y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🗑️ 開始自動清理..."
    
    deleted_count=0
    
    # 刪除文件
    for file in "${DEFINITELY_DELETE[@]}"; do
        if [ -f "$file" ] && rm "$file" 2>/dev/null; then
            echo "   ✅ 已刪除文件: $file"
            deleted_count=$((deleted_count + 1))
        fi
    done
    
    # 刪除目錄
    for dir in "${PROBABLY_DELETE_DIRS[@]}"; do
        if [ -d "$dir" ] && rm -rf "$dir" 2>/dev/null; then
            echo "   ✅ 已刪除目錄: $dir/"
            deleted_count=$((deleted_count + 1))
        fi
    done
    
    echo ""
    echo "✅ 自動清理完成！"
    echo "   📊 刪除了 $deleted_count 個項目"
    echo "   💾 釋放了 $((total_size / 1024))KB 空間"
    echo ""
    echo "🎯 現在你的目錄結構："
    echo "   📄 README.md, README_OLD.md - 文檔"
    echo "   🚀 logseq_sync_optimized.sh - 同步腳本"
    echo "   📊 sync_optimized.log - 運行日誌"  
    echo "   🖼️ Memory01.png, Memory02.png - 災難記錄圖片"
    echo "   📁 journals/, pages/, logseq/, assets/ - Logseq 數據"
    echo "   ❓ src/, scripts/, docs/ - 需要你檢查的目錄"
    echo ""
    echo "💡 下一步建議："
    echo "   1. ls src/ scripts/ docs/ - 查看這些目錄內容"
    echo "   2. 如果是 Logseq 筆記，保留；如果是舊代碼，可以刪除"
    
else
    echo ""
    echo "❌ 取消自動清理"
    echo "💡 你可以手動檢查並刪除不需要的文件"
fi

echo ""
echo "📊 當前狀態："
ls -la | grep -E "^d" | wc -l | xargs echo "   目錄數量:"
ls -la | grep -E "^-" | wc -l | xargs echo "   文件數量:"