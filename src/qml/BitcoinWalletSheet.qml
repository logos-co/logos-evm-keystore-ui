import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// One Bitcoin account file under a wallet: what it is, where it came from, and its descriptor behind a warning. The
// descriptor is fetched when asked for and held in this sheet only: its xpub reveals the
// wallet's whole history to whoever reads it.
LogosDialog {
    id: sheetRoot
    objectName: "bitcoinWalletSheet"
    title: "Bitcoin account"

    property var backend: null
    property var view: null
    property var group: null
    // The row's title as the list shows it; never the bare group id.
    property string rowTitle: ""
    property string external: ""
    property string internal: ""

    readonly property string name: rowTitle || ((view && group) ? (view.walletNameOf(group.id) || group.id) : "")

    onOpened: { external = ""; internal = ""; sheetError.clear() }
    onClosed: { external = ""; internal = ""; sheetError.clear() }

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 640)

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText {
            objectName: "btcWalletName"
            Layout.fillWidth: true
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.bold: true
            text: sheetRoot.name
        }
        LogosText {
            objectName: "btcWalletKind"
            Layout.fillWidth: true
            color: Theme.palette.textSecondary
            text: !sheetRoot.group ? ""
                  : (sheetRoot.group.family === "bitcoin_taproot" ? "Taproot" : "Native segwit")
                    + (sheetRoot.group.chain === "main" ? ", on Bitcoin" : ", on the test networks")
                    + (sheetRoot.group.usedPassphrase ? ", with a BIP39 passphrase" : "")
        }
        LogosText {
            objectName: "btcWalletPhrase"
            visible: !!(sheetRoot.group && sheetRoot.group.phrase)
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "Made from a recovery phrase kept here. Forgetting that phrase leaves this account as it is."
        }

        LogosText {
            objectName: "btcDescriptorRisk"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.warning
            text: "Anyone with the descriptor sees this account's whole history and every future payment. It can't spend."
        }
        LogosButton {
            objectName: "btcShowDescriptor"
            visible: sheetRoot.external.length === 0
            text: "Show descriptor"
            onClicked: {
                sheetError.clear()
                logos.watch(sheetRoot.backend.walletDescriptors(sheetRoot.group.id), function (json) {
                    try {
                        const d = JSON.parse(json || "{}")
                        sheetRoot.external = d.external || ""
                        sheetRoot.internal = d.internal || ""
                    } catch (e) {}
                    if (sheetRoot.external.length === 0) sheetError.take(sheetRoot.backend, "Could not read the descriptor.")
                }, function () { sheetError.lost() })
            }
        }
        LogosText {
            objectName: "btcExternalDescriptor"
            visible: sheetRoot.external.length > 0
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            font.family: "monospace"
            text: sheetRoot.external
        }
        LogosText {
            objectName: "btcInternalDescriptor"
            visible: sheetRoot.internal.length > 0
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            font.family: "monospace"
            text: sheetRoot.internal
        }

        SheetError { id: sheetError; objectName: "btcWalletError" }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            LogosButton { objectName: "btcWalletClose"; text: "Close"; onClicked: sheetRoot.close() }
        }
    }
}
