# macOS 系統文件恢復指南

## 當前狀況分析
- 恢復文件位置：`/Volumes/Install macOS Ventura`
- SIP 狀態：部分禁用（文件系統保護已禁用）
- 系統：macOS（從 df 輸出看是 APFS 文件系統）

## 安全恢復步驟

### 1. 備份當前系統（必須！）
```bash
# 創建完整的 Time Machine 備份
sudo tmutil startbackup

# 或創建系統快照
sudo tmutil localsnapshot
```

### 2. 進入恢復模式準備
由於涉及系統級文件，建議在恢復模式下操作：

```bash
# 重啟進入恢復模式
sudo shutdown -r now
# 開機時按住 Command + R
```

### 3. 識別需要恢復的文件類型

#### A. 系統核心文件（極度危險，需謹慎）
- `/System/Library/` - 系統庫文件
- `/usr/lib/` - 用戶庫文件
- `/Library/LaunchDaemons/` - 系統守護進程

#### B. 用戶級系統文件（相對安全）
- `/Library/Preferences/` - 系統偏好設置
- `/Library/Application Support/` - 應用程序支持文件
- `/Users/` - 用戶文件

### 4. 分階段恢復策略

#### 第一階段：用戶文件恢復
```bash
# 恢復用戶文件（相對安全）
sudo cp -R "/Volumes/Install macOS Ventura/Users/" "/Users/"

# 恢復應用程序偏好設置
sudo cp -R "/Volumes/Install macOS Ventura/Library/Preferences/" "/Library/Preferences/"
```

#### 第二階段：應用程序文件
```bash
# 恢復應用程序
sudo cp -R "/Volumes/Install macOS Ventura/Applications/" "/Applications/"
```

#### 第三階段：系統文件（最危險）
⚠️ **警告：只有在確定文件完整性的情況下才執行**

```bash
# 檢查文件完整性
sudo /usr/libexec/repair_packages --verify --standard-pkgs

# 逐個恢復關鍵系統文件
sudo cp -R "/Volumes/Install macOS Ventura/System/Library/LaunchDaemons/" "/System/Library/LaunchDaemons/"
```

### 5. 權限修復
```bash
# 修復權限
sudo diskutil resetUserPermissions / `id -u`

# 重建系統緩存
sudo kextcache -system-prelinked-kernel
sudo kextcache -system-caches
```

### 6. 驗證系統完整性
```bash
# 檢查系統文件完整性
sudo /usr/libexec/repair_packages --verify --standard-pkgs

# 檢查磁盤
sudo diskutil verifyVolume /
```

## 建議的執行順序

1. **立即備份**：創建當前系統的完整備份
2. **測試恢復**：先在虛擬機或測試環境中嘗試
3. **分批恢復**：從用戶文件開始，逐步到系統文件
4. **每步驗證**：每恢復一批文件就重啟測試系統穩定性

## 風險評估

### 低風險
- 用戶文件 (`/Users/`)
- 應用程序 (`/Applications/`)
- 用戶偏好設置

### 中風險
- 系統偏好設置 (`/Library/Preferences/`)
- 系統擴展 (`/Library/SystemExtensions/`)

### 高風險
- 系統庫文件 (`/System/Library/`)
- 內核擴展
- 啟動項目

## 緊急恢復計劃

如果系統無法啟動：
1. 從 Time Machine 備份恢復
2. 使用 macOS 恢復模式重新安裝系統
3. 從外部啟動盤啟動系統

## 推薦工具

- **Migration Assistant**：用於安全的用戶數據遷移
- **Disk Utility**：用於磁盤修復和驗證
- **Terminal**：用於精確的文件操作