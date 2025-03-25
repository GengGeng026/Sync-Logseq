import requests

# 替換為您的 GitHub 用戶名、存儲庫名稱和個人訪問令牌
USERNAME = 'GengGeng026'  # 替換為您的用戶名
REPO = 'Sync-Logseq'      # 替換為您的存儲庫名稱
TOKEN = '您的個人訪問令牌'  # 替換為您剛才生成的令牌

# GitHub API URL
url = f'https://api.github.com/repos/{USERNAME}/{REPO}/actions/runs'

# 設置請求頭
headers = {
    'Authorization': f'token {TOKEN}',
    'Accept': 'application/vnd.github.v3+json'
}

# 獲取所有工作流程運行
response = requests.get(url, headers=headers)
runs = response.json()

print(f"找到 {len(runs['workflow_runs'])} 個工作流程運行")

# 刪除每個工作流程運行
for run in runs['workflow_runs']:
    run_id = run['id']
    delete_url = f'{url}/{run_id}'
    delete_response = requests.delete(delete_url, headers=headers)
    if delete_response.status_code == 204:
        print(f'成功刪除運行 {run_id}')
    else:
        print(f'刪除運行 {run_id} 失敗: {delete_response.status_code}')
