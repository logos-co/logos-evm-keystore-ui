import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// Export one EVM account's vault JSON, with its password. Shown so it can be copied, and
// dropped when the sheet closes. The title is fixed.
LogosDialog {
    id: sheet
    objectName: "exportAccountSheet"
    title: "Export account"

    property var backend: null
    property string address: ""
    property string exported: ""

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 560)

    onOpened: { exported = ""; password.text = "" }
    onClosed: { exported = ""; password.text = "" }

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        // The whole address, wrapping: a selectable text would clip it instead.
        RowLayout {
            Layout.fillWidth: true
            LogosText {
                objectName: "exportAddress"
                Layout.fillWidth: true
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                text: sheet.address
            }
            LogosCopyButton { objectName: "exportAddressCopy"; value: sheet.address }
        }
        LogosText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "The vault file is encrypted under this account's password. Anyone with both can spend from it."
        }
        LogosTextField {
            id: password
            objectName: "exportPasswordField"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "This account's password"
        }
        LogosText {
            objectName: "exportedVault"
            visible: sheet.exported.length > 0
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            font.family: Theme.typography.mono
            font.pixelSize: Theme.typography.secondaryText
            text: sheet.exported
        }
        RowLayout {
            Layout.fillWidth: true
            LogosButton { objectName: "exportClose"; text: "Close"; onClicked: sheet.close() }
            Item { Layout.fillWidth: true }
            LogosCopyButton {
                objectName: "exportedVaultCopy"
                visible: sheet.exported.length > 0
                value: sheet.exported
                Accessible.name: "Copy the vault JSON"
            }
            LogosButton {
                objectName: "exportConfirm"
                text: "Export vault JSON"
                enabled: password.text.length > 0
                onClicked: logos.watch(sheet.backend.exportVaultJson(sheet.address, password.text),
                    function (vault) { sheet.exported = vault || ""; password.text = "" })
            }
        }
    }
}
