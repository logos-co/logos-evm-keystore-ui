import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// The password of one account no wallet holds: an imported key or vault, or one whose wallet
// isn't recorded. A wallet's accounts change theirs together, from the wallet. The title is fixed.
LogosDialog {
    id: sheetRoot
    objectName: "accountPasswordSheet"
    title: "Change password"

    property var backend: null
    property string address: ""
    property bool working: false
    property bool tried: false

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 520)

    function clear() { oldPw.text = ""; newPw.text = ""; repeatPw.text = "" }
    onOpened: { clear(); working = false; tried = false; sheetError.clear() }
    onClosed: { clear(); sheetError.clear() }
    // Why Change is still off, once something is typed.
    readonly property string hint:
          repeatPw.text.length > 0 && repeatPw.text !== newPw.text ? "The two new passwords don't match."
        : newPw.text.length > 0 && oldPw.text.length === 0 ? "Type the current password too."
        : ""

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText {
            objectName: "accountPasswordAddress"
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            font.family: Theme.typography.mono
            text: sheetRoot.address
        }
        LogosTextField { id: oldPw; objectName: "oldPasswordField"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Current password" }
        LogosTextField { id: newPw; objectName: "newPasswordField"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "New password" }
        LogosTextField { id: repeatPw; objectName: "repeatPasswordField"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Confirm the new password" }
        LogosText {
            objectName: "accountPasswordHint"
            Layout.fillWidth: true
            visible: text.length > 0
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: sheetRoot.hint
        }
        SheetError { id: sheetError; objectName: "accountPasswordError" }
        RowLayout {
            Layout.fillWidth: true
            LogosButton { objectName: "accountPasswordCancel"; text: "Cancel"; onClicked: sheetRoot.close() }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "changePasswordConfirm"
                text: "Change password"
                enabled: !sheetRoot.working && oldPw.text.length > 0 && newPw.text.length > 0 && newPw.text === repeatPw.text
                onClicked: {
                    sheetRoot.working = true
                    sheetRoot.tried = true
                    sheetError.clear()
                    logos.watch(sheetRoot.backend.changePassword(sheetRoot.address, oldPw.text, newPw.text), function (good) {
                        sheetRoot.working = false
                        if (good) sheetRoot.close()
                        else { oldPw.text = ""; sheetError.take(sheetRoot.backend, "The password was not changed.") }
                    }, function () { sheetRoot.working = false; sheetError.lost() })
                }
            }
        }
    }
}
