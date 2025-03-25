import requests
import time

# 替換為您的 GitHub 用戶名、存儲庫名稱和個人訪問令牌
USERNAME = 'GengGeng026'
REPO = 'Sync-Logseq'
TOKEN = '這裡貼上您的令牌'  # 替換為您已有的令牌

# GitHub API URL
url = f'https://api.github.com/repos/{USERNAME}/{REPO}/actions/runs'

# 設置請求頭
headers = {
    'Authorization': f'token {TOKEN}',
    'Accept': 'application/vnd.github.v3+json'
}

# 處理分頁
page = 1
total_deleted = 0

while True:
    # 獲取當前頁的工作流程運行
    response = requests.get(f'{url}?page={page}&per_page=100', headers=headers)
    data = response.json()
    
    if 'workflow_runs' not in data or len(data['workflow_runs']) == 0:
        break
    
    print(f"處理第 {page} 頁，找到 {len(data['workflow_runs'])} 個工作流程運行")
    
    # 刪除每個工作流程運行
    for run in data['workflow_runs']:
        run_id = run['id']
        delete_url = f'{url}/{run_id}'
        delete_response = requests.delete(delete_url, headers=headers)
        
        if delete_response.status_code == 204:
            print(f'成功刪除運行 {run_id}')
            total_deleted += 1
        else:
            print(f'刪除運行 {run_id} 失敗: {delete_response.status_code}')
        
        # 添加短暫延遲避免 API 限制
        time.sleep(0.5)
    
    # 如果這頁不滿 100 條，說明已經處理完所有記錄
    if len(data['workflow_runs']) < 100:
        break
    
    page += 1

print(f"總共成功刪除 {total_deleted} 個工作流程運行記錄")