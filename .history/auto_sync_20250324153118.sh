#!/bin/bash

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

# 監聽 Logseq 目錄內的變化
fswatch -o --exclude ".git" /Users/mac/Documents/Sync-Logseq | while read -r change; do
    echo "=== Sync started at $(date) ===" >> $LOG_FILE

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
