# Logseq 自動同步方案演進：從失敗到成功的完整記錄

> _這是一份關於如何解決 Logseq 跨設備同步問題的完整記錄，從最初的失敗嘗試到最終的穩定方案，希望能為遇到類似問題的用戶提供參考。_
>
> _圖表採用 Aura Theme 配色方案，設計為在淺色和深色主題下均有良好視覺效果，無需切換不同版本。_

![Logseq-Git-Sync](https://raw.githubusercontent.com/CharlesChiuGit/Logseq-Git-Sync-101/main/src/cover.png)

<br><br>
- ## 1. 問題起源
  
  **Logseq 作為知識管理工具，需要跨設備同步。主要挑戰：**
  - 在 Mac 重啟後自動同步失敗
  - 文件更新不完整
  - 同步過程中的衝突
  - 認證持久化問題
  
  <br><br><br>
- ## 2. 演變時間線
  
  ```mermaid
  %%{init: {
  'theme': 'base', 
  'themeVariables': {
    'primaryTextColor': '#FEC999',
    'primaryColor': '#00E9D9',
    'secondaryColor': '#A0B2F1',
    'tertiaryColor': '#B9B5D9',
    'primaryBorderColor': '#A9D9D9',
    'background': 'transparent',
    'clusterBkg': 'transparent',
    'fontFamily': 'default',
    'fontSize': '17px',
    'fontWeight': 'normal'
  }
  }}%%
  timeline
    title Logseq 同步方案演進時間軸
    section 初始階段
        基本 Git Hooks : 簡單的 post-commit hook
        : 需手動保存和提交
        : 系統重啟後失效
    section 自動化嘗試
        nohup 循環方案 : 定時自動同步
        : 浪費資源且不處理衝突
        初次 fswatch 嘗試 : 檔案變更觸發
        : 監控 .git 導致無限循環
    section 關鍵突破
        SSH 認證問題解決 : 持久化密鑰配置
        : 解決重啟後認證失效
        Git 倉庫整理 : 清理分支與歷史
        : 避免合併困難
    section 最終方案
        精確控制的 fswatch : 排除 .git 目錄
        : 文件穩定性檢測
        : 雙重安全檢查
        : 完善的錯誤處理
  ```
    - ##### 時間軸層級說明
      
      |  層級  |  說明 |
      |:----------------|:-----------------|
      | <span style="color:grey">◼</span> <span style="color:grey">頂部</span> | <span style="color:grey">主要事件 ── 時間軸上的主要事件和里程碑</span> |
      | <span style="color:darkgrey">◼</span> <span style="color:darkgrey">中間</span> | <span style="color:darkgrey">時間線 ── 連接事件的時間線</span> |
      | <span style="color:lightgrey">◼</span> <span style="color:lightgrey"> 底部</span> | <span style="color:lightgrey">次要事件 ── 次要事件和說明</span> |
  
      <br><br>
      
  - ### 2.1 階段一：基本 Git Hooks（初始方案）
    <br>

    - **實現**：Git post-commit hook
      ```bash
      #!/bin/bash
      git push origin main
      ```
    <br>

    - **缺點**：
      - 🔴 被動式：需手動保存和提交
      - 🔴 系統重啟後失效
      - 🔴 無法處理合併衝突
      
      <br><br><br>
  - ### 2.2 階段二：自動化嘗試
    <br>

    1. #### **nohup 循環方案**
        ```bash
        # 嘗試使用後台運行持續同步
        nohup bash -c 'while true; do git pull; git add .; git commit -m "Auto-sync"; git push; sleep 300; done' &
        ```

          - ##### **失敗原因**：
            - 🔴 無條件同步浪費資源
            - 🔴 不處理合併衝突
            - 🔴 重啟後需手動啟動
              <br><br>

    2. #### **初次 fswatch 嘗試**
        ```bash
        # 嘗試使用文件系統監視器觸發同步
        fswatch -o /Users/mac/Documents/Sync-Logseq | while read change; do
          git pull
          git add .
          git commit -m "Auto-sync: $(date)"
          git push
        done
        ```

          - **關鍵問題**：
            - 🔴 監控了 .git 目錄，導致無限循環
            - 🔴 未處理 SSH 認證問題
            - 🔴 未檢測文件寫入完成
            - 🔴 缺少錯誤處理機制
             <br><br>

  - ### 2.3 階段三：SSH 認證問題突破
    <br>

    - **診斷**： 重啟後 SSH 密鑰未自動加載，是同步失效的根本原因
    - **解決方案**：
    <br>
      1. 永久配置 SSH
          ```bash
          # ~/.ssh/config
          Host github.com
            AddKeysToAgent yes
            UseKeychain yes
            IdentityFile ~/.ssh/id_ed25519
          ```
      <br>

      2. 將密鑰添加到 macOS 鑰匙串
          ```bash
          ssh-add --apple-use-keychain ~/.ssh/id_ed25519
          ```
          <br>

          > 💡 **關鍵突破點** ：  解決 SSH 認證持久化是整個方案成功的基石，這確保了系統重啟後認證依然有效。

      <br>
  - ### 2.4 階段四：Git 倉庫整理
    <br>
    
    - **診斷**：多餘分支和冗餘歷史造成合併困難
    <br>

    - **解決**：
      - 清理無用分支：`git push origin --delete gh-pages`
      - 統一使用 main 分支
      - 重置關係：`git reset --hard origin/main`
      <br>

        > ⚠️ **注意** ：  在執行 `git reset --hard` 之前，請確保你已經備份了重要的本地更改！

      <br><br>
- ## 3. 最終成功方案：精確控制的 fswatch
  - ### 3.1 為何同樣是 fswatch 但這次成功了？
    <br>

      - **關鍵改進**：
        <br>

        1. **精確排除 .git 目錄** ✅
            ```bash
            # 避免監控 .git 目錄造成的無限循環
            fswatch -o --exclude ".git" "$REPO_DIR"
            ```
            <br>
        
        2. **文件穩定性檢測** ✅
            ```bash
            # 等待文件完全寫入
            sleep 5
            # 檢測文件穩定性
            latest_change=$(find "$REPO_DIR" -path '*/.git/*' -prune -o -type f -newer "$REPO_DIR/.last_sync" -print -quit)
            ```
            <br>
        
        3. **雙重安全檢查** ✅：時間間隔 + 變更量檢測
            ```bash
            # 時間間隔檢查
            if [ $(( $(date +%s) - $(stat -f %m "$REPO_DIR/.last_sync") )) -gt 120 ]; then
              # 變更量檢查
              if [ "$changes_count" -gt 2 ]; then
                # 執行同步
              fi
            fi
            ```
            <br>
        
        4. **完善的錯誤處理** ✅
            ```bash
            # 先嘗試正常流程
            pull_output=$(git pull origin main 2>&1)
            # 如失敗則恢復後重試
            if [ $pull_status -ne 0 ]; then
              git reset --hard HEAD
              git pull origin main
            fi
            ```
            <br>
          
        5. **持久的 SSH 認證** ✅：鑰匙串集成確保重啟後認證有效
          <br>
        
            **深入分析** ：
              ###### 看似相同的工具（fswatch），但通過精確控制和完善的錯誤處理，實現了完全不同的結果。
    
    <br>
  - ### 3.2 解決的核心問題
      
      1. **SSH 認證持久化** 🔐：解決重啟後認證失效
      2. **文件監控精確性** 🔍：避免無限循環
      3. **同步時機控制** ⏱️：確保文件完全寫入
      4. **衝突自動處理** 🔄：處理多設備編輯衝突
      5. **失敗恢復機制** 🛠️：出錯時自動恢復
  
  <br><br><br>
- ## 4. 場景解決方案對照表
  
  | 場景 | 症狀 | 原因 | 解決方案 |
  |:--------|:---------|:---------|:---------|
  | 系統重啟後 | 自動同步失效 | SSH 密鑰未加載 | SSH config + 鑰匙串集成 |
  | 文件不完整 | 同步後內容缺失 | 過早同步，文件未完全寫入 | 等待 + 穩定性檢測 |
  | 無限循環同步 | CPU/網絡負載高 | .git 目錄變化觸發新同步 | 精確排除 .git 目錄 |
  | 同步衝突 | 推送失敗 | 本地/遠端版本不同步 | 先拉取後推送 + 自動衝突解決 |
  | 罕見同步 | 小變更不同步 | 觸發條件過嚴格 | 雙重檢查：時間 + 變更量 |
  
  <br><br><br>
- ## 5. 關鍵經驗總結
  
    > *「同步問題的本質不是技術選擇，而是邊界處理和錯誤復原」*
    
      1. **系統性思考** 🧠：單點修復不如系統解決方案
      2. **認證是基礎** 🔑：先解決 SSH 認證再優化同步邏輯
      3. **精確控制** 🎯：關鍵在細節，如監控範圍和觸發條件
      4. **邊界處理** 🛡️：考慮各種異常情況，增強穩定性
      5. **雙重保險** 🔄：多層次觸發機制提高可靠性
  
  <br><br><br>
- ## 6. 經驗教訓
  
  📝 **主要收穫**:
  - 看似有效的自動化方案，其觸發邏輯的微小差異可能導致在特定情境下（如單一文件變更）失效，細節實現至關重要。
  - 解決複雜問題需要系統性思考，單一修復往往不夠
  - 自動化腳本需要考慮各種邊界情況，尤其是錯誤處理
  - 提前解決認證問題是自動化的基礎
  - 定期維護和檢查自動同步機制的健康狀態
    
  <br><br><br>
- ## 7. 完整成功方案：logseq_sync.sh
  
  - 以下是最終成功的同步腳本，解決了所有之前遇到的問題：
  
    ```bash
    #!/bin/bash
    # 文件名: logseq_sync.sh
    # 保存位置: /Users/mac/Documents/Sync-Logseq/logseq_sync.sh
    
    # 設置工作目錄和日誌文件
    REPO_DIR="/Users/mac/Documents/Sync-Logseq"
    LOG_FILE="/dev/null" # 改為 /dev/null 而不是實際文件
    cd "$REPO_DIR" || exit
    
    # 清理鎖定文件（如果存在）
    cleanup() {
    find .git -name "*.lock" -delete 2>/dev/null
    }
    
    # 日誌輪換
    rotate_logs() {
    # 限制日誌大小為1MB
    for log_file in "$LOG_FILE" "$REPO_DIR/sync_stdout.log" "$REPO_DIR/sync_stderr.log"; do
      if [ -f "$log_file" ] && [ $(stat -f%z "$log_file") -gt 1048576 ]; then
        timestamp=$(date +"%Y%m%d_%H%M%S")
        mv "$log_file" "${log_file}.${timestamp}"
        touch "$log_file"
        # 只保留最近5個日誌文件
        ls -t "${log_file}."* | tail -n +6 | xargs rm -f 2>/dev/null
      fi
    done
    }
    
    # 同步功能
    sync_repo() {
    echo "$(date): 開始同步..." >> "$LOG_FILE"
    
    # 清理任何潛在的鎖定文件
    cleanup
    
    # 同步策略：先拉取，如有衝突則重置再拉取
    pull_output=$(git pull origin main 2>&1)
    pull_status=$?
    
    if [ $pull_status -ne 0 ]; then
      echo "$(date): 拉取失敗，嘗試恢復..." >> "$LOG_FILE"
      git reset --hard HEAD
      git pull origin main >> "$LOG_FILE" 2>&1
    else
      # 只在輸出不是"Already up to date"時記錄
      if [ "$pull_output" != "Already up to date." ]; then
        echo "$(date): $pull_output" >> "$LOG_FILE"
      fi
    fi
    
    # 添加所有變更
    git add -A
    
    # 檢查是否有變更需要提交
    if ! git diff --cached --quiet; then
      echo "$(date): 發現變更，提交中..." >> "$LOG_FILE"
      git commit -m "Auto-sync: $(date)" >> "$LOG_FILE" 2>&1
      
      # 推送變更
      push_output=$(git push origin main 2>&1)
      if [ $? -ne 0 ]; then
        echo "$(date): 推送失敗: $push_output" >> "$LOG_FILE"
        cleanup
        git push origin main --force >> "$LOG_FILE" 2>&1
      fi
    else
      # 檢查本地是否領先遠端
      LOCAL=$(git rev-parse HEAD)
      REMOTE=$(git rev-parse origin/main 2>/dev/null)
      
      if [ "$LOCAL" != "$REMOTE" ]; then
        echo "$(date): 本地領先遠端，推送剩餘提交..." >> "$LOG_FILE"
        git push origin main >> "$LOG_FILE" 2>&1
      else
        echo "$(date): 沒有變更，無需同步" >> "$LOG_FILE"
      fi
    fi
    
    echo "$(date): 同步完成" >> "$LOG_FILE"
    echo "------------------------" >> "$LOG_FILE"
    }
    
    # 輪換日誌
    rotate_logs
    
    # 進行初始同步
    sync_repo
    
    # 監視文件變更
    echo "$(date): 開始監視文件變更..." >> "$LOG_FILE"
    
    fswatch -o --exclude ".git" "$REPO_DIR" | while read -r change; do
    # 記錄檢測到變更的時間
    change_time=$(date +%s)
    
    # 等待 5 秒
    sleep 5
    
    # 再次檢查最近修改時間，確保文件已停止修改
    latest_change=$(find "$REPO_DIR" -path '*/.git/*' -prune -o -type f -newer "$REPO_DIR/.last_sync" -print -quit 2>/dev/null)
    
    if [ -n "$latest_change" ]; then
      latest_change_time=$(stat -f %m "$latest_change")
      
      # 如果最近修改時間與檢測時間相差超過5秒，說明文件已穩定
      if [ $(( $change_time - $latest_change_time )) -gt 5 ]; then
        rotate_logs
        sync_repo
        touch "$REPO_DIR/.last_sync"
      fi
    fi
    
    # 將 300 秒(5分鐘)改為 120 秒(2分鐘)，但增加變更檢測
    if [ ! -f "$REPO_DIR/.last_sync" ] || [ $(( $(date +%s) - $(stat -f %m "$REPO_DIR/.last_sync") )) -gt 120 ]; then
      # 檢查是否有足夠的變更量
      changes_count=$(git status --porcelain | wc -l | tr -d ' ')
      
      if [ "$changes_count" -gt 2 ]; then # 至少有3個文件變更才同步
        rotate_logs
        sync_repo
        touch "$REPO_DIR/.last_sync"
      fi
    fi
    done
    ```
  
  <br><br><br>
  - ## 7.1 近期真實排查與優化歷程
    <br>

    1. ### flock 指令問題與同步腳本失效排查
        在 macOS 上，`flock` 並非預設安裝，導致原本用 flock 實現的同步腳本鎖定機制完全失效。腳本每次執行時都因找不到 flock 而直接退出，實際上沒有進行任何同步動作。
          <br>

          **學習點**：
            跨平台腳本需特別注意依賴的工具是否為目標系統預設，否則會出現「靜默失效」的隱性 bug。
            <br><br>

    2. ### 腳本調整與 flock 移除
        經過日誌排查，發現 flock 指令報錯並導致腳本提前結束。於是將 flock 相關代碼全部移除，讓同步主流程直接執行，恢復了自動同步功能。
        <br>

          **學習點**：
            簡化同步腳本結構，減少不必要的鎖定機制，在單用戶環境下更穩定。
            <br><br>

    3. ### Logseq 內建 Git 功能與同步腳本的衝突
        a. 測試發現，只要 Logseq 的「Git auto commit」或相關插件開啟，無論同步腳本多麼靜默，Logseq 仍會在遇到 git lock ref 等錯誤時強制彈窗，干擾使用體驗。
        b. 經過多輪測試，最終選擇**完全關閉 Logseq 內建 Git 功能與插件**，只保留 logseq_sync.sh 腳本負責所有同步，徹底杜絕彈窗。
        <br>

          **學習點**：
            多重自動同步機制會互相干擾，最佳實踐是「只保留一種自動同步方案」。
            <br><br>

    4. ### 腳本最終穩定運作與同步體驗
        移除 flock 並關閉 Logseq 內建 Git 功能後，logseq_sync.sh 腳本可穩定自動同步 Mac 與手機端 Logseq，且完全無彈窗干擾。
        <br>

          **學習點**：
            同步腳本需搭配詳細日誌，便於後續排查與優化；同步方案設計要兼顧「穩定性」與「用戶體驗」。

      <br><br><br>

- ## 8. 腳本流程圖
  
  ```mermaid
  %%{init: {
  'theme': 'base', 
  'themeVariables': {
    'primaryColor': '#19E9D9',
    'primaryTextColor': '#FFFFFF',
    'primaryBorderColor': '#59B79A',
    'lineColor': '#FEC999',
    'secondaryColor': '#FFCB6B',
    'tertiaryColor': '#F07178',
    'background': 'transparent',
    'textColor': '#EEFFFF',
    'mainBkg': '#273747',
    'nodeBorder': '#59B79A',
    'clusterBkg': 'transparent',
    'edgeLabelBackground': '#21252B'
  },
  'flowchart': {
    'curve': 'basis',
    'nodeSpacing': 50,
    'rankSpacing': 50,
    'padding': 15
  }
  }}%%
  flowchart TD
    %% 節點樣式優化
    classDef start fill:#005886,stroke:#005886,color:#FFFFFF,stroke-width:2px;
    classDef process fill:#19E9D,stroke:#59B79A,color:#FFFFFF,stroke-width:1px;
    classDef condition fill:#FFCB6B,stroke:#59B79A,color:#273747,stroke-width:1px,shape:diamond;
    classDef action fill:#0B776F,stroke:#59B79A,color:#FFFFFF,stroke-width:1px;
    
    A[啟動腳本] --> B[設置工作目錄]
    B --> C[初始同步]
    C --> D[開始監視文件變更]
    D --> E{檢測到文件變更?}
    E -->|是| F[等待5秒]
    F --> G{文件寫入完成?}
    G -->|是| H[執行同步]
    G -->|否| E
    E -->|否| I{超過2分鐘未同步?}
    I -->|是| J{變更超過3個文件?}
    J -->|是| H
    J -->|否| E
    I -->|否| E
    H --> K[更新最後同步時間]
    K --> E
    
    %% 應用樣式
    class A start;
    class B,D,F,K process;
    class C,H action;
    class E,G,I,J condition;
  ```
  
  <br>
- ##### 圖表[[顏色]]說明 (Aura Theme 配色)
  
  | 元素 | [[顏色]] | 說明 |
  |:--------|:---------|:---------|
  | <span style="color:#005886">◼</span> 起始節點 | 深藍色 ( #005886 ) | 流程的起始點，如「啟動腳本」 |
  | <span style="color:#59B79A">◼</span> 處理節點 | 深[[綠色]] ( #59B79A ) | [[執行]]的處理步驟，如「設置工作目錄」 |
  | <span style="color:#FFCB6B">◆</span> [[條件]]節點 | 黃色 ( #FFCB6B ) | 決策點，如「檢測到文件變更?」 |
  | <span style="color:#0B776F">◼</span> [[動作]]節點 | 淺[[綠色]] ( #0B776F ) | 重要的[[動作]]，如「[[執行]][[同步]]」 |
  | <span style="color:#FEC999">→</span> 連[[接線]] | 橙色 ( #FEC999 ) | 流程[[方向]] |
  
  <br><br><br>
- ## 9. 如何使用此方案
  
  1. 將上述腳本保存為 `logseq_sync.sh`
  2. 設置腳本為可執行: `chmod +x logseq_sync.sh`
  3. 在系統啟動時自動運行此腳本 (可通過 launchd 或登錄項實現)
  4. 享受無憂的 Logseq 自動同步體驗
  
  > 💡 **專業提示**: 考慮將此腳本設為 macOS 登錄項，確保系統啟動後自動運行。
  
  <br>
  
  ---
  
  *最後更新: 2025-04-17*