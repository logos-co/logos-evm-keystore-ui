import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// A Bitcoin wallet, from a phrase created here, typed, or kept earlier. The wallet keeps its
// account key and its database key in a vault under its own password; keeping the phrase too is
// the person's choice, off unless asked, with what it risks said beside it. The phrase itself is
// held in this sheet only, and cleared on close.
LogosDialog {
    id: sheet
    objectName: "bitcoinImportSheet"
    title: "Add a Bitcoin wallet"

    property var backend: null
    // `[{ id, groups, staged }]`, from the keystore.
    property var phrases: []

    property string source: "create"
    property string phrase: ""
    property var words: []
    property string keptId: ""
    // Set by an app's open request: the kind and chain it asked for, fixed for this wallet.
    property string presetFamily: ""
    property string presetChain: ""

    signal added(string group)

    // Not `reset`: a Dialog already has a reset() signal, which would be emitted instead.
    function clearForm() {
        source = "create"; phrase = ""; words = []; keptId = ""
        typedPhrase.text = ""; confirmWords.text = ""; passphrase.text = ""; keptPw.text = ""
        walletPw.text = ""; walletName.text = ""; keep.reset()
        createOption.checked = true
        if (presetFamily === "bitcoin_taproot") taproot.checked = true; else segwit.checked = true
        if (presetChain === "main") mainChain.checked = true; else testChain.checked = true
    }
    onOpened: clearForm()
    onClosed: { presetFamily = ""; presetChain = ""; clearForm() }

    readonly property bool phraseReady: source === "type" ? typedPhrase.text.trim().split(/\s+/).length >= 12
                                        : source === "kept" ? keptId !== "" && keptPw.text.length > 0
                                        : words.length === 12
                                          && confirmWords.text.trim().toLowerCase().split(/\s+/).join(" ")
                                             === [words[0], words[4], words[11]].join(" ")
    readonly property bool complete: phraseReady && walletPw.text.length > 0
                                     && (source === "kept" || keep.complete)

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 600)

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        ButtonGroup { id: sourceGroup }
        RowLayout {
            LogosRadioButton { id: createOption; objectName: "btcSourceCreate"; ButtonGroup.group: sourceGroup; checked: true; text: "Create a new phrase"; onCheckedChanged: if (checked) sheet.source = "create" }
            LogosRadioButton { objectName: "btcSourceType"; ButtonGroup.group: sourceGroup; text: "Type a phrase"; onCheckedChanged: if (checked) sheet.source = "type" }
            LogosRadioButton { objectName: "btcSourceKept"; ButtonGroup.group: sourceGroup; visible: sheet.phrases.length > 0; text: "Use a kept phrase"; onCheckedChanged: if (checked) sheet.source = "kept" }
        }

        // ── create: generate, show, confirm ───────────────────────────────────────
        LogosButton {
            objectName: "btcGenerateButton"
            visible: sheet.source === "create" && sheet.phrase.length === 0
            text: "Generate a recovery phrase"
            onClicked: logos.watch(sheet.backend.generateMnemonic(12), function (p) {
                sheet.phrase = p || ""
                sheet.words = sheet.phrase.length ? sheet.phrase.split(" ") : []
            })
        }
        LogosText {
            visible: sheet.source === "create" && sheet.phrase.length > 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.warning
            text: "Write this down. It is the only way to recover the wallet, and anyone who reads it can spend from it."
        }
        LogosText {
            objectName: "btcPhraseText"
            visible: sheet.source === "create" && sheet.phrase.length > 0
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: sheet.phrase
        }
        LogosTextField {
            id: confirmWords
            objectName: "btcConfirmField"
            visible: sheet.source === "create" && sheet.phrase.length > 0
            Layout.fillWidth: true
            placeholderText: "Confirm words 1, 5 and 12, separated by spaces"
        }

        // ── type ──────────────────────────────────────────────────────────────────
        LogosTextField {
            id: typedPhrase
            objectName: "btcPhraseField"
            visible: sheet.source === "type"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "Recovery phrase, words separated by spaces"
        }

        // ── kept ──────────────────────────────────────────────────────────────────
        ButtonGroup { id: keptGroup }
        Repeater {
            model: sheet.source === "kept" ? sheet.phrases : []
            delegate: LogosRadioButton {
                objectName: "btcKept_" + index
                ButtonGroup.group: keptGroup
                text: "Kept phrase " + String(modelData.id).substring(0, 10) + "…, used by "
                      + (modelData.groups || []).length + " wallet(s)"
                onCheckedChanged: if (checked) sheet.keptId = modelData.id
            }
        }
        LogosTextField {
            id: keptPw
            objectName: "btcKeptPasswordField"
            visible: sheet.source === "kept"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "The kept phrase's password"
        }

        // A second secret makes sense for a phrase written down long ago, not one being made now.
        LogosTextField {
            id: passphrase
            objectName: "btcPassphraseField"
            visible: sheet.source !== "create"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "BIP39 passphrase (optional)"
        }
        LogosText {
            visible: passphrase.visible && passphrase.text.length > 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "The passphrase is a second secret. Lose it and the phrase alone restores an empty wallet. It is never kept here."
        }

        // ── which wallet ──────────────────────────────────────────────────────────
        LogosText {
            objectName: "btcPresetNote"
            visible: sheet.presetFamily !== ""
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "The app's request decides the kind of wallet and its network."
        }
        ButtonGroup { id: familyGroup }
        RowLayout {
            enabled: sheet.presetFamily === ""
            LogosRadioButton { id: segwit; objectName: "btcFamilySegwit"; ButtonGroup.group: familyGroup; checked: true; text: "Native segwit" }
            LogosRadioButton { id: taproot; objectName: "btcFamilyTaproot"; ButtonGroup.group: familyGroup; text: "Taproot" }
        }
        ButtonGroup { id: chainGroup }
        RowLayout {
            enabled: sheet.presetChain === ""
            LogosRadioButton { id: mainChain; objectName: "btcChainMain"; ButtonGroup.group: chainGroup; text: "Bitcoin" }
            LogosRadioButton { id: testChain; objectName: "btcChainTest"; ButtonGroup.group: chainGroup; checked: true; text: "Test networks (testnet, signet, regtest)" }
        }
        LogosTextField {
            id: walletPw
            objectName: "btcWalletPasswordField"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "Password for this wallet"
        }
        LogosTextField {
            id: walletName
            objectName: "btcWalletNameField"
            Layout.fillWidth: true
            textInput.maximumLength: 40
            placeholderText: "Name this wallet (optional)"
        }

        // ── keeping the phrase ────────────────────────────────────────────────────
        KeepPhraseChoice {
            id: keep
            namePrefix: "btc"
            visible: sheet.source !== "kept"
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            LogosButton { objectName: "btcCancel"; text: "Cancel"; onClicked: sheet.close() }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "btcConfirm"
                text: "Add wallet"
                enabled: sheet.complete
                onClicked: {
                    var family = segwit.checked ? "bitcoin" : "bitcoin_taproot"
                    var chain = mainChain.checked ? "main" : "test"
                    var done = function (group) { if (group) { sheet.added(group); sheet.close() } }
                    if (sheet.source === "kept")
                        logos.watch(sheet.backend.importBitcoinFromKept(sheet.keptId, keptPw.text, passphrase.text,
                                                                        family, chain, walletPw.text, walletName.text.trim()), done)
                    else
                        logos.watch(sheet.backend.importBitcoin(sheet.source === "type" ? typedPhrase.text : sheet.phrase,
                                                                sheet.source === "type" ? passphrase.text : "",
                                                                family, chain, walletPw.text, walletName.text.trim(),
                                                                keep.password), done)
                }
            }
        }
    }
}
