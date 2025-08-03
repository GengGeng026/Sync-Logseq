#!/bin/bash

echo "🤔 評估腳本的保留價值"
echo "========================"

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$REPO_DIR" || exit

echo "📊 當前腳本分析："
echo ""

# 分析各個腳本
SCRIPTS_TO_EVALUATE=(
    "setup_log_management.sh"
    "log_manager.sh"
    "final_polish.sh"
    "analyze_remaining.sh"
    "evaluate_scripts.sh"
)

echo "🔍 腳本評估結果："
echo ""

for script in "${SCRIPTS_TO_EVALUATE[@]}"; do
    if [ -f "$script" ]; then
        size=$(stat -f%z "$script" 2>/dev/null || stat -c%s "$script" 2>/dev/null)
        size_kb=$((size / 1024))
        
        case "$script" in
            "setup_log_management.sh")
                echo "   🗑️ $script (${size_kb}KB) - 一次性設置，可刪除"
                ;;
            "log_manager.sh")
                echo "   ❓ $script (${size_kb}KB) - 維護工具，可選保留"
                ;;
            "final_polish.sh"|"analyze_remaining.sh"|"evaluate_scripts.sh")
                echo "   🗑️ $script (${size_kb}KB) - 臨時腳本，可刪除"
                ;;
        esac
    fi
done

echo ""
echo "💡 建議的處理方案："
echo ""

echo "🗑️ 建議刪除（一次性任務完成）："
echo "   • setup_log_management.sh - 日誌管理已設置完成"
echo "   • final_polish.sh - 清理任務已完成"
echo "   • analyze_remaining.sh - 分析任務已完成"
echo "   • evaluate_scripts.sh - 評估任務完成後可刪除"
echo ""

echo "❓ log_manager.sh 的選擇："
echo ""
echo "   保留的理由："
echo "   ✅ 可以手動查看日誌統計"
echo "   ✅ 可以手動輪換大日誌"
echo "   ✅ 可以清理舊備份"
echo "   ✅ 故障排除時有用"
echo ""
echo "   刪除的理由："
echo "   🔄 同步腳本已集成自動日誌管理"
echo "   🔄 正常情況下不需要手動干預"
echo "   🔄 保持系統簡潔"
echo ""

echo "🎯 最終建議："
echo ""
echo "選項 A - 極簡主義（推薦）："
echo "   刪除所有維護腳本，只保留核心文件"
echo "   優點：極其簡潔，自動化完全接管"
echo "   缺點：失去手動維護工具"
echo ""
echo "選項 B - 保守主義："
echo "   保留 log_manager.sh 作為維護工具"
echo "   優點：保留手動控制能力"
echo "   缺點：多一個文件"
echo ""

read -p "你的選擇 (A-極簡/B-保守/N-不刪除): " -n 1 -r
echo
echo

case $REPLY in
    [Aa])
        echo "🗑️ 執行極簡清理..."
        
        CLEANUP_SCRIPTS=(
            "setup_log_management.sh"
            "log_manager.sh" 
            "final_polish.sh"
            "analyze_remaining.sh"
            "evaluate_scripts.sh"
        )
        
        deleted_count=0
        for script in "${CLEANUP_SCRIPTS[@]}"; do
            if [ -f "$script" ] && rm "$script" 2>/dev/null; then
                echo "   ✅ 已刪除: $script"
                deleted_count=$((deleted_count + 1))
            fi
        done
        
        echo ""
        echo "✅ 極簡清理完成！刪除了 $deleted_count 個腳本"
        echo ""
        echo "🎯 現在你的系統極其簡潔："
        echo "   📄 README.md - 完整指南"
        echo "   🚀 logseq_sync_optimized.sh - 同步腳本（含日誌管理）"
        echo "   📊 sync_optimized.log - 運行日誌（自動管理）"
        echo "   📁 Logseq 數據目錄 - 你的筆記"
        echo ""
        echo "🔄 日誌管理完全自動化，無需手動干預！"
        ;;
        
    [Bb])
        echo "🛠️ 執行保守清理..."
        
        CLEANUP_SCRIPTS=(
            "setup_log_management.sh"
            "final_polish.sh"
            "analyze_remaining.sh"
            "evaluate_scripts.sh"
        )
        
        deleted_count=0
        for script in "${CLEANUP_SCRIPTS[@]}"; do
            if [ -f "$script" ] && rm "$script" 2>/dev/null; then
                echo "   ✅ 已刪除: $script"
                deleted_count=$((deleted_count + 1))
            fi
        done
        
        echo ""
        echo "✅ 保守清理完成！刪除了 $deleted_count 個腳本"
        echo ""
        echo "🎯 現在你的系統："
        echo "   📄 README.md - 完整指南"
        echo "   🚀 logseq_sync_optimized.sh - 同步腳本"
        echo "   🛠️ log_manager.sh - 維護工具"
        echo "   📊 sync_optimized.log - 運行日誌"
        echo "   📁 Logseq 數據目錄 - 你的筆記"
        echo ""
        echo "💡 使用維護工具："
        echo "   ./log_manager.sh status - 查看日誌統計"
        ;;
        
    *)
        echo "❌ 取消清理，保持現狀"
        ;;
esac

echo ""
echo "📊 清理後狀態："
ls -la *.sh 2>/dev/null | wc -l | xargs echo "   腳本文件數量:"
ls -la *.md 2>/dev/null | wc -l | xargs echo "   文檔文件數量:"