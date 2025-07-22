#!/bin/bash
# 修復文件中的 Git 衝突標記

fix_file_conflicts() {
    local file="$1"
    
    if grep -q "<<<<<<< HEAD" "$file"; then
        echo "修復 $file 中的衝突標記..."
        
        # 創建臨時文件
        local temp_file="/tmp/fix_conflict_$$"
        local final_file="/tmp/final_$$"
        
        # 提取所有非衝突內容和衝突內容
        awk '
        /^<<<<<<< HEAD/ { in_conflict=1; local_content=""; remote_content=""; next }
        /^=======/ { in_local=0; in_remote=1; next }
        /^>>>>>>> origin\/main/ { 
            in_conflict=0; in_remote=0;
            print ""
            print "# 🔄 合併內容 - " strftime("%Y-%m-%d %H:%M:%S")
            if (local_content) {
                print "# 📱 MacBook 版本:"
                print local_content
            }
            if (remote_content) {
                print "# 📲 iPhone 版本:"  
                print remote_content
            }
            print "# ✅ 請檢查並整理重複內容"
            print ""
            next
        }
        in_conflict && !in_remote { local_content = local_content $0 "\n"; next }
        in_conflict && in_remote { remote_content = remote_content $0 "\n"; next }
        !in_conflict { print }
        ' "$file" > "$temp_file"
        
        mv "$temp_file" "$file"
        echo "✅ $file 衝突標記已修復"
    fi
}

# 修復當前有衝突的文件
for file in $(find . -name "*.md" -exec grep -l "<<<<<<< HEAD" {} \;); do
    fix_file_conflicts "$file"
done

echo "所有衝突標記已修復"