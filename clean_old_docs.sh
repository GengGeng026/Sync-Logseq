#!/bin/bash

echo "🧹 清理整合後的舊文檔..."
echo "================================"

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$REPO_DIR" || exit

echo "📋 將要刪除的文檔："
echo ""

# 要刪除的文檔列表
OLD_DOCS=(
    "README_CRITICAL_LESSONS.md"
    "README_LOGSEQ_AUTOSTART.md"
    "README_UNIFIED.md"
    "docs/Logseq同步方案演進記錄.md"
    "docs/README_improved_sync.md"
)

# 檢查並顯示要刪除的文檔
total_size=0
existing_docs=()

for doc in "${OLD_DOCS[@]}"; do
    if [ -f "$doc" ]; then
        size=$(stat -f%z "$doc" 2>/dev/null || stat -c%s "$doc" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "   🗑️ $doc (${size_kb}KB)"
        total_size=$((total_size + size))
        existing_docs+=("$doc")
    fi
done

echo ""
echo "📊 總共將釋放: $((total_size / 1024))KB 空間"
echo ""

echo "✅ 將會保留的重要文檔："
KEEP_DOCS=(
    "README.md"
    "README_OLD.md"
)

for doc in "${KEEP_DOCS[@]}"; do
    if [ -f "$doc" ]; then
        size=$(stat -f%z "$doc" 2>/dev/null || stat -c%s "$doc" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "   📄 $doc (${size_kb}KB) - 統一指南"
    fi
done

echo ""
echo "🔍 檢查 docs/ 目錄："
if [ -d "docs" ]; then
    remaining_files=$(find docs -type f | grep -v -E "(Logseq同步方案演進記錄\.md|README_improved_sync\.md)" | wc -l)
    if [ "$remaining_files" -eq 0 ]; then
        echo "   📁 docs/ 目錄清空後將被刪除"
    else
        echo "   📁 docs/ 目錄還有 $remaining_files 個其他文件，將保留目錄"
    fi
fi

echo ""
echo "================================"
echo "🤔 確認刪除這些文檔嗎？"
echo ""
echo "⚠️  重要提醒："
echo "   • 所有內容都已整合到 README.md 中"
echo "   • README_OLD.md 保留作為備份"
echo "   • 這些文檔刪除後可以從 Git 歷史恢復"
echo ""
read -p "確定要刪除嗎？(y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🗑️ 開始清理..."
    
    deleted_count=0
    for doc in "${existing_docs[@]}"; do
        if rm "$doc" 2>/dev/null; then
            echo "   ✅ 已刪除: $doc"
            deleted_count=$((deleted_count + 1))
        else
            echo "   ❌ 刪除失敗: $doc"
        fi
    done
    
    # 檢查並清理空的 docs 目錄
    if [ -d "docs" ]; then
        remaining_files=$(find docs -type f | wc -l)
        if [ "$remaining_files" -eq 0 ]; then
            rmdir docs
            echo "   🗂️ 已刪除空的 docs/ 目錄"
        fi
    fi
    
    echo ""
    echo "✅ 清理完成！"
    echo "   📊 刪除了 $deleted_count 個文檔"
    echo "   💾 釋放了 $((total_size / 1024))KB 空間"
    echo ""
    echo "🎯 現在你的文檔結構更加簡潔："
    echo "   📄 README.md - 完整的統一指南"
    echo "   📄 README_OLD.md - 舊版本備份"
    echo "   🚀 logseq_sync_optimized.sh - 工業級同步腳本"
    echo "   📊 sync_optimized.log - 運行日誌"
    echo ""
    echo "🎉 你的 Logseq 同步系統現在既強大又簡潔！"
    
else
    echo ""
    echo "❌ 取消清理"
    echo "💡 文檔將保持現狀，你可以隨時再次運行此腳本"
fi

echo ""
echo "📊 當前文檔狀態："
ls -la *.md 2>/dev/null | awk '{print "   " $9 " (" $5 " bytes)"}' || echo "   (沒有 .md 文檔)"