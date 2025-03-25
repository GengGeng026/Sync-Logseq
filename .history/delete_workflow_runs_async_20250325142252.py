import asyncio
import aiohttp
import time
import json

# 替換為您的 GitHub 用戶名、存儲庫名稱和個人訪問令牌
USERNAME = 'GengGeng026'
REPO = 'Sync-Logseq'
TOKEN = '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'

# 初始化計數器
total_deleted = 0
failed_count = 0

async def delete_run(session, run_id):
    global total_deleted, failed_count
    delete_url = f'https://api.github.com/repos/{USERNAME}/{REPO}/actions/runs/{run_id}'
    headers = {
        'Authorization': f'token {TOKEN}',
        'Accept': 'application/vnd.github.v3+json'
    }
    
    try:
        async with session.delete(delete_url, headers=headers) as response:
            if response.status == 204:
                print(f'成功刪除運行 {run_id}')
                total_deleted += 1
            else:
                print(f'刪除運行 {run_id} 失敗: {response.status}')
                failed_count += 1
                text = await response.text()
                if text:
                    print(text)
    except Exception as e:
        print(f'刪除運行 {run_id} 出錯: {str(e)}')
        failed_count += 1

async def process_page(session, page, per_page=100):
    url = f'https://api.github.com/repos/{USERNAME}/{REPO}/actions/runs?page={page}&per_page={per_page}'
    headers = {
        'Authorization': f'token {TOKEN}',
        'Accept': 'application/vnd.github.v3+json'
    }
    
    async with session.get(url, headers=headers) as response:
        if response.status != 200:
            print(f"獲取第 {page} 頁時出錯: {response.status}")
            return []
        
        data = await response.json()
        return data.get('workflow_runs', [])

async def main():
    global total_deleted, failed_count
    
    # 創建會話
    async with aiohttp.ClientSession() as session:
        # 測試連接
        print("測試 API 連接...")
        url = f'https://api.github.com/repos/{USERNAME}/{REPO}/actions/runs'
        headers = {
            'Authorization': f'token {TOKEN}',
            'Accept': 'application/vnd.github.v3+json'
        }
        
        async with session.get(url, headers=headers) as response:
            if response.status != 200:
                print(f"API 響應狀態碼: {response.status}")
                print("錯誤響應內容:")
                print(await response.text())
                return
            
            data = await response.json()
            total_runs = data.get('total_count', 0)
            print(f"找到總共 {total_runs} 個工作流程運行")
            
            if total_runs == 0:
                print("沒有找到任何工作流程運行記錄")
                return
        
        # 使用恆定頁面方法 - 總是獲取第一頁
        page_number = 1
        while True:
            print(f"\n獲取頁面 {page_number}...")
            runs = await process_page(session, page_number)
            
            if not runs:
                print("沒有更多工作流程運行記錄")
                break
            
            print(f"找到 {len(runs)} 個工作流程運行")
            
            # 並行刪除任務
            tasks = []
            for run in runs:
                # 為避免過載 API，限制並行任務數量
                if len(tasks) >= 10:
                    await asyncio.gather(*tasks)
                    tasks = []
                    # 短暫暫停
                    await asyncio.sleep(1)
                
                tasks.append(delete_run(session, run['id']))
            
            if tasks:
                await asyncio.gather(*tasks)
            
            # 如果這一頁不是滿的，嘗試獲取下一頁
            if len(runs) < 100:
                page_number += 1
            # 否則保持在第一頁，因為新的運行會填充第一頁
            
            # 每處理一頁後暫停，避免 API 限制
            await asyncio.sleep(2)
    
    print(f"\n總共成功刪除 {total_deleted} 個工作流程運行記錄")
    print(f"失敗: {failed_count}")

if __name__ == "__main__":
    asyncio.run(main()) 