#!/bin/bash
# 改進版 Logseq 同步腳本 - 智能衝突處理
# 文件名: logseq_sync_improved.sh
# 保存位置: /Users/mac/Documents/Sync-Logseq/logseq_sync_improved.sh

# Add diagnostic message at the very beginning
echo "$(date): logseq_sync_improved.sh 腳本啟動..." >> "/Users/mac/Documents/Sync-Logseq/sync_stdout.log"

# Set the PATH to ensure commands like git and fswatch are found
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"

# 設置工作目錄和日誌文件
REPO_DIR="/Users/mac/Documents/Sync-Logseq"
LOG_FILE="$REPO_DIR/sync_stdout.log"
cd "$REPO_DIR" || exit

# 清理鎖定文件
cleanup() {
  find .git -name "*.lock" -delete 2>/dev/null
}

# 優化的日誌管理
rotate_logs() {
  # 只管理主日誌文件
  if [ -f "$LOG_FILE" ]; then
    local size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null)
    # 當日誌超過 512KB 時進行輪換
    if [ "$size" -gt 524288 ]; then
      # 保留最後 500 行，刪除舊內容
      tail -500 "$LOG_FILE" > "${LOG_FILE}.tmp"
      mv "${LOG_FILE}.tmp" "$LOG_FILE"
      echo "$(date): 📋 日誌已輪換，保留最後500行" >> "$LOG_FILE"
      
      # 清理舊的備份文件（只保留最新1個）
      ls -t "${LOG_FILE}."* 2>/dev/null | tail -n +2 | xargs rm -f 2>/dev/null
    fi
  fi
}

# 智能衝突解決函數
resolve_conflicts_intelligently() {
    local conflict_files=$(git diff --name-only --diff-filter=U)
    
    if [ -z "$conflict_files" ]; then
        return 0  # 沒有衝突
    fi
    
    echo "$(date): 🔧 檢測到衝突文件: $conflict_files" >> "$LOG_FILE"
    
    # 對每個衝突文件進行智能處理
    for file in $conflict_files; do
        echo "$(date): 📝 處理衝突文件: $file" >> "$LOG_FILE"
        
        if [[ "$file" == *.md ]]; then
            # Markdown 文件 - 嘗試智能合併
            resolve_markdown_conflict "$file"
        else
            # 其他文件 - 使用策略性解決
            resolve_generic_conflict "$file"
        fi
    done
    
    return 0
}

# Markdown 文件衝突解決
resolve_markdown_conflict() {
    local file="$1"
    local backup_file="${file}.conflict_backup_$(date +%Y%m%d_%H%M%S)"
    
    # 備份衝突文件
    cp "$file" "$backup_file"
    echo "$(date): 💾 已備份衝突文件到 $backup_file" >> "$LOG_FILE"
    
    # 檢查衝突類型
    if grep -q "<<<<<<< HEAD" "$file"; then
        # 標準 Git 衝突標記
        handle_git_conflict_markers "$file" "$backup_file"
    else
        # 其他類型衝突，嘗試合併兩個版本
        merge_both_versions "$file" "$backup_file"
    fi
}

# 處理 Git 衝突標記
handle_git_conflict_markers() {
    local file="$1"
    local backup_file="$2"
    
    # 創建臨時文件來分析衝突
    local temp_analysis="/tmp/conflict_analysis_$$"
    
    # 分析衝突內容
    local conflict_blocks=$(grep -c "<<<<<<< HEAD" "$file")
    echo "$(date): 🔍 發現 $conflict_blocks 個衝突區塊在 $file" >> "$LOG_FILE"
    
    # 策略1: 如果衝突很少且是簡單的添加/刪除，嘗試智能合併
    if [ "$conflict_blocks" -le 3 ]; then
        smart_merge_conflicts "$file"
    else
        # 策略2: 衝突太多，使用保守策略
        conservative_conflict_resolution "$file"
    fi
}

# 智能合併衝突
smart_merge_conflicts() {
    local file="$1"
    local temp_file="/tmp/smart_merge_$$"
    
    echo "$(date): 🧠 嘗試智能合併 $file" >> "$LOG_FILE"
    
    # 使用 Python 腳本進行智能合併（如果可用）
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import sys
import re
from datetime import datetime

def smart_merge_logseq_conflicts(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 找到所有衝突區塊
    conflicts = re.findall(r'<<<<<<< HEAD\n(.*?)\n=======\n(.*?)\n>>>>>>> .*?\n', content, re.DOTALL)
    
    merged_content = content
    
    for local_part, remote_part in conflicts:
        local_lines = set(line.strip() for line in local_part.split('\n') if line.strip())
        remote_lines = set(line.strip() for line in remote_part.split('\n') if line.strip())
        
        # 合併策略：保留所有唯一內容
        all_lines = local_lines.union(remote_lines)
        
        # 如果是 Logseq 的日誌條目，按時間排序
        if any('- ' in line for line in all_lines):
            # 保持原有順序，添加新內容
            merged_lines = local_part.split('\n') + [line for line in remote_part.split('\n') if line.strip() not in local_lines]
        else:
            # 普通文本，簡單合併
            merged_lines = list(all_lines)
        
        merged_block = '\n'.join(merged_lines)
        
        # 替換衝突區塊
        conflict_pattern = r'<<<<<<< HEAD\n' + re.escape(local_part) + r'\n=======\n' + re.escape(remote_part) + r'\n>>>>>>> .*?\n'
        merged_content = re.sub(conflict_pattern, merged_block + '\n', merged_content, flags=re.DOTALL)
    
    # 寫回文件
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(merged_content)
    
    return len(conflicts)

try:
    conflicts_resolved = smart_merge_logseq_conflicts('$file')
    print(f'智能合併完成，解決了 {conflicts_resolved} 個衝突')
except Exception as e:
    print(f'智能合併失敗: {e}')
    sys.exit(1)
" >> "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            echo "$(date): ✅ $file - Python 智能合併成功" >> "$LOG_FILE"
        else
            echo "$(date): ⚠️ Python 智能合併失敗，使用備用方案" >> "$LOG_FILE"
            conservative_conflict_resolution "$file"
        fi
    else
        # 沒有 Python，使用簡單的 bash 合併
        bash_simple_merge "$file"
    fi
}

# Bash 簡單合併
bash_simple_merge() {
    local file="$1"
    
    # 簡單策略：保留本地版本，但在文件末尾添加遠端的新內容
    local temp_local="/tmp/local_content_$$"
    local temp_remote="/tmp/remote_content_$$"
    local temp_merged="/tmp/merged_content_$$"
    
    # 提取本地和遠端內容
    sed -n '/<<<<<<< HEAD/,/=======/p' "$file" | sed '1d;$d' > "$temp_local"
    sed -n '/=======/,/>>>>>>> /p' "$file" | sed '1d;$d' > "$temp_remote"
    
    # 創建合併版本
    {
        # 保留非衝突部分
        sed '/<<<<<<< HEAD/,/>>>>>>> /d' "$file"
        echo ""
        echo "# === 本地內容 ==="
        cat "$temp_local"
        echo ""
        echo "# === 遠端內容 ==="
        cat "$temp_remote"
        echo ""
        echo "# === 合併完成於 $(date) ==="
    } > "$temp_merged"
    
    mv "$temp_merged" "$file"
    rm -f "$temp_local" "$temp_remote"
    
    echo "$(date): ✅ $file - Bash 簡單合併完成" >> "$LOG_FILE"
}

# 保守的衝突解決
conservative_conflict_resolution() {
    local file="$1"
    
    echo "$(date): 🛡️ 使用保守策略解決 $file (衝突過多)" >> "$LOG_FILE"
    
    # 嘗試合併兩個版本而不是丟棄
    merge_both_versions "$file" ""
    
    echo "$(date): ✅ $file - 嘗試合併兩個版本 (保守策略)" >> "$LOG_FILE"
}

# 合併兩個版本的內容
merge_both_versions() {
    local file="$1"
    local backup_file="$2"
    
    echo "$(date): 🔄 嘗試合併本地和遠程版本: $file" >> "$LOG_FILE"
    
    # 獲取本地和遠程版本
    git show HEAD:"$file" > "${file}.local" 2>/dev/null || cp "$file" "${file}.local"
    git show origin/main:"$file" > "${file}.remote" 2>/dev/null || git checkout --theirs "$file" 2>/dev/null
    
    # 創建合併版本
    {
        echo "# 自動合併版本 - $(date)"
        echo ""
        echo "## 本地版本內容："
        cat "${file}.local" 2>/dev/null || echo "無法讀取本地版本"
        echo ""
        echo "## 遠程版本內容："
        cat "${file}.remote" 2>/dev/null || echo "無法讀取遠程版本"
        echo ""
        echo "## 合併完成於 $(date)"
    } > "$file"
    
    # 清理臨時文件
    rm -f "${file}.local" "${file}.remote"
    
    echo "$(date): ✅ $file - 已合併本地和遠程內容" >> "$LOG_FILE"
}

# 通用文件衝突解決
resolve_generic_conflict() {
    local file="$1"
    
    # 對於非 Markdown 文件，保守地選擇本地版本
    git checkout --ours "$file"
    echo "$(date): ✅ $file - 保留本地版本 (非 Markdown 文件)" >> "$LOG_FILE"
}

# 改進的同步函數
sync_repo() {
    echo "$(date): 🚀 開始智能同步..." >> "$LOG_FILE"
    
    # 清理任何潛在的鎖定文件
    cleanup
    
    # 確保在 main 分支
    git checkout main >> "$LOG_FILE" 2>&1
    
    # 暫存所有本地變更
    git add -A
    
    # 檢查是否有本地變更需要提交
    if ! git diff --cached --quiet; then
        echo "$(date): 📝 提交本地變更..." >> "$LOG_FILE"
        git commit -m "Auto-sync: Local changes ($(date))" >> "$LOG_FILE" 2>&1
    else
        echo "$(date): ℹ️ 沒有本地變更需要提交" >> "$LOG_FILE"
    fi
    
    # 獲取遠端變更
    echo "$(date): 📥 獲取遠端變更..." >> "$LOG_FILE"
    git fetch origin main >> "$LOG_FILE" 2>&1
    
    # 嘗試合併
    echo "$(date): 🔄 嘗試合併遠端變更..." >> "$LOG_FILE"
    if git merge origin/main >> "$LOG_FILE" 2>&1; then
        echo "$(date): ✅ 自動合併成功" >> "$LOG_FILE"
    else
        echo "$(date): ⚠️ 檢測到合併衝突，啟動智能解決..." >> "$LOG_FILE"
        
        # 智能解決衝突
        if resolve_conflicts_intelligently; then
            # 完成合併
            git add -A
            if git commit -m "Auto-resolve: Intelligent conflict resolution ($(date))" >> "$LOG_FILE" 2>&1; then
                echo "$(date): ✅ 衝突已智能解決並提交" >> "$LOG_FILE"
            else
                echo "$(date): ❌ 衝突解決後提交失敗" >> "$LOG_FILE"
                return 1
            fi
        else
            echo "$(date): ❌ 智能衝突解決失敗" >> "$LOG_FILE"
            return 1
        fi
    fi
    
    # 推送到遠端
    echo "$(date): 📤 推送變更到遠端..." >> "$LOG_FILE"
    if git push origin main >> "$LOG_FILE" 2>&1; then
        echo "$(date): ✅ 推送成功" >> "$LOG_FILE"
    else
        echo "$(date): ⚠️ 推送失敗，嘗試 force-with-lease..." >> "$LOG_FILE"
        if git push origin main --force-with-lease >> "$LOG_FILE" 2>&1; then
            echo "$(date): ✅ Force push 成功" >> "$LOG_FILE"
        else
            echo "$(date): ❌ 推送完全失敗" >> "$LOG_FILE"
            return 1
        fi
    fi
    
    echo "$(date): 🎉 智能同步完成" >> "$LOG_FILE"
    echo "------------------------" >> "$LOG_FILE"
    return 0
}

# 定期檢查遠端更新
check_remote_updates() {
  echo "$(date): 🔍 定期檢查遠端更新中..." >> "$LOG_FILE"
  sync_repo
}

# 輪換日誌
rotate_logs

# 進行初始同步
sync_repo

# 在後台啟動定期檢查遠端更新的子進程
(
  while true; do
    check_remote_updates
    sleep 30 # 每 30 秒檢查一次
  done
) >> "$LOG_FILE" 2>&1 &

# 監視文件變更的主進程
echo "$(date): 👀 開始監視文件變更..." >> "$LOG_FILE"
echo "$(date): 🔧 準備啟動 fswatch..." >> "$LOG_FILE"
fswatch -o --exclude ".git" "$REPO_DIR" | while read -r change; do
  # 記錄檢測到變更的時間
  change_time=$(date +%s)
  # 等待 5 秒，作為 debounce
  sleep 5
  echo "$(date): 📁 檢測到文件變更，開始同步..." >> "$LOG_FILE"
  rotate_logs
  sync_repo
  touch "$REPO_DIR/.last_sync"
done >> "$LOG_FILE" 2>&1