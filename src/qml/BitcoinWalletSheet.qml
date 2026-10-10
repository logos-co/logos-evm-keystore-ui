import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// One Bitcoin wallet: what it is, where it came from, and its descriptor behind a warning. The
// descriptor is fetched when asked for and held in this sheet only: its xpub reveals the
// wallet's whole history to whoever reads it.
LogosDialog {
    id: sheet
    objectName: "bitcoinWalletSheet"
    title: "Bitcoin wallet"

    property var backend: null
    property var view: null
    property var group: null
    property string external: ""
    property string internal: ""

    readonly property string name: (view && group) ? (view.walletNameOf(group.id) || group.id) : ""

    onOpened: { external = ""; internal = "" }
    onClosed: { external = ""; internal = "" }

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
            text: sheet.name
        }
        LogosText {
            objectName: "btcWalletKind"
            Layout.fillWidth: true
            color: Theme.palette.textSecondary
            text: !sheet.group ? ""
                  : (sheet.group.family === "bitcoin_taproot" ? "Taproot" : "Native segwit")
                    + (sheet.group.chain === "main" ? ", on Bitcoin" : ", on the test networks")
                    + (sheet.group.usedPassphrase ? ", with a BIP39 passphrase" : "")
        }
        LogosText {
            objectName: "btcWalletPhrase"
            visible: !!(sheet.group && sheet.group.phrase)
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "Made from a recovery phrase kept here. Forgetting that phrase leaves this wallet as it is."
        }

        LogosText {
            objectName: "btcDescriptorRisk"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.warning
            text: "Anyone with the descriptor sees this wallet's whole history and every future payment. It can't spend."
        }
        LogosButton {
            objectName: "btcShowDescriptor"
            visible: sheet.external.length === 0
            text: "Show descriptor"
            onClicked: logos.watch(sheet.backend.walletDescriptors(sheet.group.id), function (json) {
                try {
                    var d = JSON.parse(json || "{}")
                    sheet.external = d.external || ""
                    sheet.internal = d.internal || ""
                } catch (e) {}
            })
        }
        LogosText {
            objectName: "btcExternalDescriptor"
            visible: sheet.external.length > 0
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            font.family: "monospace"
            text: sheet.external
        }
        LogosText {
            objectName: "btcInternalDescriptor"
            visible: sheet.internal.length > 0
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            font.family: "monospace"
            text: sheet.internal
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            LogosButton { objectName: "btcWalletClose"; text: "Close"; onClicked: sheet.close() }
        }
    }
}
