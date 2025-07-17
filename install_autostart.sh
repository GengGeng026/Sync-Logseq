#!/bin/bash
# 安裝開機自動啟動腳本

SCRIPT_DIR="/Users/mac/Documents/Sync-Logseq"
AUTOSTART_SCRIPT="$HOME/.logseq_autostart.sh"

# 創建自動啟動腳本
cat > "$AUTOSTART_SCRIPT" << 'EOF'
#!/bin/bash
# 等待系統完全啟動
sleep 30

# 啟動 Logseq 同步服務
cd "/Users/mac/Documents/Sync-Logseq"
./start_logseq_sync.sh >> "$HOME/.logseq_autostart.log" 2>&1
EOF

chmod +x "$AUTOSTART_SCRIPT"

# 添加到 .zshrc 或 .bash_profile
SHELL_RC="$HOME/.zshrc"
if [ ! -f "$SHELL_RC" ]; then
    SHELL_RC="$HOME/.bash_profile"
fi

# 檢查是否已經添加
if ! grep -q "logseq_autostart.sh" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# Logseq 自動同步服務" >> "$SHELL_RC"
    echo "nohup $AUTOSTART_SCRIPT > /dev/null 2>&1 &" >> "$SHELL_RC"
    echo "已添加自動啟動到 $SHELL_RC"
else
    echo "自動啟動已經配置"
fi

echo "安裝完成！重啟後將自動啟動 Logseq 同步服務"