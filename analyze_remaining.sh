#!/bin/bash

echo "🔍 分析剩餘文件和目錄的必要性"
echo "=================================="

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$REPO_DIR" || exit

echo "📊 當前目錄內容分析："
echo ""

# 分類分析剩餘內容
echo "🎯 核心系統文件 (必須保留):"
CORE_FILES=(
    "README.md"
    "README_OLD.md"
    "logseq_sync_optimized.sh"
    "sync_optimized.log"
    ".sync_lock"
    ".last_sync"
    ".gitignore"
)

for file in "${CORE_FILES[@]}"; do
    if [ -f "$file" ]; then
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "   ✅ $file (${size_kb}KB) - 必需"
    fi
done
echo ""

echo "📁 Logseq 數據目錄 (必須保留):"
LOGSEQ_DIRS=(
    "journals"
    "pages"
    "logseq"
    "assets"
    "draws"
    "whiteboards"
    "public"
)

for dir in "${LOGSEQ_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        file_count=$(find "$dir" -type f | wc -l)
        echo "   ✅ $dir/ ($file_count 個文件) - Logseq 數據"
    fi
done
echo ""

echo "❓ 需要檢查的目錄和文件:"

# 檢查可疑的目錄和文件
SUSPICIOUS_ITEMS=(
    "backup_old_scripts"
    "~"
    "src"
    "scripts"
    "docs"
)

for item in "${SUSPICIOUS_ITEMS[@]}"; do
    if [ -d "$item" ]; then
        file_count=$(find "$item" -type f | wc -l)
        echo ""
        echo "   📁 $item/ (包含 $file_count 個文件):"
        
        # 顯示目錄內容
        find "$item" -type f | head -5 | while read -r file; do
            size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            size_kb=$((size / 1024))
            echo "      📄 $(basename "$file") (${size_kb}KB)"
        done
        
        if [ "$file_count" -gt 5 ]; then
            echo "      ... 還有 $((file_count - 5)) 個文件"
        fi
        
    elif [ -f "$item" ]; then
        size=$(stat -f%z "$item" 2>/dev/null || stat -c%s "$item" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "   📄 $item (${size_kb}KB)"
    fi
done

echo ""
echo "🧹 清理腳本和備份目錄:"
CLEANUP_ITEMS=(
    "safe_cleanup.sh"
    "final_cleanup.sh"
    "cleanup_backup_20250803_214204"
)

for item in "${CLEANUP_ITEMS[@]}"; do
    if [ -d "$item" ]; then
        file_count=$(find "$item" -type f | wc -l)
        size=$(du -sk "$item" 2>/dev/null | cut -f1)
        echo "   🗑️ $item/ ($file_count 個文件, ${size}KB) - 可刪除的備份"
    elif [ -f "$item" ]; then
        size=$(stat -f%z "$item" 2>/dev/null || stat -c%s "$item" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "   🗑️ $item (${size_kb}KB) - 可刪除的清理腳本"
    fi
done

echo ""
echo "🔍 特殊文件分析:"
SPECIAL_FILES=(
    "Memory01.png"
    "Memory02.png"
    "logseq_unified.log"
)

for file in "${SPECIAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "   🖼️ $file (${size_kb}KB) - 需要確認用途"
    fi
done

echo ""
echo "=================================="
echo "📋 建議的處理方案："
echo ""

echo "🗑️ 可以安全刪除："
echo "   • safe_cleanup.sh, final_cleanup.sh - 清理腳本"
echo "   • cleanup_backup_* - 備份目錄（已完成清理）"
echo "   • logseq_unified.log - 舊的日誌文件"
echo ""

echo "❓ 需要你確認："
echo "   • backup_old_scripts/ - 舊腳本備份，可能可以刪除"
echo "   • ~/（波浪號目錄）- 可能是錯誤創建的目錄"
echo "   • src/, scripts/, docs/ - 可能是你的 Logseq 筆記，需要檢查"
echo "   • Memory01.png, Memory02.png - 可能是重要圖片"
echo ""

echo "✅ 必須保留："
echo "   • 所有 Logseq 數據目錄（journals, pages, logseq, assets 等）"
echo "   • 核心系統文件（README.md, logseq_sync_optimized.sh 等）"