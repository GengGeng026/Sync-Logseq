#!/bin/bash
# 每日日誌清理腳本

echo "$(date): 🧹 執行每日日誌清理..."

cd "/Users/mac/Documents/Sync-Logseq" || exit 1

# 1. 刪除空的日誌文件
find . -name "*.log" -size 0 -delete 2>/dev/null

# 2. 清理超過7天的輪換日誌
find . -name "sync_stdout.log.*" -mtime +7 -delete 2>/dev/null

# 3. 如果主日誌超過1MB，強制輪換
if [ -f "sync_stdout.log" ]; then
    size=$(stat -f%z "sync_stdout.log" 2>/dev/null || stat -c%s "sync_stdout.log" 2>/dev/null)
    if [ "$size" -gt 1048576 ]; then  # 1MB
        echo "$(date): 📋 主日誌超過1MB，執行強制輪換"
        tail -300 sync_stdout.log > sync_stdout.log.tmp
        mv sync_stdout.log.tmp sync_stdout.log
        echo "$(date): 📋 強制輪換完成，保留最後300行" >> sync_stdout.log
    fi
fi

# 4. 報告清理結果
remaining_logs=$(ls -1 *.log* 2>/dev/null | wc -l)
total_size=$(du -sh *.log* 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "0")

echo "$(date): ✅ 清理完成 - 剩餘 $remaining_logs 個日誌文件，總大小: ${total_size}B"