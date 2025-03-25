import requests
import time
import json

# 替換為您的 GitHub 用戶名、存儲庫名稱和個人訪問令牌
USERNAME = 'GengGeng026'
REPO = 'Sync-Logseq'
TOKEN = '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'  # 替換為您已有的令牌

# GitHub API URL
url = f'https://api.github.com/repos/{USERNAME}/{REPO}/actions/runs'

# 設置請求頭
headers = {
    'Authorization': f'token {TOKEN}',
    'Accept': 'application/vnd.github.v3+json'
}

# 首先測試連接
print("測試 API 連接...")
response = requests.get(url, headers=headers)
print(f"API 響應狀態碼: {response.status_code}")

# 如果響應不是 200，打印詳細錯誤信息
if response.status_code != 200:
    print("錯誤響應內容:")
    print(json.dumps(response.json(), indent=2))
    exit(1)

# 獲取總數
data = response.json()
total_runs = data.get('total_count', 0)
print(f"找到總共 {total_runs} 個工作流程運行")

if total_runs == 0:
    print("沒有找到任何工作流程運行記錄")
    exit(0)

# 處理分頁
page = 1
total_deleted = 0

while True:
    print(f"\n處理第 {page} 頁...")
    response = requests.get(f'{url}?page={page}&per_page=100', headers=headers)
    
    if response.status_code != 200:
        print(f"獲取第 {page} 頁時出錯:")
        print(json.dumps(response.json(), indent=2))
        break
    
    data = response.json()
    runs = data.get('workflow_runs', [])
    
    if not runs:
        print("沒有更多工作流程運行記錄")
        break
    
    print(f"本頁找到 {len(runs)} 個工作流程運行")
    
    # 刪除每個工作流程運行
    for run in runs:
        run_id = run['id']
        delete_url = f'{url}/{run_id}'
        delete_response = requests.delete(delete_url, headers=headers)
        
        if delete_response.status_code == 204:
            print(f'成功刪除運行 {run_id}')
            total_deleted += 1
        else:
            print(f'刪除運行 {run_id} 失敗: {delete_response.status_code}')
            if delete_response.text:
                print(delete_response.text)
        
        # 添加短暫延遲避免 API 限制
        time.sleep(0.5)
    
    if len(runs) < 100:
        break
    
    page += 1

print(f"\n總共成功刪除 {total_deleted} 個工作流程運行記錄")