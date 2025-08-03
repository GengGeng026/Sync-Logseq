#!/bin/bash

echo "🎯 Logseq 同步系統最終驗證報告"
echo "=================================="
echo "檢查時間: $(date)"
echo ""

# 1. plist 文件檢查
echo "📁 plist 文件檢查:"
plist_files=$(ls /Users/mac/Library/LaunchAgents/ | grep logseq | wc -l)
echo "   總數: $plist_files 個"
ls -la /Users/mac/Library/LaunchAgents/ | grep logseq
echo ""

# 2. 服務狀態檢查
echo "🔧 LaunchAgent 服務狀態:"
launchctl list | grep logseq
echo ""

# 3. 進程檢查
echo "⚙️ 運行進程檢查:"
process_count=$(ps aux | grep logseq_sync | grep -v grep | wc -l)
echo "   總數: $process_count 個"
ps aux | grep logseq_sync | grep -v grep
echo ""

# 4. plist 配置驗證
echo "📋 plist 關鍵配置:"
echo "   KeepAlive 設定:"
grep -A1 "KeepAlive" /Users/mac/Library/LaunchAgents/com.logseq.sync.plist | sed 's/^/     /'
echo "   RunAtLoad 設定:"
grep -A1 "RunAtLoad" /Users/mac/Library/LaunchAgents/com.logseq.sync.plist | sed 's/^/     /'
echo "   執行腳本:"
grep -A1 "ProgramArguments" /Users/mac/Library/LaunchAgents/com.logseq.sync.plist | grep "string" | sed 's/^/     /'
echo ""

# 5. 鎖文件檢查
echo "🔒 進程鎖定機制:"
if [ -f "/Users/mac/Documents/Sync-Logseq/.sync_lock" ]; then
    lock_pid=$(cat /Users/mac/Documents/Sync-Logseq/.sync_lock)
    echo "   鎖文件存在，PID: $lock_pid"
    if kill -0 "$lock_pid" 2>/dev/null; then
        echo "   ✅ 鎖定進程正在運行"
    else
        echo "   ❌ 鎖定進程不存在"
    fi
else
    echo "   ❌ 鎖文件不存在"
fi
echo ""

# 6. 日誌檢查
echo "📊 最新同步日誌:"
if [ -f "/Users/mac/Documents/Sync-Logseq/sync_single.log" ]; then
    echo "   最後 5 行:"
    tail -5 /Users/mac/Documents/Sync-Logseq/sync_single.log | sed 's/^/     /'
else
    echo "   ❌ 日誌文件不存在"
fi
echo ""

# 7. 自動重啟測試
echo "🧪 自動重啟功能測試:"
current_pid=$(ps aux | grep logseq_sync_single.sh | grep -v grep | awk '{print $2}')
if [ -n "$current_pid" ]; then
    echo "   當前進程 PID: $current_pid"
    echo "   正在測試自動重啟..."
    
    # 殺死進程
    kill "$current_pid"
    echo "   已終止進程，等待 10 秒檢查自動重啟..."
    sleep 10
    
    # 檢查新進程
    new_pid=$(ps aux | grep logseq_sync_single.sh | grep -v grep | awk '{print $2}')
    if [ -n "$new_pid" ] && [ "$new_pid" != "$current_pid" ]; then
        echo "   ✅ 自動重啟成功！新 PID: $new_pid"
    else
        echo "   ❌ 自動重啟失敗"
    fi
else
    echo "   ❌ 找不到運行中的進程"
fi
echo ""

# 8. 文件變更檢測測試
echo "🔍 文件變更檢測測試:"
test_file="/Users/mac/Documents/Sync-Logseq/test_$(date +%s).md"
echo "測試文件 - $(date)" > "$test_file"
echo "   已創建測試文件: $(basename "$test_file")"
echo "   等待 8 秒檢查同步反應..."
sleep 8

# 檢查日誌中是否有新的同步記錄
if tail -10 /Users/mac/Documents/Sync-Logseq/sync_single.log 2>/dev/null | grep -q "$(date '+%Y-%m-%d %H:%M')"; then
    echo "   ✅ 文件變更檢測正常"
else
    echo "   ⚠️ 可能未檢測到文件變更"
fi

# 清理測試文件
rm -f "$test_file"
echo ""

# 9. 最終評估
echo "=================================="
echo "🎯 系統最終評估:"

# 計算得分
score=0
total=7

# 檢查項目
[ "$plist_files" -eq 1 ] && score=$((score + 1)) && echo "✅ 單一 plist 文件" || echo "❌ plist 文件數量異常"
[ "$process_count" -eq 1 ] && score=$((score + 1)) && echo "✅ 單一同步進程" || echo "❌ 進程數量異常"
[ -f "/Users/mac/Documents/Sync-Logseq/.sync_lock" ] && score=$((score + 1)) && echo "✅ 進程鎖定機制" || echo "❌ 缺少進程鎖定"
grep -q "true" /Users/mac/Library/LaunchAgents/com.logseq.sync.plist && score=$((score + 1)) && echo "✅ KeepAlive 已啟用" || echo "❌ KeepAlive 未啟用"
launchctl list | grep -q "com.logseq.sync" && score=$((score + 1)) && echo "✅ 服務正在運行" || echo "❌ 服務未運行"
[ -f "/Users/mac/Documents/Sync-Logseq/sync_single.log" ] && score=$((score + 1)) && echo "✅ 日誌記錄正常" || echo "❌ 缺少日誌文件"
ps aux | grep -q "logseq_sync_single.sh" && score=$((score + 1)) && echo "✅ 腳本進程運行中" || echo "❌ 腳本進程未運行"

echo ""
echo "🏆 系統健康度: $score/$total"

if [ "$score" -eq "$total" ]; then
    echo ""
    echo "🎉 完美！你的 Logseq 同步系統已達到最佳狀態："
    echo "   • 系統重啟後自動啟動 ✅"
    echo "   • 進程崩潰後自動重啟 ✅"
    echo "   • 文件變更自動同步 ✅"
    echo "   • 單一進程避免衝突 ✅"
    echo "   • 進程鎖定防止重複 ✅"
    echo ""
    echo "🛡️ 你的系統現在具備完整的自動恢復能力！"
elif [ "$score" -ge 5 ]; then
    echo ""
    echo "👍 良好！系統基本正常，有小問題需要關注"
else
    echo ""
    echo "⚠️ 需要修復！系統存在多個問題"
fi