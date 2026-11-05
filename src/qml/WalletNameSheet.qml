import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// Name a wallet: the recovery phrase over its account files, or the one file of a wallet not yet
// linked to one. Asked first with no password, which a wallet the Signer app unlocked takes; one
// the keystore refuses is proved by any one account under it, or by the key of a file that holds
// no addresses (a Bitcoin account's). The title is fixed: a name is user-typed.
LogosDialog {
    id: sheet
    objectName: "walletNameSheet"
    title: "Rename wallet"

    property var backend: null
    property var view: null
    // The seed branch the header stands over, as the view lists it.
    property var bundle: null
    property string shownTitle: ""
    // Not linked to a phrase: the name is its one file's.
    property bool fileOnly: false
    // Set once a try with no password was refused.
    property bool askProof: false
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
    readonly property bool needsPassword: sheet.askProof && nameField.text.trim().length > 0 && proof !== null
    // What clearing the name brings back; empty from an older keystore module.
    property string defaultName: ""

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 560)

    onOpened: {
        var seedId = sheet.bundle && sheet.bundle.nodes.length ? (sheet.bundle.nodes[0].group || {}).seedId : ""
        var first = sheet.bundle && sheet.bundle.nodes.length ? sheet.bundle.nodes[0].id : ""
        nameField.text = !sheet.view ? "" : sheet.fileOnly ? sheet.view.walletNameOf(first) : sheet.view.seedNameFor(seedId)
        sheet.defaultName = !sheet.view || sheet.fileOnly ? "" : sheet.view.seedDefaultNameFor(seedId)
        password.text = ""
        sheet.askProof = false
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
            objectName: "seedWalletNameHint"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: sheet.fileOnly ? "Clearing it shows the wallet by its position again."
                  : sheet.defaultName.length > 0
                    ? "Every app shows this name for the wallet. Clearing it gives it back its default name, \u201c"
                      + sheet.defaultName + "\u201d, in every app."
                    : "Every app shows this name for the wallet. Clearing it shows the wallet by its position again."
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
            text: "This wallet isn't unlocked in the Signer app, so naming it asks for the password of "
                  + "one of its accounts. Any one will do."
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
                    var name = nameField.text.trim()
                    var group = p ? p.group : sheet.bundle.nodes[0].group.id
                    sheet.working = true
                    sheet.tried = true
                    var call = sheet.fileOnly
                        ? sheet.backend.setWalletName(group, name, p ? p.address : "", p ? password.text : "")
                        : sheet.backend.setSeedWalletName(group, name, p ? p.address : "", p ? password.text : "")
                    logos.watch(call, function (good) {
                        sheet.working = false
                        password.text = ""
                        if (good) sheet.close()
                        else if (name.length > 0) sheet.askProof = true
                    })
                }
            }
        }
    }
}
