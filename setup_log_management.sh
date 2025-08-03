#!/bin/bash

echo "📊 設置日誌管理和更新 .gitignore"
echo "=================================="

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$REPO_DIR" || exit

echo "🔧 第一步：更新 .gitignore 文件"
echo ""

# 更新 .gitignore 文件
cat > .gitignore << 'EOF'
# Logseq 同步系統日誌文件
sync.log
sync.error.log
sync_optimized.log
sync_optimized.log.*
logseq_unified.log
logseq_unified.log.*
*.log
*.log.*

# 同步系統文件
.last_sync
.sync_lock

# 備份和臨時文件
cleanup_backup_*
backup_old_scripts/
*.backup
*.tmp
*.bak

# 腳本生成的臨時文件
*.sh.tmp
test_*.txt
tmp_*.md

# macOS 系統文件
.DS_Store
.AppleDouble
.LSOverride
Thumbs.db

# Logseq 內部文件
logseq/bak/
logseq/.recycle

# 開發相關
/node_modules
/.pnp
.pnp.js
/coverage
/build
build/
.history
.vscode/

# 環境配置
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
*config.json

# 日誌輪換文件
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# 大型媒體文件（可根據需要取消註釋）
# *.mp4
# *.mov
# *.psd
# *.zip
# *.tar.gz
EOF

echo "✅ .gitignore 已更新，包含所有日誌文件和臨時文件"
echo ""

echo "🔧 第二步：創建日誌管理函數"
echo ""

# 創建日誌管理腳本
cat > log_manager.sh << 'EOF'
#!/bin/bash
# 日誌管理工具

REPO_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$REPO_DIR" || exit

# 日誌管理函數
manage_log() {
    local log_file="$1"
    local max_size_kb="${2:-512}"  # 默認 512KB
    local keep_lines="${3:-500}"   # 默認保留 500 行
    
    if [ ! -f "$log_file" ]; then
        return 0
    fi
    
    local size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null)
    local size_kb=$((size / 1024))
    
    if [ "$size_kb" -gt "$max_size_kb" ]; then
        echo "$(date): 輪換日誌 $log_file (${size_kb}KB > ${max_size_kb}KB)"
        
        # 創建備份
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        cp "$log_file" "${log_file}.${timestamp}"
        
        # 保留最後 N 行
        tail -"$keep_lines" "$log_file" > "${log_file}.tmp"
        mv "${log_file}.tmp" "$log_file"
        
        # 只保留最近 3 個備份文件
        ls -t "${log_file}".* 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null
        
        echo "$(date): 日誌已輪換，保留最後 $keep_lines 行" >> "$log_file"
    fi
}

# 清理舊日誌文件
cleanup_old_logs() {
    echo "$(date): 開始清理舊日誌文件..."
    
    # 刪除超過 7 天的日誌備份
    find . -name "*.log.*" -mtime +7 -delete 2>/dev/null
    
    # 刪除空的日誌文件
    find . -name "*.log" -size 0 -delete 2>/dev/null
    
    echo "$(date): 舊日誌清理完成"
}

# 顯示日誌統計
show_log_stats() {
    echo "📊 日誌文件統計："
    echo "=================="
    
    for log in *.log; do
        if [ -f "$log" ]; then
            size=$(stat -f%z "$log" 2>/dev/null || stat -c%s "$log" 2>/dev/null)
            size_kb=$((size / 1024))
            lines=$(wc -l < "$log" 2>/dev/null || echo 0)
            echo "   📄 $log: ${size_kb}KB, $lines 行"
        fi
    done
    
    echo ""
    backup_count=$(ls -1 *.log.* 2>/dev/null | wc -l)
    echo "   📦 備份文件: $backup_count 個"
}

# 主程序
case "${1:-status}" in
    "rotate")
        echo "🔄 手動輪換所有日誌..."
        manage_log "sync_optimized.log" 512 500
        manage_log "logseq_unified.log" 512 500
        cleanup_old_logs
        ;;
    "cleanup")
        echo "🧹 清理舊日誌..."
        cleanup_old_logs
        ;;
    "status")
        show_log_stats
        ;;
    "help")
        echo "用法: $0 [rotate|cleanup|status|help]"
        echo "  rotate  - 輪換大型日誌文件"
        echo "  cleanup - 清理舊日誌備份"
        echo "  status  - 顯示日誌統計"
        echo "  help    - 顯示此幫助"
        ;;
    *)
        echo "未知選項: $1"
        echo "使用 '$0 help' 查看幫助"
        ;;
esac
EOF

chmod +x log_manager.sh

echo "✅ 日誌管理腳本已創建"
echo ""

echo "🔧 第三步：修改同步腳本，添加自動日誌管理"
echo ""

# 檢查同步腳本是否存在
if [ -f "logseq_sync_optimized.sh" ]; then
    # 備份原腳本
    cp "logseq_sync_optimized.sh" "logseq_sync_optimized.sh.backup"
    
    # 在腳本開頭添加日誌管理函數
    cat > temp_script.sh << 'EOF'
#!/bin/bash
# 優化版 Logseq 同步腳本 - 帶日誌管理

# 日誌管理函數
manage_log_size() {
    local log_file="$1"
    local max_size_kb="${2:-512}"
    local keep_lines="${3:-500}"
    
    if [ ! -f "$log_file" ]; then
        return 0
    fi
    
    local size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null)
    local size_kb=$((size / 1024))
    
    if [ "$size_kb" -gt "$max_size_kb" ]; then
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        cp "$log_file" "${log_file}.${timestamp}"
        tail -"$keep_lines" "$log_file" > "${log_file}.tmp"
        mv "${log_file}.tmp" "$log_file"
        ls -t "${log_file}".* 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null
        echo "$(date): 日誌已輪換，保留最後 $keep_lines 行" >> "$log_file"
    fi
}

EOF
    
    # 添加原腳本內容（跳過第一行 shebang）
    tail -n +2 "logseq_sync_optimized.sh" >> temp_script.sh
    
    # 在腳本中添加日誌管理調用
    sed -i '' 's/log "🎯 啟動優化同步服務 (PID: $$)"/manage_log_size "$LOG_FILE" 512 500\nlog "🎯 啟動優化同步服務 (PID: $$)"/' temp_script.sh
    
    # 替換原腳本
    mv temp_script.sh logseq_sync_optimized.sh
    chmod +x logseq_sync_optimized.sh
    
    echo "✅ 同步腳本已更新，包含自動日誌管理"
else
    echo "⚠️ 找不到 logseq_sync_optimized.sh，跳過腳本修改"
fi

echo ""
echo "🔧 第四步：立即清理現有大日誌"
echo ""

# 立即處理現有的大日誌文件
if [ -f "logseq_unified.log" ]; then
    size=$(stat -f%z "logseq_unified.log" 2>/dev/null || stat -c%s "logseq_unified.log" 2>/dev/null)
    size_kb=$((size / 1024))
    if [ "$size_kb" -gt 100 ]; then
        echo "📊 logseq_unified.log 當前大小: ${size_kb}KB"
        ./log_manager.sh rotate
        echo "✅ 已輪換大型日誌文件"
    fi
else
    echo "ℹ️ logseq_unified.log 不存在，無需處理"
fi

echo ""
echo "✅ 日誌管理設置完成！"
echo ""
echo "📋 配置總結："
echo "   🔧 .gitignore 已更新，忽略所有日誌文件"
echo "   📊 日誌文件限制: 512KB (超過時自動輪換)"
echo "   📝 輪換時保留: 最後 500 行"
echo "   🗑️ 自動刪除: 7天前的日誌備份"
echo "   ⚙️ 同步腳本已集成自動日誌管理"
echo ""
echo "💡 使用方法："
echo "   ./log_manager.sh status   - 查看日誌統計"
echo "   ./log_manager.sh rotate   - 手動輪換日誌"
echo "   ./log_manager.sh cleanup  - 清理舊備份"
echo ""
echo "🎯 現在日誌不會超載，且不會被同步到 Git！"