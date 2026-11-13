#!/data/data/com.termux/files/usr/bin/bash
# Logseq 仓库安全同步脚本（手机端）
# 原则：普通合并；冲突标记清空后自动暂存，未解则暂停；无改动不提交；LFS 先拉后推；不强制推送、不硬重置

REPO="/data/data/com.termux/files/home/storage/shared/Documents/Sync-Logseq"
BRANCH="main"

cd "$REPO" || { echo "❌ 无法进入仓库目录: $REPO"; exit 1; }

# 冲突接管：标记已被清空的文件自动暂存；仍含冲突标记则返回 1，暂停本轮
# 用户只需在编辑器里删掉冲突标记并保存，无需手动 git add
stage_resolved_conflicts() {
    local f remaining
    remaining=""
    while IFS= read -r -d '' f; do
        if [ -f "$f" ] && grep -qE '^(<{7}|>{7})[[:space:]]' "$f"; then
            remaining="$remaining $f"
        else
            git add -- "$f" 2>/dev/null && echo "✅ 冲突标记已清除，自动暂存: $f"
        fi
    done < <(git diff --name-only --diff-filter=U -z)

    if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
        echo "⛔ 仍有未解冲突:${remaining}，暂停自动同步，等待手动修复"
        return 1
    fi
    return 0
}

echo "=== 1. 拉取远端最新引用 ==="
git fetch origin "$BRANCH" || { echo "⚠️ fetch 失败，保留本地改动退出"; exit 1; }

echo "=== 2. 检查/接管未解冲突 ==="
if ! stage_resolved_conflicts; then
    echo "⚠️ 存在未解冲突，本轮跳过自动提交，请手动处理后再同步"
    exit 1
fi

echo "=== 3. 先保存本地改动（无改动则不产生空提交） ==="
git add .
if git diff --cached --quiet --exit-code; then
    echo "=== 本地没有新改动，跳过提交 ==="
else
    git commit -m "Android Save: $(date)" || { echo "⚠️ 本地 commit 失败"; exit 1; }
fi

echo "=== 4. 普通合并远端（不 rebase、不硬重置） ==="
if ! git merge --no-edit "origin/$BRANCH"; then
    echo "⚠️ 合并出现冲突，保留本地工作区退出，不自动 add/commit"
    exit 1
fi

echo "=== 5. 合并后补齐 LFS 录音对象 ==="
git lfs pull origin "$BRANCH" || echo "⚠️ LFS pull 有警告，继续"

echo "=== 6. 再次检查/接管冲突 ==="
if ! stage_resolved_conflicts; then
    echo "⚠️ 合并后仍有未解冲突，跳过本轮提交与推送"
    exit 1
fi

echo "=== 7. 先推 LFS 对象，再推普通提交 ==="
git lfs push origin "$BRANCH" || { echo "⚠️ LFS push 失败，中止普通推送"; exit 1; }
git push origin "$BRANCH" || { echo "⚠️ push 失败"; exit 1; }

echo "=== 完成 ==="
exit 0
