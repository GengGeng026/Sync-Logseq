#!/bin/bash

# 設置詳細的 PATH 環境變量
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH"

# 設置 HOME 變量（確保 Git 可以找到配置文件）
export HOME="/Users/mac"

# 確保 Git 使用正確的憑據
export GIT_ASKPASS="/bin/echo"  

# 記錄啟動信息
echo "Launcher started at $(date)" > /Users/mac/Documents/Sync-Logseq/launcher.log

# 進入工作目錄
cd /Users/mac/Documents/Sync-Logseq

# 執行主腳本
/bin/bash /Users/mac/Documents/Sync-Logseq/auto_sync.sh >> /Users/mac/Documents/Sync-Logseq/launcher.log 2>&1
