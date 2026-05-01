#!/usr/bin/env python3
# 修復 Flask webhook 發送正確的 GitHub 格式數據

import re

# 讀取 flask_app.py
with open('/Users/mac/Desktop/GCal-Notion-Sync/flask_app.py', 'r') as f:
    content = f.read()

# 找到 github_webhook 函數並替換
old_webhook_code = '''def github_webhook():
    """GitHub webhook 處理器"""
    try:
        # 觸發 Jenkins 任務
        jenkins_url = 'http://localhost:8081'
        job_name = 'TimeLinkr'
        jenkins_job_url = f"{jenkins_url}/generic-webhook-trigger/invoke?token=generic-webhook-trigger"
        
        headers = {'User-Agent': 'Mozilla/5.0 (compatible; GitHub-Webhook/1.0)'}
        response = requests.get(jenkins_job_url, headers=headers)
        
        return {
            'status': 'success',
            'jenkins_status': response.status_code,
            'message': 'Webhook received and Jenkins triggered'
        }, 200'''

new_webhook_code = '''def github_webhook():
    """GitHub webhook 處理器"""
    try:
        # 觸發 Jenkins 任務
        jenkins_url = 'http://localhost:8081'
        jenkins_job_url = f"{jenkins_url}/generic-webhook-trigger/invoke?token=generic-webhook-trigger"
        
        # 構造符合 Jenkins 期望的 GitHub webhook 數據
        webhook_data = {
            "ref": "refs/heads/dev",
            "repository": {
                "name": "TimeLinkr",
                "full_name": "user/TimeLinkr"
            },
            "pusher": {
                "name": "webhook-trigger"
            },
            "head_commit": {
                "message": "Triggered by webhook"
            }
        }
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (compatible; GitHub-Webhook/1.0)',
            'Content-Type': 'application/json',
            'X-GitHub-Event': 'push'
        }
        
        response = requests.post(jenkins_job_url, json=webhook_data, headers=headers)
        
        return {
            'status': 'success',
            'jenkins_status': response.status_code,
            'jenkins_response': response.text[:200] if response.text else 'No response',
            'message': 'Webhook received and Jenkins triggered'
        }, 200'''

# 替換函數
if old_webhook_code in content:
    content = content.replace(old_webhook_code, new_webhook_code)
    print("✅ 已更新 github_webhook 函數")
else:
    print("❌ 找不到原始函數，手動替換...")
    # 如果找不到完全匹配，嘗試替換關鍵部分
    content = re.sub(
        r'def github_webhook\(\):.*?return \{[^}]+\}, 200',
        new_webhook_code,
        content,
        flags=re.DOTALL
    )
    print("✅ 已嘗試手動替換")

# 寫回文件
with open('/Users/mac/Desktop/GCal-Notion-Sync/flask_app.py', 'w') as f:
    f.write(content)

print("修復完成！")