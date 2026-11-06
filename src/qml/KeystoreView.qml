import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import Logos.Controls
import Logos.Theme
import "tree.js" as Tree
import "accountkit" as Accounts
import "accountkit/roster.js" as Roster

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
        function onIntentRequested(requestId, intent, params, requesterName) {
            root.serviceIntent(requestId, intent, params, requesterName)
        }
    }

    // Somebody wants accounts managed, and the shell has already brought us forward —
    // arriving IS the request, so answer now rather than waiting for the human to do
    // something. `handoff: true` is what leaves them here instead of bouncing them back.
    //
    // Answered `ok` even when this build is not the custodian. The request was to reach
    // the accounts surface and it did; whether accounts can be CHANGED from here is what
    // the READ ONLY badge and its banner are for, and `ready` may still be false at the
    // instant we are dispatched, so gating on it would refuse a request that succeeded.
    function serviceIntent(requestId, intent, params, requesterName) {
        if (intent === "keystore.accounts.open") {
            // An app's open request, by the manager's handle. Answered when the
            // person decides; a handle the manager does not hold is a bad request.
            root.intentByHandle[params.handle] = requestId
            logos.watch(root.backend.showAccess(params.handle), function (opened) {
                if (opened) accessSheet.open()
                else root.answerIntent(params.handle, false, "bad_request")
            })
            return
        }
        if (intent !== "evm.accounts.manage") return
        logos.respond(requestId, true, ({}), "")
    }

    // Intents being serviced, keyed by the manager's handle each one named.
    property var intentByHandle: ({})
    function answerIntent(handle, ok, error) {
        var id = root.intentByHandle[handle]
        if (id === undefined) return
        delete root.intentByHandle[handle]
        logos.respond(id, ok, ({}), error)
    }

    function j(t, fb) { try { return JSON.parse(t && t.length ? t : fb) } catch (e) { return JSON.parse(fb) } }
    readonly property var accounts: ready ? j(backend.accountsJson, "[]") : []
    readonly property var labels: ready ? j(backend.labelsJson, "{}") : ({})
    readonly property var groups: ready ? j(backend.groupsJson, "[]") : []
    readonly property int lockedWallets: ready ? backend.lockedWallets : 0
    // Older builds' wallets the Signer app can't open until they are added again.
    readonly property var addAgain: ready ? j(backend.addAgainJson, "[]") : []
    readonly property var emptyWallets: ready ? j(backend.emptyWalletsJson, "[]") : []
    // What an earlier version left in the keystore folder this one doesn't read until it moves in.
    readonly property var olderKeystore: ready ? j(backend.olderKeystoreJson, "{}") : ({})
    readonly property var olderLeft: olderKeystore.left || []
    property bool movingOlder: false
    readonly property var provenance: ready ? j(backend.provenanceJson, "{}") : ({})
    // What names each wallet, read from the keystore's own names document — so a wallet whose
    // record is gone keeps its name, and a torn file refuses rather than reading as "unnamed".
    readonly property var walletNames: ready ? j(backend.walletNamesJson, "{}") : ({})
    readonly property bool custodian: ready && backend.isCustodian
    readonly property var identity: ready ? j(backend.identityJson, "{}") : ({})

    // The signer manager, as its custodian: apps' open requests, and which wallets are open for
    // which apps.
    readonly property var phrases: ready ? j(backend.phrasesJson, "[]") : []
    readonly property bool managerCustodian: ready && backend.isManagerCustodian
    readonly property var access: ready ? j(backend.accessJson, "[]") : []
    readonly property var accessShown: ready ? j(backend.accessShownJson, "{}") : ({})
    readonly property var openWallets: ready ? j(backend.openJson, "[]") : []
    readonly property var deviceAccounts: ready ? j(backend.deviceAccountsJson, "[]") : []
    readonly property var deviceWallets: ready ? j(backend.deviceWalletsJson, "[]") : []
    function hasDeviceKey(signer, account) {
        return root.deviceWallets.some(function (w) { return w.signer === signer && w.account === account })
    }
    // Bitcoin accounts on devices, for an app's open: the first open sets their data password.
    readonly property var deviceBitcoinWallets: root.deviceAccounts.filter(function (a) {
            return a.family === "bitcoin" || a.family === "bitcoin_taproot"
        }).map(function (a) {
            return { id: a.id, name: (a.label || a.id) + " — on " + a.signer, family: a.family, chain: a.chain,
                     signer: a.signer, device: true, hasKey: root.hasDeviceKey(a.signer, a.id) }
        })
    // An app's open, from the manager's roster: one row per wallet, whichever signers hold it.
    // It opens under the keystore's id when the keystore holds it, else under a device whose data
    // key is already here, else the first device. From an older manager, a row per holder as before.
    readonly property var bitcoinRoster: ready ? j(backend.bitcoinRosterJson, "[]") : []
    readonly property var openChoices: {
        if (!root.bitcoinRoster.length) return root.bitcoinWallets.concat(root.deviceBitcoinWallets)
        var all = root.bitcoinRoster.map(function (e) { return root.openChoice(e) })
        // The keystore's wallets first, then devices', as before.
        return all.filter(function (w) { return !w.device }).concat(all.filter(function (w) { return w.device }))
    }
    function openChoice(e) {
        var hs = (e.holders || []).map(function (h) {
            return { id: h.accountId, signer: h.signer, device: h.transport !== "keystore", name: Roster.holderName(h) }
        })
        var keyed = hs.filter(function (h) { return h.device && root.hasDeviceKey(h.signer, h.id) })
        var home = hs.filter(function (h) { return !h.device })[0] || keyed[0] || hs[0] || { id: e.key, device: false }
        return { id: home.id, family: e.family, chain: e.chain, signer: home.signer, device: home.device,
                 hasKey: keyed.length > 0, holders: hs,
                 name: Roster.title(e) + " — " + hs.map(function (h) { return h.name }).join(", ") }
    }
    readonly property var bitcoinWallets: root.groups.filter(function (g) { return !!g.family })
        .map(function (g) {
            return { id: g.id, name: root.walletNameOf(g.id) || g.id, family: g.family, chain: g.chain }
        })

    // What the key directory holds. Read from that directory alone, so this stays populated
    // when groups.json is unreadable and no wallet is listed — otherwise the key would be
    // undeletable. `unexplained` is what the keystore can't tell from a key, shown so it can be checked.
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
                    derivationKeys: "the derivation keys on disk", walletNames: "wallet names",
                    phrases: "the kept recovery phrases" }
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
        : Tree.treeOf(accounts, provenance, groups, derivationKeys, reads, walletNames, addAgain)

    readonly property var seedNodes: Tree.seedGroupsOf(nodes).concat(Tree.emptyBundles(emptyWallets))

    function keptForSeed(bundle) {
        for (var i = 0; i < bundle.nodes.length; ++i) {
            var id = bundle.nodes[i].group.phrase
            if (id && root.phrases.some(function(p) { return p.id === id && !p.staged })) return id
        }
        return ""
    }

    function isKeyFrame(n) { return n.kind === "stranded" || n.kind === "unreadKey" }

    // Which nodes the user has folded away, by node id, so a refresh does not reopen them.
    property var collapsed: ({})
    function toggle(id) {
        var next = {}
        for (var k in root.collapsed) next[k] = root.collapsed[k]
        next[id] = !next[id]
        root.collapsed = next
    }
    function openAddAgain(bundle) {
        var g = bundle.nodes[0].group
        addAgainSheet.group = g.id
        addAgainSheet.walletName = root.seedNameFor(g.seedId) || root.walletNameOf(g.id)
        addAgainSheet.keptId = root.keptForSeed(bundle)
        addAgainSheet.needsPassphrase = bundle.nodes.some(function (n) { return n.group.usedPassphrase === true })
        addAgainSheet.open()
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
    // A phrase's wallet name, over all its account files. An older keys app wrote it onto each
    // file instead: then it is the one name they share.
    function seedNameFor(seedId) {
        if (!seedId) return ""
        var files = root.groups.filter(function (g) { return g.seedId === seedId })
        for (var i = 0; i < files.length; ++i)
            if (files[i].walletName) return files[i].walletName
        var names = []
        files.forEach(function (g) {
            var n = root.walletNameOf(g.id)
            if (n && names.indexOf(n) < 0) names.push(n)
        })
        return names.length === 1 ? names[0] : ""
    }
    // The name a wallet goes by until someone names it, as the Signer app shows it too.
    function seedDefaultNameFor(seedId) {
        if (!seedId) return ""
        var g = root.groups.find(function (g) { return g.seedId === seedId && g.walletDefaultName })
        return g ? g.walletDefaultName : ""
    }
    // The header over a recovery phrase's account files: its wallet name, else its default, else
    // its position (an older keystore module gives no default).
    function seedTitleOf(bundle, index) {
        if (bundle && bundle.empty) return bundle.empty.walletName || bundle.empty.walletDefaultName || ""
        if (!bundle || !bundle.nodes.length) return ""
        var seedId = (bundle.nodes[0].group || {}).seedId
        return root.seedNameFor(seedId) || root.seedDefaultNameFor(seedId)
               || root.walletNameOf(bundle.nodes[0].id)
               || (bundle.linked ? "Wallet " + (index + 1) : "Wallet — not yet linked")
    }
    function seedTitleForGroup(groupId) {
        for (var i = 0; i < root.seedNodes.length; ++i)
            if (root.seedNodes[i].nodes.some(function (n) { return n.group && n.group.id === groupId }))
                return root.seedTitleOf(root.seedNodes[i], i)
        return ""
    }
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
            var g = root.groups.find(function (x) { return x.id === p.group })
            var from = (g && g.seedId && root.seedTitleForGroup(p.group)) || walletTitleFor(p.group)
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
        if (n.kind === "wallet" && n.group.seedId) {
            // The account's own name only: the wallet's is over it.
            var own = root.walletNameOf(n.id)
            var label = own !== root.seedNameFor(n.group.seedId) ? own : ""
            var family = n.group.family ? "Bitcoin" : "Ethereum"
            var index = n.group.family ? parseInt(n.group.pathPrefix.split("/").pop())
                        : n.addresses.length === 1 ? (root.provFor(n.addresses[0]) || {}).index : undefined
            return family + (index !== undefined ? " " + (index + 1) : " accounts") + (label ? " · " + label : "")
        }
        if (n.kind === "wallet" || n.kind === "nameOnly" || root.isKeyFrame(n))
            return walletTitleOf(n.group)
        if (n.kind === "notAdded") return "Added before wallets could be locked"
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
        // A Bitcoin wallet has no EVM accounts to count: its addresses come from its descriptor.
        if (n.group && n.group.family)
            bits.push(n.group.family === "bitcoin_taproot" ? "Taproot" : "Native SegWit")
        else if (n.countKnown)
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
        if (n.kind === "notAdded")
            return "These keys can't sign until each is added to the Signer app, and until then "
                 + "they are stored unencrypted on this computer. Adding one asks for its password."
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
        return (root.isKeyFrame(n) || n.kind === "flat" || n.kind === "notAdded") ? Theme.palette.warning
                                                         : Theme.palette.textSecondary
    }
    // Only for a wallet that really has none. A node whose count could not be read must not
    // say "no accounts" — that is the read failing, stated as a fact about the wallet.
    function nodeEmptyLine(n) {
        if (n.kind !== "wallet" || !n.countKnown || n.addresses.length > 0) return ""
        if (n.group && n.group.family)
            return "Encrypted Bitcoin account with receive and change addresses."
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
        if (n.kind === "wallet" && n.group && n.group.family) {
            var btc = [{ name: "walletBitcoin_" + n.id, text: n.group.chain === "main" ? "BITCOIN" : "BITCOIN TEST",
                         color: Theme.palette.info }]
            if (n.group.usedPassphrase === true)
                btc.push({ name: "walletPassphrase_" + n.id, text: "PASSPHRASE", color: Theme.palette.textSecondary })
            return btc
        }
        if (n.kind === "wallet") {
            var out = [{ name: "walletBadge_" + n.id,
                         text: "JSON V3",
                         color: Theme.palette.info }]
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

    // ── Wallet cards ───────────────────────────────────────────────────────────────
    // A recovery phrase's account files are one wallet, drawn as every app draws one: its rows,
    // each account's own actions on it, and the wallet's at the top and bottom.
    function seedOf(bundle) {
        if (bundle && bundle.empty) return String(bundle.empty.seed)
        return bundle && bundle.nodes.length ? String((bundle.nodes[0].group || {}).seedId || "") : ""
    }
    function cardAccounts(bundle) {
        return Tree.cardEntries(bundle, root.provenance, root.labels, root.groups, root.walletNames,
                                root.seedNameFor(root.seedOf(bundle)))
    }
    // A build that isn't the custodian is offered nothing that changes the keystore.
    function gated(strips) {
        return strips.map(function (s) {
            var c = Object.assign({}, s)
            c.actions = (s.actions || []).map(function (a) {
                return Object.assign({}, a, { enabled: root.custodian && a.enabled !== false })
            })
            return c
        })
    }
    function rowActions(entry) {
        var on = root.custodian
        return [{ id: "rename", label: "Rename…", enabled: on }, { id: "remove", label: "Remove…", enabled: on },
                entry.family === "evm" ? { id: "export", label: "Export…", enabled: on }
                                       : { id: "descriptor", label: "Descriptor…" }]
    }
    // An account no wallet holds keeps a password of its own.
    readonly property var looseActions: [
        { id: "rename", label: "Rename…", enabled: root.custodian },
        { id: "remove", label: "Remove…", enabled: root.custodian },
        { id: "export", label: "Export…", enabled: root.custodian },
        { id: "password", label: "Password…", enabled: root.custodian }]
    // All three act on the whole wallet, so they sit together beside its name.
    function walletActions(bundle) {
        if (!bundle || !bundle.seed) return []
        var remove = { id: "removewallet", label: "Remove wallet…", enabled: root.custodian }
        // With no file left, its phrase adds to it again; there is nothing to rename or re-password.
        if (bundle.empty) return [{ id: "add", label: "Add accounts…", enabled: root.custodian }, remove]
        var out = bundle.needsPhrase ? [] : [{ id: "add", label: "Add accounts…", enabled: root.custodian }]
        out.push({ id: "rename", label: "Rename…", enabled: root.custodian })
        // One added before wallets could be locked has no wallet password until its phrase comes again.
        if (bundle.linked && !bundle.needsPhrase)
            out.push({ id: "password", label: "Change password…", enabled: root.custodian })
        out.push(remove)
        return out
    }
    function walletAction(bundle, index, id) {
        if (id === "add" && bundle.empty) {
            accountFlow.mode = "import"
            accountFlow.open()
        } else if (id === "removewallet") {
            removeSeedWalletDialog.seed = root.seedOf(bundle) || bundle.nodes[0].group.id
            removeSeedWalletDialog.shownTitle = root.seedTitleOf(bundle, index)
            removeSeedWalletDialog.count = bundle.empty ? 0 : root.cardAccounts(bundle).length
            removeSeedWalletDialog.withPassword = !bundle.empty
            removeSeedWalletDialog.open()
        } else if (id === "add") {
            accountFlow.mode = "extend"
            accountFlow.sourceGroup = bundle.nodes[0].group.id
            accountFlow.walletSeed = bundle.linked ? root.seedOf(bundle) : ""
            accountFlow.keptId = root.keptForSeed(bundle)
            accountFlow.needsPassphrase = bundle.nodes.some(function (n) { return n.group.usedPassphrase })
            accountFlow.open()
        } else if (id === "rename") {
            walletNameSheet.bundle = bundle
            walletNameSheet.fileOnly = !bundle.linked
            walletNameSheet.shownTitle = root.seedTitleOf(bundle, index)
            walletNameSheet.open()
        } else if (id === "password") {
            walletPasswordSheet.seed = root.seedOf(bundle)
            walletPasswordSheet.shownTitle = root.seedTitleOf(bundle, index)
            walletPasswordSheet.open()
        }
    }
    function stripAction(bundle, strip, id) {
        var g = strip && strip.group ? Tree.groupById(root.groups, strip.group) : null
        if (id === "addphrase") root.openAddAgain(bundle)
        else if (id === "phrase") {
            var kept = root.keptForSeed(bundle)
            keptPhraseSheet.kept = root.phrases.filter(function (p) { return p.id === kept })[0] || null
            if (keptPhraseSheet.kept) keptPhraseSheet.open()
        }
        else if (id === "addone" && g) { addSheet.group = g; addSheet.open() }
        else if (id === "forgetkey" && g) { forgetKeyDialog.group = g; forgetKeyDialog.open() }
        else if (id === "removefile" && g) { removeWalletDialog.group = g; removeWalletDialog.open() }
    }
    function accountAction(id, entry) {
        if (id === "rename") { renameAccountSheet.entry = entry; renameAccountSheet.open() }
        else if (id === "remove") { removeAccountSheet.entry = entry; removeAccountSheet.open() }
        else if (id === "export") { exportAccountSheet.address = entry.address; exportAccountSheet.open() }
        else if (id === "password") { accountPasswordSheet.address = entry.address; accountPasswordSheet.open() }
        else if (id === "descriptor") {
            bitcoinWalletSheet.group = Tree.groupById(root.groups, entry.group)
            bitcoinWalletSheet.rowTitle = Roster.rowTitle(entry) + (Roster.rowId(entry) ? " · " + Roster.rowId(entry) : "")
            bitcoinWalletSheet.open()
        }
    }
    // A phrase a card shows on its own strip; the others are listed above the wallets.
    readonly property var cardPhraseIds: root.seedNodes.filter(function (b) { return b.seed })
        .map(function (b) { return root.keptForSeed(b) }).filter(function (id) { return id !== "" })
    readonly property var loosePhrases: root.phrases.filter(function (p) { return root.cardPhraseIds.indexOf(p.id) < 0 })


    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.medium
        spacing: Theme.spacing.small

        RowLayout {
            Layout.fillWidth: true
            LogosText { text: "Keystore files"; font.pixelSize: 22 }
            LogosInfoButton { objectName: "keystoreFilesInfo"; title: "Account files and recovery groups"; Accessible.name: "Help: Account files and recovery groups"; text: "Each saved account has an encrypted file. Ethereum accounts use standard keystore JSON files; Bitcoin accounts use Bitcoin account files. Accounts derived from one recovery phrase are grouped together. An optional, separate encrypted recovery source lets you add more accounts later. Hardware accounts are managed in their device app." }
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

        // A locked wallet lists none of its files, so say it is here rather than look empty.
        LogosNotice {
            id: lockedNotice
            objectName: "lockedNotice"
            Layout.fillWidth: true
            shown: root.lockedWallets > 0
            visible: shown
            title: root.lockedWallets === 1 ? "1 wallet is locked" : root.lockedWallets + " wallets are locked"
            message: root.lockedWallets === 1 ? "Its accounts show here once you unlock it in the Signer app."
                                              : "Their accounts show here once you unlock them in the Signer app."
            actions: [
                LogosButton {
                    objectName: "lockedUnlockButton"
                    text: "Unlock"
                    // This keystore's wallets only: the Signer app takes them one after another.
                    onClicked: logos.request("wallets.unlock", ({ seeds: root.j(root.backend.lockedSeedsJson, "[]"), signer: "keystore_module" }), function (res) {
                        if (res.ok) root.backend.refresh()
                    })
                }
            ]
        }

        // Its wallets are missing from everything below until they move in. Offered only while a
        // move would bring something, so what stays there is never offered twice.
        LogosNotice {
            objectName: "olderKeystore"
            Layout.fillWidth: true
            shown: Tree.olderHolds(root.olderKeystore)
            visible: shown
            title: "Wallets from an earlier version"
            message: "An earlier version of this app kept them in a folder this one doesn't read: "
                     + Tree.olderSummary(root.olderKeystore) + ". They aren't shown and can't sign until "
                     + "they're moved here. Their files move as they are, under the same passwords."
            actions: [
                LogosButton {
                    objectName: "moveOlderKeystore"
                    text: "Move them here"
                    enabled: root.custodian && !root.movingOlder
                    onClicked: {
                        root.movingOlder = true
                        logos.watch(root.backend.moveOlderKeystore(), function () { root.movingOlder = false })
                    }
                }
            ]
        }
        LogosText {
            objectName: "olderKeystoreLeft"
            Layout.fillWidth: true
            visible: root.olderLeft.length > 0 || root.olderKeystore.ok === false
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            text: root.olderKeystore.ok === false
                  ? "The earlier version's keystore folder could not be read: " + (root.olderKeystore.error || "no reason given")
                  : "Staying in the earlier version's keystore folder, unused: " + root.olderLeft.join(", ")
        }

        // ── Kept recovery phrases: off unless the person chose to keep one ──────────────
        ColumnLayout {
            objectName: "keptPhrases"
            Layout.fillWidth: true
            visible: root.loosePhrases.length > 0
            // Every kept phrase, those the cards show included.
            readonly property int kept: root.phrases.length
            spacing: Theme.spacing.tiny
            LogosText { text: "Encrypted recovery sources"; font.bold: true }
            Repeater {
                model: root.loosePhrases
                delegate: RowLayout {
                    Layout.fillWidth: true
                    LogosText {
                        objectName: "keptPhraseLine_" + index
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        text: ((modelData.groups || []).length === 0
                               ? "A recovery phrase no account file uses any more"
                               : "Recovery phrase of " + (root.seedTitleForGroup(modelData.groups[0])
                                                          || "a wallet not listed here")
                                 + " — used by " + modelData.groups.length + " account file(s)")
                              + (modelData.staged ? ", left by an interrupted write" : "")
                    }
                    LogosButton {
                        objectName: "keptPhraseButton_" + index
                        text: "Show or forget…"
                        enabled: root.custodian
                        onClicked: { keptPhraseSheet.kept = modelData; keptPhraseSheet.open() }
                    }
                }
            }
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

        // Files in the key directory that the keystore did not write. Nothing is refused because
        // of them; they're named because one may be a live whole-wallet key, and only its
        // password could tell.
        ColumnLayout {
            objectName: "unexplainedKeyFiles"
            Layout.fillWidth: true
            visible: root.unexplainedPaths.length > 0
            spacing: Theme.spacing.tiny

            LogosText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.palette.warning
                text: "The key directory holds something this keystore did not write. It may "
                      + "be a live key for a whole wallet, and there is no way to tell without "
                      + "its password, so it is listed here and otherwise left alone."
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

        RowLayout {
            spacing: Theme.spacing.small
            LogosButton { objectName: "newAccountButton"; text: "Create"; enabled: root.custodian; onClicked: { accountFlow.mode = "create"; accountFlow.open() } }
            LogosButton { objectName: "importAccountsButton"; text: "Import"; enabled: root.custodian; onClicked: { accountFlow.mode = "import"; accountFlow.open() } }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            LogosText {
                objectName: "accountsEmpty"
                anchors.centerIn: parent
                visible: root.seedNodes.length === 0 && !root.treeReadRefused
                text: root.lockedWallets > 0 ? "No unlocked keystore files. Unlock a wallet, or create or import accounts."
                                             : "No keystore files yet. Create or import accounts to get started."
                color: Theme.palette.textSecondary
            }
            LogosText {
                objectName: "accountsUnreadable"
                anchors.centerIn: parent
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: root.seedNodes.length === 0 && root.treeReadRefused
                text: "Part of what this screen lists could not be read, so an empty screen "
                      + "here is not the same as an empty keystore. What failed is named above."
                color: Theme.palette.warning
            }

            LogosScrollView {
                id: treeScroll
                objectName: "accountTree"
                anchors.fill: parent
                visible: root.seedNodes.length > 0
                contentWidth: availableWidth

                ColumnLayout {
                    width: treeScroll.availableWidth
                    spacing: Theme.spacing.small

                    Repeater {
                        model: root.seedNodes
                        delegate: ColumnLayout {
                            id: seedBranch
                            required property var modelData
                            required property int index
                            readonly property var bundle: modelData
                            readonly property string keptId: bundle.seed ? root.keptForSeed(bundle) : ""
                            Layout.fillWidth: true
                            spacing: Theme.spacing.small

                            // A wallet: one recovery phrase over its account files, as every app shows one.
                            Accounts.WalletCard {
                                id: card
                                visible: seedBranch.bundle.seed
                                Layout.fillWidth: true
                                namePrefix: "wallet" + seedBranch.index + "_"
                                title: seedBranch.bundle.seed ? root.seedTitleOf(seedBranch.bundle, seedBranch.index) : ""
                                fingerprint: seedBranch.bundle.seed ? Tree.cardFingerprint(seedBranch.bundle) : ""
                                lines: seedBranch.bundle.seed ? Tree.cardLines(seedBranch.bundle) : []
                                strips: seedBranch.bundle.seed
                                        ? root.gated(Tree.cardStrips(seedBranch.bundle, seedBranch.keptId !== "", root.derivationKeys,
                                                                     root.stagedKeys, root.keyDirectoryKnown))
                                        : []
                                accounts: seedBranch.bundle.seed ? root.cardAccounts(seedBranch.bundle) : []
                                emptyText: "No accounts yet."
                                actions: root.walletActions(seedBranch.bundle)
                                accountActions: root.rowActions
                                onAction: function (id) { root.walletAction(seedBranch.bundle, seedBranch.index, id) }
                                onStripAction: function (i, id) { root.stripAction(seedBranch.bundle, card.strips[i], id) }
                                onAccountAction: function (id, entry) { root.accountAction(id, entry) }
                            }

                            // Accounts no wallet claims, and keys or names no record accounts for.
                            Repeater {
                                model: seedBranch.bundle.seed ? [] : seedBranch.bundle.nodes
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
                                    bitcoinGroup: null
                                    prefix: modelData.prefix
                                    emptyLine: root.nodeEmptyLine(modelData)
                                    unreadLine: root.nodeUnreadLine(modelData)
                                    expanded: root.collapsed[modelData.id] !== true

                                    addVisible: false
                                    addEnabled: root.custodian
                                    addBlockedLine: ""
                                    // A key frame is nameable too: its title is what the user has to
                                    // recognise before deciding whether to delete a live key.
                                    manageVisible: modelData.kind === "nameOnly" || root.isKeyFrame(modelData)
                                    manageEnabled: root.custodian
                                    deleteKeyVisible: root.isKeyFrame(modelData)
                                    deleteKeyEnabled: root.custodian
                                    rowActionText: modelData.kind === "notAdded" ? "Add to the Signer app…" : ""
                                    accountActions: root.looseActions

                                    onToggleRequested: root.toggle(modelData.id)
                                    onRowActionRequested: function (address) { addAgainSheet.account = address; addAgainSheet.open() }
                                    onManageWalletRequested: {
                                        walletSheet.group = modelData.group
                                        walletSheet.rowTitle = root.nodeTitle(modelData)
                                        walletSheet.seedLinked = false
                                        walletSheet.phraseKept = false
                                        walletSheet.stranded = root.isKeyFrame(modelData)
                                        walletSheet.recordKnown = modelData.kind !== "unreadKey"
                                        walletSheet.addresses = modelData.addresses
                                        walletSheet.countKnown = modelData.countKnown !== false
                                        walletSheet.keptKey = root.keptKeyOf(modelData)
                                        walletSheet.nameOnly = modelData.kind === "nameOnly"
                                        walletSheet.removable = root.walletRemovable(modelData)
                                        walletSheet.open()
                                    }
                                    onAccountActionRequested: function (id, address) {
                                        root.accountAction(id, { key: address, family: "evm", address: address,
                                                                 label: root.labelFor(address),
                                                                 path: root.hdPath((root.provFor(address) || {}).path) })
                                    }
                                    onForgetKeyRequested: logos.watch(root.backend.forgetDerivation(modelData.id),
                                                                      function () {})
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Add an account to one wallet, and manage that wallet ───────────────────────
    AddAccountSheet { id: addSheet; backend: root.backend; view: root }

    // ── An app's request ───────────────────────────────────────────────────────────
    AccessSheet {
        id: accessSheet
        backend: root.backend
        shown: root.accessShown
        wallets: root.openChoices
        onDecided: function (handle, approved) { root.answerIntent(handle, approved, approved ? "" : "rejected") }
        onDeferred: function (handle) { root.answerIntent(handle, false, "cancelled") }
        onAddWallet: function (family, chain) {
            accountFlow.mode = "request"
            accountFlow.requestHandle = accessSheet.shown.handle
            accountFlow.presetFamily = family
            accountFlow.presetChain = chain
            accountFlow.open()
        }
    }

    // ── Bitcoin wallets and kept phrases ───────────────────────────────────────────
    BitcoinWalletSheet { id: bitcoinWalletSheet; backend: root.backend; view: root }
    KeptPhraseSheet { id: keptPhraseSheet; backend: root.backend }
    WalletNameSheet { id: walletNameSheet; backend: root.backend; view: root }
    AddAgainSheet { id: addAgainSheet; backend: root.backend }
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

    // ── Remove a whole wallet ──────────────────────────────────────────────────────
    // Every account and file of it, its kept phrase and its name, then the Signer's record.
    LogosWarningDialog {
        id: removeSeedWalletDialog
        objectName: "removeSeedWalletDialog"
        title: "Remove this wallet?"
        accentColor: Theme.palette.error
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)

        property string seed: ""
        property string shownTitle: ""
        property int count: 0
        property bool withPassword: true
        onOpened: { removeSeedAck.checked = false; removeSeedPassword.text = "" }
        onClosed: { removeSeedAck.checked = false; removeSeedPassword.text = ""; seed = "" }

        contentItem: ColumnLayout {
            spacing: Theme.spacing.small

            LogosText {
                objectName: "removeSeedWalletName"
                Layout.fillWidth: true
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.typography.subtitleText
                text: removeSeedWalletDialog.shownTitle
            }
            LogosText {
                objectName: "removeSeedWalletLost"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: (removeSeedWalletDialog.count > 0
                       ? "Its " + removeSeedWalletDialog.count + (removeSeedWalletDialog.count === 1 ? " account" : " accounts")
                         + " go from this keystore, with every file of it, its saved recovery phrase and its name. "
                       : removeSeedWalletDialog.withPassword
                         ? "Every file of it goes from this keystore, with its saved recovery phrase and its name. "
                         : "It goes from this keystore, with its name. ")
                      + "The Signer app forgets it, and what other apps keep for it can't be opened again."
            }
            LogosText {
                objectName: "removeSeedWalletNotUndo"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.palette.warning
                text: "Only its recovery phrase brings these accounts back. Without it, they are gone for good."
            }
            LogosTextField {
                id: removeSeedPassword
                objectName: "removeSeedWalletPassword"
                Layout.fillWidth: true
                visible: removeSeedWalletDialog.withPassword
                echoMode: TextInput.Password
                placeholderText: "This wallet's password"
            }
            LogosText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.palette.error
                visible: text.length > 0
                text: root.backend ? root.backend.lastError : ""
            }
            LogosCheckbox {
                id: removeSeedAck
                objectName: "removeSeedWalletAck"
                text: "I want this wallet removed"
            }
            RowLayout {
                Layout.fillWidth: true
                LogosButton { objectName: "removeSeedWalletCancel"; text: "Cancel"; onClicked: removeSeedWalletDialog.close() }
                Item { Layout.fillWidth: true }
                LogosButton {
                    objectName: "removeSeedWalletConfirm"
                    text: "Remove wallet"
                    enabled: removeSeedAck.checked && removeSeedWalletDialog.seed !== ""
                             && (!removeSeedWalletDialog.withPassword || removeSeedPassword.text.length > 0)
                    onClicked: logos.watch(root.backend.removeSeedWallet(removeSeedWalletDialog.seed, removeSeedPassword.text),
                        function (good) { if (good) removeSeedWalletDialog.close() })
                }
            }
        }
    }

    // ── Remove a wallet that holds nothing ─────────────────────────────────────────
    // The whole confirmation is what is LOST, because the row being removed is empty and
    // "remove" reads like it is not. Asks for no password, and says why: the precondition is
    // that there is nothing here to sign with, so no secret exists to check against.
    LogosWarningDialog {
        id: removeWalletDialog
        objectName: "removeWalletDialog"
        title: "Remove this account file?"
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
                text: "What goes is this account file's name, and the record of where its accounts "
                      + "came from — the path it derives at, and how far along that path it "
                      + "had got."
            }
            LogosText {
                objectName: "removeWalletNothingSignable"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.palette.textSecondary
                text: "Nothing signable is affected, because there is nothing here to sign "
                      + "with: this account file keeps no derivation key and holds no accounts. That "
                      + "is also why no password is asked for — there is no secret to check "
                      + "one against."
            }
            LogosText {
                objectName: "removeWalletNotUndo"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.palette.warning
                text: "Importing the recovery phrase again does not bring this row back. It "
                      + "makes a new account file, in a new position and with no name."
            }
            LogosCheckbox {
                id: removeAck
                objectName: "removeWalletAck"
                text: "I want this account file removed"
            }
            RowLayout {
                Layout.fillWidth: true
                LogosButton { objectName: "removeWalletCancel"; text: "Cancel"; onClicked: removeWalletDialog.close() }
                Item { Layout.fillWidth: true }
                LogosButton {
                    objectName: "removeWalletConfirm"
                    text: "Remove this account file"
                    enabled: removeAck.checked && removeWalletDialog.group !== null
                    onClicked: logos.watch(root.backend.removeWallet(removeWalletDialog.group.id),
                        function (good) { if (good) removeWalletDialog.close() })
                }
            }
        }
    }

    AccountFlowSheet {
        id: accountFlow
        backend: root.backend
        phrases: root.phrases
        fileGroups: root.groups
        onSaved: function(groups) {
            if (accountFlow.requestHandle && accessSheet.opened && accessSheet.shown.handle === accountFlow.requestHandle && groups.length)
                accessSheet.pickWallet(groups[0])
        }
        onImportKey: keySheet.open()
        onImportFile: vaultSheet.open()
    }

    LogosDialog {
        id: keySheet
        objectName: "importKeySheet"
        title: "Import a private key"
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)
        onOpened: { keyField.text = ""; keyPw.text = "" }
        onClosed: { keyField.text = ""; keyPw.text = "" }
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
        title: "Import a keystore file"
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)
        property string fileUrl: ""
        onOpened: { fileUrl = ""; vaultField.text = ""; vaultOld.text = ""; vaultNew.text = ""; pasteJson.checked = false }
        onClosed: { fileUrl = ""; vaultField.text = ""; vaultOld.text = ""; vaultNew.text = "" }
        FileDialog {
            id: vaultPicker
            title: "Choose an Ethereum keystore file"
            nameFilters: ["Keystore files (*.json)", "All files (*)"]
            onAccepted: vaultSheet.fileUrl = selectedFile.toString()
        }
        contentItem: ColumnLayout {
            spacing: Theme.spacing.small
            LogosButton { visible: !pasteJson.checked; text: "Choose keystore file…"; onClicked: vaultPicker.open() }
            LogosText { visible: !pasteJson.checked; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; textFormat: Text.PlainText; text: vaultSheet.fileUrl }
            LogosCheckbox { id: pasteJson; text: "Paste JSON instead" }
            LogosTextArea {
                id: vaultField
                objectName: "vaultJsonField"
                Layout.fillWidth: true
                visible: pasteJson.checked
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
                    enabled: (pasteJson.checked ? vaultField.text.trim().length > 0 : vaultSheet.fileUrl.length > 0) && vaultNew.text.length > 0
                    onClicked: logos.watch(pasteJson.checked ? root.backend.importVaultJson(vaultField.text.trim(), vaultOld.text, vaultNew.text)
                                                            : root.backend.importVaultFile(vaultSheet.fileUrl, vaultOld.text, vaultNew.text),
                        function (good) { if (good) vaultSheet.close() })
                }
            }
        }
    }

    // ── One account: its name, removal and export, and its own password where no wallet holds it ──
    RenameAccountSheet { id: renameAccountSheet; backend: root.backend }
    RemoveAccountSheet { id: removeAccountSheet; backend: root.backend; view: root }
    ExportAccountSheet { id: exportAccountSheet; backend: root.backend }
    AccountPasswordSheet { id: accountPasswordSheet; backend: root.backend }
    WalletPasswordSheet { id: walletPasswordSheet; backend: root.backend; view: root }

    // ── Stop keeping an older file's derivation key ────────────────────────────────
    // A wallet action, offered once on the file's strip. No password: a key nobody can open
    // any more is exactly the one worth removing.
    LogosWarningDialog {
        id: forgetKeyDialog
        objectName: "forgetKeyDialog"
        title: "Stop keeping the derivation key?"
        accentColor: Theme.palette.error
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)

        property var group: null
        onOpened: forgetKeyAck.checked = false
        onClosed: { forgetKeyAck.checked = false; group = null }

        contentItem: ColumnLayout {
            spacing: Theme.spacing.small
            LogosText {
                objectName: "forgetKeyWarning"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "This file keeps a derivation key, so accounts can be added without its recovery "
                      + "phrase. Removing it cannot be undone, and it does not need the key's password — a "
                      + "key you can no longer open is exactly the one worth removing. The accounts you "
                      + "already have keep working exactly as they do now — they simply stop being "
                      + "extendable, so adding another means typing the phrase again."
            }
            LogosCheckbox { id: forgetKeyAck; objectName: "forgetKeyAck"; text: "I understand this cannot be undone" }
            RowLayout {
                Layout.fillWidth: true
                LogosButton { objectName: "forgetKeyCancel"; text: "Cancel"; onClicked: forgetKeyDialog.close() }
                Item { Layout.fillWidth: true }
                LogosButton {
                    objectName: "forgetKeyConfirm"
                    text: "Stop keeping the derivation key"
                    enabled: forgetKeyAck.checked && forgetKeyDialog.group !== null
                    onClicked: logos.watch(root.backend.forgetDerivation(forgetKeyDialog.group.id),
                        function (good) { if (good) forgetKeyDialog.close() })
                }
            }
        }
    }
}
