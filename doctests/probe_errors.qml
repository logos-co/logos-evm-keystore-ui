// The Keys view LOADED and DRIVEN offscreen, with a fabricated shell and backend: one backend
// error, one place. The backend keeps a single lastError for every action; a sheet shows the
// error its own call answered with, in words, and the page line shows only what the page did.
// The fake backend's members are the .rep's PROPs and SLOTs, one for one.
import QtQuick

Item {
    id: probe
    width: 1000
    height: 900

    property int failures: 0
    function check(label, got, want) {
        var ok = String(got) === String(want)
        if (!ok) probe.failures++
        console.log((ok ? "  PASS  " : "  FAIL  ") + label + "   got=" + got + (ok ? "" : "  want=" + want))
    }
    // Popups keep their items under contentItem, not under data.
    function kids(o) {
        var out = []
        if (o.data !== undefined) for (var i = 0; i < o.data.length; ++i) out.push(o.data[i])
        if (o.contentItem !== undefined && o.contentItem !== null && out.indexOf(o.contentItem) < 0) out.push(o.contentItem)
        return out
    }
    function find(o, name) {
        if (!o) return null
        if (o.objectName === name) return o
        var k = probe.kids(o)
        for (var i = 0; i < k.length; ++i) { var hit = probe.find(k[i], name); if (hit) return hit }
        return null
    }
    function shown(name) { var o = probe.find(view.item, name); return o !== null && o.visible ? o.text : "" }
    function sheet(name) { return probe.find(view.item, name) }

    QtObject {
        id: shell
        signal intentRequested(string requestId, string intent, var params, string requesterName)
        signal viewModuleReadyChanged(string moduleName, bool isReady)
        function module(n) { return fake }
        function isViewModuleReady(n) { return true }
        // `lose` makes the next call fail as a lost QtRO call would: the error callback, not the answer.
        property bool lose: false
        function watch(value, cb, err) {
            if (shell.lose) { shell.lose = false; if (err) err("call failed"); return }
            if (cb) cb(value)
        }
        function request(intent, params, cb) {}
        function respond(requestId, ok, data, error) {}
    }
    property var logos: shell

    QtObject {
        id: fake
        // A SLOT answers replies[name] when set, else its type's default; errors[name] is what it
        // leaves in lastError ("" on success, as the backend clears it).
        property var replies: ({})
        property var errors: ({})
        function answer(name, args, dflt) {
            fake.lastError = fake.errors[name] || ""
            return fake.replies[name] !== undefined ? fake.replies[name] : dflt
        }
        property string statusText: "Starting"
        property string lastError: ""
        property bool busy: false
        property string accountsJson: "[]"
        property string labelsJson: "{}"
        property string groupsJson: "[]"
        property int lockedWallets: 0
        property string lockedSeedsJson: "[]"
        property string addAgainJson: "[]"
        property string emptyWalletsJson: "[]"
        property string olderKeystoreJson: "{}"
        property string provenanceJson: "{}"
        property string walletNamesJson: "{}"
        property string readsJson: "{}"
        property string keyDirectoryJson: "{}"
        property string identityJson: "{}"
        property bool isCustodian: false
        property string phrasesJson: "[]"
        property bool isManagerCustodian: false
        property string accessJson: "[]"
        property string accessShownJson: "{}"
        property string openJson: "[]"
        property string deviceAccountsJson: "[]"
        property string deviceWalletsJson: "[]"
        property string bitcoinRosterJson: "[]"
        function refresh() { return fake.answer("refresh", [], undefined) }
        function refreshAccess() { return fake.answer("refreshAccess", [], undefined) }
        function showAccess(handle) { return fake.answer("showAccess", [handle], true) }
        function approveAccess(handle, bundleId, group, password) { return fake.answer("approveAccess", [handle, bundleId, group, password], true) }
        function forgetDeviceWallet(signer, account) { return fake.answer("forgetDeviceWallet", [signer, account], true) }
        function rejectAccess(handle) { return fake.answer("rejectAccess", [handle], true) }
        function dismissAccess() { return fake.answer("dismissAccess", [], undefined) }
        function closeWallet(module, group) { return fake.answer("closeWallet", [module, group], true) }
        function generateMnemonic(words) { return fake.answer("generateMnemonic", [words], "") }
        function previewSource(paramsJson) { return fake.answer("previewSource", [paramsJson], "") }
        function saveAccounts(paramsJson) { return fake.answer("saveAccounts", [paramsJson], "") }
        function importMnemonic(phrase, bip39Passphrase, accountPassword, groupPassword, derivable, groupLabel, keepPhrasePassword) { return fake.answer("importMnemonic", [phrase, bip39Passphrase, accountPassword, groupPassword, derivable, groupLabel, keepPhrasePassword], true) }
        function addSeedWallet(paramsJson) { return fake.answer("addSeedWallet", [paramsJson], true) }
        function restoreUnlockRoot(paramsJson) { return fake.answer("restoreUnlockRoot", [paramsJson], true) }
        function moveOlderKeystore() { return fake.answer("moveOlderKeystore", [], true) }
        function importMnemonicFromKept(phraseId, phrasePassword, bip39Passphrase, accountPassword, groupPassword, derivable, groupLabel) { return fake.answer("importMnemonicFromKept", [phraseId, phrasePassword, bip39Passphrase, accountPassword, groupPassword, derivable, groupLabel], true) }
        function importPrivateKey(privHex, accountPassword) { return fake.answer("importPrivateKey", [privHex, accountPassword], true) }
        function importVaultJson(vaultJson, oldPassword, newPassword) { return fake.answer("importVaultJson", [vaultJson, oldPassword, newPassword], true) }
        function importVaultFile(fileUrl, oldPassword, newPassword) { return fake.answer("importVaultFile", [fileUrl, oldPassword, newPassword], true) }
        function deriveNextAccount(group, groupPassword, accountPassword) { return fake.answer("deriveNextAccount", [group, groupPassword, accountPassword], true) }
        function deriveAccountAt(group, groupPassword, accountPassword, bip44Account, change, index) { return fake.answer("deriveAccountAt", [group, groupPassword, accountPassword, bip44Account, change, index], true) }
        function previewAddresses(group, groupPassword, change, from, count) { return fake.answer("previewAddresses", [group, groupPassword, change, from, count], "") }
        function forgetDerivation(group) { return fake.answer("forgetDerivation", [group], true) }
        function exportVaultJson(address, password) { return fake.answer("exportVaultJson", [address, password], "") }
        function setLabel(address, label, password) { return fake.answer("setLabel", [address, label, password], true) }
        function setWalletName(group, name, address, password) { return fake.answer("setWalletName", [group, name, address, password], true) }
        function setSeedWalletName(group, name, address, password) { return fake.answer("setSeedWalletName", [group, name, address, password], true) }
        function removeWallet(group) { return fake.answer("removeWallet", [group], true) }
        function removeSeedWallet(seed, password) { return fake.answer("removeSeedWallet", [seed, password], true) }
        function changePassword(address, oldPassword, newPassword) { return fake.answer("changePassword", [address, oldPassword, newPassword], true) }
        function importBitcoin(phrase, bip39Passphrase, family, chain, password, label, keepPhrasePassword) { return fake.answer("importBitcoin", [phrase, bip39Passphrase, family, chain, password, label, keepPhrasePassword], "") }
        function importBitcoinFromKept(phraseId, phrasePassword, bip39Passphrase, family, chain, password, label) { return fake.answer("importBitcoinFromKept", [phraseId, phrasePassword, bip39Passphrase, family, chain, password, label], "") }
        function showPhrase(phraseId, password) { return fake.answer("showPhrase", [phraseId, password], "") }
        function forgetPhrase(phraseId) { return fake.answer("forgetPhrase", [phraseId], true) }
        function walletDescriptors(group) { return fake.answer("walletDescriptors", [group], "") }
        function deleteAccount(address, password) { return fake.answer("deleteAccount", [address, password], true) }
        function deleteBitcoinAccount(group, password) { return fake.answer("deleteBitcoinAccount", [group, password], true) }
        function changeWalletPassword(seed, passwordsJson, newPassword) { return fake.answer("changeWalletPassword", [seed, passwordsJson, newPassword], "") }
    }

    function assertASheetErrorStaysInItsSheet() {
        console.log("")
        console.log("a refused password change shows in its sheet only, in words, and is gone once it closes")
        var s = probe.sheet("accountPasswordSheet")
        s.address = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
        s.open()
        check("the sheet is up", s.visible, true)
        check("it opens with no error", probe.shown("accountPasswordError"), "")
        fake.replies = { changePassword: false }
        fake.errors = { changePassword: "WrongSecret: the password for this account is not correct" }
        probe.find(view.item, "oldPasswordField").text = "wrong"
        probe.find(view.item, "newPasswordField").text = "newpass"
        check("two copies that differ say so", probe.shown("accountPasswordHint"), "")
        probe.find(view.item, "repeatPasswordField").text = "newpasX"
        check("...once the second is typed", probe.shown("accountPasswordHint"), "The two new passwords don't match.")
        probe.find(view.item, "repeatPasswordField").text = "newpass"
        check("...and Change is on once they match", probe.find(view.item, "changePasswordConfirm").enabled, true)
        probe.find(view.item, "changePasswordConfirm").clicked()
        check("refused: the reason in the sheet, without its code", probe.shown("accountPasswordError"),
              "The password for this account is not correct")
        check("...and not on the page behind it", probe.shown("errorLabel"), "")
        s.close()
        check("the sheet is closed", s.visible, false)
        check("closed: not on the page either", probe.shown("errorLabel"), "")
        s.open()
        check("reopened: the sheet starts clean", probe.shown("accountPasswordError"), "")
        probe.find(view.item, "newPasswordField").text = "newpass"
        check("a new password with no current one says so", probe.shown("accountPasswordHint"), "Type the current password too.")
        probe.find(view.item, "oldPasswordField").text = "old"
        probe.find(view.item, "repeatPasswordField").text = "newpass"
        shell.lose = true
        probe.find(view.item, "changePasswordConfirm").clicked()
        check("a call lost on the way: the sheet is usable again", probe.find(view.item, "changePasswordConfirm").enabled, true)
        check("...and says so", probe.shown("accountPasswordError"), "The Keys app did not answer. Try again.")
        s.close()

        var r = probe.sheet("removeAccountSheet")
        r.entry = { family: "evm", address: "0x9858EfFD232B4033E47d90003D41EC34EcaEda94", label: "" }
        r.open()
        check("another sheet shows nothing stale", probe.shown("removeAccountError"), "")
        r.close()
        fake.replies = ({})
        fake.errors = ({})
    }

    function assertThePageShowsOnlyItsOwnError() {
        console.log("")
        console.log("the page line shows the page's own error, hides while a sheet is up, and stays gone after")
        fake.lastError = "Locked: the keystore is locked"
        check("a page error, in words", probe.shown("errorLabel"), "The keystore is locked")
        var s = probe.sheet("exportAccountSheet")
        s.open()
        check("...not while a sheet is up", probe.shown("errorLabel"), "")
        s.close()
        check("...nor once it closes", probe.shown("errorLabel"), "")
        fake.lastError = ""
        fake.lastError = "Locked: the keystore is locked"
        check("the same words after a success: shown again", probe.shown("errorLabel"), "The keystore is locked")
        fake.lastError = ""
        check("a success clears it", probe.shown("errorLabel"), "")
    }

    function assertEveryRefusingSheetSaysWhy() {
        console.log("")
        console.log("a sheet that showed no error of its own now says why its action was refused")
        var s = probe.sheet("exportAccountSheet")
        s.address = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
        s.open()
        fake.replies = { exportVaultJson: "" }
        fake.errors = { exportVaultJson: "WrongSecret: the password for this account is not correct" }
        probe.find(view.item, "exportPasswordField").text = "wrong"
        probe.find(view.item, "exportConfirm").clicked()
        check("export refused: said in the sheet", probe.shown("exportError"), "The password for this account is not correct")
        check("...not on the page", probe.shown("errorLabel"), "")
        s.close()
        check("closed: gone everywhere", probe.shown("exportError") + probe.shown("errorLabel"), "")
        fake.replies = ({})
        fake.errors = ({})
        fake.lastError = ""
    }

    Loader {
        id: view
        anchors.fill: parent
        onStatusChanged: {
            if (status === Loader.Error) { console.log("  FAIL  the view did not load"); Qt.exit(1) }
            if (status !== Loader.Ready) return
            item.ready = true
            // Popups open only in a window, and the window comes after this load: run on the next turn.
            run.start()
        }
    }
    Timer {
        id: run
        interval: 50
        onTriggered: {
            probe.assertASheetErrorStaysInItsSheet()
            probe.assertThePageShowsOnlyItsOwnError()
            probe.assertEveryRefusingSheetSaysWhy()
            console.log("")
            console.log(probe.failures ? "RESULT: FAILURES" : "RESULT: ALL PASS")
            Qt.exit(probe.failures ? 1 : 0)
        }
    }

    Component.onCompleted: view.source = Qt.resolvedUrl("../src/qml/KeystoreView.qml")
}
