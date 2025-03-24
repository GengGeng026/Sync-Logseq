#!/bin/bash

# 檢查是否已有實例在運行
SCRIPT_NAME=$(basename "$0")
SCRIPT_PID=$$
RUNNING_PIDS=$(pgrep -f "$SCRIPT_NAME" | grep -v "$SCRIPT_PID")

if [ -n "$RUNNING_PIDS" ]; then
    echo "另一個實例已經在運行，PID: $RUNNING_PIDS。退出..." >> /Users/mac/Documents/Sync-Logseq/sync_log.txt
    exit 1
fi

# 設置鎖文件
LOCK_FILE="/tmp/auto_sync.lock"
if [ -f "$LOCK_FILE" ]; then
    # 檢查鎖文件中的PID是否仍在運行
    OLD_PID=$(cat "$LOCK_FILE")
    if ps -p "$OLD_PID" > /dev/null; then
        echo "另一個實例正在運行 (PID: $OLD_PID)。退出..." >> /Users/mac/Documents/Sync-Logseq/sync_log.txt
        exit 1
    else
        echo "發現過期的鎖文件，將其刪除" >> /Users/mac/Documents/Sync-Logseq/sync_log.txt
        rm -f "$LOCK_FILE"
    fi
fi

# 創建新的鎖文件
echo $$ > "$LOCK_FILE"

# 確保腳本退出時刪除鎖文件和終止後台進程
cleanup() {
    echo "清理並退出..." >> /Users/mac/Documents/Sync-Logseq/sync_log.txt
    rm -f "$LOCK_FILE"
    [[ -n $TIMER_PID ]] && kill $TIMER_PID 2>/dev/null
    exit
}
trap cleanup INT TERM EXIT

# 進入 Logseq 目錄
cd /Users/mac/Documents/Sync-Logseq

# 設置日誌文件
LOG_FILE="/Users/mac/Documents/Sync-Logseq/sync_log.txt"

# 同步函數
check_and_sync() {
    echo "=== Sync check at $(date) ===" >> $LOG_FILE
    
    # 更新遠程分支信息
    git fetch origin >> $LOG_FILE 2>&1
    
    # 檢查分支狀態
    LOCAL=$(git rev-parse main)
    REMOTE=$(git rev-parse origin/main)
    BASE=$(git merge-base main origin/main)
    
    # 如果有本地變更，先提交
    git add -A
    if ! git diff --cached --quiet; then
        echo "發現本地變更，正在提交..." >> $LOG_FILE
        git commit -m "Auto-sync: $(date)" >> $LOG_FILE 2>&1
        LOCAL=$(git rev-parse main)
    fi
    
    # 處理分支狀態
    if [ "$LOCAL" = "$REMOTE" ]; then
        echo "本地和遠程分支同步，無需處理" >> $LOG_FILE
    elif [ "$LOCAL" = "$BASE" ]; then
        echo "本地分支落後於遠程，正在拉取..." >> $LOG_FILE
        git pull origin main >> $LOG_FILE 2>&1
    elif [ "$REMOTE" = "$BASE" ]; then
        echo "本地分支領先遠程，正在推送..." >> $LOG_FILE
        git push origin main >> $LOG_FILE 2>&1
    else
        echo "本地和遠程分支已分歧，嘗試解決..." >> $LOG_FILE
        echo "分歧情況：本地$(git rev-list --count origin/main..main)個提交，遠程$(git rev-list --count main..origin/main)個提交" >> $LOG_FILE
        
        # 先嘗試 rebase
        if git pull --rebase origin main >> $LOG_FILE 2>&1; then
            echo "Rebase 成功，正在推送..." >> $LOG_FILE
            git push origin main >> $LOG_FILE 2>&1
        else
            # 如果 rebase 失敗，嘗試強制合併策略
            echo "Rebase 失敗，嘗試合併..." >> $LOG_FILE
            git rebase --abort >> $LOG_FILE 2>&1  # 中止失敗的 rebase
            
            if git pull --no-edit --strategy recursive --strategy-option theirs origin main >> $LOG_FILE 2>&1; then
                echo "合併成功，正在推送..." >> $LOG_FILE
                git push origin main >> $LOG_FILE 2>&1
            else
                echo "自動合併失敗，需要手動解決！" >> $LOG_FILE
            fi
        fi
    fi
    
    echo "=== Sync completed at $(date) ===" >> $LOG_FILE
}

# 初始檢查
check_and_sync

# 後台定時檢查任務 - 每30秒檢查一次
(
    while true; do
        sleep 30
        check_and_sync
    done
) &
TIMER_PID=$!
echo "後台定時檢查任務啟動，PID: $TIMER_PID" >> $LOG_FILE

# 同時使用 fswatch 監聽文件變更
echo "啟動 fswatch 監聽..." >> $LOG_FILE
fswatch -o -l 2 --event=Created --event=Updated --event=Removed --exclude "\.git" --exclude "sync_log\.txt" --exclude "\.#" --exclude "~$" /Users/mac/Documents/Sync-Logseq | while read -r change; do
    echo "=== 檢測到變更: $change ===" >> $LOG_FILE
    check_and_sync
done
