#!/usr/bin/env python3
import base64, json, mimetypes, pathlib, sys, urllib.error, urllib.request
try:
    request = json.loads(sys.stdin.readline())
    cfg = json.loads((pathlib.Path.home()/'.config/panacea/settings.json').read_text())
    url, model = cfg.get('aiUrl','').strip(), cfg.get('aiModel','').strip()
    if not url or not model: raise ValueError('Укажите адрес API и модель в настройках лаунчера')
    if not url.endswith('/chat/completions'): url = url.rstrip('/')+'/chat/completions'
    messages = request.get('messages', [])[-30:]
    paths = request.get('files', [])
    if paths and messages:
        parts = [{'type':'text','text':messages[-1]['content']}]
        for raw in paths:
            path = pathlib.Path(raw)
            if not path.is_file() or path.stat().st_size > 5*1024*1024: raise ValueError('Файл недоступен или больше 5 МБ: '+path.name)
            data = path.read_bytes(); mime = mimetypes.guess_type(path.name)[0] or 'application/octet-stream'
            if mime.startswith('image/'):
                parts.append({'type':'image_url','image_url':{'url':'data:'+mime+';base64,'+base64.b64encode(data).decode()}})
            else:
                try: text = data.decode('utf-8')
                except UnicodeDecodeError: raise ValueError('Поддерживаются изображения и текстовые файлы: '+path.name)
                parts.append({'type':'text','text':'Файл '+path.name+':\n'+text})
        messages[-1]['content'] = parts
    headers={'Content-Type':'application/json'}
    if cfg.get('aiKey'): headers['Authorization']='Bearer '+cfg['aiKey']
    body=json.dumps({'model':model,'messages':messages},ensure_ascii=False).encode()
    req=urllib.request.Request(url,data=body,headers=headers)
    with urllib.request.urlopen(req,timeout=90) as response: data=json.load(response)
    answer=data['choices'][0]['message']['content']
    print(json.dumps({'answer':answer},ensure_ascii=False))
except Exception as e:
    print(json.dumps({'error':str(e)},ensure_ascii=False))
