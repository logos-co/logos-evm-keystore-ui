import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// An app asks the signer manager to open a Bitcoin wallet for it, or to unlock an account, and
// the person decides here. The lines are the manager's own, shown verbatim; the requester's
// reason among them is marked as its claim. The title is fixed: LogosDialog renders `title`
// as AutoText, and a module name is not ours to render that way.
LogosDialog {
    id: sheet
    objectName: "accessSheet"
    title: "A request from an app"

    property var backend: null
    // `{ handle, requester, kind, bundle_id, lines, asked }`, from the manager.
    property var shown: ({})
    // Bitcoin wallets the person may pick from: `[{ id, name, family, chain }]`.
    property var wallets: []

    signal decided(string handle, bool approved)
    signal deferred(string handle)
    // The person adds a wallet of the kind asked for; it comes back through pickWallet.
    signal addWallet(string family, string chain)

    readonly property bool isOpen: shown.kind === "open"
    readonly property var asked: shown.asked || ({})
    // A request that names its wallet leaves nothing to pick.
    readonly property bool picks: isOpen && !asked.group
    // The networks a test wallet signs for; a main one signs for the main network only.
    function chainOf(network) {
        return network === "bitcoin" || network === "mainnet" || network === "main" ? "main" : "test"
    }
    readonly property var choices: !picks ? [] : wallets.filter(function (w) {
        return w.family === sheet.asked.family && w.chain === sheet.chainOf(sheet.asked.network)
    })
    property string picked: ""
    function pickWallet(group) {
        picked = group
        for (var i = 0; i < walletRepeater.count; ++i)
            if (sheet.choices[i].id === group) walletRepeater.itemAt(i).checked = true
    }

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 600)

    onOpened: {
        picked = ""
        pw.text = ""
        alsoUnlock.checked = !!(isOpen && asked.unlock)
        terms.load(isOpen ? asked.unlock : asked.terms)
        // An app that named no apps asks for itself.
        terms.defaultApps(shown.requester || "")
    }

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        Repeater {
            model: sheet.shown.lines || []
            delegate: LogosText {
                objectName: "accessLine"
                Layout.fillWidth: true
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                text: modelData
            }
        }

        // ── open: which wallet, and what that hands over ───────────────────────────
        LogosText {
            visible: sheet.picks
            text: sheet.choices.length > 0 ? "Pick the wallet to open, or add one:"
                  : "No wallet here matches. Add one, and it is picked here."
            color: Theme.palette.textSecondary
        }
        ButtonGroup { id: walletGroup }
        Repeater {
            id: walletRepeater
            model: sheet.choices
            delegate: LogosRadioButton {
                objectName: "accessWallet_" + index
                ButtonGroup.group: walletGroup
                text: modelData.name
                onCheckedChanged: if (checked) sheet.picked = modelData.id
                // The list is rebuilt when wallets change; keep the pick checked.
                Component.onCompleted: if (modelData.id === sheet.picked) checked = true
            }
        }
        LogosButton {
            objectName: "accessAddWallet"
            visible: sheet.picks
            text: "Add a wallet…"
            onClicked: sheet.addWallet(sheet.asked.family || "bitcoin", sheet.chainOf(sheet.asked.network))
        }
        LogosText {
            objectName: "accessOpenRisk"
            visible: sheet.isOpen
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Theme.palette.warning
            text: (sheet.shown.requester || "The app") + " will see every address and transaction of "
                  + "this wallet, and can ask you to sign. It can't sign by itself."
        }
        LogosCheckbox {
            id: alsoUnlock
            objectName: "accessAlsoUnlock"
            visible: sheet.isOpen
            text: "Also unlock it"
        }

        // ── the terms, for an unlock request or an open that unlocks too ───────────
        UnlockTerms {
            id: terms
            namePrefix: "access"
            Layout.fillWidth: true
            visible: !sheet.isOpen || alsoUnlock.checked
        }

        LogosTextField {
            id: pw
            objectName: "accessPasswordField"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: sheet.isOpen ? "The wallet's password" : "The account's password"
            Component.onCompleted: textInput.passwordMaskDelay = 0
        }

        RowLayout {
            Layout.fillWidth: true
            LogosButton {
                objectName: "accessRejectButton"
                text: "Reject"
                onClicked: {
                    var h = sheet.shown.handle
                    logos.watch(sheet.backend.rejectAccess(h), function () { sheet.decided(h, false) })
                    pw.text = ""
                    sheet.close()
                }
            }
            LogosButton {
                objectName: "accessLaterButton"
                text: "Not now"
                onClicked: {
                    var h = sheet.shown.handle
                    sheet.backend.dismissAccess()
                    pw.text = ""
                    sheet.close()
                    sheet.deferred(h)
                }
            }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "accessApproveButton"
                text: sheet.isOpen ? "Open" : "Unlock"
                enabled: pw.text.length > 0
                         && (!sheet.picks || sheet.picked !== "")
                         && ((sheet.isOpen && !alsoUnlock.checked) || terms.complete)
                onClicked: {
                    var h = sheet.shown.handle
                    var unlock = (!sheet.isOpen || alsoUnlock.checked) ? JSON.stringify(terms.value) : ""
                    logos.watch(sheet.backend.approveAccess(h, sheet.shown.bundle_id,
                                                           sheet.picks ? sheet.picked : "", pw.text, unlock),
                                function (ok) { if (ok) { sheet.decided(h, true); sheet.close() } })
                    pw.text = ""
                }
            }
        }
    }
}
