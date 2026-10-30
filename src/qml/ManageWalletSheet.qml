import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// Manage one account file: a row under a wallet (its recovery phrase), which is named on its
// own header. Called a "wallet" here before the keystore gave the seed that name.
//
// Everything here is a property of the WALLET, not of an account. Offering "stop keeping the
// derivation key" once per account meant a wallet with three accounts offered it three times,
// each behind a different address, and each doing the same thing to all three.
//
// The title is fixed. LogosDialog renders `title` through a bare LogosText, i.e. AutoText, so
// a wallet's name — the one user-typed string on this screen — is shown in the body instead.
LogosDialog {
    id: sheet
    objectName: "manageWalletSheet"
    title: "Manage account file"

    property var backend: null
    // The row's title as the list shows it, and whether a wallet (seed) stands over the row and
    // keeps its recovery phrase here: then accounts are added from that phrase's password.
    property string rowTitle: ""
    property bool seedLinked: false
    property bool phraseKept: false
    property var view: null
    property var group: null
    // A key on disk that this frame stands for rather than a recorded wallet. Deleting it is
    // offered on its own row, so this sheet only adds a name. `recordKnown` is false when the
    // wallet list was refused: the key is a frame either way, but nothing here knows why.
    property bool stranded: false
    property bool recordKnown: true
    // The accounts nested under this wallet, and whether that could be read at all. Both
    // decide what naming it costs: a wallet's name is a claim about the accounts under it.
    property var addresses: []
    property bool countKnown: true
    // Offered only where the view could SHOW the wallet holds nothing — see walletRemovable.
    property bool removable: false
    // A derivation key on disk at either path, as the view read it. Whole-wallet material,
    // so it is what removal refuses on and what naming has to be proved against.
    property bool keptKey: false
    // A name with no record and no key left under it. There is no wallet to manage here —
    // only the name, and the row it keeps on screen.
    property bool nameOnly: false
    readonly property bool keysKnown: sheet.view ? sheet.view.keyDirectoryKnown : true
    // The wallet holds nothing, and both reads behind that claim answered.
    readonly property bool holdsNothing:
        sheet.countKnown && sheet.addresses.length === 0 && sheet.keysKnown && !sheet.keptKey

    signal removeRequested()

    // Which account proves this wallet is the user's. Any one of them does: holding one is
    // exactly the claim a name on the header makes about the accounts beneath it.
    property string credAddress: ""
    // What the wallet HOLDS prices the name, exactly as the keystore prices it: an account's
    // password where it has accounts, and where it has only a key, that key's — the name will
    // come to stand over whatever it mints. Only a wallet that holds nothing is free.
    readonly property bool provedByAccount: sheet.addresses.length > 0
    readonly property bool provedByKey: sheet.addresses.length === 0 && sheet.keptKey
    readonly property bool needsCredential:
        (sheet.provedByAccount || sheet.provedByKey) && nameField.text.trim().length > 0

    // Why removing the row is not offered, where it is not. Reached only with the key
    // directory read and no live key on disk, so the cases are: the accounts could not be
    // read, accounts remain, or an interrupted import left a copy of the key.
    readonly property string removeBlockedLine:
        sheet.removable ? ""
        : !sheet.countKnown
          ? " Whether it holds accounts could not be read, so removing the account file itself is "
            + "not offered here."
        : sheet.addresses.length > 0
          ? " Removing the account file itself is offered once it holds no accounts: this record "
            + "is what says where they came from, so delete them first."
        : " An interrupted import left a copy of this account file's derivation key here. "
          + "Removing the account file itself is offered once nothing of it is stored."

    readonly property string storedName:
        (view && group) ? view.walletNameOf(group.id) : ""
    readonly property bool duplicateName:
        (view && group) ? view.walletQualifierOf(group.id).length > 0 : false

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 560)

    onOpened: {
        forgetAck.checked = false
        nameField.text = sheet.storedName
        credPw.text = ""
        sheet.credAddress = sheet.addresses.length > 0 ? sheet.addresses[0] : ""
    }
    onClosed: { forgetAck.checked = false; credPw.text = ""; sheet.credAddress = "" }

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText {
            objectName: "manageWalletName"
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.typography.subtitleText
            text: sheet.rowTitle || (sheet.view ? sheet.view.walletTitleOf(sheet.group) : "")
        }
        LogosText {
            objectName: "manageWalletPath"
            Layout.fillWidth: true
            textFormat: Text.PlainText
            font.family: Theme.typography.mono
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            text: sheet.view ? sheet.view.walletSubtitleOf(sheet.group) : ""
        }

        // Where a name is changed. An unnamed wallet is shown by its position, and a position
        // moves when another wallet is imported — a name is the only thing that stays put.
        LogosText { text: "Name"; color: Theme.palette.textSecondary }
        RowLayout {
            Layout.fillWidth: true
            LogosTextField {
                id: nameField
                objectName: "walletNameField"
                Layout.fillWidth: true
                textInput.maximumLength: 40
                placeholderText: "Name this account file"
            }
            LogosButton {
                objectName: "walletNameConfirm"
                text: "Rename"
                enabled: sheet.group !== null && sheet.view !== null && sheet.view.custodian
                         && (!sheet.needsCredential || credPw.text.length > 0)
                onClicked: logos.watch(
                    sheet.backend.setWalletName(sheet.group.id, nameField.text,
                                                sheet.provedByAccount ? sheet.credAddress : "",
                                                sheet.needsCredential ? credPw.text : ""),
                    function (good) { if (good) credPw.text = "" })
            }
        }

        // ── Proving the wallet is yours ────────────────────────────────────────────
        // A wallet name is a claim about the accounts nested under it, so it is proved by
        // holding one of them. Any of them: an attacker would pick the weakest password
        // either way, and refusing the others would only lock out the honest owner.
        ButtonGroup { id: credPick }
        LogosText {
            objectName: "walletNameCredentialHint"
            Layout.fillWidth: true
            visible: sheet.needsCredential && sheet.provedByAccount
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "Naming an account file renames what other screens show in place of its accounts' "
                  + "addresses, so it asks for the password of one of them. Any one will do."
        }
        LogosText {
            objectName: "walletNameKeyCredentialHint"
            Layout.fillWidth: true
            visible: sheet.needsCredential && sheet.provedByKey
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "This account file has no accounts yet, but it keeps a derivation key that can add "
                  + "them — and they would be shown under this name. So the name is proved "
                  + "against that key, with the password you chose for it."
        }
        Repeater {
            // Rebuilt whenever the block appears, so a pick from a previous open cannot
            // survive as a checked radio the sheet no longer agrees with.
            model: (sheet.needsCredential && sheet.provedByAccount) ? sheet.addresses : []
            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.small
                LogosRadioButton {
                    objectName: "walletCredPick_" + modelData
                    ButtonGroup.group: credPick
                    checked: modelData === sheet.credAddress
                    Accessible.name: "Use this account"
                    onClicked: sheet.credAddress = modelData
                }
                LogosText {
                    objectName: "walletCredAddress_" + modelData
                    textFormat: Text.PlainText
                    font.family: Theme.typography.mono
                    text: sheet.view ? sheet.view.shortAddr(modelData) : ""
                }
            }
        }
        LogosTextField {
            id: credPw
            objectName: "walletNamePasswordField"
            Layout.fillWidth: true
            visible: sheet.needsCredential
            echoMode: TextInput.Password
            placeholderText: sheet.provedByKey ? "This account file's derivation key password"
                                               : "That account's password"
        }
        // Both halves of the rule the keystore actually applies, said where it applies.
        LogosText {
            objectName: "walletNameNoSecret"
            Layout.fillWidth: true
            visible: sheet.holdsNothing
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "No password is asked for here. This account file holds nothing — no accounts, and "
                  + "no derivation key — so its name stands in for nothing, and with no key it "
                  + "can never gain an account for the name to come to stand over."
        }
        LogosText {
            objectName: "walletNameCountUnread"
            Layout.fillWidth: true
            visible: (!sheet.countKnown || !sheet.keysKnown) && nameField.text.trim().length > 0
            wrapMode: Text.WordWrap
            color: Theme.palette.warning
            text: (sheet.countKnown ? "The keys stored on disk could not be read"
                                    : "Which accounts belong to this account file could not be read")
                  + ", so nothing here can tell what naming it has to be proved against. The "
                  + "keystore checks for itself and will say so if a password is needed."
        }
        LogosText {
            objectName: "walletNameHint"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            // Under a wallet a row is shown by its kind and number, not by its position.
            text: sheet.seedLinked
                  ? (sheet.storedName.length === 0
                     ? "A name is shown after its kind and number, as in the list."
                     : "Clearing this field removes the name.")
                  : sheet.storedName.length === 0
                    ? "Unnamed account files are shown by their position in this list, which "
                      + "importing another can change. A name stays where you put it."
                    : "Clearing this field removes the name and shows this account file by its "
                      + "position again."
        }
        LogosText {
            objectName: "walletNameDuplicate"
            Layout.fillWidth: true
            visible: sheet.duplicateName && !sheet.seedLinked
            wrapMode: Text.WordWrap
            color: Theme.palette.warning
            text: "Another account file here carries this name too. Both are shown with the start "
                  + "of their id beside it, because a name that names two of them is not one."
        }

        LogosText {
            objectName: "strandedHere"
            Layout.fillWidth: true
            visible: sheet.stranded
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: sheet.recordKnown
                  ? "No wallet record here accounts for this derivation key, so there is nothing "
                    + "else to manage. Deleting the key is offered on its own row."
                  : "The wallet list could not be read, so what this derivation key belongs to "
                    + "is not known here. Deleting it is offered on its own row."
        }

        // A real, cheap reduction in exposure for someone who is done adding accounts —
        // and the only direction this choice can be changed in.
        LogosText {
            visible: !sheet.stranded && sheet.group !== null && sheet.group.derivable === true
            text: "Derivation"
            color: Theme.palette.textSecondary
        }
        LogosText {
            objectName: "forgetDerivationWarning"
            Layout.fillWidth: true
            visible: !sheet.stranded && (sheet.view ? sheet.view.hasKeyOnDisk(sheet.group) : false)
            wrapMode: Text.WordWrap
            text: "This account file keeps a derivation key, so accounts can be added without its "
                  + "recovery phrase. Removing it cannot be undone, and it does not need the "
                  + "key's password — a key you can no longer open is exactly the one worth "
                  + "removing. The accounts you already have keep working exactly as they do "
                  + "now — they simply stop being extendable, so adding another means typing "
                  + "the phrase again."
        }
        LogosText {
            objectName: "forgetDerivationStaged"
            Layout.fillWidth: true
            visible: !sheet.stranded && sheet.group !== null && sheet.group.staged === true
            wrapMode: Text.WordWrap
            color: Theme.palette.warning
            text: "An interrupted import left a copy of this account file's derivation key here. "
                  + "It cannot add accounts, but it opens the whole account file just as the real "
                  + "key would — so removing the account file itself is refused while it is here, "
                  + "and naming it asks for that key's password."
        }
        LogosCheckbox {
            id: forgetAck
            objectName: "forgetDerivationAck"
            visible: !sheet.stranded && (sheet.view ? sheet.view.hasKeyOnDisk(sheet.group) : false)
            text: "I understand this cannot be undone"
        }
        LogosButton {
            objectName: "forgetDerivationConfirm"
            visible: !sheet.stranded && (sheet.view ? sheet.view.hasKeyOnDisk(sheet.group) : false)
            text: "Stop keeping the derivation key"
            enabled: forgetAck.checked
            onClicked: logos.watch(sheet.backend.forgetDerivation(sheet.group.id),
                function (good) { if (good) sheet.close() })
        }

        LogosText {
            objectName: "walletNothingToManage"
            Layout.fillWidth: true
            // Only when the key directory ANSWERED. A refused read empties it, and "keeps no
            // derivation key" is then the read failing, stated as a fact about the wallet.
            visible: !sheet.stranded && !sheet.nameOnly && sheet.group !== null && sheet.keysKnown
                     && !(sheet.view && sheet.view.hasKeyOnDisk(sheet.group))
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            // It used to end "there is nothing stored here to remove", which is true about the
            // KEY and useless to someone who wants the row gone. Removing the row is a
            // different thing, and it is offered below or explained here.
            text: (sheet.phraseKept
                   ? "This account file keeps no derivation key. To add accounts, use Add accounts… "
                     + "on its wallet: the recovery phrase kept here opens with its password, "
                     + "without typing the words."
                   : "This account file keeps no derivation key, so adding an account means "
                     + "typing its recovery phrase again.") + sheet.removeBlockedLine
        }

        LogosText {
            objectName: "nameOnlyLeftover"
            Layout.fillWidth: true
            visible: sheet.nameOnly
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "Nothing is stored under this account file but the name itself — no record, no "
                  + "derivation key, no accounts. Clearing the field above removes it, and so "
                  + "does removing the row."
        }

        // ── Remove the wallet itself ───────────────────────────────────────────────
        LogosText { visible: sheet.removable; text: "Remove"; color: Theme.palette.error }
        LogosText {
            objectName: "removeWalletOffer"
            Layout.fillWidth: true
            visible: sheet.removable
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "This account file holds nothing: no derivation key, and no accounts. Removing it "
                  + "takes away its name and its record, and touches nothing else."
        }
        LogosButton {
            objectName: "removeWalletStart"
            visible: sheet.removable
            text: "Remove this account file"
            enabled: sheet.view !== null && sheet.view.custodian
            onClicked: sheet.removeRequested()
        }

        LogosText {
            objectName: "walletKeysUnread"
            Layout.fillWidth: true
            visible: !sheet.stranded && sheet.group !== null && !sheet.keysKnown
            wrapMode: Text.WordWrap
            color: Theme.palette.warning
            text: "The keys stored on disk could not be read, so whether this account file keeps a "
                  + "derivation key is not known here."
        }

        LogosButton { objectName: "manageWalletClose"; text: "Close"; onClicked: sheet.close() }
    }
}
