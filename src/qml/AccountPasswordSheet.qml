import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// The password of one account no wallet holds: an imported key or vault, or one whose wallet
// isn't recorded. A wallet's accounts change theirs together, from the wallet. The title is fixed.
LogosDialog {
    id: sheet
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

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText {
            objectName: "accountPasswordAddress"
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            font.family: Theme.typography.mono
            text: sheet.address
        }
        LogosTextField { id: oldPw; objectName: "oldPasswordField"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Current password" }
        LogosTextField { id: newPw; objectName: "newPasswordField"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "New password" }
        LogosTextField { id: repeatPw; objectName: "repeatPasswordField"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Confirm the new password" }
        SheetError { id: sheetError; objectName: "accountPasswordError" }
        RowLayout {
            Layout.fillWidth: true
            LogosButton { objectName: "accountPasswordCancel"; text: "Cancel"; onClicked: sheet.close() }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "changePasswordConfirm"
                text: "Change password"
                enabled: !sheet.working && oldPw.text.length > 0 && newPw.text.length > 0 && newPw.text === repeatPw.text
                onClicked: {
                    sheet.working = true
                    sheet.tried = true
                    sheetError.clear()
                    logos.watch(sheet.backend.changePassword(sheet.address, oldPw.text, newPw.text), function (good) {
                        sheet.working = false
                        if (good) sheet.close()
                        else { oldPw.text = ""; sheetError.take(sheet.backend, "The password was not changed.") }
                    }, function () { sheet.working = false; sheetError.lost() })
                }
            }
        }
    }
}
