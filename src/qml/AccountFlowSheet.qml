import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

LogosDialog {
    id: sheet
    objectName: "accountFlowSheet"
    title: mode === "request" ? "Add Bitcoin accounts" : mode === "create" ? "Create keystore files" : mode === "extend" ? "Add accounts" : "Import"
    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 720)
    height: Math.min(parent.height - 40, 760)
    closePolicy: working ? Popup.NoAutoClose : Popup.CloseOnEscape
    property var backend: null
    property string mode: "import"
    // An app may request a Bitcoin account with a fixed family and network.
    property string requestHandle: ""
    property string presetFamily: ""
    property string presetChain: ""
    property var phrases: []
    readonly property bool requested: requestHandle !== ""
    property string sourceGroup: ""
    property string keptId: ""
    property bool needsPassphrase: false
    property int step: 0
    property bool working: false
    property string generated: ""
    property int generation: 0
    readonly property int wordCount: [12, 18, 24][wordCountPicker.currentIndex]
    property bool showGenerated: true
    property var rows: []
    property var selected: []
    // Each selected account's own name, by its row key: kept apart so typing doesn't rebuild the rows.
    property var names: ({})
    property int page: 0
    property string notice: ""
    signal importKey()
    signal importFile()
    signal saved(var groups)
    readonly property string family: coin.currentIndex === 0 ? "evm" : scriptType.currentIndex === 0 ? "bitcoin" : "bitcoin_taproot"
    readonly property string chain: testnet.checked ? "test" : "main"
    // A restored Bitcoin wallet may say when it was first used; a created one starts today.
    readonly property bool asksBirthday: mode !== "create" && selected.some(function(r) { return r.family !== "evm" })
    // The keystore checks it is a real day; here, only its shape.
    readonly property bool birthdayOk: !asksBirthday || birthday.text.trim() === "" || /^\d{4}-\d{2}-\d{2}$/.test(birthday.text.trim())
    function clearSecrets() { words.text = ""; phrasePw.text = ""; passphrase.text = ""; password.text = ""; repeatPassword.text = ""; confirmWords.text = ""; generated = "" }
    function generatePhrase() {
        if (working) return
        var request = ++generation
        generated = ""; confirmWords.text = ""; rows = []; selected = []; page = 0
        showGenerated = true; notice = ""; working = true
        logos.watch(backend.generateMnemonic(wordCount), function(p) {
            if (request !== generation || !sheet.opened) return
            working = false
            generated = p || ""
            if (!generated) notice = backend.lastError
        })
    }
    function source() {
        var p = { passphrase: hasPassphrase.checked ? passphrase.text : "" }
        if (keptId) { p.keptPhrase = keptId; p.phrasePassword = phrasePw.text }
        else p.phrase = mode === "create" ? generated : words.text
        if (sourceGroup) p.sourceGroup = sourceGroup
        return p
    }
    function rowKey(row) { return row.family + ":" + row.chain + ":" + row.path }
    function chosen(key) { return selected.some(function(r) { return r.key === key }) }
    function toggle(row, checked) {
        var copy = selected.slice(), key = rowKey(row)
        if (checked && !chosen(key)) { var r = Object.assign({}, row); r.key = key; copy.push(r) }
        if (!checked) copy = copy.filter(function(r) { return r.key !== key })
        selected = copy
    }
    function preview() {
        if (working) return
        notice = ""; rows = []; working = true
        var p = source()
        p.family = family; p.chain = chain; p.account = Number(evmAccount.text || "0"); p.from = page * 5; p.count = 5
        logos.watch(backend.previewSource(JSON.stringify(p)), function(reply) {
            working = false
            if (!sheet.opened) return
            if (!reply) { notice = backend.lastError; return }
            try { rows = JSON.parse(reply); step = 1 } catch (e) { notice = "Could not read the address preview." }
        })
        p = {}
    }
    function refreshPage() { if (step === 1) { page = 0; preview() } }
    function saveSelection() {
        notice = ""; working = true
        // Each account its own name, empty unless given; the wallet's, for a new phrase only.
        var named = selected.map(function(r) { return Object.assign({}, r, { name: (names[r.key] || "").trim() }) })
        var p = { source: source(), selected: named, walletName: sourceGroup ? "" : groupName.text.trim(), password: password.text,
                  keepRecovery: keep.checked && !keptId, origin: mode === "create" ? "created" : "restored",
                  birthday: asksBirthday ? birthday.text.trim() : "" }
        logos.watch(backend.saveAccounts(JSON.stringify(p)), function(reply) {
            working = false
            var r
            try { r = JSON.parse(reply) } catch (e) { notice = "Could not read the save result. Check the account list before retrying."; return }
            var done = r.saved || []
            selected = selected.filter(function(row) { return done.indexOf(row.key) < 0 })
            if (r.keptPhrase && !keptId) { keptId = r.keptPhrase; phrasePw.text = password.text; words.text = ""; generated = "" }
            password.text = ""; repeatPassword.text = ""
            if (!r.error && selected.length === 0) { sheet.saved(r.groups || []); sheet.close() }
            else notice = (done.length ? "Saved " + done.length + " account(s). Remaining accounts were not saved. " : "") + (r.error || "Check the file list before retrying.")
        })
        p = {}
    }
    onOpened: {
        clearSecrets(); rows = []; selected = []; names = ({}); page = 0; notice = ""; working = false
        step = mode === "import" || mode === "request" ? -1 : 0
        coin.currentIndex = presetFamily ? 1 : 0; scriptType.currentIndex = presetFamily === "bitcoin_taproot" ? 1 : 0; testnet.checked = presetChain === "test"
        evmAccount.text = "0"; groupName.text = ""; birthday.text = ""; keep.checked = false; advanced.checked = false
        hasPassphrase.checked = needsPassphrase; showGenerated = true
        wordCountPicker.currentIndex = 0
        if (mode === "create") generatePhrase()
    }
    onClosed: { generation++; working = false; clearSecrets(); rows = []; selected = []; names = ({}); sourceGroup = ""; keptId = ""; needsPassphrase = false; notice = ""; requestHandle = ""; presetFamily = ""; presetChain = "" }
    contentItem: ColumnLayout {
        spacing: Theme.spacing.small
        LogosText {
            visible: sheet.step >= 0
            text: sheet.step >= 0 ? ["1 · Recovery source", "2 · Choose accounts", "3 · Save files"][sheet.step] : ""
            color: Theme.palette.textSecondary
        }
        LogosText {
            objectName: "flowRequestScope"; visible: sheet.requested
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "The app requested " + (sheet.presetFamily === "bitcoin_taproot" ? "Bitcoin Taproot" : "Bitcoin Native SegWit")
                  + (sheet.presetChain === "main" ? " on Bitcoin mainnet." : " on test networks.")
                  + " After saving, review the request before opening the account for the app."
        }
        LogosScrollView {
            id: flowScroll
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: availableWidth
            ColumnLayout {
                width: flowScroll.availableWidth
                spacing: Theme.spacing.small
                ColumnLayout {
                    visible: sheet.step === -1; Layout.fillWidth: true
                    LogosButton {
                        objectName: "flowCreatePhrase"; visible: sheet.requested
                        text: "Create a recovery phrase"; Layout.fillWidth: true
                        onClicked: { sheet.mode = "create"; sheet.step = 0; sheet.generatePhrase() }
                    }
                    LogosButton { visible: !sheet.requested; text: "Keystore file"; Layout.fillWidth: true; onClicked: { sheet.close(); sheet.importFile() } }
                    LogosButton { objectName: "flowImportPhrase"; text: "Recovery phrase"; Layout.fillWidth: true; onClicked: { sheet.mode = "import"; sheet.step = 0 } }
                    RowLayout {
                        visible: sheet.requested && sheet.phrases.length > 0
                        Layout.fillWidth: true
                        LogosComboBox {
                            id: keptSource; objectName: "flowKeptSource"; Layout.fillWidth: true
                            model: sheet.phrases.map(function(p) { return p.id })
                        }
                        LogosButton {
                            objectName: "flowUseKept"; text: "Use saved recovery source"
                            enabled: keptSource.currentIndex >= 0
                            onClicked: { sheet.mode = "extend"; sheet.keptId = sheet.phrases[keptSource.currentIndex].id; sheet.step = 0 }
                        }
                    }
                    LogosButton { visible: !sheet.requested; text: "Private key"; Layout.fillWidth: true; onClicked: { sheet.close(); sheet.importKey() } }
                }
                ColumnLayout {
                    visible: sheet.step === 0; Layout.fillWidth: true
                    LogosText {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        text: sheet.mode === "create" ? "Write this down. It is the only way to recover the account, it is shown "
                                                        + "once, and anyone who reads it can spend from the account."
                            : sheet.keptId ? "Unlock the encrypted recovery source to preview more accounts."
                            : "Enter your recovery phrase to preview Ethereum and Bitcoin accounts."
                    }
                    RowLayout {
                        visible: sheet.mode === "create" && sheet.showGenerated
                        Layout.fillWidth: true
                        LogosComboBox {
                            id: wordCountPicker; objectName: "flowWordCount"
                            model: ["12 words", "18 words", "24 words"]
                            enabled: !sheet.working
                            Accessible.name: "Recovery phrase length"
                            onActivated: sheet.generatePhrase()
                        }
                        LogosInfoButton { objectName: "phraseLengthInfo"; title: "Recovery phrase length"; Accessible.name: "Help: Recovery phrase length"; text: "Choose 12, 18 or 24 words before recording the phrase. Longer phrases contain more entropy and take more words to back up. All supported lengths can derive Ethereum and Bitcoin accounts. Changing the length or choosing New phrase replaces the entire phrase and its addresses; write down the final words in numbered order." }
                        Item { Layout.fillWidth: true }
                        LogosButton {
                            objectName: "flowRegenerate"; text: "New phrase"
                            enabled: !sheet.working
                            onClicked: sheet.generatePhrase()
                        }
                    }
                    GridLayout {
                        objectName: "flowGeneratedWords"
                        visible: sheet.mode === "create" && sheet.showGenerated
                        Layout.fillWidth: true
                        columns: width < 380 ? 1 : 2
                        columnSpacing: Theme.spacing.small
                        rowSpacing: Theme.spacing.small
                        Repeater {
                            model: sheet.mode === "create" && sheet.showGenerated && sheet.generated ? sheet.generated.split(" ") : []
                            delegate: Frame {
                                objectName: "flowWord_" + index
                                Layout.fillWidth: true
                                padding: 6
                                background: Rectangle { radius: 6; color: Theme.palette.backgroundMuted }
                                contentItem: RowLayout {
                                    spacing: Theme.spacing.small
                                    LogosText {
                                        text: (index + 1) + "."
                                        Layout.preferredWidth: 26
                                        color: Theme.palette.textSecondary
                                    }
                                    LogosText {
                                        Layout.fillWidth: true
                                        text: modelData; textFormat: Text.PlainText
                                    }
                                }
                            }
                        }
                    }
                    LogosButton {
                        visible: sheet.mode === "create" && sheet.generated.length > 0
                        text: sheet.showGenerated ? "I've written it down" : "Show phrase again"
                        onClicked: sheet.showGenerated = !sheet.showGenerated
                    }
                    LogosTextField {
                        id: confirmWords; objectName: "flowConfirmWords"; Layout.fillWidth: true
                        visible: sheet.mode === "create" && !sheet.showGenerated
                        placeholderText: "Confirm words 1, 5 and " + sheet.wordCount
                    }
                    LogosTextField {
                        id: words; objectName: "flowWords"; Layout.fillWidth: true
                        visible: sheet.mode !== "create" && !sheet.keptId
                        echoMode: TextInput.Password; placeholderText: "Recovery phrase"
                    }
                    LogosTextField {
                        id: phrasePw; objectName: "flowPhrasePassword"; Layout.fillWidth: true
                        visible: !!sheet.keptId; echoMode: TextInput.Password; placeholderText: "Recovery source password"
                    }
                    RowLayout {
                        visible: sheet.mode !== "create"
                        LogosCheckbox { id: hasPassphrase; objectName: "flowHasPassphrase"; text: "This recovery phrase has a BIP39 passphrase" }
                        LogosInfoButton { objectName: "bip39PassphraseInfo"; title: "BIP39 passphrase"; Accessible.name: "Help: BIP39 passphrase"; text: "Use this only if the wallet was originally created with an additional BIP39 passphrase. Every different passphrase, including a typo, produces different accounts. It is separate from the password that encrypts your account files and must be backed up separately." }
                    }
                    LogosTextField {
                        id: passphrase; objectName: "flowPassphrase"; Layout.fillWidth: true
                        visible: hasPassphrase.checked; echoMode: TextInput.Password; placeholderText: "BIP39 passphrase (exactly as originally used)"
                    }
                    // The field is masked, so a stray space is invisible, and it derives other accounts.
                    LogosText {
                        objectName: "flowPassphraseHint"; visible: hasPassphrase.checked && passphrase.text.length > 0
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.palette.textSecondary
                        text: passphrase.text.length + " characters"
                              + (passphrase.text !== passphrase.text.trim()
                                 ? " — starts or ends with a space, which counts as part of it" : "")
                    }
                    LogosText {
                        visible: hasPassphrase.checked; Layout.fillWidth: true; wrapMode: Text.WordWrap
                        text: "This is separate from the file password. It changes every address and is never saved here."
                    }
                }
                ColumnLayout {
                    visible: sheet.step === 1; Layout.fillWidth: true
                    RowLayout {
                        Layout.fillWidth: true
                        ComboBox { id: coin; objectName: "flowCoin"; model: ["Ethereum", "Bitcoin"]; enabled: !sheet.working && !sheet.requested; onActivated: sheet.refreshPage() }
                        LogosCheckbox { id: testnet; objectName: "flowTestnet"; visible: coin.currentIndex === 1; enabled: !sheet.working && !sheet.requested; text: "Test networks"; onToggled: sheet.refreshPage() }
                    }
                    RowLayout {
                        LogosCheckbox { id: advanced; text: "Advanced derivation settings" }
                        LogosInfoButton { objectName: "derivationInfo"; title: "Finding the same accounts"; Accessible.name: "Help: Finding the same accounts"; text: "The recovery phrase, BIP39 passphrase and derivation path together determine an account. Use the same settings as the wallet you are restoring. Ethereum branches and Bitcoin address types can reveal different accounts from the same phrase. The Bitcoin preview shows the first receiving address for each account, not every address in it." }
                    }
                    RowLayout {
                        visible: advanced.checked; Layout.fillWidth: true
                        LogosText { visible: coin.currentIndex === 0; text: "Ethereum account branch" }
                        LogosTextField {
                            id: evmAccount; objectName: "flowEvmBranch"; visible: coin.currentIndex === 0
                            Layout.fillWidth: true; text: "0"; enabled: !sheet.working
                            validator: RegularExpressionValidator { regularExpression: /[0-9]{1,10}/ }
                        }
                        ComboBox { id: scriptType; objectName: "flowScript"; visible: coin.currentIndex === 1; model: ["Native SegWit (BIP84)", "Taproot (BIP86)"]; enabled: !sheet.working && !sheet.requested; onActivated: sheet.refreshPage() }
                        LogosButton { text: "Preview"; enabled: !sheet.working; onClicked: sheet.refreshPage() }
                    }
                    LogosText {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.palette.textSecondary
                        text: coin.currentIndex === 0 ? "Select addresses to save as standard Ethereum keystore files."
                            : "Each Bitcoin account includes receive and change addresses. The first receiving address is shown."
                    }
                    Repeater {
                        model: sheet.rows
                        delegate: Frame {
                            Layout.fillWidth: true
                            RowLayout {
                                anchors.fill: parent
                                LogosCheckbox {
                                    objectName: "flowSelect_" + index
                                    checked: sheet.chosen(sheet.rowKey(modelData))
                                    enabled: !sheet.working && !modelData.present && (checked || sheet.selected.length < 20)
                                    onToggled: sheet.toggle(modelData, checked)
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    LogosText { text: (modelData.family === "evm" ? "Ethereum " : "Bitcoin ") + (modelData.index + 1) + (modelData.present ? " · Already saved" : "") }
                                    LogosText { Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; textFormat: Text.PlainText; text: modelData.address }
                                    LogosText { visible: advanced.checked; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; color: Theme.palette.textSecondary; text: modelData.path }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LogosButton { objectName: "flowPrevious"; text: "Previous"; enabled: !sheet.working && sheet.page > 0; onClicked: { sheet.page--; sheet.preview() } }
                        LogosText { text: (sheet.page * 5 + 1) + "–" + (sheet.page * 5 + 5) }
                        LogosButton { objectName: "flowNext"; text: "Next"; enabled: !sheet.working && sheet.page < 429496728; onClicked: { sheet.page++; sheet.preview() } }
                        Item { Layout.fillWidth: true }
                    }
                }
                ColumnLayout {
                    visible: sheet.step === 2; Layout.fillWidth: true
                    LogosTextField {
                        id: groupName; objectName: "flowName"; Layout.fillWidth: true
                        visible: !sheet.sourceGroup
                        placeholderText: "Wallet name (optional)"; textInput.maximumLength: 40
                    }
                    Repeater {
                        model: sheet.selected
                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            LogosText {
                                Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; textFormat: Text.PlainText
                                text: (modelData.family === "evm" ? "Ethereum keystore JSON" : "Bitcoin account file") + " · " + modelData.path + "\n" + modelData.address
                            }
                            LogosTextField {
                                objectName: "flowAccountName_" + index
                                Layout.fillWidth: true
                                placeholderText: "Account name (optional)"; textInput.maximumLength: 40
                                text: sheet.names[modelData.key] || ""
                                onTextChanged: sheet.names[modelData.key] = text
                            }
                        }
                    }
                    LogosTextField { id: password; objectName: "flowPassword"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Password for the new files" }
                    LogosTextField { id: repeatPassword; objectName: "flowRepeatPassword"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Confirm password" }
                    RowLayout {
                        visible: !sheet.keptId
                        LogosCheckbox { id: keep; objectName: "flowKeepRecovery"; text: "Keep an encrypted recovery source" }
                        LogosInfoButton { objectName: "recoverySourceInfo"; title: "Keeping a recovery source"; Accessible.name: "Help: Keeping a recovery source"; text: "Account files hold only the keys needed for the selected accounts. The optional recovery source is a separate encrypted file that can derive more accounts from the same phrase. It uses the new files password when saved. Keep your own recovery backup even if you enable this option; a BIP39 passphrase is not saved here." }
                    }
                    LogosTextField {
                        id: birthday; objectName: "flowBirthday"; Layout.fillWidth: true
                        visible: sheet.asksBirthday; placeholderText: "Bitcoin wallet first used on, as YYYY-MM-DD (optional)"
                    }
                    LogosText {
                        objectName: "flowBirthdayHint"; visible: sheet.asksBirthday
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        color: sheet.birthdayOk ? Theme.palette.textSecondary : Theme.palette.warning
                        text: sheet.birthdayOk
                              ? "Apps look for this wallet's coins from this day on. A day after its first use hides older coins; if unsure, leave it empty and they look from the beginning, which takes longer."
                              : "Write the day as YYYY-MM-DD, such as 2021-11-14."
                    }
                    LogosText {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.palette.textSecondary
                        text: sheet.keptId ? "The existing encrypted recovery source will be reused. Its password stays unchanged."
                            : keep.checked ? "Saved separately with the same password. Unlock it later to add accounts."
                            : "Only the selected account keys are saved. Enter your recovery phrase again to add more accounts."
                    }
                }
                LogosText {
                    objectName: "flowNotice"; visible: sheet.notice.length > 0
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; textFormat: Text.PlainText
                    color: Theme.palette.error; text: sheet.notice
                }
            }
        }
        LogosText { visible: sheet.step === 1; text: sheet.selected.length + " selected across account types (up to 20)" }
        RowLayout {
            Layout.fillWidth: true
            LogosButton { objectName: "flowCancel"; text: "Cancel"; enabled: !sheet.working; onClicked: sheet.close() }
            LogosButton {
                objectName: "flowBack"; text: "Back"; visible: sheet.step > 0 || (sheet.requested && sheet.step === 0); enabled: !sheet.working
                onClicked: { if (sheet.step === 0) { sheet.clearSecrets(); sheet.keptId = ""; hasPassphrase.checked = false; sheet.mode = "request" }; sheet.step--; sheet.notice = ""; if (sheet.step === 0) { sheet.rows = []; sheet.selected = [] } }
            }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "flowContinue"; visible: sheet.step === 0
                text: sheet.working ? "Loading…" : "Choose accounts"
                enabled: !sheet.working && (sheet.keptId ? phrasePw.text.length > 0
                    : sheet.mode !== "create" ? words.text.trim().length > 0
                    : !sheet.showGenerated && sheet.generated.length > 0 && confirmWords.text.trim().toLowerCase().split(/\s+/).join(" ") === [sheet.generated.split(" ")[0], sheet.generated.split(" ")[4], sheet.generated.split(" ")[sheet.wordCount - 1]].join(" "))
                onClicked: sheet.preview()
            }
            LogosButton { objectName: "flowReview"; visible: sheet.step === 1; text: "Continue"; enabled: !sheet.working && sheet.selected.length > 0; onClicked: sheet.step = 2 }
            LogosButton {
                objectName: "flowSave"; visible: sheet.step === 2; text: sheet.working ? "Saving…" : "Save " + sheet.selected.length + " account(s)"
                enabled: !sheet.working && sheet.selected.length > 0 && password.text.length > 0 && password.text === repeatPassword.text
                         && sheet.birthdayOk
                onClicked: sheet.saveSelection()
            }
        }
    }
}
