#!/bin/bash
# 修復 Logseq 自動啟動問題的腳本

echo "=== 修復 Logseq 自動啟動問題 ==="

# 1. 修復 ~/.logseq_autostart.sh 腳本
echo "1. 修復自動啟動腳本..."
cat > ~/.logseq_autostart.sh << 'EOF'
#!/bin/bash
# 等待系統完全啟動
sleep 5

# 檢查是否已經在運行
if pgrep -f "logseq_sync.sh" > /dev/null; then
    echo "$(date): Logseq sync 已經在運行中" >> "$HOME/.logseq_autostart.log"
    exit 0
fi

# 啟動 Logseq 同步服務
cd "/Users/mac/Documents/Sync-Logseq"
echo "$(date): 開始啟動 Logseq 同步服務..." >> "$HOME/.logseq_autostart.log"
./start_logseq_sync.sh >> "$HOME/.logseq_autostart.log" 2>&1
EOF

chmod +x ~/.logseq_autostart.sh

# 2. 檢查 ~/.zshrc 配置
echo "2. 檢查 ~/.zshrc 配置..."
if ! grep -q "logseq_autostart.sh" ~/.zshrc; then
    echo "添加自動啟動配置到 ~/.zshrc"
    cat >> ~/.zshrc << 'EOF'

# Logseq 自動同步服務
if ! pgrep -f "logseq_sync.sh" > /dev/null; then
    nohup /Users/mac/.logseq_autostart.sh > /dev/null 2>&1 &
fi
EOF
else
    echo "自動啟動配置已存在"
fi

# 3. 測試自動啟動
echo "3. 測試自動啟動功能..."
./stop_logseq_sync.sh
sleep 3

# 手動執行自動啟動腳本
~/.logseq_autostart.sh

sleep 10

# 檢查結果
if pgrep -f "logseq_sync.sh" > /dev/null; then
    echo "✅ 自動啟動修復成功！"
    echo "運行中的進程："
    ps aux | grep -E "(logseq_sync|fswatch)" | grep -v grep
else
    echo "❌ 自動啟動仍有問題"
    echo "檢查日誌："
    tail -5 ~/.logseq_autostart.log
fi

echo ""
echo "=== 問題診斷總結 ==="
echo "原因分析："
echo "1. ~/.logseq_autostart.sh 中的 sleep 30 延遲太長"
echo "2. 缺少重複啟動檢查邏輯"
echo "3. ~/.zshrc 配置可能不完整"
echo ""
echo "解決方案："
echo "1. 減少啟動延遲到 5 秒"
echo "2. 添加進程檢查避免重複啟動"
echo "3. 確保 ~/.zshrc 正確配置自動啟動"
echo ""
echo "重啟系統後，Logseq 同步服務應該會自動啟動。"