#!/usr/bin/env python3
"""Live regression on an EMPTY isolated profile. Public test phrase only.
Set QML_INSPECTOR_PORT (default 3769). Never use a personal wallet profile.
"""
import json
import os
import socket
import time

def send(command, params=None):
    with socket.create_connection(('127.0.0.1', int(os.getenv('QML_INSPECTOR_PORT', '3769'))), timeout=60) as s:
        s.sendall((json.dumps({'command': command, 'params': params or {}}) + '\n').encode())
        with s.makefile('rb') as f:
            response = json.loads(f.readline())
    if 'error' in response:
        raise RuntimeError(response)
    return response.get('result', response)

def obj(name):
    result = send('findByProperty', {'property': 'objectName', 'value': name})
    assert result['count'] == 1, (name, result)
    return result['matches'][0]['id']

def evaluate(expr, name='keystoreRoot'):
    return send('evaluate', {'objectId': obj(name), 'expression': expr})

def value(expr, name='keystoreRoot'):
    return json.loads(evaluate('JSON.stringify(' + expr + ')', name))

def setp(name, prop, val):
    send('setProperty', {'objectId': obj(name), 'property': prop, 'value': val})

def click(name):
    send('click', {'objectId': obj(name)})

def wait(expr, name='keystoreRoot'):
    for _ in range(400):
        if value(expr, name):
            return
        time.sleep(.1)
    raise AssertionError((expr, value('backend.lastError')))

def close():
    evaluate('close()', 'accountFlowSheet')

def select_coin(n):
    setp('flowCoin', 'currentIndex', n)
    evaluate('activated(' + str(n) + ')', 'flowCoin')
    wait('!working && rows.length === 5', 'accountFlowSheet')

def save():
    click('flowReview')
    setp('flowPassword', 'text', 'flow-test-password')
    setp('flowRepeatPassword', 'text', 'flow-test-password')
    click('flowSave')
    wait('!working', 'accountFlowSheet')

if __name__ == '__main__':
    wait('ready && custodian')
    assert value('groups.length === 0 && accounts.length === 0 && phrases.length === 0'), 'Requires EMPTY isolated profile'
    assert send('findByProperty', {'property': 'objectName', 'value': 'deviceAccounts'})['count'] == 0
    click('newAccountButton')
    wait('generated.length > 0 && !working', 'accountFlowSheet')
    assert value('step === 0 && selected.length === 0', 'accountFlowSheet')
    close()
    assert value('groups.length === 0 && accounts.length === 0 && phrases.length === 0')
    assert value('generated === ""', 'accountFlowSheet')
    print('PASS: cancelled creation leaves no keys or saved recovery source', flush=True)

    click('importAccountsButton'); click('flowImportPhrase')
    setp('flowWords', 'text', 'invalid recovery phrase')
    click('flowContinue'); wait('!working', 'accountFlowSheet')
    assert value('step === 0 && notice.length > 0', 'accountFlowSheet')
    setp('flowWords', 'text', 'test test test test test test test test test test test junk')
    click('flowContinue'); wait('step === 1 && rows.length === 5 && !working', 'accountFlowSheet')
    assert value('rows[0].address.toLowerCase()', 'accountFlowSheet') == '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266'
    click('flowSelect_0'); click('flowNext'); wait('!working && rows[0].index === 5', 'accountFlowSheet')
    click('flowSelect_0')
    select_coin(1); click('flowSelect_0')
    assert value('selected.length', 'accountFlowSheet') == 3
    assert value('groups.length === 0 && accounts.length === 0 && phrases.length === 0')
    click('flowReview')
    setp('flowName', 'text', 'Personal test')
    setp('flowPassword', 'text', 'flow-test-password')
    setp('flowRepeatPassword', 'text', 'different')
    assert value('enabled', 'flowSave') is False
    setp('flowRepeatPassword', 'text', 'flow-test-password')
    click('flowKeepRecovery'); click('flowSave')
    wait('groups.length === 3 && accounts.length === 2 && phrases.length === 1')
    wait('!opened', 'accountFlowSheet')
    assert value('seedNodes.length') == 1
    assert value('phrases[0].groups.length') == 3
    assert value('groups.every(function(g) { return !g.family ? !g.derivable : true })')
    print('PASS: selection survives pagination and coin changes; independent EVM files plus a Bitcoin account share one encrypted source', flush=True)

    click('addSeedWallet_0')
    setp('flowPhrasePassword', 'text', 'wrong')
    click('flowContinue'); wait('!working', 'accountFlowSheet')
    assert value('step === 0 && notice.length > 0', 'accountFlowSheet')
    setp('flowPhrasePassword', 'text', 'flow-test-password')
    setp('flowHasPassphrase', 'checked', True)
    setp('flowPassphrase', 'text', 'wrong passphrase')
    click('flowContinue'); wait('!working', 'accountFlowSheet')
    assert value('notice.indexOf("do not match") >= 0', 'accountFlowSheet')
    setp('flowHasPassphrase', 'checked', False)
    click('flowContinue'); wait('step === 1 && !working', 'accountFlowSheet')
    assert value('rows[0].present', 'accountFlowSheet') is True
    assert value('enabled', 'flowSelect_0') is False
    select_coin(1)
    assert value('rows[0].present', 'accountFlowSheet') is True
    setp('flowScript', 'currentIndex', 1)
    evaluate('activated(1)', 'flowScript')
    wait('!working && rows[0].family === "bitcoin_taproot"', 'accountFlowSheet')
    click('flowSelect_0'); save()
    wait('groups.length === 4 && phrases.length === 1')
    assert value('seedNodes.length') == 1
    print('PASS: saved source adds Taproot; wrong credentials and already-saved accounts are rejected', flush=True)

    for address in value('accounts'):
        assert value('copyText', 'account_' + address).lower() == address.lower()
        assert value('text', 'path_' + address).startswith("Derivation path: m/44'/60'/0'/0/")
    for group in value('groups.filter(function(g) { return !!g.family })'):
        assert group['preview']['address'].startswith('bc1')
        assert group['preview']['path'] == group['pathPrefix'] + '/0/0'
        assert value('copyText', 'bitcoinAddress_' + group['id']) == group['preview']['address']
        assert value('text', 'bitcoinPath_' + group['id']) == 'Derivation path: ' + group['pathPrefix']
    print('PASS: Ethereum, SegWit and Taproot rows show paths and full copy values', flush=True)
