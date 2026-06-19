import urllib.request
import json
import sys

try:
    with urllib.request.urlopen("https://demo.jellyfin.org/stable/api-docs/swagger.json") as url:
        data = json.loads(url.read().decode())
        
        for path in data.get('paths', {}):
            if 'Played' in path:
                print(path)
                for method, details in data['paths'][path].items():
                    print(f"  {method.upper()}: {details.get('summary', '')}")
except Exception as e:
    print(e)
