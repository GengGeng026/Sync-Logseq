#!/bin/bash
# 切換到改進版同步腳本

echo "正在切換到改進版 Logseq 同步腳本..."

# 停止當前的同步服務
./stop_logseq_sync.sh

# 備份原始腳本
if [ ! -f "logseq_sync.sh.backup" ]; then
    cp logseq_sync.sh logseq_sync.sh.backup
    echo "已備份原始腳本到 logseq_sync.sh.backup"
fi

# 替換腳本
cp logseq_sync_improved.sh logseq_sync.sh
echo "已替換為改進版腳本"

# 重新啟動服務
./start_logseq_sync.sh

echo "切換完成！新的智能衝突處理功能已啟用"
echo ""
echo "新功能包括："
echo "✅ 智能 Markdown 衝突合併"
echo "✅ 自動備份衝突文件"
echo "✅ Python 增強的合併算法"
echo "✅ 保守的備用策略"
echo "✅ 詳細的衝突處理日誌"