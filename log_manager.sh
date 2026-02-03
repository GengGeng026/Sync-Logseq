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
