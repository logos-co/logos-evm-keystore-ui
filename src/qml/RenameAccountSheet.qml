import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme
import "accountkit/roster.js" as Roster

// Name one account: an EVM account by its address, a Bitcoin account by its file. Asked first
// with no password, which a wallet the Signer app unlocked takes; one the keystore refuses asks
// for the account's password. Clearing a name asks for nothing. The title is fixed.
LogosDialog {
    id: sheet
    objectName: "renameAccountSheet"
    title: "Rename account"

    property var backend: null
    // The row's entry, as the wallet card gives it: { family, address | group, label, path }.
    property var entry: null
    property bool askPassword: false
    property bool working: false
    property bool tried: false

    readonly property bool bitcoin: !!sheet.entry && sheet.entry.family !== "evm"

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 520)

    onOpened: {
        nameField.text = sheet.entry ? (sheet.entry.label || "") : ""
        password.text = ""
        sheet.askPassword = false
        sheet.working = false
        sheet.tried = false
    }
    onClosed: password.text = ""

    function save() {
        var name = nameField.text.trim()
        var pw = sheet.askPassword ? password.text : ""
        sheet.working = true
        sheet.tried = true
        var call = sheet.bitcoin ? sheet.backend.setWalletName(sheet.entry.group, name, "", pw)
                                 : sheet.backend.setLabel(sheet.entry.address, name, pw)
        logos.watch(call, function (good) {
            sheet.working = false
            password.text = ""
            if (good) sheet.close()
            // A wallet not unlocked this session proves custody with the account's password.
            else if (name.length > 0) sheet.askPassword = true
        })
    }

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText {
            objectName: "renameAccountWhich"
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            color: Theme.palette.textSecondary
            text: !sheet.entry ? ""
                  : [Roster.familyWord(sheet.entry), Roster.rowId(sheet.entry), sheet.entry.path].filter(Boolean).join(" · ")
        }
        LogosTextField {
            id: nameField
            objectName: "accountNameField"
            Layout.fillWidth: true
            textInput.maximumLength: 40
            placeholderText: "Account name"
        }
        LogosText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            font.pixelSize: Theme.typography.secondaryText
            text: "Shown in every app in place of its address. Clearing it shows the address again."
        }
        LogosText {
            objectName: "renameAccountNeedsPassword"
            Layout.fillWidth: true
            visible: sheet.askPassword
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "This wallet isn't unlocked in the Signer app, so naming one of its accounts asks for "
                  + "that account's password."
        }
        LogosTextField {
            id: password
            objectName: "renameAccountPassword"
            Layout.fillWidth: true
            visible: sheet.askPassword
            echoMode: TextInput.Password
            placeholderText: "That account's password"
        }
        LogosText {
            objectName: "renameAccountError"
            Layout.fillWidth: true
            visible: sheet.tried && !sheet.working && text.length > 0
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Theme.palette.error
            text: sheet.backend ? sheet.backend.lastError : ""
        }
        RowLayout {
            Layout.fillWidth: true
            LogosButton { objectName: "renameAccountCancel"; text: "Cancel"; onClicked: sheet.close() }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "saveAccountName"
                text: "Save"
                enabled: !sheet.working && sheet.entry !== null
                         && (!sheet.askPassword || nameField.text.trim().length === 0 || password.text.length > 0)
                onClicked: sheet.save()
            }
        }
    }
}
