#!/bin/bash
# 智能日志管理器 - 处理高频日志

LOG_DIR="/Users/mac/Documents/Sync-Logseq"
MAX_LOG_SIZE=102400  # 100KB (比原来的512KB更小)
MAX_LINES=200        # 最多保留200行 (比原来的500行更少)
MAX_BACKUP_FILES=2   # 最多保留2个备份文件

# 日志文件列表
LOG_FILES=(
    "$LOG_DIR/sync_stdout.log"
    "$LOG_DIR/launchagent_stdout.log"
    "$LOG_DIR/launchagent_stderr.log"
    "$LOG_DIR/startup_check.log"
)

rotate_single_log() {
    local log_file="$1"
    
    if [ ! -f "$log_file" ]; then
        return 0
    fi
    
    local size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null)
    local lines=$(wc -l < "$log_file" 2>/dev/null || echo 0)
    
    # 检查是否需要轮换 (大小超过限制 OR 行数超过限制)
    if [ "$size" -gt "$MAX_LOG_SIZE" ] || [ "$lines" -gt "$MAX_LINES" ]; then
        echo "$(date): 🔄 轮换日志: $log_file (大小: ${size}B, 行数: $lines)"
        
        # 创建备份
        local backup_file="${log_file}.$(date +%Y%m%d_%H%M%S)"
        cp "$log_file" "$backup_file"
        
        # 保留最后的关键行数
        tail -$((MAX_LINES / 2)) "$log_file" > "${log_file}.tmp"
        echo "$(date): 📋 日志已轮换，保留最后 $((MAX_LINES / 2)) 行" > "$log_file"
        cat "${log_file}.tmp" >> "$log_file"
        rm -f "${log_file}.tmp"
        
        # 清理旧备份文件
        ls -t "${log_file}."* 2>/dev/null | tail -n +$((MAX_BACKUP_FILES + 1)) | xargs rm -f 2>/dev/null
        
        echo "$(date): ✅ 日志轮换完成: $log_file"
    fi
}

# 轮换所有日志文件
for log_file in "${LOG_FILES[@]}"; do
    rotate_single_log "$log_file"
done

# 清理超过7天的备份文件
find "$LOG_DIR" -name "*.log.*" -type f -mtime +7 -delete 2>/dev/null

echo "$(date): 🧹 日志管理完成"
