#!/bin/bash
# 簡化日誌管理器 - 只保留最後 100 行，不創建備份

trim_log() {
    local log_file="$1"
    local max_lines="${2:-100}"
    
    if [ -f "$log_file" ]; then
        local current_lines=$(wc -l < "$log_file")
        if [ "$current_lines" -gt "$max_lines" ]; then
            # 只保留最後 100 行，直接覆蓋
            tail -"$max_lines" "$log_file" > "${log_file}.tmp"
            mv "${log_file}.tmp" "$log_file"
            echo "$(date '+%H:%M:%S'): 日誌已修剪至 $max_lines 行" >> "$log_file"
        fi
    fi
}

# 修剪兩個日誌文件
trim_log "sync.log" 100
trim_log "error.log" 100
