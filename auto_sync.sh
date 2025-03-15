#!/bin/bash

# 进入 Logseq Git 仓库目录
cd /Users/mac/Documents/Sync-Logseq

# 监听目录中的文件变化并拉取更新
fswatch -o /Users/mac/Documents/Sync-Logseq | while read f
do
  # 检查是否有变化并拉取更新
  git pull origin main
done

