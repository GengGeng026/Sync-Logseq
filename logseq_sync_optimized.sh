#!/bin/bash
# 優化版 Logseq 同步腳本 - 徹底解決方案
# 解決 fswatch 自我觸發、push rejected 自動處理、穩定後台運行

# 進程鎖定機制
LOCK_FILE="/Users/mac/Documents/Sync-Logseq/.sync_lock"
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/sync_optimized.log"

# 檢查是否已有實例在運行 (防止 LaunchAgent 重複啟動)
if [ -f "$LOCK_FILE" ]; then
    lock_pid=$(cat "$LOCK_FILE")
    if kill -0 "$lock_pid" 2>/dev/null; then
        echo "$(date): [PID:$$] 已有主進程運行 (PID: $lock_pid)，退出本次啟動" >> "$LOG_FILE"
        exit 0
    else
        # 清理無效的鎖文件
        rm -f "$LOCK_FILE"
    fi
fi

# 創建鎖文件
echo $$ > "$LOCK_FILE"

# 清理函數 (確保在腳本退出時移除鎖文件和子進程)
cleanup() {
    echo "$(date): [PID:$$] 腳本正在退出，清理中..." >> "$LOG_FILE"
    rm -f "$LOCK_FILE"
    # 殺死所有由本腳本啟動的子進程 (fswatch 和定期檢查進程)
    pkill -P $$ 2>/dev/null || true
    echo "$(date): [PID:$$] 清理完成。" >> "$LOG_FILE"
}

# 設置信號處理 (確保腳本被終止時能清理)
trap cleanup EXIT INT TERM

# 設置環境變數
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"
cd "$REPO_DIR" || { echo "$(date): [PID:$$] 錯誤：無法進入 Logseq 同步目錄。請檢查路徑。" >> "$LOG_FILE"; exit 1; }

# 日誌管理函數 (集成到腳本內部)
manage_log_size() {
    local log_file="$1"
    local max_size_kb="${2:-512}" # 默認 512KB
    local keep_lines="${3:-500}"  # 默認保留 500 行
    
    if [ ! -f "$log_file" ]; then
        return 0
    fi
    
    local size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null)
    local size_kb=$((size / 1024))
    
    if [ "$size_kb" -gt "$max_size_kb" ]; then
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        cp "$log_file" "${log_file}.${timestamp}"
        tail -"$keep_lines" "$log_file" > "${log_file}.tmp"
        mv "${log_file}.tmp" "$log_file"
        ls -t "${log_file}".* 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null
        echo "$(date): [PID:$$] 日誌已輪換 $log_file，保留最後 $keep_lines 行" >> "$log_file"
    fi
}
log() {
    echo "$(date): [PID:$$] $1" >> "$LOG_FILE"
}

sync_repo() {
    manage_log_size "$LOG_FILE" 512 500 # 每次同步前管理日誌大小
    log "🚀 開始同步..."
    
    # 清理 Git 鎖定文件
    find .git -name "*.lock" -delete 2>/dev/null
    
    # 確保在 main 分支
    git checkout main >> "$LOG_FILE" 2>&1
    
    # 添加所有變更
    git add -A
    
    # 檢查是否有本地變更需要提交
    if ! git diff --cached --quiet; then
        git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1
        log "📝 本地變更已提交"
    else
        log "ℹ️ 沒有本地變更需要提交"
    fi
    
    # 拉取遠端變更
    log "📥 獲取遠端變更..."
    if git pull origin main --no-edit >> "$LOG_FILE" 2>&1; then
        log "📥 成功拉取遠端變更"
    else
        log "⚠️ 拉取失敗，執行 git reset --hard HEAD"
        git reset --hard HEAD >> "$LOG_FILE" 2>&1 # 失敗時重置到最新本地提交
    fi
    
    # 推送到遠端，增強重試邏輯
    log "📤 推送變更到遠端..."
    local push_success=0
    local push_retry_count=0
    local max_push_retries=3 # 最多重試3次

    while [ "$push_retry_count" -lt "$max_push_retries" ]; do
        push_output=$(git push origin main 2>&1)
        if [ $? -eq 0 ]; then
            log "📤 成功推送到遠端"
            push_success=1
            break # 推送成功，跳出循環
        else
            log "⚠️ 推送失敗: $push_output"
            push_retry_count=$((push_retry_count + 1))
            
            # 如果是 rejected (遠端有新變更)，則先 pull
            if echo "$push_output" | grep -q "Updates were rejected"; then
                log "🔄 檢測到推送被拒絕，執行 git pull..."
                if git pull origin main --no-edit >> "$LOG_FILE" 2>&1; then
                    log "📥 成功拉取遠端變更 (重試推送前)"
                else
                    log "❌ 重試拉取失敗，放棄本次推送重試。"
                    break # 如果拉取失敗，則放棄本次推送重試
                fi
            else
                # 其他推送失敗原因，短暫等待後重試
                log "⚠️ 非拒絕式推送失敗，等待 5 秒後重試..."
            fi
            sleep 5 # 短暫等待後重試
        fi
    done

    if [ "$push_success" -eq 0 ]; then
        log "❌ 最終推送失敗，請手動檢查。"
    fi
    log "✅ 同步完成"
}
# 第三部分：文件監控函數和定期檢查函數
fswatch_monitor() {
    log "👀 開始監控文件變更..."
    # 使用 fswatch 持續監控
    fswatch -r "$REPO_DIR" \
        --exclude="\.git/" \
        --exclude="\.log$" \
        --exclude="\.lock$" \
        --exclude="\.tmp$" \
        --exclude="\.last_sync$" \
        --latency=2 \
        --one-per-batch | while read -r event; do
        
        log "📁 檢測到文件變更: $(echo "$event" | wc -l) 個文件"
        # Debounce: 等待2秒，避免頻繁同步
        sleep 2
        sync_repo # 觸發同步
    done
}

# 定期檢查函數
periodic_check() {
    log "⏰ 啟動定期檢查 (每1分鐘)..."
    while true; do
        sleep 60  # 1分鐘
        log "⏰ 定期檢查觸發... 自動拉取最新版本"
        sync_repo # 觸發同步
        touch "$REPO_DIR/.last_sync" # 定期檢查時更新時間戳
    done
}
# 第四部分：主程序啟動邏輯和腳本激活命令
# 主程序啟動子進程
launch_subprocesses() {
    log "啟動監控和定期檢查子進程..."
    fswatch_monitor & # 文件監控放入後台
    periodic_check & # 定期檢查放入後台
    log "監控和定期檢查子進程已啟動。"
}

# 主程序開始
log "🎯 啟動優化同步服務 (PID: $$)"
sync_repo # 初始同步

launch_subprocesses # 啟動監控和定期檢查子進程

# 主進程保持運行，等待子進程 (確保 LaunchAgent 監控主進程)
wait
