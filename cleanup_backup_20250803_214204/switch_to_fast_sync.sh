#!/bin/bash
# 切換到快速同步模式（每10秒檢查一次）

echo "切換到快速同步模式..."

./stop_logseq_sync.sh

# 備份當前版本
cp logseq_sync.sh logseq_sync_30s.sh

# 修改為10秒檢查
sed 's/sleep 30 # 每 30 秒檢查一次/sleep 10 # 每 10 秒檢查一次/g' logseq_sync.sh > logseq_sync_fast.sh
cp logseq_sync_fast.sh logseq_sync.sh

./start_logseq_sync.sh

echo "✅ 已切換到快速模式：每10秒檢查遠程更新"
echo "如要恢復30秒模式：cp logseq_sync_30s.sh logseq_sync.sh && ./start_logseq_sync.sh"