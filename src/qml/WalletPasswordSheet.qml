import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme
import "tree.js" as Tree

// One password for every file of a wallet: its accounts, its account files and a phrase kept
// here. Each file takes the first password given that opens it; the keystore names the ones none
// opened, and each password asked for after that is asked once. The title is fixed.
LogosDialog {
    id: sheet
    objectName: "walletPasswordSheet"
    title: "Change the wallet's password"

    property var backend: null
    property var view: null
    property string seed: ""
    property string shownTitle: ""
    // Old passwords given so far, and what the last call left under none of them.
    property var tried: []
    property var left: []
    property bool working: false
    property bool attempted: false

    readonly property bool more: sheet.left.length > 0

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 560)

    function clear() { oldPw.text = ""; newPw.text = ""; repeatPw.text = ""; sheet.tried = [] }
    onOpened: { clear(); sheet.left = []; sheet.working = false; sheet.attempted = false }
    onClosed: { clear(); sheet.left = [] }

    function submit() {
        var olds = sheet.tried.concat(oldPw.text.length ? [oldPw.text] : [])
        sheet.working = true
        sheet.attempted = true
        logos.watch(sheet.backend.changeWalletPassword(sheet.seed, JSON.stringify(olds), newPw.text), function (reply) {
            sheet.working = false
            var r = null
            try { r = reply ? JSON.parse(reply) : null } catch (e) {}
            if (!r) { oldPw.text = ""; return }
            sheet.tried = olds
            oldPw.text = ""
            sheet.left = r.left || []
            if (sheet.left.length === 0) sheet.close()
        })
    }

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText {
            objectName: "walletPasswordName"
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.typography.subtitleText
            text: sheet.shownTitle
        }
        LogosText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "Every account of this wallet, and its recovery phrase if kept here, will open with the new "
                  + "password, and so will the wallet in the Signer app."
        }
        LogosTextField {
            id: newPw
            objectName: "walletNewPassword"
            Layout.fillWidth: true
            visible: !sheet.more
            echoMode: TextInput.Password
            placeholderText: "New password"
        }
        LogosTextField {
            id: repeatPw
            objectName: "walletRepeatPassword"
            Layout.fillWidth: true
            visible: !sheet.more
            echoMode: TextInput.Password
            placeholderText: "Confirm the new password"
        }
        LogosText {
            objectName: "walletPasswordLeft"
            Layout.fillWidth: true
            visible: sheet.more
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Theme.palette.warning
            text: "Moved what that password opened. Still under another password: "
                  + Tree.leftFiles(sheet.left, sheet.view ? sheet.view.groups : []).join(", ") + "."
        }
        LogosTextField {
            id: oldPw
            objectName: "walletOldPassword"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: sheet.more ? "The password they use" : "Current password"
        }
        LogosText {
            objectName: "walletPasswordError"
            Layout.fillWidth: true
            visible: sheet.attempted && !sheet.working && text.length > 0
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Theme.palette.error
            text: sheet.backend ? sheet.backend.lastError : ""
        }
        RowLayout {
            Layout.fillWidth: true
            LogosButton {
                objectName: "walletPasswordClose"
                // What moved stays moved: the rest keep their own passwords until asked again.
                text: sheet.more ? "Leave the rest" : "Cancel"
                onClicked: sheet.close()
            }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "walletPasswordConfirm"
                text: sheet.more ? "Continue" : "Change password"
                enabled: !sheet.working && sheet.seed.length > 0 && oldPw.text.length > 0
                         && newPw.text.length > 0 && newPw.text === repeatPw.text
                onClicked: sheet.submit()
            }
        }
    }
}
