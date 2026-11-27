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
    id: sheetRoot
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
        var nodes = (sheetRoot.bundle && sheetRoot.bundle.nodes) || []
        for (var i = 0; i < nodes.length; ++i) {
            var n = nodes[i]
            if (n.kind !== "wallet" || !sheetRoot.view) continue
            var row = sheetRoot.view.nodeTitle(n)
            if (n.addresses.length > 0)
                n.addresses.forEach(function (a) {
                    out.push({ group: n.group.id, address: a, label: row + " · " + sheetRoot.view.shortAddr(a) })
                })
            else if (sheetRoot.view.keptKeyOf(n))
                out.push({ group: n.group.id, address: "", label: row })
        }
        return out
    }
    readonly property var proof: proofs.length > proofIndex ? proofs[proofIndex] : null
    readonly property bool needsPassword: sheetRoot.askProof && nameField.text.trim().length > 0 && proof !== null
    // What clearing the name brings back; empty from an older keystore module.
    property string defaultName: ""

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 560)

    onOpened: {
        var seedId = sheetRoot.bundle && sheetRoot.bundle.nodes.length ? (sheetRoot.bundle.nodes[0].group || {}).seedId : ""
        var first = sheetRoot.bundle && sheetRoot.bundle.nodes.length ? sheetRoot.bundle.nodes[0].id : ""
        nameField.text = !sheetRoot.view ? "" : sheetRoot.fileOnly ? sheetRoot.view.walletNameOf(first) : sheetRoot.view.seedNameFor(seedId)
        sheetRoot.defaultName = !sheetRoot.view || sheetRoot.fileOnly ? "" : sheetRoot.view.seedDefaultNameFor(seedId)
        password.text = ""
        sheetRoot.askProof = false
        sheetRoot.proofIndex = 0
        sheetRoot.working = false
        sheetError.clear()
        sheetRoot.tried = false
    }
    onClosed: { password.text = ""; sheetError.clear() }

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText {
            objectName: "walletNameCurrent"
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.typography.subtitleText
            text: sheetRoot.shownTitle
        }
        LogosText {
            objectName: "seedWalletNameHint"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: sheetRoot.fileOnly ? "Clearing it shows the wallet by its position again."
                  : sheetRoot.defaultName.length > 0
                    ? "Every app shows this name for the wallet. Clearing it gives it back its default name, \u201c"
                      + sheetRoot.defaultName + "\u201d, in every app."
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
            visible: sheetRoot.needsPassword
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "This wallet isn't unlocked in the Signer app, so naming it asks for the password of "
                  + "one of its accounts. Any one will do."
        }
        ButtonGroup { id: proofPick }
        Repeater {
            model: sheetRoot.needsPassword ? sheetRoot.proofs : []
            delegate: LogosRadioButton {
                objectName: "seedWalletProof_" + index
                ButtonGroup.group: proofPick
                checked: index === sheetRoot.proofIndex
                text: modelData.label
                onClicked: { sheetRoot.proofIndex = index; password.text = "" }
            }
        }
        LogosTextField {
            id: password
            objectName: "seedWalletPassword"
            Layout.fillWidth: true
            visible: sheetRoot.needsPassword
            echoMode: TextInput.Password
            placeholderText: "That account's password"
        }
        SheetError { id: sheetError; objectName: "seedWalletNameError" }

        RowLayout {
            Layout.fillWidth: true
            LogosButton { objectName: "seedWalletNameClose"; text: "Close"; onClicked: sheetRoot.close() }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "seedWalletNameConfirm"
                text: "Rename"
                enabled: !sheetRoot.working && sheetRoot.bundle !== null && sheetRoot.view !== null && sheetRoot.view.custodian
                         && (!sheetRoot.needsPassword || password.text.length > 0)
                onClicked: {
                    var p = sheetRoot.needsPassword ? sheetRoot.proof : null
                    var name = nameField.text.trim()
                    var group = p ? p.group : sheetRoot.bundle.nodes[0].group.id
                    sheetRoot.working = true
                    sheetRoot.tried = true
                    sheetError.clear()
                    var call = sheetRoot.fileOnly
                        ? sheetRoot.backend.setWalletName(group, name, p ? p.address : "", p ? password.text : "")
                        : sheetRoot.backend.setSeedWalletName(group, name, p ? p.address : "", p ? password.text : "")
                    logos.watch(call, function (good) {
                        sheetRoot.working = false
                        password.text = ""
                        if (good) { sheetRoot.close(); return }
                        sheetError.take(sheetRoot.backend, "The name was not saved.")
                        if (name.length > 0) sheetRoot.askProof = true
                    }, function () { sheetRoot.working = false; sheetError.lost() })
                }
            }
        }
    }
}
