#!/bin/bash

# 1. 備份當前腳本
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
SCRIPT_FILE="$REPO_DIR/logseq_sync_optimized.sh"
cp "$SCRIPT_FILE" "${SCRIPT_FILE}.backup_final_fix_$(date +%Y%m%d_%H%M%S)"

# 2. 創建新的優化版腳本內容 (第一部分)
cat > "$SCRIPT_FILE" << 'EOF'
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
