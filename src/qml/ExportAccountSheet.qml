import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// Export one EVM account's vault JSON, with its password. Shown so it can be copied, and
// dropped when the sheet closes. The title is fixed.
LogosDialog {
    id: sheetRoot
    objectName: "exportAccountSheet"
    title: "Export account"

    property var backend: null
    property string address: ""
    property string exported: ""

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 560)

    onOpened: { exported = ""; password.text = ""; sheetError.clear() }
    onClosed: { exported = ""; password.text = ""; sheetError.clear() }

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
                text: sheetRoot.address
            }
            LogosCopyButton { objectName: "exportAddressCopy"; value: sheetRoot.address }
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
            visible: sheetRoot.exported.length > 0
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            font.family: Theme.typography.mono
            font.pixelSize: Theme.typography.secondaryText
            text: sheetRoot.exported
        }
        SheetError { id: sheetError; objectName: "exportError" }
        RowLayout {
            Layout.fillWidth: true
            LogosButton { objectName: "exportClose"; text: "Close"; onClicked: sheetRoot.close() }
            Item { Layout.fillWidth: true }
            LogosCopyButton {
                objectName: "exportedVaultCopy"
                visible: sheetRoot.exported.length > 0
                value: sheetRoot.exported
                Accessible.name: "Copy the vault JSON"
            }
            LogosButton {
                objectName: "exportConfirm"
                text: "Export vault JSON"
                enabled: password.text.length > 0
                onClicked: {
                    sheetError.clear()
                    logos.watch(sheetRoot.backend.exportVaultJson(sheetRoot.address, password.text),
                        function (vault) {
                            sheetRoot.exported = vault || ""
                            password.text = ""
                            if (!vault) sheetError.take(sheetRoot.backend, "Nothing was exported.")
                        }, function () { sheetError.lost() })
                }
            }
        }
    }
}
