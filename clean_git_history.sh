#!/bin/bash

echo "🧹 清理 Git 歷史中的日誌文件並優化 .gitignore"
echo "================================================"

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$REPO_DIR" || exit

echo "⚠️  重要警告："
echo "   這個操作會重寫 Git 歷史，是不可逆的！"
echo "   建議在執行前確保："
echo "   1. 所有重要變更已經提交"
echo "   2. 沒有其他人在使用這個倉庫"
echo "   3. 已經備份重要數據"
echo ""

read -p "你確定要繼續嗎？(y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 操作已取消"
    exit 0
fi

echo ""
echo "🔍 第一步：檢查要清理的日誌文件"
echo ""

# 檢查 Git 歷史中的日誌文件
LOG_FILES_TO_REMOVE=(
    "logseq_unified.log"
    "sync_optimized.log"
    "sync_stdout.log"
    "sync_simple.log"
    "sync_single.log"
    "autostart.log"
    "daemon.log"
    "launchagent_*.log"
    "*.log.*"
)

echo "📋 將從 Git 歷史中移除的文件模式："
for pattern in "${LOG_FILES_TO_REMOVE[@]}"; do
    echo "   🗑️ $pattern"
done

echo ""
echo "🔍 檢查這些文件是否在 Git 歷史中："
for pattern in "${LOG_FILES_TO_REMOVE[@]}"; do
    if git log --name-only --pretty=format: | grep -q "$pattern" 2>/dev/null; then
        echo "   ⚠️ 發現: $pattern 存在於 Git 歷史中"
    fi
done

echo ""
echo "🔧 第二步：更新 .gitignore"
echo ""

# 創建完善的 .gitignore
cat > .gitignore << 'EOF'
# ================================
# Logseq 同步系統配置
# ================================

# 所有日誌文件
*.log
*.log.*
sync_*.log
logseq_*.log
autostart*.log
daemon*.log
launchagent*.log

# 同步系統運行文件
.last_sync
.sync_lock

# 備份和臨時文件
cleanup_backup_*
backup_old_scripts/
*.backup
*.tmp
*.bak
*.swp

# 腳本生成的臨時文件
test_*.txt
tmp_*.md
*.sh.tmp

# ================================
# 系統和編輯器文件
# ================================

# macOS
.DS_Store
.AppleDouble
.LSOverride
Icon?
._*
Thumbs.db

# Windows
Thumbs.db
ehthumbs.db
Desktop.ini

# ================================
# Logseq 內部文件
# ================================

# Logseq 備份和回收站
logseq/bak/
logseq/.recycle

# ================================
# 開發相關文件
# ================================

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.pnp/
.pnp.js

# 構建輸出
/build
/dist
/coverage

# IDE 和編輯器
.vscode/
.idea/
*.swp
*.swo
*~
.history/

# 環境配置
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
*config.json

# ================================
# 可選：大型媒體文件
# ================================
# 如果你的筆記包含大型文件，可以取消下面的註釋

# 視頻文件
# *.mp4
# *.mov
# *.avi
# *.mkv

# 音頻文件
# *.mp3
# *.wav
# *.flac

# 大型圖像文件
# *.psd
# *.ai
# *.eps

# 壓縮文件
# *.zip
# *.rar
# *.7z
# *.tar.gz
EOF

echo "✅ .gitignore 已更新"

# 立即生效 .gitignore
git add .gitignore
git commit -m "feat: 更新 .gitignore，忽略所有日誌和臨時文件"

echo ""
echo "🔧 第三步：從 Git 歷史中移除日誌文件"
echo ""

# 檢查是否有 git filter-branch 或 git filter-repo
if command -v git-filter-repo >/dev/null 2>&1; then
    echo "📦 使用 git-filter-repo 清理歷史..."
    
    # 使用 git-filter-repo 移除文件
    git filter-repo --invert-paths \
        --path-glob '*.log' \
        --path-glob '*.log.*' \
        --path-glob 'sync_*.log' \
        --path-glob 'logseq_*.log' \
        --path-glob 'autostart*.log' \
        --path-glob 'daemon*.log' \
        --path-glob 'launchagent*.log' \
        --force
        
    echo "✅ 使用 git-filter-repo 清理完成"
    
elif command -v git >/dev/null 2>&1; then
    echo "📦 使用 git filter-branch 清理歷史..."
    
    # 使用 git filter-branch 移除文件
    git filter-branch --force --index-filter \
        'git rm --cached --ignore-unmatch \
            "*.log" \
            "*.log.*" \
            "sync_*.log" \
            "logseq_*.log" \
            "autostart*.log" \
            "daemon*.log" \
            "launchagent*.log"' \
        --prune-empty --tag-name-filter cat -- --all
        
    echo "✅ 使用 git filter-branch 清理完成"
    
    # 清理 refs
    git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d
    
else
    echo "❌ 找不到 git filter-repo 或 git filter-branch"
    exit 1
fi

echo ""
echo "🔧 第四步：清理和優化倉庫"
echo ""

# 清理無用的引用和對象
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo "✅ 倉庫已優化"

echo ""
echo "🔧 第五步：檢查清理結果"
echo ""

# 檢查倉庫大小
repo_size=$(du -sh .git | cut -f1)
echo "📊 當前倉庫大小: $repo_size"

# 檢查是否還有日誌文件在歷史中
echo "🔍 檢查清理結果："
remaining_logs=$(git log --name-only --pretty=format: | grep -E '\.(log|log\.)' | sort | uniq)
if [ -z "$remaining_logs" ]; then
    echo "✅ 所有日誌文件已從 Git 歷史中移除"
else
    echo "⚠️ 仍有一些日誌文件在歷史中："
    echo "$remaining_logs"
fi

echo ""
echo "🚀 第六步：推送到遠程倉庫"
echo ""

echo "⚠️  注意：這會強制推送，重寫遠程歷史！"
read -p "確定要推送到遠程倉庫嗎？(y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📤 強制推送到遠程倉庫..."
    git push origin --force --all
    git push origin --force --tags
    echo "✅ 已推送到遠程倉庫"
else
    echo "⏸️ 跳過推送，你可以稍後手動推送："
    echo "   git push origin --force --all"
    echo "   git push origin --force --tags"
fi

echo ""
echo "=================================="
echo "✅ Git 歷史清理完成！"
echo ""
echo "📋 完成的操作："
echo "   🧹 從 Git 歷史中移除所有日誌文件"
echo "   📝 更新 .gitignore 忽略日誌文件"
echo "   🗜️ 優化倉庫大小"
echo "   📤 推送到遠程倉庫（如果選擇）"
echo ""
echo "🎯 現在你的倉庫："
echo "   ✅ 歷史中沒有日誌文件"
echo "   ✅ 未來不會追蹤日誌文件"
echo "   ✅ 倉庫大小已優化"
echo "   ✅ .gitignore 配置完善"
echo ""
echo "💡 關於 .gitignore："
echo "   ✅ 建議保存在遠程倉庫"
echo "   ✅ 幫助其他協作者避免提交不必要的文件"
echo "   ✅ 確保倉庫保持清潔"