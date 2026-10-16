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
    // Bitcoin wallets the person may pick from: `[{ id, name, family, chain, device?, hasKey?, signer?,
    // holders? }]`, one per wallet; `holders` are every signer's id for it, `[{ id, signer, device }]`.
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
    // The wallet this open names, or the one picked. An app may name it by any holder's id: then
    // it opens as that holder, a device's with its data password.
    readonly property var target: {
        var id = sheet.asked.group || sheet.picked
        var hit = sheet.wallets.filter(function (w) {
            return w.id === id || (w.holders || []).some(function (h) { return h.id === id })
        })
        if (!hit.length) return null
        var holder = (hit[0].holders || []).filter(function (h) { return h.id === id })[0]
        return holder ? Object.assign({}, hit[0], { id: id, device: holder.device, signer: holder.signer }) : hit[0]
    }
    // A device signs on its own screen: nothing to unlock, and its data has a password of its own.
    readonly property bool onDevice: isOpen && !!(target && target.device)
    readonly property bool firstOpen: onDevice && !target.hasKey
    readonly property bool birthdayOk: birthday.text.trim() === "" || /^\d{4}-\d{2}-\d{2}$/.test(birthday.text.trim())
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
        pwAgain.text = ""
        birthday.text = ""
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
            visible: sheet.isOpen && !sheet.onDevice
            text: "Also unlock it"
        }
        LogosText {
            objectName: "accessDeviceNote"
            visible: sheet.onDevice
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: sheet.onDevice
                  ? "This wallet's key is on " + sheet.target.signer + ": it signs there, so there is nothing to unlock. "
                    + (sheet.firstOpen
                       ? "Set a password for its data: the app keeps the wallet's history encrypted with a key kept "
                         + "here, behind it. Forget it, and the app reads the wallet's history again from the start."
                       : "Type the password of its data, set the first time it was opened.")
                  : ""
        }

        // ── the terms, for an unlock request or an open that unlocks too ───────────
        UnlockTerms {
            id: terms
            namePrefix: "access"
            Layout.fillWidth: true
            visible: !sheet.isOpen || (alsoUnlock.checked && !sheet.onDevice)
        }

        LogosTextField {
            id: pw
            objectName: "accessPasswordField"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: !sheet.isOpen ? "The account's password"
                             : sheet.firstOpen ? "Set a password for this wallet's data"
                             : sheet.onDevice ? "This wallet's data password"
                             : "The wallet's password"
            Component.onCompleted: textInput.passwordMaskDelay = 0
        }
        LogosTextField {
            id: pwAgain
            objectName: "accessPasswordAgainField"
            visible: sheet.firstOpen
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "Type it again"
            Component.onCompleted: textInput.passwordMaskDelay = 0
        }
        // A device keeps no record of when its seed was made; the person may know the day.
        LogosTextField {
            id: birthday
            objectName: "accessBirthdayField"
            visible: sheet.firstOpen
            Layout.fillWidth: true
            placeholderText: "First used on, as YYYY-MM-DD (optional)"
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
                         && (!sheet.firstOpen || (pwAgain.text === pw.text && sheet.birthdayOk))
                         && ((sheet.isOpen && (!alsoUnlock.checked || sheet.onDevice)) || terms.complete)
                onClicked: {
                    var h = sheet.shown.handle
                    var unlock = (!sheet.isOpen || (alsoUnlock.checked && !sheet.onDevice)) ? JSON.stringify(terms.value) : ""
                    var day = sheet.firstOpen ? birthday.text.trim() : ""
                    logos.watch(sheet.backend.approveAccess(h, sheet.shown.bundle_id,
                                                           sheet.picks ? sheet.picked : "", pw.text, unlock, day),
                                function (ok) { if (ok) { sheet.decided(h, true); sheet.close() } })
                    pw.text = ""
                    pwAgain.text = ""
                }
            }
        }
    }
}
