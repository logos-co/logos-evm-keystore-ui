import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme
import "accountkit/roster.js" as Roster

// Remove one account: an EVM account's vault, or a Bitcoin account's file. Checked against that
// account's password, so a wrong one removes nothing. The title is fixed.
LogosWarningDialog {
    id: sheetRoot
    objectName: "removeAccountSheet"
    title: "Remove account"
    accentColor: Theme.palette.error

    property var backend: null
    property var view: null
    property var entry: null
    property bool working: false
    property bool tried: false

    readonly property bool bitcoin: !!sheetRoot.entry && sheetRoot.entry.family !== "evm"
    // Whether a recovery phrase brings it back: a Bitcoin account, or an EVM one derived from one.
    readonly property bool fromPhrase: sheetRoot.bitcoin
        || (!!sheetRoot.entry && !!sheetRoot.view && (sheetRoot.view.provFor(sheetRoot.entry.address) || {}).origin === "derived")

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 560)

    onOpened: { password.text = ""; ack.checked = false; sheetRoot.working = false; sheetRoot.tried = false; sheetError.clear() }
    onClosed: { password.text = ""; ack.checked = false; sheetError.clear() }

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText {
            objectName: "removeAccountName"
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.typography.subtitleText
            text: sheetRoot.entry ? Roster.rowTitle(sheetRoot.entry) + (Roster.rowId(sheetRoot.entry) ? " · " + Roster.rowId(sheetRoot.entry) : "") : ""
        }
        LogosText {
            objectName: "removeAccountWhere"
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            font.family: Theme.typography.mono
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            text: !sheetRoot.entry ? "" : sheetRoot.bitcoin ? (sheetRoot.entry.path || "") : (sheetRoot.entry.address || "")
        }
        LogosText {
            objectName: "removeAccountProvenance"
            Layout.fillWidth: true
            visible: !sheetRoot.bitcoin && text.length > 0
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: (!sheetRoot.bitcoin && sheetRoot.entry && sheetRoot.view) ? sheetRoot.view.originLine(sheetRoot.entry.address) : ""
        }
        LogosText {
            objectName: "removeAccountLost"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: sheetRoot.fromPhrase ? Theme.palette.textSecondary : Theme.palette.warning
            text: sheetRoot.fromPhrase
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
        SheetError { id: sheetError; objectName: "removeAccountError" }
        RowLayout {
            Layout.fillWidth: true
            LogosButton { objectName: "removeAccountCancel"; text: "Cancel"; onClicked: sheetRoot.close() }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "removeAccountConfirm"
                text: "Remove"
                enabled: !sheetRoot.working && sheetRoot.entry !== null && ack.checked && password.text.length > 0
                onClicked: {
                    sheetRoot.working = true
                    sheetRoot.tried = true
                    sheetError.clear()
                    var call = sheetRoot.bitcoin ? sheetRoot.backend.deleteBitcoinAccount(sheetRoot.entry.group, password.text)
                                             : sheetRoot.backend.deleteAccount(sheetRoot.entry.address, password.text)
                    logos.watch(call, function (good) {
                        sheetRoot.working = false
                        password.text = ""
                        if (good) sheetRoot.close()
                        else sheetError.take(sheetRoot.backend, "Nothing was removed.")
                    }, function () { sheetRoot.working = false; sheetError.lost() })
                }
            }
        }
    }
}
