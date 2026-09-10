import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme
import "tree.js" as Tree

// The keystore: the only surface that creates, imports, exports or deletes an account. Which
// node an account belongs to is decided in tree.js, where a table can run it; why the screen
// is shaped this way is in README.md. Two hazards this file is written around:
//
// A .rep SLOT with a return type answers a QRemoteObjectPendingReply, NOT the value, so every
// such call goes through `logos.watch(...)`. Using the return directly is always truthy.
//
// LogosText is a bare Text, i.e. Qt AutoText. Every string this view did not author sets
// `textFormat: Text.PlainText`, and a wallet's NAME never reaches a badge, combo box or title.
Item {
    id: root
    objectName: "keystoreRoot"
    anchors.fill: parent

    Rectangle { anchors.fill: parent; color: Theme.palette.background }

    readonly property var backend: logos.module("evm_keystore_ui")

    // Writable, fed by the signal — a binding containing a function call evaluates once at
    // creation, before ui-host has handed over, and latches false forever.
    property bool ready: false
    Connections {
        target: logos
        function onViewModuleReadyChanged(moduleName, isReady) {
            if (moduleName === "evm_keystore_ui") root.ready = isReady && root.backend !== null
        }

        // Somebody wants accounts managed, and the shell has already brought us forward —
        // arriving IS the request, so answer now rather than waiting for the human to do
        // something. `handoff: true` is what leaves them here instead of bouncing them back.
        //
        // Answered `ok` even when this build is not the custodian. The request was to reach
        // the accounts surface and it did; whether accounts can be CHANGED from here is what
        // the READ ONLY badge and its banner are for, and `ready` may still be false at the
        // instant we are dispatched, so gating on it would refuse a request that succeeded.
        function onIntentRequested(requestId, intent, params, requesterName) {
            if (intent !== "evm.accounts.manage") return
            logos.respond(requestId, true, ({}), "")
        }
    }

    function j(t, fb) { try { return JSON.parse(t && t.length ? t : fb) } catch (e) { return JSON.parse(fb) } }
    readonly property var accounts: ready ? j(backend.accountsJson, "[]") : []
    readonly property var labels: ready ? j(backend.labelsJson, "{}") : ({})
    readonly property var groups: ready ? j(backend.groupsJson, "[]") : []
    readonly property var provenance: ready ? j(backend.provenanceJson, "{}") : ({})
    // What names each wallet, read from the keystore's own names document — so a wallet whose
    // record is gone keeps its name, and a torn file refuses rather than reading as "unnamed".
    readonly property var walletNames: ready ? j(backend.walletNamesJson, "{}") : ({})
    readonly property bool custodian: ready && backend.isCustodian
    readonly property var identity: ready ? j(backend.identityJson, "{}") : ({})

    // What the key directory holds. Read from that directory alone, so this stays populated
    // when groups.json is unreadable and no wallet is listed — otherwise the key would be
    // undeletable. `staged` and `unexplained` are the states that refuse a new account, and a
    // refusal whose cause is invisible is a wedge.
    readonly property var keyDirectory: ready ? j(backend.keyDirectoryJson, "{}") : ({})
    readonly property var derivationKeys: keyDirectory.groups || []
    readonly property var stagedKeys: keyDirectory.staged || []
    readonly property var unexplainedPaths: keyDirectory.unexplained || []

    // Which reads answered. A refused read empties what it feeds, and an empty list is also
    // what an empty keystore looks like — inferring the refusal from that emptiness could not
    // tell the two apart, so the backend reports it instead.
    readonly property var reads: ready ? j(backend.readsJson, "{}") : ({})
    readonly property var refusedReads: {
        var say = { accounts: "the account list", labels: "account names",
                    groups: "the wallet list", provenance: "where each account came from",
                    derivationKeys: "the derivation keys on disk", walletNames: "wallet names" }
        var out = []
        for (var k in say) if (root.reads[k] === false) out.push(say[k])
        return out
    }

    // Whether the wallet list answered decides whether a key on disk may be CALLED stranded:
    // absence from a list that was not read is not an absence. The frames stay either way, so
    // the key stays deletable.
    readonly property bool groupsKnown: reads.groups !== false
    readonly property bool keyDirectoryKnown: reads.derivationKeys !== false
    readonly property var keyFrames: Tree.keyFrameIdsOf(groups, derivationKeys, groupsKnown)
    // Names with no record and no key left under them. Their own frames, because the keystore
    // can remove one and a row that is not drawn cannot be pointed at.
    readonly property var nameFrames: Tree.nameFrameIdsOf(groups, walletNames, keyFrames, groupsKnown)

    // The three reads the tree is BUILT from. Names, provenance and wallet names decorate what
    // is there; only these decide whether there is anything at all.
    readonly property bool treeReadRefused: reads.accounts === false || reads.groups === false
                                            || reads.derivationKeys === false

    readonly property var nodes: !ready ? []
        : Tree.treeOf(accounts, provenance, groups, derivationKeys, reads, walletNames)

    function isKeyFrame(n) { return n.kind === "stranded" || n.kind === "unreadKey" }

    // Which nodes the user has folded away, by node id, so a refresh does not reopen them.
    property var collapsed: ({})
    function toggle(id) {
        var next = {}
        for (var k in root.collapsed) next[k] = root.collapsed[k]
        next[id] = !next[id]
        root.collapsed = next
    }

    // Asked of the key DIRECTORY, not of the wallet record: `derivable` is a promise about
    // adding accounts, and the question here is only whether there is something to delete.
    function hasKeyOnDisk(g) {
        return !!g && (root.derivationKeys || []).indexOf(g.id) !== -1
    }

    // A key on disk at EITHER path — live, or the copy an interrupted import left, which
    // opens the whole wallet just the same. One question, asked by both the rows below.
    function keptKeyOf(n) {
        return root.hasKeyOnDisk(n.group) || root.stagedKeys.indexOf(n.id) !== -1
               || (!!n.group && n.group.staged === true)
    }

    // A wallet may be removed only where this can SHOW it holds nothing — no key on disk, live
    // or staged, and no accounts. Each of those is a read that can fail, and an unread answer
    // is not a yes: the keystore refuses either way, but offering the button would be a claim.
    function walletRemovable(n) {
        return (n.kind === "wallet" || n.kind === "nameOnly") && n.countKnown === true
               && n.addresses.length === 0 && root.keyDirectoryKnown && !root.keptKeyOf(n)
    }

    function shortAddr(a) { return (!a || a.length < 12) ? (a || "") : a.substring(0,6) + "…" + a.substring(a.length-4) }
    function labelFor(a) {
        if (!a) return ""
        var k = a.replace(/^0x/, "").toLowerCase()
        for (var key in labels) if (key.toLowerCase() === k) return labels[key]
        return ""
    }
    function provFor(a) { return Tree.provOf(root.provenance, a) }

    // Paths are rebuilt from their parsed parts: a hand-edited accounts.json must not be able
    // to put anything on screen that this view did not author. "" means it did not parse, and
    // every caller says something else rather than calling the account's path unrecognised.
    function hdPath(path) {
        var m = Tree.parsePath(path)
        return m ? "m/44'/60'/" + m[0] + "'/" + m[1] + "/" + m[2] : ""
    }
    // Empty unless the badge beside it abbreviates a path. PRIVATE KEY names how a key
    // arrived; hovering it must not assert a path the account never had.
    function pathTipFor(a, prefix) { return Tree.pathTipOf(root.provenance, a, prefix) }
    // What the leftmost column says for one account. "" is a reserved slot, not a missing one.
    function ordinalFor(a, prefix) { return Tree.ordinalOf(root.provenance, a, prefix) }

    // What identifies a wallet: the name someone gave it, else its position here. Never its
    // first account — deleting account #0 retires the provenance entry that named the wallet,
    // and renamed it in the header, both sheets and the origin line at once.
    function walletTitleOf(g) { return walletTitleFor(g ? g.id : "") }
    function walletTitleFor(id) {
        var t = Tree.walletTitle(root.groups, root.keyFrames, root.walletNames, id, root.nameFrames)
        if (t.kind === "unlisted") return ""
        return t.qualifier.length > 0 ? t.text + "  ·  " + t.qualifier : t.text
    }
    // The stored name, for the field that edits it — never the ordinal standing in for one.
    function walletNameOf(id) { return Tree.nameOf(root.groups, root.walletNames, id) }
    function walletQualifierOf(id) {
        return Tree.walletTitle(root.groups, root.keyFrames, root.walletNames, id, root.nameFrames).qualifier
    }
    function walletSubtitleOf(g) {
        var p = Tree.parsePrefix(g ? g.pathPrefix : "")
        return p >= 0 ? "m/44'/60'/" + p + "'" : ""
    }

    function badgeFor(a, prefix) { return Tree.badgeOf(root.provenance, a, prefix) }
    function badgeColor(kind) {
        if (kind === "index" || kind === "change") return Theme.palette.info
        if (kind === "imported") return Theme.palette.textSecondary
        return Theme.palette.textTertiary
    }

    function originLine(a) {
        var p = provFor(a)
        if (!p) return "Where this account came from was not recorded, so nothing here can say whether a phrase covers it."
        if (p.origin === "derived") {
            var from = walletTitleFor(p.group)
            var who = from.length > 0 ? from
                    : (root.groupsKnown ? "a wallet not listed here"
                                        : "a wallet the list could not be read to name")
            var path = hdPath(p.path)
            return path.length > 0
                   ? "Derived at " + path + " from " + who + "."
                   : "Derived from " + who + ". The path recorded for it is not one this can read."
        }
        if (p.origin === "imported-key") return "Imported from a private key."
        if (p.origin === "imported-json") return "Imported from a vault file."
        if (p.origin === "random") return "A random key, covered by no recovery phrase."
        return "Where this account came from was not recorded."
    }

    // ── What each kind of node says about itself ───────────────────────────────────
    function nodeTitle(n) {
        if (n.kind === "wallet" || n.kind === "nameOnly" || root.isKeyFrame(n))
            return walletTitleOf(n.group)
        if (n.kind === "imported") return "Imported"
        if (n.kind === "random") return "Created here, not from a phrase"
        if (n.kind === "orphan")
            return n.groupsKnown === false ? "Derived from a wallet the list could not be read to name"
                                           : "Derived from a wallet not listed here"
        if (n.kind === "unrecorded") return "Origin not recorded"
        return "Accounts"
    }
    function nodeSubtitle(n) {
        var bits = []
        var pre = walletSubtitleOf(n.group)
        if (pre.length > 0) bits.push(pre)
        if (n.countKnown)
            bits.push(n.addresses.length === 1 ? "1 account" : n.addresses.length + " accounts")
        return bits.join("  ·  ")
    }
    function nodeNote(n) {
        if (n.kind === "stranded")
            return "A derivation key is stored here that no wallet record accounts for. It "
                 + "cannot add accounts, because the path it belongs to is not recorded — but "
                 + "it still opens a whole wallet. Deleting it leaves every account you "
                 + "already have untouched: they keep signing, they simply stop being "
                 + "extendable without the recovery phrase."
        if (n.kind === "imported")
            return "These arrived as a private key or a vault file, so no recovery phrase "
                 + "here covers them. Their only backup is a vault file you export and keep "
                 + "yourself."
        if (n.kind === "random")
            return "These were generated from randomness rather than derived from a phrase, "
                 + "so writing a recovery phrase down does not back them up. Their only "
                 + "backup is a vault file you export and keep yourself."
        if (n.kind === "orphan")
            return n.groupsKnown === false
                 ? "The wallet list could not be read, so which wallet these came from is "
                 + "unknown here. Nothing about the accounts themselves changed."
                 : "These still sign exactly as they did. What is gone is the record of the "
                 + "wallet they came from, so nothing here can add more alongside them."
        if (n.kind === "unrecorded")
            return "Nothing on record says where these came from. A vault copied into the "
                 + "keystore directory by hand looks exactly like this, and so does an account "
                 + "made before the keystore recorded any of it. It is not guessed here: "
                 + "whether a recovery phrase covers an account is the one thing this must not "
                 + "get wrong."
        if (n.kind === "nameOnly")
            return "Only a name is stored under this wallet — no record of where its accounts "
                 + "came from, and no derivation key. Whatever it named has already gone. "
                 + "Removing it takes the name, and nothing else is here to take."
        if (n.kind === "unreadKey")
            return "The wallet list could not be read, so whether a record accounts for this "
                 + "derivation key is not known here. It is listed because the key itself is on "
                 + "disk, and deleting it does not need that list."
        if (n.kind === "flat")
            return "Where these accounts came from could not be read, so nothing here can "
                 + "group them."
        return ""
    }
    function nodeNoteColor(n) {
        return (root.isKeyFrame(n) || n.kind === "flat") ? Theme.palette.warning
                                                         : Theme.palette.textSecondary
    }
    // Only for a wallet that really has none. A node whose count could not be read must not
    // say "no accounts" — that is the read failing, stated as a fact about the wallet.
    function nodeEmptyLine(n) {
        if (n.kind !== "wallet" || !n.countKnown || n.addresses.length > 0) return ""
        return n.group.derivable === true
               ? "No accounts. Adding one continues from #" + Tree.nextIndexOf(n.group) + "."
               : "No accounts. Adding one needs this wallet's recovery phrase."
    }
    // The other half of the rule above, said where the accounts would be. Without it a wallet
    // whose accounts could not be read is drawn exactly like one that has none.
    function nodeUnreadLine(n) {
        if (n.countKnown !== false) return ""
        return "Which accounts belong to this wallet could not be read. That is not the same "
             + "as it having none."
    }
    function nodeBadges(n) {
        if (n.kind === "wallet") {
            var out = [{ name: "walletBadge_" + n.id,
                         text: n.group.derivable ? "DERIVABLE" : "NOT DERIVABLE",
                         color: n.group.derivable ? Theme.palette.info : Theme.palette.textSecondary }]
            if (n.group.usedPassphrase === true)
                out.push({ name: "walletPassphrase_" + n.id, text: "PASSPHRASE",
                           color: Theme.palette.textSecondary })
            // NOT DERIVABLE plus a key still on disk: an interrupted import. The two together
            // are why "not derivable" must not read as "nothing to delete".
            if (n.group.staged === true)
                out.push({ name: "walletStaged_" + n.id, text: "INTERRUPTED IMPORT",
                           color: Theme.palette.warning })
            return out
        }
        if (root.isKeyFrame(n)) {
            // NO RECORD is a claim about the wallet list. Unread, it says so instead.
            var s = n.kind === "stranded"
                  ? [{ name: "strandedNoRecord_" + n.id, text: "NO RECORD",
                       color: Theme.palette.warning }]
                  : [{ name: "keyRecordUnread_" + n.id, text: "RECORD NOT READ",
                       color: Theme.palette.warning }]
            if (root.stagedKeys.indexOf(n.id) !== -1)
                s.push({ name: "strandedStaged_" + n.id, text: "INTERRUPTED IMPORT",
                         color: Theme.palette.warning })
            return s
        }
        if (n.kind === "nameOnly")
            return [{ name: "nameOnlyBadge_" + n.id, text: "NAME ONLY",
                      color: Theme.palette.textSecondary }]
        return []
    }

    property string selected: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.medium
        spacing: Theme.spacing.small

        RowLayout {
            Layout.fillWidth: true
            LogosText { text: "Accounts"; font.pixelSize: 22 }
            Item { Layout.fillWidth: true }
            LogosBadge {
                objectName: "custodianBadge"
                text: root.custodian ? "CUSTODIAN" : "READ ONLY"
                color: root.custodian ? Theme.palette.success : Theme.palette.warning
            }
        }

        // Said once, plainly, rather than letting every button fail one screen later.
        LogosText {
            objectName: "notCustodianNotice"
            Layout.fillWidth: true
            visible: root.ready && !root.custodian
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            // The keystore holds the names; `configure` is what changes them. Naming who does
            // hold the role separates "deployed the wrong way round" from "named nobody".
            text: "This build is not the keystore's configured custodian, so accounts cannot "
                  + "be changed here. The keystore names "
                  + ((root.identity.custodians || []).join(", ") || "no module")
                  + " as its custodian."
        }

        LogosText {
            objectName: "errorLabel"
            Layout.fillWidth: true
            visible: root.ready && root.backend.lastError.length > 0
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Theme.palette.error
            text: root.ready ? root.backend.lastError : ""
        }

        // A refusal names itself. Every one of these reads empties what it feeds, and each of
        // those empty answers is also a truthful screen for some keystore — so the difference
        // has to be said outright rather than left to be inferred from what is missing.
        LogosText {
            objectName: "refusedReadsNotice"
            Layout.fillWidth: true
            visible: root.refusedReads.length > 0
            wrapMode: Text.WordWrap
            color: Theme.palette.warning
            text: "Could not be read: " + root.refusedReads.join(", ") + ". What each would "
                  + "have said is unknown here — an unreadable answer is not an empty one."
        }

        // Files in the key directory that the keystore did not write. It refuses to create an
        // unrelated account while one is there, because it cannot tell one from a live
        // whole-wallet key without its password — so say which file, or the refusal is a wall.
        ColumnLayout {
            objectName: "unexplainedKeyFiles"
            Layout.fillWidth: true
            visible: root.unexplainedPaths.length > 0
            spacing: Theme.spacing.tiny

            LogosText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.palette.warning
                text: "The key directory holds something this keystore did not write. Until it is "
                      + "removed, creating an account is refused: an unidentified file there may "
                      + "be a live key for a whole wallet, and there is no way to tell without "
                      + "its password."
            }
            Repeater {
                model: root.unexplainedPaths
                delegate: LogosText {
                    objectName: "unexplainedPath_" + index
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    font.pixelSize: Theme.typography.secondaryText
                    text: modelData
                }
            }
        }

        // No global "Add account": it belongs to a wallet, and with two of them a global one
        // cannot say which. It sits on each wallet's own row instead.
        RowLayout {
            spacing: Theme.spacing.tiny
            LogosButton { objectName: "newAccountButton";   text: "Create";        enabled: root.custodian; onClicked: createSheet.open() }
            LogosButton { objectName: "importPhraseButton"; text: "Import phrase"; enabled: root.custodian; onClicked: phraseSheet.open() }
            LogosButton { objectName: "importKeyButton";    text: "Import key";    enabled: root.custodian; onClicked: keySheet.open() }
            LogosButton { objectName: "importVaultButton";  text: "Import vault";  enabled: root.custodian; onClicked: vaultSheet.open() }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            LogosText {
                objectName: "accountsEmpty"
                anchors.centerIn: parent
                visible: root.nodes.length === 0 && !root.treeReadRefused
                text: "No accounts yet"
                color: Theme.palette.textSecondary
            }
            LogosText {
                objectName: "accountsUnreadable"
                anchors.centerIn: parent
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: root.nodes.length === 0 && root.treeReadRefused
                text: "Part of what this screen lists could not be read, so an empty screen "
                      + "here is not the same as an empty keystore. What failed is named above."
                color: Theme.palette.warning
            }

            LogosScrollView {
                id: treeScroll
                objectName: "accountTree"
                anchors.fill: parent
                visible: root.nodes.length > 0
                contentWidth: availableWidth

                ColumnLayout {
                    width: treeScroll.availableWidth
                    spacing: Theme.spacing.small

                    Repeater {
                        model: root.nodes
                        delegate: AccountGroupNode {
                            Layout.fillWidth: true
                            view: root
                            nodeId: modelData.id
                            title: root.nodeTitle(modelData)
                            subtitle: root.nodeSubtitle(modelData)
                            note: root.nodeNote(modelData)
                            noteColor: root.nodeNoteColor(modelData)
                            badges: root.nodeBadges(modelData)
                            addresses: modelData.addresses
                            prefix: modelData.prefix
                            ordinals: Tree.showsOrdinals(modelData)
                            emptyLine: root.nodeEmptyLine(modelData)
                            unreadLine: root.nodeUnreadLine(modelData)
                            expanded: root.collapsed[modelData.id] !== true

                            addVisible: modelData.kind === "wallet" && modelData.group.derivable === true
                            addEnabled: root.custodian
                            addBlockedLine: (modelData.kind === "wallet" && modelData.group.derivable !== true)
                                            ? "Adding an account needs this wallet's recovery phrase." : ""
                            // A key frame is nameable too: its title is what the user has to
                            // recognise before deciding whether to delete a live key.
                            manageVisible: modelData.kind === "wallet" || modelData.kind === "nameOnly"
                                           || root.isKeyFrame(modelData)
                            manageEnabled: root.custodian
                            deleteKeyVisible: root.isKeyFrame(modelData)
                            deleteKeyEnabled: root.custodian

                            onToggleRequested: root.toggle(modelData.id)
                            onAddRequested: { addSheet.group = modelData.group; addSheet.open() }
                            onManageWalletRequested: {
                                walletSheet.group = modelData.group
                                walletSheet.stranded = root.isKeyFrame(modelData)
                                walletSheet.recordKnown = modelData.kind !== "unreadKey"
                                walletSheet.addresses = modelData.addresses
                                walletSheet.countKnown = modelData.countKnown !== false
                                walletSheet.keptKey = root.keptKeyOf(modelData)
                                walletSheet.nameOnly = modelData.kind === "nameOnly"
                                walletSheet.removable = root.walletRemovable(modelData)
                                walletSheet.open()
                            }
                            onManageAccountRequested: function (address) { root.selected = address; manageSheet.open() }
                            onForgetKeyRequested: logos.watch(root.backend.forgetDerivation(modelData.id),
                                                              function () {})
                        }
                    }
                }
            }
        }
    }

    // ── Add an account to one wallet, and manage that wallet ───────────────────────
    AddAccountSheet { id: addSheet; backend: root.backend; view: root }
    ManageWalletSheet {
        id: walletSheet
        backend: root.backend
        view: root
        // Closed first, then the confirmation: a dialog opened over a modal dialog is a
        // second scrim over a sheet the user can no longer reach.
        onRemoveRequested: {
            removeWalletDialog.group = walletSheet.group
            walletSheet.close()
            removeWalletDialog.open()
        }
    }

    // ── Remove a wallet that holds nothing ─────────────────────────────────────────
    // The whole confirmation is what is LOST, because the row being removed is empty and
    // "remove" reads like it is not. Asks for no password, and says why: the precondition is
    // that there is nothing here to sign with, so no secret exists to check against.
    LogosWarningDialog {
        id: removeWalletDialog
        objectName: "removeWalletDialog"
        title: "Remove this wallet?"
        accentColor: Theme.palette.error
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)

        property var group: null
        onOpened: removeAck.checked = false
        onClosed: { removeAck.checked = false; group = null }

        contentItem: ColumnLayout {
            spacing: Theme.spacing.small

            // In the body, not the title: LogosDialog renders `title` through a bare
            // LogosText, and a wallet's name is the one user-typed string on this screen.
            LogosText {
                objectName: "removeWalletName"
                Layout.fillWidth: true
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.typography.subtitleText
                text: root.walletTitleOf(removeWalletDialog.group)
            }
            LogosText {
                objectName: "removeWalletLost"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "What goes is this wallet's name, and the record of where its accounts "
                      + "came from — the path it derives at, and how far along that path it "
                      + "had got."
            }
            LogosText {
                objectName: "removeWalletNothingSignable"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.palette.textSecondary
                text: "Nothing signable is affected, because there is nothing here to sign "
                      + "with: this wallet keeps no derivation key and holds no accounts. That "
                      + "is also why no password is asked for — there is no secret to check "
                      + "one against."
            }
            LogosText {
                objectName: "removeWalletNotUndo"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.palette.warning
                text: "Importing the recovery phrase again does not bring this row back. It "
                      + "makes a new wallet, in a new position and with no name."
            }
            LogosCheckbox {
                id: removeAck
                objectName: "removeWalletAck"
                text: "I want this wallet removed"
            }
            RowLayout {
                Layout.fillWidth: true
                LogosButton { objectName: "removeWalletCancel"; text: "Cancel"; onClicked: removeWalletDialog.close() }
                Item { Layout.fillWidth: true }
                LogosButton {
                    objectName: "removeWalletConfirm"
                    text: "Remove this wallet"
                    enabled: removeAck.checked && removeWalletDialog.group !== null
                    onClicked: logos.watch(root.backend.removeWallet(removeWalletDialog.group.id),
                        function (good) { if (good) removeWalletDialog.close() })
                }
            }
        }
    }

    // ── Create: generate, SHOW, confirm, then commit ───────────────────────────────
    LogosDialog {
        id: createSheet
        objectName: "createSheet"
        title: "Create an account"
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)

        // Held here only, and cleared on close. Never a property.
        property string phrase: ""
        property var words: []
        onOpened: { phrase = ""; words = []; confirmField.text = ""; newPw.text = ""; createName.text = ""; createStorage.reset() }
        onClosed: { phrase = ""; words = []; confirmField.text = ""; newPw.text = ""; createName.text = ""; createStorage.reset() }

        contentItem: ColumnLayout {
            spacing: Theme.spacing.small

            LogosButton {
                objectName: "generateButton"
                text: "Generate a recovery phrase"
                visible: createSheet.phrase.length === 0
                onClicked: logos.watch(root.backend.generateMnemonic(12),
                    function (phrase) {
                        createSheet.phrase = phrase || ""
                        createSheet.words = createSheet.phrase.length ? createSheet.phrase.split(" ") : []
                    })
            }

            LogosText {
                objectName: "phraseWarning"
                visible: createSheet.phrase.length > 0
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.palette.warning
                text: "Write this down. It is the only way to recover the account, it is shown "
                      + "once, and anyone who reads it can spend from the account."
            }
            LogosText {
                objectName: "phraseText"
                visible: createSheet.phrase.length > 0
                Layout.fillWidth: true
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                text: createSheet.phrase
            }

            LogosText {
                visible: createSheet.phrase.length > 0
                color: Theme.palette.textSecondary
                text: createSheet.words.length > 0
                      ? "Confirm words 1, 5 and 12, separated by spaces"
                      : ""
            }
            LogosTextField {
                id: confirmField
                objectName: "confirmField"
                visible: createSheet.phrase.length > 0
                Layout.fillWidth: true
                placeholderText: "word1 word5 word12"
            }
            LogosTextField {
                id: newPw
                objectName: "createPasswordField"
                visible: createSheet.phrase.length > 0
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "Password for this account"
            }
            // Offered here because a wallet is easiest to recognise the moment it is made;
            // it can be changed later from that wallet's Manage sheet.
            LogosTextField {
                id: createName
                objectName: "createWalletNameField"
                visible: createSheet.phrase.length > 0
                Layout.fillWidth: true
                textInput.maximumLength: 40
                placeholderText: "Name this wallet (optional)"
            }

            // The choice is made here, before the account exists, because it governs every
            // account of this wallet and cannot be turned on afterwards.
            StorageChoice {
                id: createStorage
                objectName: "createStorageChoice"
                visible: createSheet.phrase.length > 0
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                LogosButton { objectName: "createCancel"; text: "Cancel"; onClicked: createSheet.close() }
                Item { Layout.fillWidth: true }
                LogosButton {
                    objectName: "createConfirm"
                    text: "Create account"
                    // The confirmation is the point: an unwritten phrase is an unrecoverable
                    // account, so it is checked here before anything is stored.
                    enabled: createSheet.words.length === 12 && newPw.text.length > 0
                             && createStorage.complete
                             && confirmField.text.trim().toLowerCase().split(/\s+/).join(" ")
                                === [createSheet.words[0], createSheet.words[4], createSheet.words[11]].join(" ")
                    // No BIP-39 passphrase on a phrase we just generated: it would be a second
                    // secret to write down at the moment the first one is still unwritten.
                    onClicked: logos.watch(root.backend.importMnemonic(createSheet.phrase, "", newPw.text,
                                                                       createStorage.groupPassword,
                                                                       createStorage.derivable,
                                                                       createName.text.trim()),
                        function (good) { if (good) createSheet.close() })
                }
            }
        }
    }

    // ── Import: phrase / private key / vault JSON ──────────────────────────────────
    LogosDialog {
        id: phraseSheet
        objectName: "importPhraseSheet"
        title: "Import a recovery phrase"
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)
        onOpened: { seedField.text = ""; seedPassphrase.text = ""; seedPw.text = ""; seedName.text = ""; phraseStorage.reset() }
        onClosed: { seedField.text = ""; seedPassphrase.text = ""; seedPw.text = ""; seedName.text = ""; phraseStorage.reset() }
        contentItem: ColumnLayout {
            spacing: Theme.spacing.small
            LogosTextArea {
                id: seedField
                objectName: "seedField"
                Layout.fillWidth: true
                placeholderText: "Recovery phrase (BIP-39 words)"
            }

            // Visible by default, never behind a disclosure: a passphrase that is silently
            // dropped produces a different, equally valid wallet, and nothing later says so.
            LogosTextField {
                id: seedPassphrase
                objectName: "bip39PassphraseField"
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "BIP-39 passphrase, if the wallet had one (ASCII, optional)"
            }
            LogosText {
                objectName: "passphraseHint"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.palette.textSecondary
                // Spaces are counted, never trimmed: a trailing space is a different
                // passphrase, and trimming it would derive accounts no other wallet agrees on.
                text: seedPassphrase.text.length === 0
                      ? "No passphrase. Leave this empty unless the wallet was set up with one."
                      : seedPassphrase.text.length + " characters"
                        + (seedPassphrase.text !== seedPassphrase.text.trim()
                           ? " — starts or ends with a space, which counts as part of it" : "")
            }
            LogosText {
                Layout.fillWidth: true
                visible: seedPassphrase.text.length > 0
                wrapMode: Text.WordWrap
                color: Theme.palette.warning
                text: "The passphrase is part of the secret and is not stored anywhere. Losing "
                      + "it loses these accounts as completely as losing the phrase."
            }

            LogosTextField {
                id: seedPw
                objectName: "seedPasswordField"
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "Password for this account"
            }
            // Two wallets are told apart by their names before anything else. Without one this
            // wallet is shown by its position here, which another import can move.
            LogosTextField {
                id: seedName
                objectName: "importWalletNameField"
                Layout.fillWidth: true
                textInput.maximumLength: 40
                placeholderText: "Name this wallet (optional)"
            }
            StorageChoice {
                id: phraseStorage
                objectName: "importStorageChoice"
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                LogosButton { text: "Cancel"; onClicked: phraseSheet.close() }
                Item { Layout.fillWidth: true }
                LogosButton {
                    objectName: "importPhraseConfirm"
                    text: "Import"
                    enabled: seedField.text.trim().length > 0 && seedPw.text.length > 0
                             && phraseStorage.complete
                    onClicked: logos.watch(root.backend.importMnemonic(seedField.text.trim(),
                                                                      seedPassphrase.text,
                                                                      seedPw.text,
                                                                      phraseStorage.groupPassword,
                                                                      phraseStorage.derivable,
                                                                      seedName.text.trim()),
                        function (good) { if (good) phraseSheet.close() })
                }
            }
        }
    }

    LogosDialog {
        id: keySheet
        objectName: "importKeySheet"
        title: "Import a private key"
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)
        onOpened: { keyField.text = ""; keyPw.text = "" }
        onClosed: keyField.text = ""
        contentItem: ColumnLayout {
            spacing: Theme.spacing.small
            LogosTextField {
                id: keyField
                objectName: "privKeyField"
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "Private key (hex)"
            }
            LogosTextField {
                id: keyPw
                objectName: "privKeyPasswordField"
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "Password for this account"
            }
            RowLayout {
                Layout.fillWidth: true
                LogosButton { text: "Cancel"; onClicked: keySheet.close() }
                Item { Layout.fillWidth: true }
                LogosButton {
                    objectName: "importKeyConfirm"
                    text: "Import"
                    enabled: keyField.text.trim().length > 0 && keyPw.text.length > 0
                    onClicked: logos.watch(root.backend.importPrivateKey(keyField.text.trim(), keyPw.text),
                        function (good) { if (good) keySheet.close() })
                }
            }
        }
    }

    LogosDialog {
        id: vaultSheet
        objectName: "importVaultSheet"
        title: "Import a keystore vault"
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)
        onOpened: { vaultField.text = ""; vaultOld.text = ""; vaultNew.text = "" }
        onClosed: vaultField.text = ""
        contentItem: ColumnLayout {
            spacing: Theme.spacing.small
            LogosTextArea {
                id: vaultField
                objectName: "vaultJsonField"
                Layout.fillWidth: true
                placeholderText: "Vault JSON"
            }
            LogosTextField {
                id: vaultOld
                objectName: "vaultOldPasswordField"
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "Its current password"
            }
            LogosTextField {
                id: vaultNew
                objectName: "vaultNewPasswordField"
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "Password to store it under here"
            }
            RowLayout {
                Layout.fillWidth: true
                LogosButton { text: "Cancel"; onClicked: vaultSheet.close() }
                Item { Layout.fillWidth: true }
                LogosButton {
                    objectName: "importVaultConfirm"
                    text: "Import"
                    enabled: vaultField.text.trim().length > 0 && vaultNew.text.length > 0
                    onClicked: logos.watch(root.backend.importVaultJson(vaultField.text.trim(), vaultOld.text, vaultNew.text),
                        function (good) { if (good) vaultSheet.close() })
                }
            }
        }
    }

    // ── Manage one account: provenance, rename, change password, export, delete ────
    LogosDialog {
        id: manageSheet
        objectName: "manageSheet"
        title: "Manage account"
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)

        property string exported: ""
        onOpened: {
            exported = ""
            renameField.text = root.labelFor(root.selected)
            renamePw.text = ""
            oldPw.text = ""; newPw2.text = ""; exportPw.text = ""; deletePw.text = ""
        }
        onClosed: exported = ""

        contentItem: ColumnLayout {
            spacing: Theme.spacing.small

            // The button, not LogosCopyableText: this is the one place the WHOLE address is
            // shown, and LogosSelectableText cannot wrap — it would clip it instead.
            RowLayout {
                Layout.fillWidth: true
                LogosText {
                    objectName: "manageAddress"
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    wrapMode: Text.WrapAnywhere
                    text: root.selected
                }
                LogosCopyButton { objectName: "manageAddressCopy"; value: root.selected }
            }
            LogosText {
                objectName: "manageProvenance"
                textFormat: Text.PlainText
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.palette.textSecondary
                text: root.originLine(root.selected)
            }

            LogosText { text: "Name"; color: Theme.palette.textSecondary }
            RowLayout {
                Layout.fillWidth: true
                LogosTextField { id: renameField; objectName: "renameField"; Layout.fillWidth: true; placeholderText: "Account name" }
                LogosButton {
                    objectName: "renameConfirm"
                    text: "Rename"
                    // Clearing needs nothing; setting needs the password. Both are enabled
                    // states, so the button never sits dead with no way to see why.
                    enabled: renameField.text.trim().length === 0 || renamePw.text.length > 0
                    onClicked: logos.watch(root.backend.setLabel(root.selected, renameField.text,
                                                                 renamePw.text),
                        function (good) { if (good) renamePw.text = "" })
                }
            }
            LogosTextField {
                id: renamePw
                objectName: "renamePasswordField"
                Layout.fillWidth: true
                visible: renameField.text.trim().length > 0
                echoMode: TextInput.Password
                placeholderText: "This account's password, to set a name"
            }
            LogosText {
                objectName: "renameNeedsPassword"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.palette.textSecondary
                text: renameField.text.trim().length > 0
                      ? "A name is what other screens show in place of this address, so setting "
                        + "one asks for this account's password."
                      : "Clearing a name asks for nothing: with none, screens show the address "
                        + "itself, which cannot stand in for another account."
            }

            LogosText { text: "Change password"; color: Theme.palette.textSecondary }
            LogosTextField { id: oldPw;  objectName: "oldPasswordField"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Current password" }
            LogosTextField { id: newPw2; objectName: "newPasswordField"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "New password" }
            LogosButton {
                objectName: "changePasswordConfirm"
                text: "Change password"
                enabled: oldPw.text.length > 0 && newPw2.text.length > 0
                onClicked: logos.watch(root.backend.changePassword(root.selected, oldPw.text, newPw2.text),
                    function (good) { if (good) { oldPw.text = ""; newPw2.text = "" } })
            }

            LogosText { text: "Export"; color: Theme.palette.textSecondary }
            LogosTextField { id: exportPw; objectName: "exportPasswordField"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Password" }
            LogosButton {
                objectName: "exportConfirm"
                text: "Export vault JSON"
                enabled: exportPw.text.length > 0
                onClicked: logos.watch(root.backend.exportVaultJson(root.selected, exportPw.text),
                    function (vault) { manageSheet.exported = vault || "" })
            }
            LogosText {
                objectName: "exportedVault"
                visible: manageSheet.exported.length > 0
                Layout.fillWidth: true
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                // Shown so it can be copied, and dropped when the sheet closes.
                text: manageSheet.exported
            }

            LogosText { text: "Delete"; color: Theme.palette.error }
            LogosTextField { id: deletePw; objectName: "deletePasswordField"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Password, to confirm" }
            LogosButton {
                objectName: "deleteConfirm"
                text: "Delete this account"
                enabled: deletePw.text.length > 0
                onClicked: logos.watch(root.backend.deleteAccount(root.selected, deletePw.text),
                    function (good) { if (good) manageSheet.close() })
            }

            LogosButton { objectName: "manageClose"; text: "Close"; onClicked: manageSheet.close() }
        }
    }
}
