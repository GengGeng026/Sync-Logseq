#!/bin/bash
# 優化日誌管理腳本

echo "🧹 開始優化日誌文件..."

# 1. 清理舊的輪換日誌（保留最新2個）
echo "清理舊的輪換日誌..."
ls -t sync_stdout.log.* 2>/dev/null | tail -n +3 | xargs rm -f
echo "已清理舊的輪換日誌，保留最新2個"

# 2. 合併並清理重複的日誌文件
echo "合併重複的日誌文件..."
if [ -f "sync.log" ] && [ -f "sync_stdout.log" ]; then
    # 檢查是否有重複內容
    if ! diff -q sync.log sync_stdout.log > /dev/null 2>&1; then
        echo "合併 sync.log 到 sync_stdout.log"
        cat sync.log >> sync_stdout.log
    fi
    rm -f sync.log
fi

# 3. 清理空的或無用的日誌
if [ -f "sync_stderr.log" ] && [ ! -s "sync_stderr.log" ]; then
    rm -f sync_stderr.log
    echo "已刪除空的 sync_stderr.log"
fi

if [ -f "sync.error.log" ]; then
    # 如果錯誤日誌內容已經在主日誌中，則刪除
    rm -f sync.error.log
    echo "已刪除 sync.error.log"
fi

# 4. 壓縮當前主日誌（如果太大）
if [ -f "sync_stdout.log" ]; then
    size=$(stat -f%z "sync_stdout.log" 2>/dev/null || stat -c%s "sync_stdout.log" 2>/dev/null)
    if [ "$size" -gt 524288 ]; then  # 大於 512KB
        echo "主日誌文件較大 ($(($size/1024))KB)，進行壓縮..."
        # 保留最後1000行
        tail -1000 sync_stdout.log > sync_stdout.log.tmp
        mv sync_stdout.log.tmp sync_stdout.log
        echo "已壓縮主日誌，保留最後1000行"
    fi
fi

echo "📊 優化後的日誌文件："
ls -lah *.log* 2>/dev/null | head -10
echo ""
echo "💾 總磁盤使用："
du -sh *.log* 2>/dev/null | awk '{sum+=$1} END {print sum "B 總計"}'