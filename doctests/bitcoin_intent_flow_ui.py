#!/usr/bin/env python3
"""Request-UI integration on an EMPTY isolated profile (never a personal profile).
Uses a synthetic manager review and the real Keystore backend. It exercises the
same Add a wallet handler as keystore.accounts.open, without granting any access.
QML_INSPECTOR_PORT defaults to 3769. Only the public test mnemonic is used.
"""
import time
from account_flow_ui import click, evaluate, value, setp, send, wait

FLOW = 'accountFlowSheet'
ACCESS = 'accessSheet'
PHRASE = 'test test test test test test test test test test test junk'
PASSWORD = 'intent-test-password'


def request(family, network, number):
    setp(ACCESS, 'shown', {'handle': 'request-' + str(number), 'kind': 'open',
                         'requester': 'Test wallet', 'asked': {'family': family, 'network': network}})
    evaluate('open()', ACCESS)
    click('accessAddWallet')
    wait('opened && step === -1', FLOW)
    assert value('requested', FLOW)
    assert value('family', FLOW) == family
    assert value('chain', FLOW) == ('main' if network == 'bitcoin' else 'test')
    assert not send('findByProperty', {'property': 'objectName', 'value': 'bitcoinImportSheet'})['count']


for _ in range(100):
    try:
        if value('ready'):
            break
    except (OSError, AssertionError):
        pass
    time.sleep(.2)
else:
    raise AssertionError('Keystore UI did not become ready')
assert value('groups.length') == 0, 'Use an empty isolated profile'
request('bitcoin_taproot', 'bitcoin', 0)
click('flowCreatePhrase')
wait('!working && generated.length > 0', FLOW)
setp('flowWordCount', 'currentIndex', 1)
evaluate('activated(1)', 'flowWordCount')
wait('!working && generated.split(" ").length === 18', FLOW)
assert value('visible', 'flowGeneratedWords')
click('flowBack')
assert value('generated.length === 0 && step === -1', FLOW)
click('flowCancel')
assert value('opened && picked === ""', ACCESS)
assert value('groups.length') == 0
assert value('requestHandle === "" && presetFamily === "" && presetChain === ""', FLOW)
evaluate('close()', ACCESS)
print('PASS request uses numbered phrase wizard; cancellation clears context and leaves approval pending')

for i, (family, network) in enumerate([('bitcoin', 'bitcoin'), ('bitcoin', 'regtest'),
                                     ('bitcoin_taproot', 'bitcoin'), ('bitcoin_taproot', 'signet')]):
    request(family, network, i + 1)
    if i == 0:
        click('flowImportPhrase')
        setp('flowWords', 'text', PHRASE)
    else:
        click('flowUseKept')
        setp('flowPhrasePassword', 'text', PASSWORD)
    click('flowContinue')
    wait('!working && step === 1 && rows.length === 5', FLOW)
    assert all(r['family'] == family and r['chain'] == ('main' if network == 'bitcoin' else 'test') for r in value('rows', FLOW))
    for name in ['flowCoin', 'flowTestnet', 'flowScript']:
        assert not value('enabled', name), name
    click('flowSelect_0')
    click('flowReview')
    setp('flowPassword', 'text', PASSWORD)
    setp('flowRepeatPassword', 'text', PASSWORD)
    if i == 0:
        click('flowKeepRecovery')
    click('flowSave')
    wait('!opened', FLOW)
    wait('target !== null && picked !== ""', ACCESS)
    assert value('opened', ACCESS), 'Saving must leave the access decision pending'
    assert value('target.family', ACCESS) == family
    assert value('target.chain', ACCESS) == ('main' if network == 'bitcoin' else 'test')
    assert value('text', 'accessPasswordField') == '', 'Do not carry the file password into authorization'
    assert not value('enabled', 'accessApproveButton')
    assert value('groups.length') == i + 1
    evaluate('close()', ACCESS)
print('PASS native SegWit and Taproot on main/test networks save and select the correct account without approval')

click('importAccountsButton')
click('flowImportPhrase')
assert not value('requested', FLOW)
assert value('family', FLOW) == 'evm'
assert value('enabled', 'flowCoin')
assert value('enabled', 'flowScript')
assert value('enabled', 'flowTestnet')
evaluate('close()', FLOW)
print('PASS ordinary account creation has no leftover request restrictions')
