import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme
import "accountkit" as Accounts

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
    property var fileGroups: []
    readonly property bool requested: requestHandle !== ""
    property string sourceGroup: ""
    // Added to this wallet (its seed): the new files take its password, asked once.
    property string walletSeed: ""
    readonly property bool joining: walletSeed !== ""
    // A kept phrase's wallet: the seed of the files it made.
    function seedOfKept(id) {
        var p = phrases.filter(function(x) { return x.id === id })[0]
        var first = p && (p.groups || []).length ? p.groups[0] : ""
        var g = fileGroups.filter(function(x) { return x.id === first })[0]
        return g && g.seedId ? g.seedId : ""
    }
    property string keptId: ""
    property bool needsPassphrase: false
    property int step: 0
    property bool working: false
    property string generated: ""
    property int generation: 0
    readonly property int wordCount: [12, 18, 24][wordCountPicker.currentIndex]
    property bool showGenerated: true
    // A new phrase stays hidden behind its warning until the person chooses to see it, as on Keycard.
    property bool revealed: false
    // The backup check, as in the Keycard app: three random positions, typed back.
    property var confirmPos: []
    readonly property var seedList: generated ? generated.split(" ") : []
    function pickConfirm() {
        var all = []; for (var i = 0; i < seedList.length; ++i) all.push(i)
        for (var k = all.length - 1; k > 0; --k) { var r = Math.floor(Math.random() * (k + 1)); var t = all[k]; all[k] = all[r]; all[r] = t }
        confirmPos = all.slice(0, 3).sort(function (a, b) { return a - b })
        cw0.text = ""; cw1.text = ""; cw2.text = ""
    }
    function wordOk(field, n) { return field.text.trim().toLowerCase() === (seedList[confirmPos[n]] || "") }
    readonly property bool confirmValid: confirmPos.length === 3 && wordOk(cw0, 0) && wordOk(cw1, 1) && wordOk(cw2, 2)
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
    function clearSecrets() { words.text = ""; phrasePw.text = ""; passphrase.text = ""; password.text = ""; repeatPassword.text = ""; cw0.text = ""; cw1.text = ""; cw2.text = ""; generated = "" }
    function generatePhrase() {
        if (working) return
        var request = ++generation
        generated = ""; cw0.text = ""; cw1.text = ""; cw2.text = ""; rows = []; selected = []; page = 0
        showGenerated = true; notice = ""; working = true
        logos.watch(backend.generateMnemonic(wordCount), function(p) {
            if (request !== generation || !sheet.opened) return
            working = false
            generated = p || ""
            if (!generated) notice = backend.lastError || "Could not make a recovery phrase."
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
        if (checked && !chosen(key)) { let r = Object.assign({}, row); r.key = key; copy.push(r) }
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
                  keepRecovery: keep.checked && !keptId }
        if (joining) p.wallet = walletSeed
        logos.watch(backend.saveAccounts(JSON.stringify(p)), function(reply) {
            working = false
            var r
            try { r = JSON.parse(reply) } catch (e) { notice = "Could not read the save result. Check the account list before retrying."; return }
            var done = r.saved || []
            selected = selected.filter(function(row) { return done.indexOf(row.key) < 0 })
            if (r.keptPhrase && !keptId) { keptId = r.keptPhrase; phrasePw.text = password.text; words.text = ""; generated = "" }
            password.text = ""; repeatPassword.text = ""
            // Every account saved: what went wrong after that, such as a name, stays in the view.
            if (selected.length === 0) { sheet.saved(r.groups || []); sheet.close() }
            else notice = (done.length ? "Saved " + done.length + " account(s). Remaining accounts were not saved. " : "") + (r.error || "Check the file list before retrying.")
        })
        p = {}
    }
    onOpened: {
        clearSecrets(); rows = []; selected = []; names = ({}); page = 0; notice = ""; working = false
        step = mode === "import" || mode === "request" ? -1 : 0
        coin.currentIndex = presetFamily ? 1 : 0; scriptType.currentIndex = presetFamily === "bitcoin_taproot" ? 1 : 0; testnet.checked = presetChain === "test"
        evmAccount.text = "0"; groupName.text = ""; keep.checked = false; advanced.checked = false
        hasPassphrase.checked = needsPassphrase; showGenerated = true; revealed = false
        wordCountPicker.currentIndex = 0
        if (mode === "create") generatePhrase()
    }
    onClosed: { generation++; working = false; clearSecrets(); rows = []; selected = []; names = ({}); sourceGroup = ""; walletSeed = ""; keptId = ""; needsPassphrase = false; notice = ""; requestHandle = ""; presetFamily = ""; presetChain = "" }
    contentItem: ColumnLayout {
        spacing: Theme.spacing.small
        // Step header, as in the Keycard app: "Step N of 4", a title and one line, centred.
        ColumnLayout {
            visible: sheet.step >= 0
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.small
            spacing: Theme.spacing.tiny
            LogosText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: "Step " + (sheet.step + 1) + " of 4"; color: Theme.palette.textSecondary; font.pixelSize: Theme.typography.secondaryText }
            LogosText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: ["Recovery phrase", "Choose accounts", "Name them", "Set a password"][Math.max(0, sheet.step)]; font.weight: Theme.typography.weightBold; font.pixelSize: Theme.typography.subtitleText }
            LogosText {
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                color: Theme.palette.textSecondary; font.pixelSize: Theme.typography.secondaryText
                text: ["", "Pick the accounts to keep on this computer.", "Optional: names show in every app.",
                       sheet.joining ? "One password opens every account of a wallet, so the new ones take the one it already uses."
                                     : "It encrypts the new files. You type it to unlock the wallet."][Math.max(0, sheet.step)]
                visible: text.length > 0
            }
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
                        onClicked: { sheet.mode = "create"; sheet.step = 0; sheet.revealed = false; sheet.generatePhrase() }
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
                            onClicked: { sheet.mode = "extend"; sheet.keptId = sheet.phrases[keptSource.currentIndex].id; sheet.walletSeed = sheet.seedOfKept(sheet.keptId); sheet.step = 0 }
                        }
                    }
                    LogosButton { visible: !sheet.requested; text: "Private key"; Layout.fillWidth: true; onClicked: { sheet.close(); sheet.importKey() } }
                }
                ColumnLayout {
                    visible: sheet.step === 0; Layout.fillWidth: true
                    LogosText {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        visible: !(sheet.mode === "create" && (!sheet.revealed || !sheet.showGenerated))
                        text: sheet.mode === "create" ? "Write this down. It is the only way to recover the account, it is shown "
                                                        + "once, and anyone who reads it can spend from the account."
                            : sheet.keptId ? "Open the encrypted recovery source with its password to preview more accounts."
                            : "Enter your recovery phrase to preview Ethereum and Bitcoin accounts."
                    }
                    // Before the words: a centred warning and one compact button, as on Keycard.
                    ColumnLayout {
                        visible: sheet.mode === "create" && !sheet.revealed
                        // The sheet's full content width: the column around it sizes to its contents.
                        Layout.preferredWidth: flowScroll.availableWidth
                        // Centred vertically in the sheet's body as well.
                        Layout.topMargin: Math.max(Theme.spacing.xxlarge, (flowScroll.availableHeight - implicitHeight) / 2)
                        spacing: Theme.spacing.small
                        LogosText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Your recovery phrase"
                            font.weight: Theme.typography.weightBold
                            font.pixelSize: Theme.typography.subtitleText
                        }
                        LogosText {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: 420
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            color: Theme.palette.textSecondary
                            text: "Anyone who sees it can take everything in this wallet. Make sure no one is watching "
                                  + "and nothing is recording your screen, and have paper ready."
                        }
                        LogosButton {
                            objectName: "flowRevealPhrase"
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: Theme.spacing.small
                            variant: LogosButton.Variant.Primary
                            text: "Show recovery phrase"
                            enabled: sheet.generated.length > 0
                            onClicked: sheet.revealed = true
                        }
                        // A failed generation leaves nothing to reveal, and New phrase sits behind the
                        // reveal: offer the retry here, under the notice that says what went wrong.
                        LogosButton {
                            objectName: "flowRetryPhrase"
                            Layout.alignment: Qt.AlignHCenter
                            visible: !sheet.working && sheet.generated.length === 0 && sheet.notice.length > 0
                            text: "Try again"
                            onClicked: sheet.generatePhrase()
                        }
                    }
                    RowLayout {
                        visible: sheet.mode === "create" && sheet.showGenerated && sheet.revealed
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
                        visible: sheet.mode === "create" && sheet.showGenerated && sheet.revealed
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
                        visible: sheet.mode === "create" && sheet.generated.length > 0 && sheet.revealed
                        variant: sheet.showGenerated ? LogosButton.Variant.Primary : LogosButton.Variant.Secondary
                        text: sheet.showGenerated ? "I've written it down" : "Show phrase again"
                        onClicked: { if (sheet.showGenerated) sheet.pickConfirm(); sheet.showGenerated = !sheet.showGenerated }
                    }
                    // Confirm the backup: three random words, each checked as it is left.
                    ColumnLayout {
                        objectName: "flowConfirmWords"
                        visible: sheet.mode === "create" && !sheet.showGenerated
                        Layout.preferredWidth: flowScroll.availableWidth
                        spacing: Theme.spacing.small
                        LogosText { Layout.alignment: Qt.AlignHCenter; text: "Confirm your backup"; font.weight: Theme.typography.weightBold; font.pixelSize: Theme.typography.subtitleText }
                        LogosText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; color: Theme.palette.textSecondary; text: "Enter these words from your recovery phrase to confirm you wrote it down." }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Theme.spacing.small
                            LogosText { Layout.preferredWidth: 32; horizontalAlignment: Text.AlignRight; text: "#" + ((sheet.confirmPos[0] || 0) + 1); color: Theme.palette.textSecondary }
                            ColumnLayout {
                                spacing: 2
                                LogosTextField { id: cw0; objectName: "flowConfirmWord0"; Layout.preferredWidth: 220; placeholderText: "type word" }
                                LogosText { visible: cw0.text.trim().length > 0 && !cw0.textInput.activeFocus && !sheet.wordOk(cw0, 0); text: "That is not word #" + ((sheet.confirmPos[0] || 0) + 1); color: Theme.palette.error; font.pixelSize: Theme.typography.secondaryText }
                            }
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Theme.spacing.small
                            LogosText { Layout.preferredWidth: 32; horizontalAlignment: Text.AlignRight; text: "#" + ((sheet.confirmPos[1] || 0) + 1); color: Theme.palette.textSecondary }
                            ColumnLayout {
                                spacing: 2
                                LogosTextField { id: cw1; objectName: "flowConfirmWord1"; Layout.preferredWidth: 220; placeholderText: "type word" }
                                LogosText { visible: cw1.text.trim().length > 0 && !cw1.textInput.activeFocus && !sheet.wordOk(cw1, 1); text: "That is not word #" + ((sheet.confirmPos[1] || 0) + 1); color: Theme.palette.error; font.pixelSize: Theme.typography.secondaryText }
                            }
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Theme.spacing.small
                            LogosText { Layout.preferredWidth: 32; horizontalAlignment: Text.AlignRight; text: "#" + ((sheet.confirmPos[2] || 0) + 1); color: Theme.palette.textSecondary }
                            ColumnLayout {
                                spacing: 2
                                LogosTextField { id: cw2; objectName: "flowConfirmWord2"; Layout.preferredWidth: 220; placeholderText: "type word" }
                                LogosText { visible: cw2.text.trim().length > 0 && !cw2.textInput.activeFocus && !sheet.wordOk(cw2, 2); text: "That is not word #" + ((sheet.confirmPos[2] || 0) + 1); color: Theme.palette.error; font.pixelSize: Theme.typography.secondaryText }
                            }
                        }
                    }
                    Accounts.PhraseGrid {
                        id: words; objectName: "flowWords"; Layout.fillWidth: true
                        visible: sheet.mode !== "create" && !sheet.keptId
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
                    // Account type as radio buttons (design-system controls), as in the Keycard app.
                    // The choice itself, kept as a value with ComboBox's `currentIndex` / `activated` so callers and
                    // the doc-tests drive it the same way.
                    Item { id: coin; objectName: "flowCoin"; visible: false; enabled: !sheet.working && !sheet.requested; property int currentIndex: 0; signal activated(int index); onActivated: sheet.refreshPage() }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Theme.spacing.large
                        LogosRadioButton { objectName: "flowCoinEthereum"; text: "Ethereum"; checkable: false; checked: coin.currentIndex === 0; enabled: !sheet.working && !sheet.requested; onClicked: { coin.currentIndex = 0; coin.activated(0) } }
                        LogosRadioButton { objectName: "flowCoinBitcoin"; text: "Bitcoin"; checkable: false; checked: coin.currentIndex === 1; enabled: !sheet.working && !sheet.requested; onClicked: { coin.currentIndex = 1; coin.activated(1) } }
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
                        Item { id: scriptType; objectName: "flowScript"; visible: false; enabled: !sheet.working && !sheet.requested; property int currentIndex: 0; signal activated(int index); onActivated: sheet.refreshPage() }
                        LogosRadioButton { visible: coin.currentIndex === 1; text: "Native SegWit"; checkable: false; checked: scriptType.currentIndex === 0; enabled: !sheet.working && !sheet.requested; onClicked: { scriptType.currentIndex = 0; scriptType.activated(0) } }
                        LogosRadioButton { visible: coin.currentIndex === 1; text: "Taproot"; checkable: false; checked: scriptType.currentIndex === 1; enabled: !sheet.working && !sheet.requested; onClicked: { scriptType.currentIndex = 1; scriptType.activated(1) } }
                        LogosButton { text: "Preview"; enabled: !sheet.working; onClicked: sheet.refreshPage() }
                    }
                    LogosText {
                        visible: coin.currentIndex === 1
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.palette.textSecondary; font.pixelSize: Theme.typography.secondaryText
                        text: "Each Bitcoin account includes receive and change addresses. The first receiving address is shown."
                    }
                    // One tappable tile per account, as in the Keycard app's add flow.
                    Repeater {
                        model: sheet.rows
                        delegate: Rectangle {
                            id: tile
                            required property var modelData
                            required property int index
                            readonly property bool canToggle: !sheet.working && !modelData.present && (sheet.chosen(sheet.rowKey(modelData)) || sheet.selected.length < 20)
                            Layout.fillWidth: true
                            radius: 6
                            color: modelData.present ? Theme.palette.backgroundMuted
                                   : rowHover.hovered ? Theme.palette.backgroundTertiary : Theme.palette.background
                            border.width: 1
                            border.color: rowHover.hovered ? Theme.palette.border : Theme.palette.borderSubtle
                            opacity: modelData.present ? 0.6 : 1.0
                            implicitHeight: rowInner.implicitHeight + 2 * Theme.spacing.small
                            HoverHandler { id: rowHover; enabled: tile.canToggle }
                            TapHandler { enabled: tile.canToggle; onTapped: sheet.toggle(modelData, !sheet.chosen(sheet.rowKey(modelData))) }
                            RowLayout {
                                id: rowInner
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.spacing.medium; anchors.rightMargin: Theme.spacing.medium
                                spacing: Theme.spacing.small
                                LogosCheckbox {
                                    objectName: "flowSelect_" + index
                                    enabled: tile.canToggle
                                    checkable: false
                                    checked: sheet.chosen(sheet.rowKey(modelData)) || modelData.present
                                    onClicked: sheet.toggle(modelData, !sheet.chosen(sheet.rowKey(modelData)))
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    LogosText { text: "Index " + modelData.index + (modelData.present ? "  ·  Already saved" : ""); color: modelData.present ? Theme.palette.textSecondary : Theme.palette.text }
                                    LogosText { Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; textFormat: Text.PlainText; text: modelData.address; font.pixelSize: Theme.typography.secondaryText }
                                    LogosText { Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; color: Theme.palette.textTertiary; text: modelData.path; font.pixelSize: Theme.typography.secondaryText }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LogosButton { objectName: "flowPrevious"; text: "Previous"; enabled: !sheet.working && sheet.page > 0; onClicked: { sheet.page--; sheet.preview() } }
                        LogosText { text: (sheet.page * 5) + "–" + (sheet.page * 5 + 4); color: Theme.palette.textSecondary; font.pixelSize: Theme.typography.secondaryText }
                        Item { Layout.fillWidth: true }
                        LogosText { visible: sheet.selected.length > 0; text: sheet.selected.length + " selected (up to 20)"; color: Theme.palette.textSecondary; font.pixelSize: Theme.typography.secondaryText }
                        Item { Layout.fillWidth: true }
                        LogosButton { objectName: "flowNext"; text: "Next"; enabled: !sheet.working && sheet.page < 429496728; onClicked: { sheet.page++; sheet.preview() } }
                    }
                }
                // Step 3: the wallet's name and each account's, one block per account as in Keycard.
                ColumnLayout {
                    visible: sheet.step === 2; Layout.fillWidth: true
                    spacing: Theme.spacing.medium
                    LogosTextField {
                        id: groupName; objectName: "flowName"; Layout.fillWidth: true
                        visible: !sheet.sourceGroup
                        placeholderText: "Wallet name (optional)"; textInput.maximumLength: 40
                    }
                    Repeater {
                        model: sheet.selected
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            radius: 6
                            color: Theme.palette.background
                            border.width: 1
                            border.color: Theme.palette.borderSubtle
                            implicitHeight: nameInner.implicitHeight + 2 * Theme.spacing.medium
                            ColumnLayout {
                                id: nameInner
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.spacing.medium; anchors.rightMargin: Theme.spacing.medium
                                spacing: Theme.spacing.small
                                LogosText {
                                    Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; textFormat: Text.PlainText
                                    text: (modelData.family === "evm" ? "Ethereum" : "Bitcoin") + (modelData.chain === "test" ? " · Test" : "") + "  ·  " + modelData.path + "\n" + modelData.address
                                    color: Theme.palette.textSecondary; font.pixelSize: Theme.typography.secondaryText
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
                    }
                }
                // Step 4: the password, on its own, centred.
                ColumnLayout {
                    visible: sheet.step === 3
                    Layout.preferredWidth: flowScroll.availableWidth
                    Layout.topMargin: Theme.spacing.large
                    spacing: Theme.spacing.small
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Math.min(flowScroll.availableWidth, 340)
                        spacing: Theme.spacing.small
                        LogosTextField { id: password; objectName: "flowPassword"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: sheet.joining ? "The wallet's password" : "Password"
                                         Component.onCompleted: textInput.passwordMaskDelay = 0 }
                        LogosTextField { id: repeatPassword; objectName: "flowRepeatPassword"; Layout.fillWidth: true; visible: !sheet.joining; echoMode: TextInput.Password; placeholderText: "Password again"
                                         Component.onCompleted: textInput.passwordMaskDelay = 0 }
                        LogosText {
                            visible: !sheet.joining && repeatPassword.text.length > 0 && password.text !== repeatPassword.text
                            text: "The passwords don't match."; color: Theme.palette.error; font.pixelSize: Theme.typography.secondaryText
                        }
                        RowLayout {
                            visible: !sheet.keptId
                            Layout.topMargin: Theme.spacing.small
                            LogosCheckbox { id: keep; objectName: "flowKeepRecovery"; text: "Keep an encrypted recovery source" }
                            LogosInfoButton { objectName: "recoverySourceInfo"; title: "Keeping a recovery source"; Accessible.name: "Help: Keeping a recovery source"; text: "Account files hold only the keys needed for the selected accounts. The optional recovery source is a separate encrypted file, under this same password, that can derive more accounts from the phrase later. Without it, you type the recovery phrase again to add accounts. Keep your own written backup either way; a BIP39 passphrase is not saved here." }
                        }
                    }
                }
                LogosText {
                    objectName: "flowNotice"; visible: sheet.notice.length > 0
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; textFormat: Text.PlainText
                    color: Theme.palette.error; text: sheet.notice
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            // Left: Cancel on every step (the dialog has no close button on desktop), Back beside it after the first.
            LogosButton { objectName: "flowCancel"; text: "Cancel"; enabled: !sheet.working; onClicked: sheet.close() }
            LogosButton {
                objectName: "flowBack"; text: "Back"; visible: sheet.step > 0 || (sheet.requested && sheet.step === 0); enabled: !sheet.working
                onClicked: { if (sheet.step === 0) { sheet.clearSecrets(); sheet.keptId = ""; sheet.walletSeed = ""; hasPassphrase.checked = false; sheet.mode = "request" }; sheet.step--; sheet.notice = ""; if (sheet.step === 0) { sheet.rows = []; sheet.selected = [] } }
            }
            Item { Layout.fillWidth: true }
            LogosButton {
                objectName: "flowContinue"; visible: sheet.step === 0
                variant: LogosButton.Variant.Primary
                text: sheet.working ? "Loading…" : "Continue"
                enabled: !sheet.working && (sheet.keptId ? phrasePw.text.length > 0
                    : sheet.mode !== "create" ? words.text.trim().length > 0
                    : !sheet.showGenerated && sheet.confirmValid)
                onClicked: sheet.preview()
            }
            LogosButton { objectName: "flowReview"; visible: sheet.step === 1; variant: LogosButton.Variant.Primary; text: "Continue"; enabled: !sheet.working && sheet.selected.length > 0; onClicked: sheet.step = 2 }
            LogosButton { objectName: "flowToPassword"; visible: sheet.step === 2; variant: LogosButton.Variant.Primary; text: "Continue"; enabled: !sheet.working; onClicked: sheet.step = 3 }
            LogosButton {
                objectName: "flowSave"; visible: sheet.step === 3; variant: LogosButton.Variant.Primary
                text: sheet.working ? "Saving…" : "Add " + sheet.selected.length + (sheet.selected.length === 1 ? " account" : " accounts")
                enabled: !sheet.working && sheet.selected.length > 0 && password.text.length > 0
                         && (sheet.joining || password.text === repeatPassword.text)
                onClicked: sheet.saveSelection()
            }
        }
    }
}
