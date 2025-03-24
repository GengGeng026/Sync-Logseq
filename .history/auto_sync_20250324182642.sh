#!/bin/bash

# 記錄開始時間並設置日誌文件
START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
LOG_FILE="/Users/mac/Documents/Sync-Logseq/sync_log.txt"

# 確保只有一個腳本實例運行
LOCKFILE="/tmp/auto_sync.lock"
if [ -e "$LOCKFILE" ] && kill -0 $(cat "$LOCKFILE") 2>/dev/null; then
    echo "[$(date)] 已有另一個實例在運行" >> $LOG_FILE
    exit 1
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

# 清空日誌文件並記錄開始信息
echo "[$(date)] === 自動同步開始：腳本版本 v2.1 ===" > $LOG_FILE
echo "[$(date)] 用戶：$(whoami)" >> $LOG_FILE

# 進入工作目錄
cd /Users/mac/Documents/Sync-Logseq
echo "[$(date)] 工作目錄：$(pwd)" >> $LOG_FILE

# 檢查並同步
while true; do
    echo "[$(date)] --- 開始新一輪同步 ---" >> $LOG_FILE
    
    # 1. 保存本地修改
    echo "[$(date)] 檢查本地修改" >> $LOG_FILE
    git add -A >> $LOG_FILE 2>&1
    if ! git diff --staged --quiet; then
        echo "[$(date)] 發現本地修改，提交中" >> $LOG_FILE
        git commit -m "自動保存: $(date)" >> $LOG_FILE 2>&1
    fi
    
    # 2. 獲取遠程更新（強制執行）
    echo "[$(date)] 獲取遠程更新" >> $LOG_FILE
    git fetch --all >> $LOG_FILE 2>&1
    
    # 3. 檢查分支狀態
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main)
    BASE=$(git merge-base HEAD origin/main)
    echo "[$(date)] 本地提交：$LOCAL" >> $LOG_FILE
    echo "[$(date)] 遠程提交：$REMOTE" >> $LOG_FILE
    echo "[$(date)] 共同祖先：$BASE" >> $LOG_FILE
    
    # 檢查分支是否分歧
    if [ "$LOCAL" != "$REMOTE" ] && [ "$LOCAL" != "$BASE" ] && [ "$REMOTE" != "$BASE" ]; then
        echo "[$(date)] 檢測到分支分歧，嘗試解決" >> $LOG_FILE
        
        # 使用合併策略解決分歧
        echo "[$(date)] 執行合併" >> $LOG_FILE
        git merge origin/main --no-edit >> $LOG_FILE 2>&1
        MERGE_STATUS=$?
        
        if [ $MERGE_STATUS -eq 0 ]; then
            echo "[$(date)] 合併成功，推送結果" >> $LOG_FILE
            git push origin main >> $LOG_FILE 2>&1
        else
            echo "[$(date)] 合併衝突，嘗試儲藏本地更改並重置" >> $LOG_FILE
            git merge --abort >> $LOG_FILE 2>&1
            
            # 儲藏本地變更
            git stash >> $LOG_FILE 2>&1
            
            # 重置到遠程版本
            git reset --hard origin/main >> $LOG_FILE 2>&1
            
            # 嘗試應用儲藏的變更
            git stash pop >> $LOG_FILE 2>&1
            
            # 如果有變更，提交並推送
            if ! git diff --quiet; then
                git add -A >> $LOG_FILE 2>&1
                git commit -m "自動解決衝突: $(date)" >> $LOG_FILE 2>&1
                git push origin main >> $LOG_FILE 2>&1
            fi
        fi
    else
        # 4. 常規同步邏輯 - 檢查是否落後於遠程
        BEHIND=$(git rev-list --count HEAD..origin/main)
        if [ "$BEHIND" -gt 0 ]; then
            echo "[$(date)] 本地落後於遠程 $BEHIND 個提交，執行拉取" >> $LOG_FILE
            git pull --no-edit origin main >> $LOG_FILE 2>&1
            echo "[$(date)] 拉取完成" >> $LOG_FILE
        else
            echo "[$(date)] 本地已是最新" >> $LOG_FILE
        fi
        
        # 5. 檢查是否領先於遠程，需要推送
        AHEAD=$(git rev-list --count origin/main..HEAD)
        if [ "$AHEAD" -gt 0 ]; then
            echo "[$(date)] 本地領先於遠程 $AHEAD 個提交，執行推送" >> $LOG_FILE
            git push origin main >> $LOG_FILE 2>&1
            echo "[$(date)] 推送完成" >> $LOG_FILE
        fi
    fi
    
    echo "[$(date)] --- 本次同步完成 ---" >> $LOG_FILE
    
    # 等待下一次同步
    echo "[$(date)] 休眠 20 秒" >> $LOG_FILE
    sleep 30
done