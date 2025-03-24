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

# 確保腳本退出時刪除鎖文件
trap 'rm -f "$LOCK_FILE"; exit' INT TERM EXIT

# 進入 Logseq 目錄
cd /Users/mac/Documents/Sync-Logseq

# 設置日誌文件
LOG_FILE="/Users/mac/Documents/Sync-Logseq/sync_log.txt"

# 初始檢查時間記錄
echo "=== Initial check at $(date) ===" >> $LOG_FILE

# 更新遠程分支信息
git fetch origin >> $LOG_FILE 2>&1

# 檢查分支狀態
LOCAL=$(git rev-parse main)
REMOTE=$(git rev-parse origin/main)
BASE=$(git merge-base main origin/main)

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

# 初始檢查函數（提取現有代碼為函數，以便重用）
check_and_sync() {
    echo "=== Periodic check at $(date) ===" >> $LOG_FILE
    
    # 更新遠程分支信息
    git fetch origin >> $LOG_FILE 2>&1
    
    # 檢查分支狀態
    LOCAL=$(git rev-parse main)
    REMOTE=$(git rev-parse origin/main)
    BASE=$(git merge-base main origin/main)
    
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
}

# 執行初始檢查
check_and_sync

# 設置上次同步和檢查時間
LAST_SYNC_TIME=$(date +%s)
LAST_CHECK_TIME=$(date +%s)

# 監聽 Logseq 目錄內的變化
fswatch -o -l 5 --event=Created --event=Updated --event=Removed --exclude "\.git" --exclude "sync_log\.txt" --exclude "\.#" --exclude "~$" /Users/mac/Documents/Sync-Logseq | while read -r change; do
    # 獲取當前時間
    CURRENT_TIME=$(date +%s)
    
    # 每15分鐘（900秒）檢查一次遠程更新，即使沒有本地變更
    if [ $((CURRENT_TIME - LAST_CHECK_TIME)) -gt 900 ]; then
        check_and_sync
        LAST_CHECK_TIME=$CURRENT_TIME
        LAST_SYNC_TIME=$CURRENT_TIME  # 更新同步時間，避免短時間內重複同步
        continue
    fi
    
    # 如果距離上次同步不到 30 秒，跳過此次同步
    if [ $((CURRENT_TIME - LAST_SYNC_TIME)) -lt 30 ]; then
        echo "上次同步時間過近，跳過此次同步操作" >> $LOG_FILE
        continue
    fi
    
    LAST_SYNC_TIME=$CURRENT_TIME
    echo "=== Sync started at $(date) ===" >> $LOG_FILE
    echo "檢測到變更：$change" >> $LOG_FILE

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
    fi
    
    # 重新獲取分支狀態（可能因提交而改變）
    LOCAL=$(git rev-parse main)
        
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
done
