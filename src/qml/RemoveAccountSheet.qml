import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme
import "accountkit/roster.js" as Roster

// Remove one account: an EVM account's vault, or a Bitcoin account's file. Checked against that
// account's password, so a wrong one removes nothing. The title is fixed.
LogosWarningDialog {
    id: sheet
    objectName: "removeAccountSheet"
    title: "Remove account"
    accentColor: Theme.palette.error

    property var backend: null
    property var view: null
    property var entry: null
    property bool working: false
    property bool tried: false

    readonly property bool bitcoin: !!sheet.entry && sheet.entry.family !== "evm"
    // Whether a recovery phrase brings it back: a Bitcoin account, or an EVM one derived from one.
    readonly property bool fromPhrase: sheet.bitcoin
        || (!!sheet.entry && !!sheet.view && (sheet.view.provFor(sheet.entry.address) || {}).origin === "derived")

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 560)

    onOpened: { password.text = ""; ack.checked = false; sheet.working = false; sheet.tried = false }
    onClosed: { password.text = ""; ack.checked = false }

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText {
            objectName: "removeAccountName"
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.typography.subtitleText
            text: sheet.entry ? Roster.rowTitle(sheet.entry) + (Roster.rowId(sheet.entry) ? " · " + Roster.rowId(sheet.entry) : "") : ""
        }
        LogosText {
            objectName: "removeAccountWhere"
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            font.family: Theme.typography.mono
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            text: !sheet.entry ? "" : sheet.bitcoin ? (sheet.entry.path || "") : (sheet.entry.address || "")
        }
        LogosText {
            objectName: "removeAccountProvenance"
            Layout.fillWidth: true
            visible: !sheet.bitcoin && text.length > 0
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: (!sheet.bitcoin && sheet.entry && sheet.view) ? sheet.view.originLine(sheet.entry.address) : ""
        }
        LogosText {
            objectName: "removeAccountLost"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: sheet.fromPhrase ? Theme.palette.textSecondary : Theme.palette.warning
            text: sheet.fromPhrase
                  ? "Its encrypted key file is deleted from this computer. Its recovery phrase brings it back, "
                    + "at the same address."
                  : "No recovery phrase here covers it: unless you exported it, it is gone for good."
        }
        LogosTextField {
            id: password
            objectName: "removeAccountPassword"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "This account's password"
        }
        LogosCheckbox {
            id: ack
            objectName: "removeAccountAck"
            text: "I want this account removed"
        }
        LogosText {
            objectName: "removeAccountError"
            Layout.fillWidth: true
            visible: sheet.tried && !sheet.working && text.length > 0
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Theme.palette.error
            text: sheet.backend ? sheet.backend.lastError : ""
        }
        RowLayout {
            Layout.fillWidth: true
            LogosButton { objectName: "removeAccountCancel"; text: "Cancel"; onClicked: sheet.close() }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "removeAccountConfirm"
                text: "Remove"
                enabled: !sheet.working && sheet.entry !== null && ack.checked && password.text.length > 0
                onClicked: {
                    sheet.working = true
                    sheet.tried = true
                    var call = sheet.bitcoin ? sheet.backend.deleteBitcoinAccount(sheet.entry.group, password.text)
                                             : sheet.backend.deleteAccount(sheet.entry.address, password.text)
                    logos.watch(call, function (good) {
                        sheet.working = false
                        password.text = ""
                        if (good) sheet.close()
                    })
                }
            }
        }
    }
}
