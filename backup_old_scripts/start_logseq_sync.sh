#!/bin/bash
# 啟動 Logseq 同步服務的腳本 - 优化日志版本

# 檢查是否已經在運行
if pgrep -f "logseq_sync.sh" > /dev/null; then
    # 静默退出，不记录重复启动日志
    exit 0
fi

# 設置工作目錄
cd "/Users/mac/Documents/Sync-Logseq" || exit 1

# 运行日志管理器
./smart_log_manager.sh > /dev/null 2>&1

# 啟動同步服務 (减少启动日志)
echo "$(date): 🚀 启动同步服务" >> sync_stdout.log
nohup ./logseq_sync.sh > /dev/null 2>&1 &

# 等待一下確保啟動成功
sleep 2

# 檢查是否成功啟動 (简化日志)
if pgrep -f "logseq_sync.sh" > /dev/null; then
    echo "$(date): ✅ 同步服务已启动" >> sync_stdout.log
else
    echo "$(date): ❌ 同步服务启动失败" >> sync_stdout.log
    exit 1
fi
