#!/bin/bash
# 改進版 Logseq 同步腳本 - 智能衝突處理

# 智能衝突解決函數
resolve_conflicts_intelligently() {
    local conflict_files=$(git diff --name-only --diff-filter=U)
    
    if [ -z "$conflict_files" ]; then
        return 0  # 沒有衝突
    fi
    
    echo "$(date): 檢測到衝突文件: $conflict_files" >> "$LOG_FILE"
    
    # 對每個衝突文件進行智能處理
    for file in $conflict_files; do
        if [[ "$file" == *.md ]]; then
            # Markdown 文件 - 嘗試智能合併
            resolve_markdown_conflict "$file"
        else
            # 其他文件 - 使用策略性解決
            resolve_generic_conflict "$file"
        fi
    done
}

# Markdown 文件衝突解決
resolve_markdown_conflict() {
    local file="$1"
    local backup_file="${file}.conflict_backup_$(date +%Y%m%d_%H%M%S)"
    
    # 備份衝突文件
    cp "$file" "$backup_file"
    echo "$(date): 已備份衝突文件到 $backup_file" >> "$LOG_FILE"
    
    # 檢查衝突類型
    if grep -q "<<<<<<< HEAD" "$file"; then
        # 標準 Git 衝突標記
        handle_git_conflict_markers "$file" "$backup_file"
    else
        # 其他類型衝突，保留本地版本
        git checkout --ours "$file"
        echo "$(date): $file - 保留本地版本" >> "$LOG_FILE"
    fi
}

# 處理 Git 衝突標記
handle_git_conflict_markers() {
    local file="$1"
    local backup_file="$2"
    
    # 提取衝突的兩個版本
    local temp_local="/tmp/local_version_$$"
    local temp_remote="/tmp/remote_version_$$"
    
    # 提取本地版本 (HEAD)
    sed -n '/<<<<<<< HEAD/,/=======/p' "$file" | sed '1d;$d' > "$temp_local"
    
    # 提取遠端版本
    sed -n '/=======/,/>>>>>>> /p' "$file" | sed '1d;$d' > "$temp_remote"
    
    # 智能選擇策略
    local local_size=$(wc -c < "$temp_local")
    local remote_size=$(wc -c < "$temp_remote")
    local local_lines=$(wc -l < "$temp_local")
    local remote_lines=$(wc -l < "$temp_remote")
    
    echo "$(date): $file 衝突分析 - 本地: ${local_lines}行/${local_size}字節, 遠端: ${remote_lines}行/${remote_size}字節" >> "$LOG_FILE"
    
    # 策略1: 如果一邊是空的，選擇有內容的
    if [ "$local_size" -eq 0 ] && [ "$remote_size" -gt 0 ]; then
        use_remote_version "$file" "$temp_remote"
    elif [ "$remote_size" -eq 0 ] && [ "$local_size" -gt 0 ]; then
        use_local_version "$file" "$temp_local"
    # 策略2: 如果內容相似度高，嘗試合併
    elif content_similarity_high "$temp_local" "$temp_remote"; then
        merge_similar_content "$file" "$temp_local" "$temp_remote"
    # 策略3: 根據時間戳選擇較新的
    else
        choose_by_timestamp "$file" "$temp_local" "$temp_remote"
    fi
    
    # 清理臨時文件
    rm -f "$temp_local" "$temp_remote"
}

# 使用遠端版本
use_remote_version() {
    local file="$1"
    local remote_content="$2"
    
    # 移除衝突標記，保留遠端內容
    sed '/<<<<<<< HEAD/,/>>>>>>> /c\
'"$(cat "$remote_content")" "$file" > "${file}.tmp"
    mv "${file}.tmp" "$file"
    echo "$(date): $file - 選擇遠端版本 (本地為空)" >> "$LOG_FILE"
}

# 使用本地版本
use_local_version() {
    local file="$1"
    local local_content="$2"
    
    # 移除衝突標記，保留本地內容
    sed '/<<<<<<< HEAD/,/>>>>>>> /c\
'"$(cat "$local_content")" "$file" > "${file}.tmp"
    mv "${file}.tmp" "$file"
    echo "$(date): $file - 選擇本地版本 (遠端為空)" >> "$LOG_FILE"
}

# 檢查內容相似度
content_similarity_high() {
    local file1="$1"
    local file2="$2"
    
    # 簡單的相似度檢查 - 如果有共同行數超過80%
    local common_lines=$(comm -12 <(sort "$file1") <(sort "$file2") | wc -l)
    local total_lines=$(cat "$file1" "$file2" | sort -u | wc -l)
    
    if [ "$total_lines" -gt 0 ]; then
        local similarity=$((common_lines * 100 / total_lines))
        [ "$similarity" -gt 80 ]
    else
        false
    fi
}

# 合併相似內容
merge_similar_content() {
    local file="$1"
    local local_content="$2"
    local remote_content="$3"
    
    # 創建合併版本 - 本地在前，遠端在後，去重
    {
        echo "# 自動合併版本 - $(date)"
        echo ""
        cat "$local_content"
        echo ""
        echo "# --- 來自遠端的額外內容 ---"
        echo ""
        # 只添加遠端獨有的行
        comm -13 <(sort "$local_content") <(sort "$remote_content")
    } > "${file}.merged"
    
    # 移除衝突標記，使用合併版本
    sed '/<<<<<<< HEAD/,/>>>>>>> /c\
'"$(cat "${file}.merged")" "$file" > "${file}.tmp"
    mv "${file}.tmp" "$file"
    rm -f "${file}.merged"
    
    echo "$(date): $file - 智能合併完成" >> "$LOG_FILE"
}

# 根據時間戳選擇
choose_by_timestamp() {
    local file="$1"
    local local_content="$2"
    local remote_content="$3"
    
    # 檢查文件修改時間 (這裡簡化為選擇本地版本，因為本地通常是最新的)
    use_local_version "$file" "$local_content"
    echo "$(date): $file - 選擇本地版本 (預設策略)" >> "$LOG_FILE"
}

# 通用文件衝突解決
resolve_generic_conflict() {
    local file="$1"
    
    # 對於非 Markdown 文件，保守地選擇本地版本
    git checkout --ours "$file"
    echo "$(date): $file - 保留本地版本 (非 Markdown 文件)" >> "$LOG_FILE"
}

# 改進的同步函數
improved_sync_repo() {
    echo "$(date): 開始智能同步..." >> "$LOG_FILE"
    
    # 清理任何潛在的鎖定文件
    cleanup
    
    # 暫存所有本地變更
    git add -A
    
    # 檢查是否有本地變更需要提交
    if ! git diff --cached --quiet; then
        echo "$(date): 提交本地變更..." >> "$LOG_FILE"
        git commit -m "Auto-sync: Local changes ($(date))" >> "$LOG_FILE" 2>&1
    fi
    
    # 嘗試拉取遠端變更
    echo "$(date): 拉取遠端變更..." >> "$LOG_FILE"
    git fetch origin main >> "$LOG_FILE" 2>&1
    
    # 嘗試合併
    if git merge origin/main >> "$LOG_FILE" 2>&1; then
        echo "$(date): 自動合併成功" >> "$LOG_FILE"
    else
        echo "$(date): 檢測到合併衝突，啟動智能解決..." >> "$LOG_FILE"
        
        # 智能解決衝突
        resolve_conflicts_intelligently
        
        # 完成合併
        git add -A
        git commit -m "Auto-resolve: Intelligent conflict resolution ($(date))" >> "$LOG_FILE" 2>&1
        
        echo "$(date): 衝突已智能解決並提交" >> "$LOG_FILE"
    fi
    
    # 推送到遠端
    if git push origin main >> "$LOG_FILE" 2>&1; then
        echo "$(date): 推送成功" >> "$LOG_FILE"
    else
        echo "$(date): 推送失敗，可能需要強制推送" >> "$LOG_FILE"
        git push origin main --force-with-lease >> "$LOG_FILE" 2>&1
    fi
    
    echo "$(date): 智能同步完成" >> "$LOG_FILE"
    echo "------------------------" >> "$LOG_FILE"
}

echo "智能衝突處理腳本已準備就緒"