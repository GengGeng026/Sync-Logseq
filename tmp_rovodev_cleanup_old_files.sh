#!/bin/bash
# 安全清理舊版 Logseq 同步文件和配置

echo "🧹 開始清理舊版 Logseq 同步文件..."

# 設置工作目錄
SYNC_DIR="/Users/mac/Documents/Sync-Logseq"
cd "$SYNC_DIR" || exit 1

# 創建備份目錄
BACKUP_DIR="./old_files_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 創建備份目錄: $BACKUP_DIR"

# 1. 備份並移除工作區中的舊腳本
echo ""
echo "1. 處理工作區中的舊腳本文件..."

OLD_SCRIPTS=(
    "logseq_sync.sh"
    "start_logseq_sync.sh" 
    "stop_logseq_sync.sh"
    "switch_to_fast_sync.sh"
    "switch_to_improved_sync.sh"
)

for script in "${OLD_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "   📄 備份並移除: $script"
        cp "$script" "$BACKUP_DIR/"
        rm "$script"
    else
        echo "   ✅ 已不存在: $script"
    fi
done

# 2. 處理舊的日誌文件
echo ""
echo "2. 處理舊的日誌文件..."

OLD_LOGS=(
    "sync_stdout.log"
    "sync_stderr.log" 
    "logseq_unified.log"
    "launchd_stdout.log"
    "launchd_stderr.log"
)

for log in "${OLD_LOGS[@]}"; do
    if [ -f "$log" ]; then
        echo "   📄 備份並移除: $log"
        cp "$log" "$BACKUP_DIR/"
        rm "$log"
    else
        echo "   ✅ 已不存在: $log"
    fi
done

# 3. 清理 ~/.zshrc 中的舊配置
echo ""
echo "3. 清理 ~/.zshrc 中的舊自動啟動配置..."

if grep -q "logseq_autostart.sh" ~/.zshrc; then
    echo "   📝 備份 ~/.zshrc"
    cp ~/.zshrc "$BACKUP_DIR/zshrc_backup"
    
    echo "   🗑️ 移除舊的自動啟動配置"
    # 移除包含 logseq_autostart.sh 的行和相關註釋
    sed -i '' '/# Logseq 自動同步服務/d' ~/.zshrc
    sed -i '' '/logseq_autostart\.sh/d' ~/.zshrc
    sed -i '' '/if ! pgrep -f "logseq_sync\.sh"/d' ~/.zshrc
    sed -i '' '/nohup \/Users\/mac\/.logseq_autostart\.sh/d' ~/.zshrc
    sed -i '' '/fi$/d' ~/.zshrc
    
    echo "   ✅ ~/.zshrc 清理完成"
else
    echo "   ✅ ~/.zshrc 中無舊配置"
fi

# 4. 處理 ~/.logseq_autostart.sh
echo ""
echo "4. 處理 ~/.logseq_autostart.sh..."

if [ -f ~/.logseq_autostart.sh ]; then
    echo "   📄 備份並移除: ~/.logseq_autostart.sh"
    cp ~/.logseq_autostart.sh "$BACKUP_DIR/"
    rm ~/.logseq_autostart.sh
else
    echo "   ✅ ~/.logseq_autostart.sh 已不存在"
fi

# 5. 處理舊的 LaunchAgent plist 備份
echo ""
echo "5. 處理舊的 LaunchAgent 配置..."

OLD_PLIST="~/Library/LaunchAgents/com.user.logseqsync.plist"
if [ -f "$OLD_PLIST" ]; then
    echo "   📄 備份並移除: $OLD_PLIST"
    cp "$OLD_PLIST" "$BACKUP_DIR/"
    rm "$OLD_PLIST"
else
    echo "   ✅ 舊的 plist 文件已不存在"
fi

# 6. 清理舊的日誌備份文件
echo ""
echo "6. 清理舊的日誌備份文件..."

find . -name "*.log.*" -mtime +7 -type f | while read -r old_log; do
    echo "   🗑️ 移除舊日誌備份: $old_log"
    mv "$old_log" "$BACKUP_DIR/"
done

# 7. 顯示清理結果
echo ""
echo "🎉 清理完成！"
echo ""
echo "📊 清理統計："
echo "   📦 備份目錄: $BACKUP_DIR"
echo "   📄 備份文件數量: $(ls -1 "$BACKUP_DIR" 2>/dev/null | wc -l)"
echo ""
echo "📋 當前保留的文件："
ls -la *.sh *.log 2>/dev/null || echo "   (無相關文件)"
echo ""
echo "✅ 當前運行的系統："
echo "   🔧 LaunchAgent: com.logseq.sync"
echo "   📜 主腳本: logseq_sync_optimized.sh"
echo "   🛠️ 工具腳本: log_manager.sh"
echo "   📝 主日誌: sync_optimized.log"
echo ""
echo "💡 提示："
echo "   - 備份文件保存在 $BACKUP_DIR"
echo "   - 如需恢復，可從備份目錄中復制文件"
echo "   - 建議保留備份目錄至少一週"