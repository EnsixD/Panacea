#!/usr/bin/env python3
"""Discover NetworkManager VPN profiles and report their connection state."""
import json, shutil, subprocess, sys, urllib.request

def nm(*args):
    return subprocess.run(['nmcli', *args], text=True, capture_output=True, timeout=15, check=True).stdout

def profiles():
    result=[]
    if not shutil.which('nmcli'): return result
    ids=nm('-g','UUID','connection','show').splitlines()
    active=set(nm('-g','UUID','connection','show','--active').splitlines())
    for uid in ids:
        try:
            lines=nm('-g','connection.id,connection.type','connection','show','uuid',uid).splitlines()
            if len(lines)>=2 and lines[1] in ('vpn','wireguard'):
                result.append({'id':uid,'name':lines[0],'active':uid in active})
        except subprocess.SubprocessError: pass
    return result

def main():
    op=sys.argv[1] if len(sys.argv)>1 else 'list'
    if op in ('up','down'):
        uid=sys.argv[2]
        if not any(p['id']==uid for p in profiles()): raise ValueError('VPN profile not found')
        nm('connection',op,'uuid',uid)
        return {'ok':True,'profiles':profiles()}
    if op=='geo':
        req=urllib.request.Request('https://ipwho.is/',headers={'User-Agent':'Panacea VPN indicator'})
        with urllib.request.urlopen(req,timeout=6) as response: data=json.load(response)
        if not data.get('success'): raise ValueError('Location unavailable')
        return {'country':str(data.get('country_code','')).upper(),'name':str(data.get('country',''))}
    apps=[]
    for name,exe in [('Mullvad VPN','mullvad-vpn'),('Proton VPN','protonvpn-app'),('NordVPN','nordvpn'),('WARP','warp-cli'),('OpenVPN','openvpn')]:
        if shutil.which(exe): apps.append({'name':name,'exe':exe})
    return {'profiles':profiles(),'apps':apps,'networkManager':bool(shutil.which('nmcli'))}
try: print(json.dumps(main(),ensure_ascii=False))
except Exception as e: print(json.dumps({'error':str(e)},ensure_ascii=False))
