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
    id: sheetRoot
    objectName: "renameAccountSheet"
    title: "Rename account"

    property var backend: null
    // The row's entry, as the wallet card gives it: { family, address | group, label, path }.
    property var entry: null
    property bool askPassword: false
    property bool working: false
    property bool tried: false

    readonly property bool bitcoin: !!sheetRoot.entry && sheetRoot.entry.family !== "evm"

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 520)

    onOpened: {
        nameField.text = sheetRoot.entry ? (sheetRoot.entry.label || "") : ""
        password.text = ""
        sheetRoot.askPassword = false
        sheetRoot.working = false
        sheetRoot.tried = false
        sheetError.clear()
    }
    onClosed: { password.text = ""; sheetError.clear() }

    function save() {
        var name = nameField.text.trim()
        var pw = sheetRoot.askPassword ? password.text : ""
        sheetRoot.working = true
        sheetRoot.tried = true
        sheetError.clear()
        var call = sheetRoot.bitcoin ? sheetRoot.backend.setWalletName(sheetRoot.entry.group, name, "", pw)
                                 : sheetRoot.backend.setLabel(sheetRoot.entry.address, name, pw)
        logos.watch(call, function (good) {
            sheetRoot.working = false
            password.text = ""
            if (good) { sheetRoot.close(); return }
            sheetError.take(sheetRoot.backend, "The name was not saved.")
            // A wallet not unlocked this session proves custody with the account's password.
            if (name.length > 0) sheetRoot.askPassword = true
        }, function () { sheetRoot.working = false; sheetError.lost() })
    }

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText {
            objectName: "renameAccountWhich"
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            color: Theme.palette.textSecondary
            text: !sheetRoot.entry ? ""
                  : [Roster.familyWord(sheetRoot.entry), Roster.rowId(sheetRoot.entry), sheetRoot.entry.path].filter(Boolean).join(" · ")
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
            visible: sheetRoot.askPassword
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "This wallet isn't unlocked in the Signer app, so naming one of its accounts asks for "
                  + "that account's password."
        }
        LogosTextField {
            id: password
            objectName: "renameAccountPassword"
            Layout.fillWidth: true
            visible: sheetRoot.askPassword
            echoMode: TextInput.Password
            placeholderText: "That account's password"
        }
        SheetError { id: sheetError; objectName: "renameAccountError" }
        RowLayout {
            Layout.fillWidth: true
            LogosButton { objectName: "renameAccountCancel"; text: "Cancel"; onClicked: sheetRoot.close() }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "saveAccountName"
                text: "Save"
                enabled: !sheetRoot.working && sheetRoot.entry !== null
                         && (!sheetRoot.askPassword || nameField.text.trim().length === 0 || password.text.length > 0)
                onClicked: sheetRoot.save()
            }
        }
    }
}
