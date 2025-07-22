#!/bin/bash
# 測試智能衝突解決功能

echo "🧪 測試智能衝突解決功能..."

# 創建測試衝突文件
cat > test_conflict.md << 'EOF'
# 測試頁面

## 日誌條目
<<<<<<< HEAD
- [[2025-07-17]] 本地添加的內容
- 這是本地的修改
- 本地特有的筆記
=======
- [[2025-07-17]] 遠端添加的內容  
- 這是遠端的修改
- 遠端特有的筆記
>>>>>>> origin/main

## 其他內容
這部分沒有衝突
EOF

echo "📝 創建了測試衝突文件 test_conflict.md"

# 測試智能合併函數
source logseq_sync_improved.sh

echo "🔧 測試智能衝突解決..."
resolve_markdown_conflict "test_conflict.md"

echo "📄 處理後的文件內容："
echo "================================"
cat test_conflict.md
echo "================================"

# 檢查備份文件
backup_files=$(ls test_conflict.md.conflict_backup_* 2>/dev/null)
if [ -n "$backup_files" ]; then
    echo "💾 備份文件已創建: $backup_files"
else
    echo "⚠️ 未找到備份文件"
fi

# 清理測試文件
read -p "是否清理測試文件？(y/N): " cleanup_choice
if [[ "$cleanup_choice" =~ ^[Yy]$ ]]; then
    rm -f test_conflict.md test_conflict.md.conflict_backup_*
    echo "🗑️ 測試文件已清理"
fi