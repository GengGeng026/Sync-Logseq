#!/data/data/com.termux/files/usr/bin/bash

# --- 路徑設定 ---
LOGSEQ_ROOT="/data/data/com.termux/files/home/storage/shared/Documents/Sync-Logseq"
ASSETS_DIR="$LOGSEQ_ROOT/assets"
JOURNALS_DIR="$LOGSEQ_ROOT/journals"
IGNORE_FILE="$HOME/.termux/tasker/.auto_log_ignore"

# 忽略清單：每行一個檔名，# 開頭為註解
IGNORE_LIST=()
if [ -f "$IGNORE_FILE" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | xargs)"
    [ -n "$line" ] && IGNORE_LIST+=("$line")
  done < "$IGNORE_FILE"
fi

in_ignore() {
  local fn="$1" entry
  for entry in "${IGNORE_LIST[@]}"; do
    [ "$entry" = "$fn" ] && return 0
  done
  return 1
}

# 日期設定
TODAY_DATE=$(date +%Y-%m-%d)
TODAY_FILE="$JOURNALS_DIR/${TODAY_DATE}.md"
CURRENT_TIME=$(date +%H:%M)

# 如果今天還沒開筆記，幫你開一個
if [ ! -f "$TODAY_FILE" ]; then
  touch "$TODAY_FILE"
fi

# --- 步驟 1：收集並排序（只抓今天的常見音檔） ---
SAVEIFS=$IFS
IFS=$'\n'

sorted_files=$(find "$ASSETS_DIR" -daystart -mtime 0 \( \
  -name "*.m4a" -o -name "*.aac" -o -name "*.mp3" \
  -o -name "*.opus" -o -name "*.ogg" \) -print0 | xargs -0 -r ls -tr)

# --- 步驟 2：過濾（忽略清單 + 全歷史日記去重，只比對 .md） ---
pending_files=()
for filepath in $sorted_files; do
  filename=$(basename "$filepath")
  if in_ignore "$filename"; then
    continue
  fi
  if ! grep -rF --include='*.md' -q "$filename" "$JOURNALS_DIR"; then
    pending_files+=("$filepath")
  fi
done
IFS=$SAVEIFS

# --- 步驟 3：聚合寫入 ---
if [ ${#pending_files[@]} -gt 0 ]; then
  if [ -s "$TODAY_FILE" ] && [ "$(tail -c 1 "$TODAY_FILE")" != "" ]; then
    echo "" >> "$TODAY_FILE"
  fi
  echo "- $CURRENT_TIME [[quick capture]]: #voice-memo" >> "$TODAY_FILE"
  for filepath in "${pending_files[@]}"; do
    filename=$(basename "$filepath")
    pure_name="${filename%.*}"
    echo "  - **$pure_name**" >> "$TODAY_FILE"
    echo "    - ![$filename](../assets/$filename)" >> "$TODAY_FILE"
  done
  echo "[$CURRENT_TIME] 已聚合歸檔：$pure_name"
else
  echo "沒有發現新錄音。"
fi

exit 0
