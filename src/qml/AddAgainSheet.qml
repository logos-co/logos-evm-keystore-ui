import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme
import "accountkit" as Accounts

// An older build's wallet, added again so the Signer app can open it. A wallet takes its phrase,
// checked against the accounts it already holds; a key its password. Nothing else changes: no
// account is added and no file written again.
LogosDialog {
    id: sheet
    objectName: "addAgainSheet"
    title: account !== "" ? "Add to the Signer app" : "Add the recovery phrase again"

    property var backend: null
    // A file of the wallet, for a phrase; or an imported key's address, for its password.
    property string group: ""
    property string account: ""
    // Shown in the body, never the title: the dialog renders its title as rich text.
    property string walletName: ""
    property bool needsPassphrase: false
    // A phrase kept here, opened with its own password in place of typing the words.
    property string keptId: ""
    property bool working: false
    property string notice: ""

    signal added()

    function clearSecrets() { words.clear(); phrasePw.text = ""; passphrase.text = ""; pw.text = "" }
    function ready() {
        if (pw.text.length === 0) return false
        if (account !== "") return true
        return keptId ? phrasePw.text.length > 0 : words.complete
    }
    function submit() {
        var p = { password: pw.text }
        if (account !== "") p.account = account
        else {
            p.group = group
            if (keptId) { p.keptPhrase = keptId; p.phrasePassword = phrasePw.text }
            else p.phrase = words.text
            if (needsPassphrase) p.passphrase = passphrase.text
        }
        working = true; notice = ""
        logos.watch(backend.restoreUnlockRoot(JSON.stringify(p)), function (ok) {
            working = false
            if (ok) { sheet.added(); sheet.close() }
            else notice = backend.lastError || "It was not added. Check the phrase and the password."
        })
        p = {}
        clearSecrets()
    }

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 600)

    onOpened: { clearSecrets(); notice = ""; working = false }
    onClosed: { clearSecrets(); group = ""; account = ""; walletName = ""; keptId = ""; needsPassphrase = false }

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText {
            objectName: "addAgainName"
            Layout.fillWidth: true
            visible: text.length > 0
            font.bold: true
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: sheet.account !== "" ? sheet.account : sheet.walletName
        }
        LogosText {
            objectName: "addAgainExplanation"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: sheet.account !== ""
                  ? "This key was added before wallets could be locked. Its password adds it to the "
                    + "Signer app; nothing else changes."
                  : "This wallet was added before wallets could be locked. Its recovery phrase is checked "
                    + "against the accounts it already holds, and the password of its account files locks "
                    + "it from then on. No account is added and no file changes."
        }

        Accounts.PhraseGrid {
            id: words; objectName: "addAgainWords"; Layout.fillWidth: true
            visible: sheet.account === "" && !sheet.keptId
        }
        LogosTextField {
            id: phrasePw; objectName: "addAgainPhrasePassword"; Layout.fillWidth: true
            visible: sheet.account === "" && !!sheet.keptId
            echoMode: TextInput.Password; placeholderText: "Recovery source password"
        }
        LogosTextField {
            id: passphrase; objectName: "addAgainPassphrase"; Layout.fillWidth: true
            visible: sheet.account === "" && sheet.needsPassphrase
            echoMode: TextInput.Password; placeholderText: "BIP39 passphrase (exactly as originally used)"
        }
        LogosTextField {
            id: pw; objectName: "addAgainPassword"; Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: sheet.account !== "" ? "This account's password" : "The password of its account files"
            Component.onCompleted: textInput.passwordMaskDelay = 0
        }
        LogosText {
            objectName: "addAgainNotice"
            Layout.fillWidth: true
            visible: sheet.notice.length > 0
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Theme.palette.error
            text: sheet.notice
        }

        RowLayout {
            Layout.fillWidth: true
            LogosButton { objectName: "addAgainCancel"; text: "Cancel"; onClicked: sheet.close() }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "addAgainConfirm"
                text: sheet.account !== "" ? "Add to the Signer app" : "Add the phrase"
                enabled: !sheet.working && sheet.ready()
                onClicked: sheet.submit()
            }
        }
    }
}
