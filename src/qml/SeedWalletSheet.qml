import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

LogosDialog {
    id: sheet
    objectName: "seedWalletSheet"
    title: "Add a wallet from this seed"
    property var backend: null
    property var bundle: null
    property string keptId: ""
    property bool working: false
    readonly property string family: kind.currentIndex === 0 ? "evm" : kind.currentIndex === 1 ? "bitcoin" : "bitcoin_taproot"
    readonly property string chain: testNetwork.checked ? "test" : "main"
    function clearSecrets() { words.text = ""; phrasePw.text = ""; passphrase.text = ""; walletPw.text = "" }
    function suggestAccount() {
        var used = {}
        if (bundle) bundle.nodes.forEach(function(n) {
            var g = n.group
            if ((g.family || "evm") === sheet.family && (sheet.family === "evm" || g.chain === sheet.chain)) {
                var segments = g.pathPrefix.split("/")
                used[parseInt(segments[segments.length - 1])] = true
            }
        })
        var n = 0
        while (used[n]) ++n
        account.text = String(n)
    }
    onOpened: { clearSecrets(); working = false; walletName.text = ""; birthday.text = ""; kind.currentIndex = 0; derivable.checked = false; suggestAccount() }
    onClosed: { clearSecrets(); working = false }
    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 620)
    contentItem: ColumnLayout {
        spacing: Theme.spacing.small
        LogosText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: sheet.keptId ? "Unlock the saved recovery phrase. Its words stay inside the Keystore."
                               : "Enter the recovery phrase for this seed group. It will be checked against the existing wallet and will not be saved."
        }
        LogosTextField {
            id: words; objectName: "seedWords"
            visible: !sheet.keptId
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "Recovery phrase"
        }
        LogosTextField {
            id: phrasePw; objectName: "seedPhrasePassword"
            visible: !!sheet.keptId
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "Saved phrase's password"
        }
        LogosTextField {
            id: passphrase; objectName: "seedPassphrase"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "BIP39 passphrase, if you originally used one"
        }
        RowLayout {
            Layout.fillWidth: true
            ComboBox {
                id: kind; objectName: "seedWalletKind"
                Layout.fillWidth: true
                model: ["Ethereum", "Bitcoin — native segwit", "Bitcoin — taproot"]
                onActivated: sheet.suggestAccount()
            }
            LogosCheckbox {
                id: testNetwork; objectName: "seedTestNetwork"
                visible: sheet.family !== "evm"
                text: "Test networks"; checked: true
                onToggled: sheet.suggestAccount()
            }
        }
        RowLayout {
            LogosText { text: "Account index" }
            LogosTextField {
                id: account; objectName: "seedAccountIndex"
                text: "0"; Layout.fillWidth: true
                validator: RegularExpressionValidator { regularExpression: /[0-9]{1,10}/ }
            }
        }
        LogosTextField {
            id: walletName; objectName: "seedWalletName"
            Layout.fillWidth: true
            placeholderText: "Wallet name (optional)"
        }
        LogosTextField {
            id: walletPw; objectName: "seedWalletPassword"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "Password for the new wallet"
        }
        LogosCheckbox {
            id: derivable; objectName: "seedDerivable"
            visible: sheet.family === "evm"
            text: "Allow adding Ethereum addresses with this wallet password"
        }
        LogosTextField {
            id: birthday; objectName: "seedBirthday"
            visible: sheet.family !== "evm"
            Layout.fillWidth: true
            placeholderText: "First used on, YYYY-MM-DD (optional)"
        }
        LogosText {
            visible: sheet.family !== "evm"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "Leave the date empty if unsure, so the Bitcoin wallet scans from the beginning."
        }
        LogosText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            color: Theme.palette.error
            text: sheet.backend ? sheet.backend.lastError : ""
        }
        RowLayout {
            LogosButton { text: "Cancel"; enabled: !sheet.working; onClicked: sheet.close() }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "seedAddConfirm"
                text: sheet.working ? "Adding…" : "Add wallet"
                enabled: !sheet.working && sheet.bundle && walletPw.text.length > 0
                         && (sheet.keptId ? phrasePw.text.length > 0 : words.text.trim().length > 0)
                         && account.text.length > 0 && Number(account.text) < 2147483648
                onClicked: {
                    var p = { sourceGroup: sheet.bundle.nodes[0].group.id, family: sheet.family,
                        passphrase: passphrase.text, password: walletPw.text, chain: sheet.chain,
                        account: Number(account.text), bip44Account: Number(account.text),
                        storage: derivable.checked ? "extkey" : "plain", groupPassword: walletPw.text,
                        groupLabel: walletName.text.trim(), label: walletName.text.trim() }
                    if (sheet.keptId) { p.keptPhrase = sheet.keptId; p.phrasePassword = phrasePw.text }
                    else p.phrase = words.text
                    if (sheet.family !== "evm" && birthday.text.trim()) p.birthday = birthday.text.trim()
                    sheet.working = true
                    var reply = sheet.backend.addSeedWallet(JSON.stringify(p))
                    p = {}; sheet.clearSecrets()
                    logos.watch(reply, function(ok) { sheet.working = false; if (ok) sheet.close() })
                }
            }
        }
    }
}
