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
    id: sheetRoot
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

    readonly property bool more: sheetRoot.left.length > 0

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 560)

    function clear() { oldPw.text = ""; newPw.text = ""; repeatPw.text = ""; sheetRoot.tried = [] }
    onOpened: { clear(); sheetRoot.left = []; sheetRoot.working = false; sheetRoot.attempted = false; sheetError.clear() }
    onClosed: { clear(); sheetRoot.left = []; sheetError.clear() }
    // Why the button is still off, once something is typed.
    readonly property string hint:
          !sheetRoot.more && repeatPw.text.length > 0 && repeatPw.text !== newPw.text ? "The two new passwords don't match."
        : newPw.text.length > 0 && oldPw.text.length === 0 ? (sheetRoot.more ? "Type the password they use." : "Type the current password too.")
        : ""

    function submit() {
        var olds = sheetRoot.tried.concat(oldPw.text.length ? [oldPw.text] : [])
        sheetRoot.working = true
        sheetRoot.attempted = true
        sheetError.clear()
        logos.watch(sheetRoot.backend.changeWalletPassword(sheetRoot.seed, JSON.stringify(olds), newPw.text), function (reply) {
            sheetRoot.working = false
            var r = null
            try { r = reply ? JSON.parse(reply) : null } catch (e) {}
            if (!r) { oldPw.text = ""; sheetError.take(sheetRoot.backend, "The password was not changed."); return }
            sheetRoot.tried = olds
            oldPw.text = ""
            sheetRoot.left = r.left || []
            if (sheetRoot.left.length === 0) sheetRoot.close()
        }, function () { sheetRoot.working = false; sheetError.lost() })
    }

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText {
            objectName: "walletPasswordName"
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.typography.subtitleText
            text: sheetRoot.shownTitle
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
            visible: !sheetRoot.more
            echoMode: TextInput.Password
            placeholderText: "New password"
        }
        LogosTextField {
            id: repeatPw
            objectName: "walletRepeatPassword"
            Layout.fillWidth: true
            visible: !sheetRoot.more
            echoMode: TextInput.Password
            placeholderText: "Confirm the new password"
        }
        LogosText {
            objectName: "walletPasswordLeft"
            Layout.fillWidth: true
            visible: sheetRoot.more
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Theme.palette.warning
            text: "Moved what that password opened. Still under another password: "
                  + Tree.leftFiles(sheetRoot.left, sheetRoot.view ? sheetRoot.view.groups : []).join(", ") + "."
        }
        LogosTextField {
            id: oldPw
            objectName: "walletOldPassword"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: sheetRoot.more ? "The password they use" : "Current password"
        }
        LogosText {
            objectName: "walletPasswordHint"
            Layout.fillWidth: true
            visible: text.length > 0
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: sheetRoot.hint
        }
        SheetError { id: sheetError; objectName: "walletPasswordError" }
        RowLayout {
            Layout.fillWidth: true
            LogosButton {
                objectName: "walletPasswordClose"
                // What moved stays moved: the rest keep their own passwords until asked again.
                text: sheetRoot.more ? "Leave the rest" : "Cancel"
                onClicked: sheetRoot.close()
            }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "walletPasswordConfirm"
                text: sheetRoot.more ? "Continue" : "Change password"
                enabled: !sheetRoot.working && sheetRoot.seed.length > 0 && oldPw.text.length > 0
                         && newPw.text.length > 0 && newPw.text === repeatPw.text
                onClicked: sheetRoot.submit()
            }
        }
    }
}
