import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// Name a wallet: the recovery phrase over its account files. The keystore prices it as it
// prices one file's name, so it is proved by any one account under it, or by the key of a file
// that holds no addresses (a Bitcoin account's). The title is fixed: a name is user-typed.
LogosDialog {
    id: sheet
    objectName: "walletNameSheet"
    title: "Rename wallet"

    property var backend: null
    property var view: null
    // The seed branch the header stands over, as the view lists it.
    property var bundle: null
    property string shownTitle: ""
    property int proofIndex: 0
    property bool working: false
    // The backend's last error is shared with every other action: show it only after a try here.
    property bool tried: false

    readonly property var proofs: {
        var out = []
        var nodes = (sheet.bundle && sheet.bundle.nodes) || []
        for (var i = 0; i < nodes.length; ++i) {
            var n = nodes[i]
            if (n.kind !== "wallet" || !sheet.view) continue
            var row = sheet.view.nodeTitle(n)
            if (n.addresses.length > 0)
                n.addresses.forEach(function (a) {
                    out.push({ group: n.group.id, address: a, label: row + " · " + sheet.view.shortAddr(a) })
                })
            else if (sheet.view.keptKeyOf(n))
                out.push({ group: n.group.id, address: "", label: row })
        }
        return out
    }
    readonly property var proof: proofs.length > proofIndex ? proofs[proofIndex] : null
    readonly property bool needsPassword: nameField.text.trim().length > 0 && proof !== null

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 560)

    onOpened: {
        var seedId = sheet.bundle && sheet.bundle.nodes.length ? (sheet.bundle.nodes[0].group || {}).seedId : ""
        nameField.text = sheet.view ? sheet.view.seedNameFor(seedId) : ""
        password.text = ""
        sheet.proofIndex = 0
        sheet.working = false
        sheet.tried = false
    }
    onClosed: password.text = ""

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText {
            objectName: "walletNameCurrent"
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.typography.subtitleText
            text: sheet.shownTitle
        }
        LogosText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "The name is shown over all of this wallet's account files. Clearing it asks for "
                  + "nothing and shows the wallet by its position again."
        }
        LogosTextField {
            id: nameField
            objectName: "seedWalletNameField"
            Layout.fillWidth: true
            textInput.maximumLength: 40
            placeholderText: "Name this wallet"
        }

        LogosText {
            objectName: "seedWalletProofHint"
            Layout.fillWidth: true
            visible: sheet.needsPassword
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "Naming a wallet renames what is shown for every account in it, so it asks for "
                  + "the password of one of them. Any one will do."
        }
        ButtonGroup { id: proofPick }
        Repeater {
            model: sheet.needsPassword ? sheet.proofs : []
            delegate: LogosRadioButton {
                objectName: "seedWalletProof_" + index
                ButtonGroup.group: proofPick
                checked: index === sheet.proofIndex
                text: modelData.label
                onClicked: { sheet.proofIndex = index; password.text = "" }
            }
        }
        LogosTextField {
            id: password
            objectName: "seedWalletPassword"
            Layout.fillWidth: true
            visible: sheet.needsPassword
            echoMode: TextInput.Password
            placeholderText: "That account's password"
        }
        LogosText {
            objectName: "seedWalletNameError"
            Layout.fillWidth: true
            visible: sheet.tried && text.length > 0
            wrapMode: Text.WordWrap
            color: Theme.palette.error
            text: sheet.backend ? sheet.backend.lastError : ""
        }

        RowLayout {
            Layout.fillWidth: true
            LogosButton { objectName: "seedWalletNameClose"; text: "Close"; onClicked: sheet.close() }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "seedWalletNameConfirm"
                text: "Rename"
                enabled: !sheet.working && sheet.bundle !== null && sheet.view !== null && sheet.view.custodian
                         && (!sheet.needsPassword || password.text.length > 0)
                onClicked: {
                    var p = sheet.needsPassword ? sheet.proof : null
                    sheet.working = true
                    sheet.tried = true
                    logos.watch(sheet.backend.setSeedWalletName(p ? p.group : sheet.bundle.nodes[0].group.id,
                                                                nameField.text.trim(),
                                                                p ? p.address : "",
                                                                p ? password.text : ""),
                                function (good) {
                                    sheet.working = false
                                    password.text = ""
                                    if (good) sheet.close()
                                })
                }
            }
        }
    }
}
