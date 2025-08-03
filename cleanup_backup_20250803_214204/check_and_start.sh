#!/bin/bash
# Logseq 同步服务检查和启动脚本

LOG_FILE="/Users/mac/Documents/Sync-Logseq/startup_check.log"
echo "$(date): 检查 Logseq 同步服务状态..." >> "$LOG_FILE"

# 检查是否已经运行
if pgrep -f "logseq_sync.sh" > /dev/null; then
    echo "$(date): Logseq 同步服务已在运行" >> "$LOG_FILE"
    exit 0
fi

# 启动服务
echo "$(date): 启动 Logseq 同步服务..." >> "$LOG_FILE"
cd "/Users/mac/Documents/Sync-Logseq"
./start_logseq_sync.sh >> "$LOG_FILE" 2>&1

# 验证启动
sleep 3
if pgrep -f "logseq_sync.sh" > /dev/null; then
    echo "$(date): Logseq 同步服务启动成功" >> "$LOG_FILE"
else
    echo "$(date): Logseq 同步服务启动失败" >> "$LOG_FILE"
fi
