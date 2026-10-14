#!/usr/bin/env python3
"""Run against an EMPTY isolated Keystore profile with the QML inspector on port 3768.
Uses a public test mnemonic. Never point this at a personal wallet profile.
"""
from inspector import call

def send(command, params=None):
    result = call(command, params)
    if "error" in result:
        raise RuntimeError(result["error"])
    return result.get("result", result)

import json, time

def obj(name):
 r=send('findByProperty',{'property':'objectName','value':name}); assert r['count']==1,(name,r); return r['matches'][0]['id']
def ev(expr): return send('evaluate',{'objectId':obj('keystoreRoot'),'expression':expr})
def value(expr): return json.loads(ev('JSON.stringify('+expr+')'))
def setp(name,prop,val): return send('setProperty',{'objectId':obj(name),'property':prop,'value':val})
def click(name): return send('click',{'objectId':obj(name)})
def wait_for(expr):
 for _ in range(100):
  if value(expr): return
  time.sleep(.1)
 raise AssertionError((expr,ev('backend.lastError')))
phrase='test test test test test test test test test test test junk'
wait_for('ready && custodian')
assert value('groups.length') == 0, 'This test requires an EMPTY isolated profile'
ev('backend.importMnemonic('+','.join(json.dumps(v) for v in [phrase,'','wallet-test','wallet-test',True,'Ethereum test','phrase-test'])+')')
wait_for('groups.length === 1')
assert value('seedNodes.length')==1
assert value('seedNodes[0].linked') is True
print('PASS: a new Ethereum wallet has a seed parent')

def add(kind,name,badpass=False,typed=False):
 click('addSeedWallet_0');time.sleep(.2)
 setp('seedWalletKind','currentIndex',kind)
 send('evaluate',{'objectId':obj('seedWalletKind'),'expression':'activated('+str(kind)+')'})
 if typed: setp('seedWords','text',phrase)
 else: setp('seedPhrasePassword','text','phrase-test')
 setp('seedWalletPassword','text','wallet-test')
 setp('seedWalletName','text',name)
 if badpass: setp('seedPassphrase','text','wrong-passphrase')
 click('seedAddConfirm')

send('callMethod',{'objectId':obj('seedWalletSheet'),'method':'close','args':[]})
add(1,'Bitcoin test')
wait_for('groups.length === 2')
assert value('seedNodes.length')==1
assert value('groups[0].seedId === groups[1].seedId') is True
print('PASS: Bitcoin and Ethereum share one seed parent via the saved phrase')
add(0,'Wrong seed',badpass=True)
wait_for('backend.lastError.indexOf("do not match") >= 0')
assert value('groups.length')==2
print('PASS: a mismatched BIP39 passphrase is refused without adding a wallet')
send('callMethod',{'objectId':obj('seedWalletSheet'),'method':'close','args':[]})
add(2,'Taproot test')
wait_for('groups.length === 3')
assert value('seedNodes.length')==1
print('PASS: Taproot joins the same seed parent')
add(0,'Ethereum account 1')
wait_for('groups.length === 4')
assert value('seedNodes.length')==1
assert value('groups.some(function(g){return g.pathPrefix === "m/44\'/60\'/1\'"})')
print('PASS: another Ethereum account uses the next unused account branch')
ev('backend.forgetPhrase('+json.dumps(value('phrases[0].id'))+')')
wait_for('phrases.length === 0')
add(1,'Bitcoin account 1',typed=True)
wait_for('groups.length === 5')
assert value('seedNodes.length')==1
print('PASS: re-entering an unsaved phrase also adds a wallet under the same seed')
print('UI checks passed')
