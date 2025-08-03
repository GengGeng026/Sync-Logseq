#!/bin/bash
# Logseq 統一自動同步腳本 - 單腳本解決方案
# 功能：守護進程 + 同步服務 + 自動重啟
# 作者：Rovo Dev
# 版本：1.0

# ==================== 配置區域 ====================
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/logseq_unified.log"
DAEMON_MODE=false
SYNC_INTERVAL=30  # 守護進程檢查間隔（秒）

# 設置環境變數
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"

# ==================== 工具函數 ====================

# 日誌函數
log() {
    echo "$(date): $1" >> "$LOG_FILE"
}

# 檢查是否已有同步進程在運行
is_sync_running() {
    pgrep -f "logseq_unified\.sh sync" > /dev/null
}

# 檢查是否已有守護進程在運行
is_daemon_running() {
    pgrep -f "logseq_unified\.sh daemon" > /dev/null
}

# 清理函數
cleanup() {
    log "🧹 清理鎖定文件和殭屍進程..."
    find "$REPO_DIR/.git" -name "*.lock" -delete 2>/dev/null || true
    pkill -f "fswatch.*Sync-Logseq" 2>/dev/null || true
}

# 日誌輪換
rotate_logs() {
    if [ -f "$LOG_FILE" ]; then
        local size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null)
        if [ "$size" -gt 524288 ]; then  # 512KB
            tail -500 "$LOG_FILE" > "${LOG_FILE}.tmp"
            mv "${LOG_FILE}.tmp" "$LOG_FILE"
            log "📋 日誌已輪換，保留最後500行"
        fi
    fi
}

# ==================== 同步功能 ====================

# Git 同步函數
git_sync() {
    cd "$REPO_DIR" || return 1
    
    # 檢查 Git 狀態
    if ! git status > /dev/null 2>&1; then
        log "❌ Git 倉庫狀態異常"
        return 1
    fi
    
    # 添加所有變更
    if git add . 2>/dev/null; then
        # 檢查是否有變更需要提交
        if ! git diff --cached --quiet; then
            git commit -m "Auto sync: $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null
            log "📝 本地變更已提交"
        fi
    fi
    
    # 拉取遠端變更
    if git fetch origin main 2>/dev/null; then
        # 嘗試合併
        if git merge origin/main 2>/dev/null; then
            log "✅ 成功合併遠端變更"
        else
            log "⚠️ 合併衝突，使用本地版本"
            git merge --abort 2>/dev/null || true
            git reset --hard HEAD 2>/dev/null || true
        fi
    fi
    
    # 推送到遠端
    if git push origin main 2>/dev/null; then
        log "📤 成功推送到遠端"
    else
        log "⚠️ 推送失敗，將在下次重試"
    fi
}

# 文件監控同步模式
sync_mode() {
    log "🚀 啟動同步模式..."
    cd "$REPO_DIR" || exit 1
    
    # 初始同步
    git_sync
    
    # 啟動文件監控
    log "👁️ 開始監控文件變更..."
    fswatch -r "$REPO_DIR" \
        --exclude="\.git/" \
        --exclude="\.log$" \
        --exclude="\.tmp$" \
        --exclude="\.swp$" \
        --latency=2 \
        --one-per-batch | while read -r event; do
        
        log "📁 檢測到文件變更: $event"
        sleep 1  # 避免頻繁觸發
        git_sync
        log "🎉 同步完成"
        echo "------------------------" >> "$LOG_FILE"
    done
}

# ==================== 守護進程功能 ====================

# 守護進程模式
daemon_mode() {
    log "🛡️ 啟動守護進程模式..."
    
    while true; do
        # 檢查同步進程是否在運行
        if ! is_sync_running; then
            log "🔄 檢測到同步服務停止，正在重啟..."
            
            # 清理殭屍進程
            cleanup
            sleep 2
            
            # 重啟同步服務
            nohup "$0" sync > /dev/null 2>&1 &
            sleep 5
            
            if is_sync_running; then
                log "✅ 同步服務已重啟"
            else
                log "❌ 同步服務重啟失敗"
            fi
        fi
        
        # 定期清理和日誌輪換
        rotate_logs
        
        # 等待下次檢查
        sleep "$SYNC_INTERVAL"
    done
}

# ==================== 主程序 ====================

# 顯示幫助信息
show_help() {
    cat << EOF
Logseq 統一自動同步腳本

用法: $0 [選項]

選項:
    daemon    啟動守護進程模式（自動重啟同步服務）
    sync      啟動同步模式（文件監控 + Git 同步）
    start     智能啟動（如果沒有運行則啟動守護進程）
    stop      停止所有相關進程
    status    顯示運行狀態
    restart   重啟服務
    help      顯示此幫助信息

示例:
    $0 start     # 智能啟動服務
    $0 daemon    # 手動啟動守護進程
    $0 sync      # 手動啟動同步服務
    $0 stop      # 停止所有服務
EOF
}

# 智能啟動
smart_start() {
    if is_daemon_running; then
        log "ℹ️ 守護進程已在運行"
        echo "守護進程已在運行"
    else
        log "🚀 啟動智能守護進程..."
        echo "正在啟動 Logseq 自動同步服務..."
        nohup "$0" daemon > /dev/null 2>&1 &
        sleep 2
        
        if is_daemon_running; then
            log "✅ 守護進程啟動成功"
            echo "✅ 服務啟動成功"
        else
            log "❌ 守護進程啟動失敗"
            echo "❌ 服務啟動失敗"
        fi
    fi
}

# 停止所有服務
stop_all() {
    log "🛑 停止所有 Logseq 同步服務..."
    
    # 停止守護進程
    pkill -f "logseq_unified\.sh daemon" 2>/dev/null || true
    
    # 停止同步進程
    pkill -f "logseq_unified\.sh sync" 2>/dev/null || true
    
    # 停止文件監控
    pkill -f "fswatch.*Sync-Logseq" 2>/dev/null || true
    
    sleep 2
    
    if ! is_daemon_running && ! is_sync_running; then
        log "✅ 所有服務已停止"
        echo "✅ 所有服務已停止"
    else
        log "⚠️ 部分服務可能仍在運行"
        echo "⚠️ 部分服務可能仍在運行"
    fi
}

# 顯示狀態
show_status() {
    echo "=== Logseq 同步服務狀態 ==="
    
    if is_daemon_running; then
        echo "🛡️ 守護進程: ✅ 運行中"
        daemon_pid=$(pgrep -f "logseq_unified.sh.*daemon")
        echo "   PID: $daemon_pid"
    else
        echo "🛡️ 守護進程: ❌ 未運行"
    fi
    
    if is_sync_running; then
        echo "🔄 同步服務: ✅ 運行中"
        sync_pid=$(pgrep -f "logseq_unified.sh.*sync")
        echo "   PID: $sync_pid"
    else
        echo "🔄 同步服務: ❌ 未運行"
    fi
    
    if pgrep -f "fswatch.*Sync-Logseq" > /dev/null; then
        echo "👁️ 文件監控: ✅ 運行中"
    else
        echo "👁️ 文件監控: ❌ 未運行"
    fi
    
    echo ""
    echo "📊 最近日誌 (最後10行):"
    if [ -f "$LOG_FILE" ]; then
        tail -10 "$LOG_FILE"
    else
        echo "   (無日誌文件)"
    fi
}

# 重啟服務
restart_service() {
    echo "🔄 重啟 Logseq 同步服務..."
    stop_all
    sleep 3
    smart_start
}

# ==================== 主入口 ====================

# 確保工作目錄存在
mkdir -p "$REPO_DIR"
cd "$REPO_DIR" || exit 1

# 解析命令行參數
case "${1:-start}" in
    "daemon")
        daemon_mode
        ;;
    "sync")
        sync_mode
        ;;
    "start")
        smart_start
        ;;
    "stop")
        stop_all
        ;;
    "status")
        show_status
        ;;
    "restart")
        restart_service
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "未知選項: $1"
        echo "使用 '$0 help' 查看幫助信息"
        exit 1
        ;;
esac