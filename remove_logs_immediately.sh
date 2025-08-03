#!/bin/bash

echo "🗑️ 立即從遠程倉庫移除日誌文件並永久停止追蹤"
echo "=================================================="

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$REPO_DIR" || exit

echo "🎯 目標："
echo "   • 立即從遠程倉庫移除所有日誌文件"
echo "   • 未來永遠不再追蹤日誌文件"
echo "   • 保留 Git 歷史（不重寫）"
echo ""

echo "🔍 第一步：檢查當前被追蹤的日誌文件"
echo ""

# 檢查當前被 Git 追蹤的日誌文件
tracked_logs=$(git ls-files | grep -E '\.(log|log\.)' | head -10)
if [ -n "$tracked_logs" ]; then
    echo "📋 發現以下被追蹤的日誌文件："
    echo "$tracked_logs" | while read -r file; do
        if [ -f "$file" ]; then
            size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            size_kb=$((size / 1024))
            echo "   🗑️ $file (${size_kb}KB)"
        else
            echo "   🗑️ $file (已刪除但仍被追蹤)"
        fi
    done
else
    echo "✅ 沒有發現被追蹤的日誌文件"
fi

echo ""
echo "🔧 第二步：更新 .gitignore（如果尚未更新）"
echo ""

# 確保 .gitignore 包含所有日誌文件
if ! grep -q "*.log" .gitignore 2>/dev/null; then
    echo "📝 更新 .gitignore..."
    
cat >> .gitignore << 'EOF'

# ================================
# 日誌文件 - 永不追蹤
# ================================
*.log
*.log.*
sync_*.log
logseq_*.log
autostart*.log
daemon*.log
launchagent*.log

# 同步系統文件
.last_sync
.sync_lock

# 備份和臨時文件
cleanup_backup_*
backup_old_scripts/
*.backup
*.tmp
*.bak
EOF

    echo "✅ .gitignore 已更新"
else
    echo "✅ .gitignore 已包含日誌文件規則"
fi

echo ""
echo "🗑️ 第三步：從 Git 追蹤中移除所有日誌文件"
echo ""

# 從 Git 追蹤中移除日誌文件（但保留本地文件）
LOG_PATTERNS=(
    "*.log"
    "*.log.*" 
    "sync_*.log"
    "logseq_*.log"
    "autostart*.log"
    "daemon*.log"
    "launchagent*.log"
)

removed_count=0
for pattern in "${LOG_PATTERNS[@]}"; do
    # 檢查是否有匹配的文件被追蹤
    if git ls-files | grep -E "$(echo "$pattern" | sed 's/\*/.*/')" >/dev/null 2>&1; then
        echo "   🗑️ 停止追蹤: $pattern"
        git rm --cached "$pattern" 2>/dev/null || true
        removed_count=$((removed_count + 1))
    fi
done

# 也處理具體的已知日誌文件
SPECIFIC_LOGS=(
    "logseq_unified.log"
    "sync_optimized.log"
    "sync_stdout.log"
    "sync_simple.log"
    "sync_single.log"
    "autostart.log"
    "daemon.log"
)

for log_file in "${SPECIFIC_LOGS[@]}"; do
    if git ls-files | grep -q "^$log_file$"; then
        echo "   🗑️ 停止追蹤: $log_file"
        git rm --cached "$log_file" 2>/dev/null || true
        removed_count=$((removed_count + 1))
    fi
done

echo ""
if [ "$removed_count" -gt 0 ]; then
    echo "✅ 已停止追蹤 $removed_count 個日誌文件模式"
else
    echo "ℹ️ 沒有發現需要停止追蹤的日誌文件"
fi

echo ""
echo "📝 第四步：提交變更"
echo ""

# 添加 .gitignore 的變更
git add .gitignore

# 檢查是否有變更需要提交
if ! git diff --cached --quiet; then
    echo "💾 提交變更..."
    git commit -m "feat: 停止追蹤所有日誌文件並更新 .gitignore

- 從 Git 追蹤中移除所有 *.log 文件
- 更新 .gitignore 永久忽略日誌文件
- 保持本地日誌文件不變
- 確保遠程倉庫立即清潔"
    
    echo "✅ 變更已提交"
else
    echo "ℹ️ 沒有變更需要提交"
fi

echo ""
echo "📤 第五步：推送到遠程倉庫"
echo ""

echo "🚀 推送變更到遠程倉庫..."
if git push origin main; then
    echo "✅ 成功推送到遠程倉庫"
else
    echo "❌ 推送失敗，請檢查網絡連接"
    exit 1
fi

echo ""
echo "🔍 第六步：驗證結果"
echo ""

# 檢查本地狀態
echo "📊 本地狀態檢查："
current_logs=$(ls *.log 2>/dev/null | head -5)
if [ -n "$current_logs" ]; then
    echo "   📁 本地日誌文件（保留）:"
    echo "$current_logs" | while read -r file; do
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "      📄 $file (${size_kb}KB)"
    done
else
    echo "   📁 本地沒有日誌文件"
fi

# 檢查 Git 追蹤狀態
echo ""
echo "📊 Git 追蹤狀態檢查："
still_tracked=$(git ls-files | grep -E '\.(log|log\.)' | head -5)
if [ -n "$still_tracked" ]; then
    echo "   ⚠️ 仍被追蹤的日誌文件:"
    echo "$still_tracked"
else
    echo "   ✅ 沒有日誌文件被追蹤"
fi

echo ""
echo "=================================="
echo "🎉 操作完成！"
echo ""
echo "📋 完成的操作："
echo "   🗑️ 從 Git 追蹤中移除所有日誌文件"
echo "   📝 更新 .gitignore 永久忽略日誌文件"
echo "   💾 提交並推送變更到遠程倉庫"
echo "   📁 保留本地日誌文件不變"
echo ""
echo "🎯 現在的狀態："
echo "   ✅ 遠程倉庫立即看不到日誌文件"
echo "   ✅ 未來永遠不會再追蹤日誌文件"
echo "   ✅ 本地日誌文件仍然存在並正常工作"
echo "   ✅ Git 歷史保持完整（未重寫）"
echo ""
echo "💡 結果："
echo "   • 遠程倉庫現在是清潔的"
echo "   • 日誌系統繼續正常工作"
echo "   • 未來的日誌不會被提交"
echo "   • 協作者不會看到日誌文件"