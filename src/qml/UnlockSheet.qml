import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// The person unlocks an account on their own terms, with no app asking: the keystore holds its
// key in locked memory for the time and count chosen, and the manager keeps which apps it
// covers and whether each signature is still confirmed.
LogosDialog {
    id: sheet
    objectName: "unlockSheet"
    title: "Unlock an account"

    property var backend: null
    // `[{ id, name }]`: EVM accounts by address, Bitcoin wallets by id.
    property var accounts: []
    property string picked: ""

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 600)

    onOpened: { picked = ""; pw.text = ""; terms.load({}) }

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText { text: "Which account"; color: Theme.palette.textSecondary }
        ButtonGroup { id: accountGroup }
        Repeater {
            model: sheet.accounts
            delegate: LogosRadioButton {
                objectName: "unlockAccount_" + index
                ButtonGroup.group: accountGroup
                text: modelData.name
                onCheckedChanged: if (checked) sheet.picked = modelData.id
            }
        }

        UnlockTerms { id: terms; Layout.fillWidth: true }

        LogosTextField {
            id: pw
            objectName: "unlockPasswordField"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "The account's password"
            Component.onCompleted: textInput.passwordMaskDelay = 0
        }

        RowLayout {
            Layout.fillWidth: true
            LogosButton { objectName: "unlockCancelButton"; text: "Cancel"; onClicked: { pw.text = ""; sheet.close() } }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "unlockConfirmButton"
                text: "Unlock"
                enabled: sheet.picked !== "" && pw.text.length > 0 && terms.complete
                onClicked: {
                    logos.watch(sheet.backend.unlockAccount(sheet.picked, pw.text, JSON.stringify(terms.value)),
                                function (ok) { if (ok) sheet.close() })
                    pw.text = ""
                }
            }
        }
    }
}
