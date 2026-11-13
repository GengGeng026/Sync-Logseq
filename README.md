# Logseq 雙端自動同步系統 - 重建與排障手冊

> **狀態**：✅ 雙端對齊運行（Mac + Android Termux），Git LFS 接管錄音
> **最後更新**：2026-11-13
> **倉庫**：GitHub `GengGeng026/Sync-Logseq`，分支 `main`
> **用途**：設備丟失/重裝時，按本文逐步恢復 Mac 與手機端的自動同步；日常排障見第 6 節對齊與衝突處理。

## 1. 系統架構

```
錄音 APP → FolderSync → 手機 assets/
                              ↓ assets 變動
                     auto_log_oneshot.sh（寫入今日日記）
                              ↓ journals 變動
                     sync.sh（fetch → 提交 → merge → LFS 推拉 → push）
                              ↓ 遠端 GitHub main
                     Mac LaunchAgent 定時/監聽同步（同樣 fetch → merge → LFS → push）
```

- **Mac**：LaunchAgent `com.logseq.sync.v2` 跑 `logseq_sync_optimized.sh`，定時輪詢 + fswatch 本地監聽，去抖動、互斥鎖、過期鎖自清。
- **手機**：Termux 跑 `sync.sh`（Git 同步）與 `auto_log_oneshot.sh`（錄音歸檔），Tasker 事件觸發，FolderSync 落地錄音。
- **大檔**：錄音走 Git LFS；mp4/mov/zip 等用 `.gitignore` 擋在庫外。

### 路徑與遠端
| 端 | 倉庫路徑 | 遠端 |
|---|---|---|
| Mac | `/Users/mac/Documents/Sync-Logseq` | SSH `git@github.com:GengGeng026/Sync-Logseq.git` |
| 手機 | `/data/data/com.termux/files/home/storage/shared/Documents/Sync-Logseq` | HTTPS `https://github.com/GengGeng026/Sync-Logseq.git` |

> 手機腳本內必須用實體絕對路徑，勿用 `~/storage/shared` 軟連結寫法。

### 1.1 排障索引（症狀 → 對接章節）
| 看到的症狀 | 對接章節 | 首要動作 |
|---|---|---|
| 錄音/大檔 push 被 GitHub 拒絕（>100MB） | 第 4 節 | 確認 `.gitattributes` 已登記副檔名並提交 |
| 新端 clone 後錄音打不開、檔案是指標 | 第 4 節 | `git lfs install` → `git lfs pull origin main` |
| 錄音已進 assets，但沒寫進今日日記 | 第 3.4、5 節 | 查腳本路徑/副檔名/忽略清單/`.md` 去重 |
| 日記出現 `<<<<<<<` 衝突標記、同步每輪即停 | 第 6.2、6.3 節 | 清標記存檔，等腳本自動接管；兜底再手動 add |
| 解完衝突很快被「遠端反彈」覆蓋、push 被 non-fast-forward 拒、本地與遠端分叉 | 第 6.5、6.2 節 | 停手不要 force；先看對齊計數，普通合併後推送 |
| push 報 `cannot lock ref ... is at <新> but expected <舊>` | 第 6.5 節 | 基線過期，重跑同步腳本即可，不需 force |
| 想確認兩端是否對齊 | 第 6.1 節 | `git fetch` + 對齊計數應為 `0 0` |
| `Could not resolve host: github.com` / fetch 超時 / 連不上 | 第 6.4 節 | `curl` 測連通；切網絡或稍後重試，恢復後跑 sync.sh 補推 |
| 提示 `post-merge` hook was ignored | 第 4 節備註 | `chmod +x .git/hooks/post-merge` |
| Mac 同步服務沒在跑 | 第 2.3 節 | 檢查 plist 載入、腳本權限、fswatch |
| Notion 鏡像沒更新 | 第 10 節 | 查 Actions 日誌與兩個 Secrets |
| 新機重建雙端 | 第 8 節 | 按 Mac / 手機步驟部署 |
| 準備執行刪除或危險操作 | 第 9 節 | 先讀安全底線，確認路徑與備份 |

## 2. Mac 端配置

### 2.1 LaunchAgent plist
`~/Library/LaunchAgents/com.logseq.sync.v2.plist`（Label `com.logseq.sync.v2`，唯一入口）：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.logseq.sync.v2</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/mac/Documents/Sync-Logseq/logseq_sync_optimized.sh</string>
  </array>
  <key>WorkingDirectory</key>
  <string>/Users/mac/Documents/Sync-Logseq</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
    <key>HOME</key><string>/Users/mac</string>
    <key>LOGSEQ_SYNC_BRANCH</key><string>main</string>
    <key>LOGSEQ_PULL_INTERVAL</key><string>60</string>
  </dict>
  <key>StandardOutPath</key>
  <string>/Users/mac/Documents/Sync-Logseq/launchd_stdout.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/mac/Documents/Sync-Logseq/launchd_stderr.log</string>
</dict>
</plist>
```

### 2.2 腳本關鍵點（logseq_sync_optimized.sh）
- 參數（可被 plist 環境變數覆蓋）：`PULL_INTERVAL` 預設 15（plist 設 60）、`DEBOUNCE_GAP=2`、`MAX_FILE_SIZE=100000000`（100MB）、`GIT_TIMEOUT=30`、`MAX_LOCK_AGE=120`、`QUIET_GAP` 預設 15（env `LOGSEQ_QUIET_GAP` 覆蓋，編輯靜置秒數）。
- 流程：清理 rebase 殘留 → `git checkout` → `git fetch` → **預檢衝突** → 遠端有更新才 `merge --no-edit`（普通合併，不 rebase、不硬重置）→ **merge 失敗即中斷**（不帶傷進入提交）→ merge 後複查衝突 → **編輯靜置緩衝** → `add -A`（>100MB 移出索引）→ 有暫存改動才 commit（訊息 `Auto-sync: 日期`）→ `lfs push` → `git push`（普通推送，不 force）。
- 衝突處理：`stage_resolved_conflicts()` 在 fetch 後、merge 後各檢查一次；標記已清空的文件自動 `git add` 接管，仍含 `<<<<<<<` / `>>>>>>>` 標記則本輪暫停，不進入 add/commit。
- 靜置緩衝：改動文件在 `QUIET_GAP` 秒內仍被修改，本輪先不提交，留待下一輪，避免編輯中途被搶提交。
- 日誌：`.logs/sync.log`（自動修剪上限 1000 行）；stdout/stderr 進 `launchd_stdout.log` / `launchd_stderr.log`。

### 2.3 啟用與驗證
```bash
chmod 644 ~/Library/LaunchAgents/com.logseq.sync.v2.plist
chmod 755 /Users/mac/Documents/Sync-Logseq/logseq_sync_optimized.sh
launchctl unload ~/Library/LaunchAgents/com.logseq.sync.v2.plist 2>/dev/null
launchctl load -w ~/Library/LaunchAgents/com.logseq.sync.v2.plist
launchctl list | grep com.logseq.sync.v2
tail -n 100 /Users/mac/Documents/Sync-Logseq/.logs/sync.log
```
依賴：`brew install fswatch`，確認 `which fswatch` 在 `/usr/local/bin` 或 `/opt/homebrew/bin`。

## 3. 手機端鏈路（Termux + Tasker + FolderSync）

### 3.1 腳本目錄
- **運行原件**（手機 Termux 本地）：`/data/data/com.termux/files/home/.termux/tasker/`
  - `sync.sh`：Git 同步
  - `auto_log_oneshot.sh`：錄音歸檔進日記
  - `.auto_log_ignore`：忽略清單（每行一個檔名，`#` 註解）
- **倉庫備份副本**：`scripts/android/`（隨倉庫入庫，重建時從這裡取回；修改手機原件後需同步副本並提交）。

> 手機端無獨立日誌文件：同步失敗看 Tasker 失敗通知；排查時在手機 Termux 手動跑 `sync.sh`，直接看終端輸出。

### 3.2 Tasker Profiles
| Profile | 觸發 | 任務 |
|---|---|---|
| AutoPull/Push Github when Open/Close Logs.. | 打開 / 離開 Logseq | Git Sync → `sync.sh` |
| /journals modified | journals 目錄 Modify | Git Sync → `sync.sh` |
| Auto-Pull Github every 15 min | 每 15 分鐘定時 | Git Sync → `sync.sh` |
| /assets modified → VoiceSync | assets 目錄 Modify | `auto_log_oneshot.sh` |

**FolderSync 任務** `SD CARD: Voice Recorder > assets`
- 來源：`/storage/65A3-810C/Recordings/VoiceRecorder/`（SD 卡錄音目錄；卡序號隨卡變更，換卡後核對路徑）
- 目的地：倉庫 `assets/`

**Git Sync Task 內部動作配置**（重建 Tasker 任務時照此設）
- 動作 1 · Termux：執行 `/data/data/com.termux/files/home/.termux/tasker/sync.sh`；Arguments、Working directory、Stdin 留空；**Wait For Result ✓**；**Timeout 60 秒**。
- 動作 2 · Notify：標題 `⚠️ Android Logseq 同步失敗`，條件 `If %result != 0`（即 sync.sh 返回非 0 才通知）。
- 沒勾 Wait For Result 就拿不到退出碼，失敗通知不會觸發。

### 3.3 sync.sh 流程
1. `git fetch origin main`
2. 查未解衝突（`diff-filter=U`）：有則即停退出，不自動 add/commit
3. `git add .`；無暫存改動則跳過提交
4. `git merge --no-edit origin/main`（普通合併，不 rebase、不硬重置）
5. `git lfs pull origin main`
6. 再查衝突：有則跳過提交與推送
7. `git lfs push` → `git push origin main`

原則：普通合併、衝突即停、無改動不提交、LFS 先拉後推、不強制推送、不硬重置。

### 3.4 auto_log_oneshot.sh 歸檔規則
- 只取當天 mtime 的副檔名：m4a / aac / mp3 / opus / ogg。
- 先比對忽略清單，命中跳過；再全歷史 `journals/*.md` 去重（只比對 `.md`，不讀 `.bak` 備份）。
- 去重比對必須限定 `--include='*.md'`：若不限定副檔名，journals 內的 `.bak-*` 備份會被當成「已有條目」，導致全部誤判已歸檔、待寫清單變 0 行。
- 寫入今日日記：空行分隔 → `- HH:MM [[quick capture]]: #voice-memo` 父節點 → 每檔 `  - **純名**` 與 `    - ![檔名](../assets/檔名)`。

## 4. Git LFS 錄音接管

### 背景與症狀
- 錄音體積大，普通 Git 追蹤後推送被 GitHub 100MB 限制擋下，自動提交無法上遠端。
- 只跑 `git lfs install` 不能解決：它只初始化本地過濾器，不把規則寫進倉庫；新端 clone 後仍不知道哪些檔案走 LFS。

### 規則（`.gitattributes`，必須隨倉庫提交）
```gitattributes
*.m4a filter=lfs diff=lfs merge=lfs -text
*.aac filter=lfs diff=lfs merge=lfs -text
*.mp3 filter=lfs diff=lfs merge=lfs -text
*.opus filter=lfs diff=lfs merge=lfs -text
*.ogg filter=lfs diff=lfs merge=lfs -text
```

### 舊檔轉 LFS（不改歷史、不強推）
```bash
cd <倉庫目錄>
git add --renormalize '*.mp3'
git commit -m "chore: LFS 接管 mp3，補 opus/ogg 規則"
git lfs push origin main
git push origin main
```
新端克隆後：先確認 `git --version`、`git lfs version` 可用；再 `git lfs install` → `git lfs pull origin main`。

### 核對
```bash
git lfs ls-files | wc -l
git lfs ls-files | grep -i test
# LFS 指標檔應含：version https://git-lfs... / oid sha256:... / size ...
```
> 不要直接 `cat` / 打開 `assets/` 裡的錄音二進制：控制字符會刷屏、弄亂終端標題。核對檔案用 `git lfs ls-files`、`ls -l assets/`，確認內容用 Logseq 播放。
> renormalize 只改索引與之後的提交，不回溯改寫舊提交；`.gitattributes` 不提交的話，clone 後規則會丟失。
>
> 若提示某個 `.git/hooks/*` hook was ignored（未設可執行，post-commit / post-merge / pre-push 同類）：`chmod +x .git/hooks/post-checkout .git/hooks/post-commit .git/hooks/post-merge .git/hooks/pre-push 2>/dev/null`。這些鉤子多為 LFS 輔助；同步腳本已顯式 `git lfs pull` / `git lfs push`，未補權限也不會缺物件。`.git/hooks/` 不隨倉庫同步，每端本地各自安裝。

## 5. 2026-11-13 故障時間線

1. **大錄音推不上遠端**：超過 100MB 限制；單獨 `git lfs install` 無效。根因 `.gitattributes` 未登記錄音副檔名。補齊 LFS 規則，舊 mp3 用 renormalize 轉 LFS，不改歷史、不強推。
2. **錄音不再自動寫日記**：
   - 腳本倉庫路徑指向已不存在的舊目錄 `~/Documents/logseq-termux`；改實體絕對路徑。
   - 舊腳本只抓 m4a；補上 aac/mp3/opus/ogg。
   - 去重被日記 `.bak-*` 備份干擾；改為只比對 `*.md`。
   - 補回 `SAVEIFS=$IFS` 保存/還原分隔符。
3. **歷史存量音頻被誤補進今日日記**：6 個當天 mtime、歷史日記無全名的舊錄音被當成新待寫條目。已從日記移除，檔名寫入 `.auto_log_ignore` 永久跳過。檔案仍在 assets/LFS、日記無條目；是否補回歷史日期由人工決定，腳本不自動補寫。
4. **雙端同日改同一日記 → 合併衝突**：處理見第 6 節。
5. **merge 失敗後未中斷，本地與遠端反覆分叉（2026-11-13 晚）**：舊版 Mac 腳本在 `git merge` 被 index.lock 連擋、或被 `local changes would be overwritten` 中止後，流程沒有 `return`，照常 `git add -A` 並連續提交；fswatch 監聽子進程與 60 秒輪詢並發觸發，搶同一倉庫產生鎖。本地提交基於舊基線，push 全部 non-fast-forward 被拒，分叉越積越多；手動解出的正確內容被後續自動提交與並發事件反覆覆蓋，最終只能 `git push --force` 頂掉遠端，把手機提交（含一條 141MB 錄音實體）擠出 main。根因與修復見第 6.5 節。

## 6. 雙端對齊核對與衝突處理

### 6.1 對齊核對（兩端各跑一次）
```bash
cd <倉庫目錄>
git fetch origin main
git status -sb
git rev-list --left-right --count main...origin/main   # 左=本地領先 右=遠端領先；0 0 即對齊
git --no-pager log --oneline -5
git lfs ls-files | wc -l
```

### 6.2 出現 `both modified` / 未解衝突時

**預設方式（新 Mac 腳本，不用手敲 git）**
1. 看衝突段：`grep -n '<<<<<<<\|=======\|>>>>>>>' journals/日期.md`
2. 在 Logseq / 編輯器裡保留兩邊應留內容，刪除 `<<<<<<<` / `=======` / `>>>>>>>` 標記，存檔。
3. 腳本下一輪偵測到標記已清空，會自動 `git add` 接管；過 `QUIET_GAP` 靜置緩衝後自動提交、推 LFS 與普通提交。接管期間不要重複編輯同一檔，避免靜置計時重新開始。
4. 對齊核對見 6.1；另一端必要時 `git lfs pull origin main` 補齊錄音物件。

**兜底：手動走 git（自動接管沒生效時）**
1. 編輯器刪標記存檔後：`git add journals/日期.md`
2. 確認暫存只有該檔：`git --no-pager diff --cached --stat`
3. 完成合併提交：`git commit --no-edit`
4. 先合併遠端再普通推送（不可跳過 pull 直接 push）：
   ```bash
   git pull --no-edit origin main
   git lfs push origin main
   git push origin main
   ```
> 無論哪條路，都不使用 `git push --force`；force 會頂掉遠端已有提交，見第 9 節與 6.5 節。

### 6.3 解完衝突後腳本怎麼接管
- 舊版：衝突檢查在 `git add` 之前，沒手動 `git add` 就一直算未解，每輪即停。
- 新版 Mac 腳本：`stage_resolved_conflicts()` 逐檔檢查標記是否還在；標記已清空就自動 `git add`，全部清空後過 `QUIET_GAP` 靜置緩衝才提交。用戶只需在編輯器改完存檔，不用手敲 add/commit/push。
- 仍含標記的文件留在未解狀態，本輪暫停自動寫操作，等繼續編輯。
- 手機 `sync.sh` 維持保守邏輯：查 U 狀態有衝突即停退出，不自動 add/commit。

### 6.4 網絡與 DNS 瞬時故障（外部環境，非倉庫損壞）
**判讀**：報錯形如 `Could not resolve host: github.com`、`Failed to connect`、fetch 超時。這是手機當下 DNS 解析或網絡連通問題，腳本邏輯、倉庫檔案、路徑均完好。GitHub 站點是否在線，可用另一台設備或雲主機對照 `curl` 判斷。

**先測連通**（Termux 未裝 dnsutils，不用 `nslookup`）：
```bash
curl -sS -m 10 https://github.com -o /dev/null -w "HTTP %{http_code}, IP %{remote_ip}\n"
```
- 返回 `HTTP 200/301/302` + 真實 IP：DNS 與網絡已恢復。
- 仍報 `Could not resolve host`：DNS 未通，切 Wi-Fi/移動數據後重試。
- 卡住到超時：網絡被掐，檢查手機網絡/VPN/信號。

**處理**：網絡恢復後跑 `bash ~/.termux/tasker/sync.sh` 補推；本地積壓改動會在該輪 fetch→merge→push 自動補齊。

**數據安全**：錄音歸檔先在本地倉庫提交、音頻進本地 LFS 緩存，推送只是最後一步；推送失敗不丟素材，下一輪定時任務（或手動跑腳本）在網絡恢復後自動補推。

**易混區分**：
- Termux 軟件鏡像報 `429 Too Many Requests`、`pkg install` 失敗、倉庫 not signed：這是軟件源限流/校驗問題，**與 GitHub 同步鏈路無關**；需要裝工具時用 `termux-change-repo` 換鏡像。
- `nslookup` 屬於 dnsutils，未安裝時用上面的 `curl` 測試，不必為此強行裝包。

### 6.5 分叉事故根因、修復與預防（2026-11-13 晚）

**現象**：雙端同日改同一日記，Mac 端出現衝突；手動刪標記保留正確內容後，改動很快被「遠端反彈」覆蓋，只能爭分奪秒 `git push --force` 才保住。

**根因（不是遠端主動覆蓋本地，而是本地腳本把自己逼成分叉）**
1. **merge 失敗後流程未中斷**：舊腳本 `git merge` 被 index.lock 連擋、或被 `local changes would be overwritten` 中止後，`else` 分支只記日誌、沒有 `return`，流程繼續往下 `git add -A` 並提交。這些提交基於舊基線，push 全部 non-fast-forward 被拒，本地與遠端越岔越遠。
2. **衝突檢測覆蓋不全**：只認 `<<<<<<<` 標記與 U 狀態；merge 被「本地改動會被覆蓋」中止、尚未進入標記階段時，檢測不到而放行，繼續自動提交。
3. **並發搶同一倉庫**：fswatch 監聽子進程與 60 秒輪詢同時觸發，反覆搶 index.lock；重試邏輯把非鎖錯誤也當鎖問題反覆重試，加劇分叉。

**修復（已上線，提交 `5cb0989d7`）**
- merge 失敗分支：記日誌、清 rebase 殘留、更新時間戳後 `return 0` 中斷本輪，**不再 add/commit**；工作區改動原樣保留。
- `stage_resolved_conflicts()`：fetch 後、merge 後兩次檢查；標記已清空自動暫存接管，仍含標記則暫停所有自動寫操作。
- `QUIET_GAP` 靜置緩衝：改動文件在緩衝窗內仍被修改，本輪先不提交，留待下一輪，避免編輯中途被搶提交。
- 腳本全程無 `reset --hard`、無 `checkout --theirs`、無 `git clean`、無 force push。

**預防要點**
- 衝突未解期間，腳本凍結自動 Git 寫操作；只在編輯器裡改，標記清空後由腳本自動接管收尾。
- 不要在分叉未理清時反覆手動 push；先 `git fetch` 看對齊計數（6.1），確認本地基線。
- 若日誌反覆出現 `index.lock` 或 `local changes would be overwritten`，先停掉重試、保留工作區，按 6.2 處理，不要靠 force push 解圍。

**另一種 push 被拒：基線過期（非分叉、非衝突）**
- 報錯形如 `cannot lock ref 'refs/heads/main': is at <新tip> but expected <舊tip>`。本端 fetch 之後、push 之前，另一端又推了新提交，遠端 tip 前進，本地拿舊基線去推被拒。
- 處理：重跑一次同步腳本（`fetch` → 合併最新遠端 → 普通 push）即可；這不是內容衝突，不需要 force。
- 與 non-fast-forward 分叉的區別：後者本地有基於舊歷史的獨立提交，需先合併；前者只是基線快照過期，重跑同步自動追上。

## 7. 大型檔案與忽略規則（不改歷史）

`.gitignore` 關鍵規則：
```gitignore
*.log
*.bak
*.bak-*
.DS_Store
logseq/bak/
logseq/.recycle
.logs/
.sync_debounce
.sync_debounce_v2
assets/*.mp4
assets/*.mov
assets/*.zip
```

已被追蹤的大檔，只移出索引、不刪磁碟檔：
```bash
git ls-files -z 'assets/*.mp4' 'assets/*.mov' 'assets/*.zip' | xargs -0 -r git rm --cached --
git add .gitignore
git commit -m "chore: ignore large media and internal files"
```
> 僅改 `.gitignore` 無法移除已在歷史中的大檔；此策略只保證「以後不再提交」。清理舊歷史另用 Git LFS 或 git-filter-repo。

## 8. 新機最小部署步驟

### Mac
1. 確認依賴：`git --version`、`git lfs version`；`brew install fswatch`
2. 克隆倉庫到 `/Users/mac/Documents/Sync-Logseq`
3. 確認 `.gitignore` 含第 7 節規則；`.gitattributes` 含第 4 節 LFS 規則
4. `logseq_sync_optimized.sh` 已隨倉庫帶入，`chmod 755`
5. 放置 `com.logseq.sync.v2.plist`（第 2.1 節），`chmod 644`
6. 啟用：`launchctl load -w ~/Library/LaunchAgents/com.logseq.sync.v2.plist`
7. 驗證：`launchctl list | grep com.logseq.sync.v2`；`tail -n 100 .logs/sync.log`
8. 做一次小提交，60 秒內應看到本地拉取與推送

### 手機
1. 克隆到第 1 節實體路徑；確認 `git --version`、`git lfs version`
2. 從倉庫 `scripts/android/` 複製 `sync.sh`、`auto_log_oneshot.sh`、`.auto_log_ignore` 到 `~/.termux/tasker/`，並 `chmod 700 sync.sh auto_log_oneshot.sh`
3. 按第 3.2 節配 Tasker Profiles 與 FolderSync
4. 跑第 6.1 節核對命令，確認 `0 0` 對齊

### 倉庫內其餘跟蹤文件
- `logseq_sync_optimized.sh`：Mac 主同步腳本（第 2.2 節）。
- `log_manager.sh`：Mac 日誌管理工具（離線維護用，不進同步主流程）。
- `.githooks/pre-commit` + `scripts/install-hooks.sh`：提交前攔截 >100MB 檔案；安裝後 `chmod +x .git/hooks/pre-commit`。
- `scripts/sync_logseq_journals.py`：Notion 鏡像同步（第 10 節）。
- `fix_webhook_data.py`：歷史一次性工具，日常同步不依賴。

## 9. 安全底線
- **不強制推送：本倉庫不用 `git push --force`，也不用 `--force-with-lease`** 覆蓋遠端歷史。普通分叉先用 `git pull --no-edit` 合併遠端，再普通 push。
- force push 的實際後果（本次事故已驗證）：頂掉遠端 tip 後，被跳過的提交及其引入的 LFS 實體引用一併丟失；實體可能在遠端 LFS 存儲保留一段時間，但其他端無法經 main 引用取回，只能從 dangling 提交、本地 LFS 緩存或原始錄製端找回。本次一條 141MB 錄音被擠出 main，事後靠指針 oid 從遠端 LFS 重新拉回，屬僥倖；對象被回收後即無法恢復。
- 未完整備份前不刪本地檔案。
- 衝突期間不自動 add 衝突檔，避免把未核對內容提交進去。
- 執行任何刪除腳本前：路徑用絕對路徑、先搜 `rm -rf` 等危險命令、確認變數已正確展開、先在安全環境測試、刪除前二次確認目標路徑。
- 定期備份：Time Machine、Git 倉庫、離線備份。

## 10. Notion 鏡像鏈路（獨立於 Git 雙端同步）

### 觸發與流程
- 工作流：`.github/workflows/sync-logseq-journals.yml`，push 變更 `journals/**` 時自動觸發，也可在 Actions 頁手動 `workflow_dispatch`。
- 執行：ubuntu-latest → checkout（`fetch-depth: 0`）→ Python 3.11 裝 `requests` → 取出變更的 `journals/*.md` → 跑 `scripts/sync_logseq_journals.py` 寫入 Notion 鏡像庫。
- 腳本只處理 `journals/YYYY-MM-DD.md`；HTTP 請求重試 3 次、遇 429 按 `Retry-After` 退避。

### 依賴（GitHub Secrets，不入倉庫）
- `NOTION_API_KEY`：Notion 整合金鑰。
- `NOTION_LOGSEQ_MIRROR_DATABASE_URL`：鏡像資料庫 URL。
- 缺任一 Secrets，Actions 會在 Python 步驟報錯；Secrets 在倉庫 GitHub Settings → Secrets and variables → Actions 配置。

### 排查
1. Notion 沒更新：先到倉庫 Actions 頁看最近一次運行是成功還是失敗、卡在哪一步。
2. 失敗在 Python 步驟：先核對兩個 Secrets 是否存在/過期，再看日誌是權限、資料庫 URL 還是限流（429）。
3. 注意：Git 雙端 `0 0` 對齊只代表筆記已同步到 GitHub，不代表 Notion 鏡像已更新；兩條鏈路要分開確認。
