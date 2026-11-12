#!/usr/bin/env python3
"""Discover NetworkManager VPN profiles and report their connection state."""
import json, os, pathlib, shlex, shutil, subprocess, sys, urllib.request

def nm(*args):
    return subprocess.run(['nmcli', *args], text=True, capture_output=True, timeout=15, check=True).stdout

def profiles():
    result=[]
    if not shutil.which('nmcli'): return result
    try:
        ids=nm('-g','UUID','connection','show').splitlines()
        active=set(nm('-g','UUID','connection','show','--active').splitlines())
    except subprocess.SubprocessError:
        return result
    for uid in ids:
        try:
            lines=nm('-g','connection.id,connection.type','connection','show','uuid',uid).splitlines()
            if len(lines)>=2 and lines[1] in ('vpn','wireguard'):
                result.append({'id':uid,'name':lines[0],'active':uid in active})
        except subprocess.SubprocessError: pass
    return result

def tunnel_active():
    if not shutil.which('ip'): return False
    try:
        proc = subprocess.run(['ip', '-j', '-d', 'link', 'show', 'up'], text=True, capture_output=True, timeout=3, check=True)
        for link in json.loads(proc.stdout):
            name = str(link.get('ifname','')).lower()
            kind = str(link.get('linkinfo', {}).get('info_kind', '')).lower()
            if kind in ('tun', 'wireguard', 'ppp') or name.startswith(('tun','tap','utun','ppp','wg','proton','mullvad','tailscale','warp','nordlynx','amnezia','awgtun')):
                return True
    except (OSError, ValueError, subprocess.SubprocessError): pass
    return False

def main():
    op=sys.argv[1] if len(sys.argv)>1 else 'list'
    if op in ('up','down'):
        uid=sys.argv[2]
        if not any(p['id']==uid for p in profiles()): raise ValueError('VPN profile not found')
        nm('connection',op,'uuid',uid)
        return {'ok':True,'profiles':profiles(),'tunnelActive':tunnel_active()}
    if op=='geo':
        req=urllib.request.Request('https://ipwho.is/',headers={'User-Agent':'Panacea VPN indicator'})
        with urllib.request.urlopen(req,timeout=6) as response: data=json.load(response)
        if not data.get('success'): raise ValueError('Location unavailable')
        return {'country':str(data.get('country_code','')).upper(),'name':str(data.get('country',''))}
    apps=[]
    seen=set()
    locations=[pathlib.Path.home()/'.local/share/applications', pathlib.Path('/usr/local/share/applications'), pathlib.Path('/usr/share/applications')]
    for folder in locations:
        if not folder.is_dir(): continue
        for file in folder.glob('*.desktop'):
            try:
                data={}
                for line in file.read_text(errors='replace').splitlines():
                    if line.startswith('[') and line != '[Desktop Entry]': break
                    if '=' in line:
                        key,value=line.split('=',1)
                        if key in ('Name','Exec','Hidden','NoDisplay','TryExec','GenericName','Comment','Keywords','Categories'): data[key]=value
                name=data.get('Name','')
                searchable = ' '.join([file.stem, name, data.get('Exec',''), data.get('GenericName',''), data.get('Comment',''), data.get('Keywords','')]).casefold()
                names = ('vpn', 'happ', 'hiddify', 'nekoray', 'nekobox', 'v2ray', 'v2raya', 'qv2ray', 'clash', 'mihomo', 'sing-box', 'singbox', 'amnezia', 'wireguard', 'openconnect', 'openvpn', 'tailscale', 'zerotier', 'windscribe', 'mullvad', 'proton', 'nordvpn', 'outline', 'shadowsocks', 'surfshark', 'expressvpn', 'tunnelbear', 'ivpn', 'psiphon', 'browsec', 'forticlient', 'cisco anyconnect', 'pritunl', 'softether')
                if not any(token in searchable for token in names) or data.get('Hidden')=='true' or data.get('NoDisplay')=='true': continue
                argv=shlex.split(data.get('Exec',''))
                executable=data.get('TryExec') or (argv[0] if argv else '')
                if not executable or not shutil.which(executable): continue
                key=name.casefold()
                if key not in seen:
                    seen.add(key); apps.append({'name':name,'desktop':str(file)})
            except (OSError, ValueError): pass
    return {'profiles':profiles(),'apps':apps,'networkManager':bool(shutil.which('nmcli')),'tunnelActive':tunnel_active()}
try: print(json.dumps(main(),ensure_ascii=False))
except Exception as e: print(json.dumps({'error':str(e)},ensure_ascii=False))
