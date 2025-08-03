#!/bin/bash

echo "📝 整合所有文檔到統一的 README.md..."
echo "=========================================="

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$REPO_DIR" || exit

echo "🔍 檢查要整合的文檔："
echo ""

# 檢查各個文檔的存在性和大小
docs_to_check=(
    "README.md"
    "README_CRITICAL_LESSONS.md"
    "docs/Logseq同步方案演進記錄.md"
    "docs/README_improved_sync.md"
)

total_size=0
for doc in "${docs_to_check[@]}"; do
    if [ -f "$doc" ]; then
        size=$(stat -f%z "$doc" 2>/dev/null || stat -c%s "$doc" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "   📄 $doc (${size_kb}KB)"
        total_size=$((total_size + size))
    else
        echo "   ❌ $doc (不存在)"
    fi
done

echo ""
echo "📊 原文檔總大小: $((total_size / 1024))KB"
echo ""

# 檢查統一文檔
if [ -f "README_UNIFIED.md" ]; then
    unified_size=$(stat -f%z "README_UNIFIED.md" 2>/dev/null || stat -c%s "README_UNIFIED.md" 2>/dev/null)
    unified_kb=$((unified_size / 1024))
    echo "📄 統一文檔大小: ${unified_kb}KB"
    echo ""
fi

echo "🤔 要執行文檔整合嗎？"
echo ""
echo "這將會："
echo "   1. 備份現有的 README.md → README_OLD.md"
echo "   2. 用統一版本替換 README.md"
echo "   3. 保留所有原始文檔作為參考"
echo ""
read -p "確定要執行整合嗎？(y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔄 開始整合..."
    
    # 備份現有 README
    if [ -f "README.md" ]; then
        cp "README.md" "README_OLD.md"
        echo "   💾 已備份 README.md → README_OLD.md"
    fi
    
    # 替換為統一版本
    if [ -f "README_UNIFIED.md" ]; then
        cp "README_UNIFIED.md" "README.md"
        echo "   ✅ 已更新 README.md"
    else
        echo "   ❌ 找不到 README_UNIFIED.md"
        exit 1
    fi
    
    echo ""
    echo "✅ 文檔整合完成！"
    echo ""
    echo "📋 現在的文檔結構："
    echo "   📄 README.md - 統一的完整指南"
    echo "   📄 README_OLD.md - 舊版本備份"
    echo "   📄 README_CRITICAL_LESSONS.md - 原始教訓文檔（可清理）"
    echo "   📁 docs/ - 原始詳細文檔（可清理）"
    echo ""
    echo "💡 建議："
    echo "   1. 檢查新的 README.md 是否符合需求"
    echo "   2. 確認後可以清理舊文檔："
    echo "      - README_CRITICAL_LESSONS.md"
    echo "      - docs/Logseq同步方案演進記錄.md"
    echo "      - docs/README_improved_sync.md"
    echo ""
    echo "🎯 新的 README.md 包含了所有重要的："
    echo "   • 災難教訓和安全原則"
    echo "   • 技術演進和關鍵突破"
    echo "   • 實戰部署和故障排除"
    echo "   • 系統監控和維護指南"
    
else
    echo ""
    echo "❌ 取消整合"
    echo "💡 如果以後想整合，再次運行此腳本即可"
fi

echo ""
echo "📊 當前文檔狀態："
ls -la *.md | grep -E "(README|CRITICAL)" | awk '{print "   " $9 " (" $5 " bytes)"}'