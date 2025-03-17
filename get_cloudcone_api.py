import requests
import json

try:
    # 设置请求头，模拟浏览器访问
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'application/json',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://cloudcone-api.readme.io/reference/welcome',
        'Origin': 'https://cloudcone-api.readme.io'
    }

    # 获取API文档页面
    response = requests.get('https://cloudcone-api.readme.io/api/v1/docs/welcome', headers=headers)
    response.raise_for_status()
    
    # 解析JSON响应
    data = response.json()
    
    # 提取API信息
    api_info = {
        'title': data.get('title', 'No title found'),
        'description': data.get('body', 'No description found')[:1000],
        'endpoints': []
    }
    
    # 获取API端点列表
    endpoints_response = requests.get('https://cloudcone-api.readme.io/api/v1/categories', headers=headers)
    endpoints_response.raise_for_status()
    
    # 解析端点信息
    endpoints_data = endpoints_response.json()
    for category in endpoints_data:
        for doc in category.get('docs', []):
            api_info['endpoints'].append({
                'name': doc.get('title', 'Unknown'),
                'url': doc.get('slug', 'Unknown')
            })
            if len(api_info['endpoints']) >= 10:
                break
        if len(api_info['endpoints']) >= 10:
            break
    
    # 输出结果
    print(json.dumps(api_info, ensure_ascii=False, indent=2))
    
except Exception as e:
    print(f'Error: {str(e)}')
    
    # 如果API请求失败，尝试获取基本信息
    try:
        response = requests.get('https://cloudcone-api.readme.io/reference/welcome', 
                               headers=headers)
        print(f'Status code: {response.status_code}')
        print(f'Content type: {response.headers.get("content-type")}')
        print(f'First 500 characters: {response.text[:500]}')
    except Exception as e2:
        print(f'Secondary error: {str(e2)}')