.pragma library

// The accounts tree, as pure functions.
//
// Which node an account belongs to, what its badge claims, and what names a wallet are decided
// here rather than in a binding, because a binding can only be checked by running the app.
// doctests/tree_table.mjs runs this file against a case table and needs neither.
//
// Nothing here reaches Theme or Text: a node reports a semantic kind and QML picks the colour
// and the text format. So the table asserts the claim, not a palette token.

function norm(a) { return String(a || "").replace(/^0x/i, "").toLowerCase() }

function isGroupId(id) { return /^g_[0-9a-f]{32}$/.test(String(id || "")) }

// Parsed, never echoed: a hand-edited accounts.json must not be able to put a string on screen
// this view did not author.
function parsePath(path) {
    var m = /^m\/44'\/60'\/(\d+)'\/(\d+)\/(\d+)$/.exec(String(path || ""))
    return m ? [parseInt(m[1], 10), parseInt(m[2], 10), parseInt(m[3], 10)] : null
}
function parsePrefix(prefix) {
    var m = /^m\/44'\/60'\/(\d+)'$/.exec(String(prefix || ""))
    return m ? parseInt(m[1], 10) : -1
}

function provOf(provenance, address) {
    var k = norm(address)
    for (var key in (provenance || {})) if (norm(key) === k) return provenance[key]
    return null
}
// An account with no record is `unknown`, exactly as the keystore reports one: not guessed,
// because a guess about whether a phrase covers an account is the one lie this must not tell.
function originOf(provenance, address) {
    var p = provOf(provenance, address)
    return (p && p.origin) ? String(p.origin) : "unknown"
}
function groupIdOf(provenance, address) {
    var p = provOf(provenance, address)
    return (p && p.group) ? String(p.group) : ""
}
function indexAt(provenance, address) {
    var p = provOf(provenance, address)
    return (p && typeof p.index === "number") ? p.index : -1
}

// By derivation index, so the second account you made sits second. list_accounts is sorted by
// lowercase hex, which under a wallet is an order nobody can explain.
function sortAccounts(provenance, addresses) {
    return (addresses || []).slice().sort(function (x, y) {
        var ix = indexAt(provenance, x), iy = indexAt(provenance, y)
        if (ix !== iy) return ix - iy
        return norm(x) < norm(y) ? -1 : (norm(x) > norm(y) ? 1 : 0)
    })
}

function accountsOf(accounts, provenance, groupId) {
    if (!groupId) return []
    return sortAccounts(provenance, (accounts || []).filter(function (a) {
        return groupIdOf(provenance, a) === groupId
    }))
}

function shortId(id) { return isGroupId(id) ? String(id).substring(2, 10) : "" }

function groupById(groups, id) {
    for (var i = 0; i < (groups || []).length; ++i)
        if (String(groups[i].id) === String(id)) return groups[i]
    return null
}

// Every wallet frame, in the order they are drawn. An ordinal is a position in THIS list, so
// it moves when a wallet is added or removed and never when an account is.
function walletFrameIds(groups, keyIds, nameIds) {
    var out = []
    var recorded = (groups || []).filter(function (g) { return !g.stranded })
    for (var i = 0; i < recorded.length; ++i)
        if (String(recorded[i].id || "").length > 0) out.push(String(recorded[i].id))
    for (var s = 0; s < (keyIds || []).length; ++s)
        if (String(keyIds[s] || "").length > 0) out.push(String(keyIds[s]))
    for (var n = 0; n < (nameIds || []).length; ++n) out.push(String(nameIds[n]))
    return out
}

// Which keys on disk get a frame of their own: the ones no live wallet record accounts for.
// With the wallet list unread there are no records to check, so every key gets one — and
// `keyFrameKind` is what stops that frame claiming there is no record.
function keyFrameIdsOf(groups, derivationKeys, groupsKnown) {
    return (derivationKeys || []).filter(function (id) {
        if (String(id || "").length === 0) return false
        if (groupsKnown === false) return true
        for (var i = 0; i < (groups || []).length; ++i)
            if (groups[i].id === id && !groups[i].stranded) return false
        return true
    })
}
// Stranded is a CLAIM about the wallet list, so it may only be made when that list answered.
function keyFrameKind(groupsKnown) { return groupsKnown === false ? "unreadKey" : "stranded" }

// Names left standing over nothing: no record, no key, nothing derived from it. The keystore
// removes one, so it needs a frame — without one there is nowhere to ask. Like `stranded` this
// is a claim about the wallet list, so it may only be made when that list answered.
function nameFrameIdsOf(groups, names, keyIds, groupsKnown) {
    if (groupsKnown === false) return []
    var out = []
    for (var id in (names || {})) {
        if (!isGroupId(id)) continue
        if (String(names[id] || "").trim().length === 0) continue
        if (groupById(groups, id) || (keyIds || []).indexOf(id) !== -1) continue
        out.push(id)
    }
    return out.sort()
}

// The name a wallet was given: the keystore's names document first, then the copy an older
// build left on the record. A name of spaces is not one.
function nameOf(groups, names, id) {
    var n = (names && typeof names[id] === "string") ? names[id].trim() : ""
    if (n.length > 0) return n
    var g = groupById(groups, id)
    return (g && typeof g.label === "string") ? g.label.trim() : ""
}

// Every frame's title, decided together — a duplicate can only be seen from the siblings, and
// the keystore lets two wallets carry one name on purpose. Unnamed falls to an ordinal, NOT to
// the first account: deleting account #0 removes the provenance entry that named the wallet.
function walletTitles(groups, keyIds, names, nameIds) {
    var ids = walletFrameIds(groups, keyIds, nameIds)
    var out = []
    for (var i = 0; i < ids.length; ++i) {
        var named = nameOf(groups, names, ids[i])
        out.push({ id: ids[i], kind: named.length > 0 ? "label" : "ordinal",
                   text: named.length > 0 ? named : "Wallet " + (i + 1),
                   ordinal: i + 1, qualifier: "" })
    }
    // A list, not a map: a wallet may be named `__proto__`, and counting names in a bare
    // object would ask Object.prototype instead.
    for (var k = 0; k < out.length; ++k)
        for (var m = 0; m < out.length; ++m)
            if (m !== k && out[m].text === out[k].text)
                out[k].qualifier = shortId(out[k].id) || ("wallet " + out[k].ordinal)
    return out
}

// One frame's title. `unlisted` is a group id no frame carries — an account whose wallet is
// in neither list — and the caller says so in words rather than showing the id.
function walletTitle(groups, keyIds, names, id, nameIds) {
    var all = walletTitles(groups, keyIds, names, nameIds)
    for (var i = 0; i < all.length; ++i) if (all[i].id === String(id)) return all[i]
    return { id: String(id), kind: "unlisted", text: "", ordinal: 0, qualifier: "" }
}

// The keystore's own rule: a monotone high-water mark a hand-edited sidecar can only make skip
// an index, never hand out one already taken.
function nextIndexOf(group) {
    if (!group) return 0
    var n = group.nextIndex || 0
    var used = group.usedIndices || []
    for (var i = 0; i < used.length; ++i) if (used[i] + 1 > n) n = used[i] + 1
    return n
}

// The parent carries the shared prefix; the child carries only what varies. `prefix` is the
// parent's account level, -1 for none: a child recorded at another level shows its whole path,
// or `#3` under a header reading m/44'/60'/0' would name a path the account does not have.
function badgeOf(provenance, address, prefix) {
    var p = provOf(provenance, address)
    var origin = originOf(provenance, address)
    if (origin === "derived") {
        var m = parsePath(p ? p.path : "")
        if (!m) return { kind: "none", text: "" }
        if (m[0] !== prefix)
            return { kind: "path", text: "m/44'/60'/" + m[0] + "'/" + m[1] + "/" + m[2] }
        return m[1] === 1 ? { kind: "change", text: "CHANGE #" + m[2] }
                          : { kind: "index", text: "#" + m[2] }
    }
    if (origin === "imported-key") return { kind: "imported", text: "PRIVATE KEY" }
    if (origin === "imported-json") return { kind: "imported", text: "VAULT FILE" }
    // random and unknown carry no badge: their node header states the whole truth in a
    // sentence, and a one-word badge repeated down a column cannot.
    return { kind: "none", text: "" }
}

function nodeOf(kind, id, group, addresses, prefix) {
    return { kind: kind, id: id, group: group, addresses: addresses,
             prefix: prefix, countKnown: true }
}

// Every top-level node, in a fixed order: wallets, the keys no live record accounts for, then
// the accounts no wallet claims, split by how each arrived. `keyIds` comes from the key
// DIRECTORY, so such a key stays listed — and so deletable — when groups.json is unreadable.
// `notAdded` are keys an older build imported that the Signer app was never told of.
function buildNodes(accounts, provenance, groups, keyIds, keyKind, nameIds, notAdded) {
    var out = []
    var claimed = {}
    var recorded = (groups || []).filter(function (g) { return !g.stranded })
    for (var i = 0; i < recorded.length; ++i) {
        var mine = accountsOf(accounts, provenance, recorded[i].id)
        for (var k = 0; k < mine.length; ++k) claimed[norm(mine[k])] = true
        out.push(nodeOf("wallet", recorded[i].id, recorded[i], mine,
                        parsePrefix(recorded[i].pathPrefix)))
    }
    for (var s = 0; s < (keyIds || []).length; ++s) {
        var id = keyIds[s]
        var rec = (groups || []).filter(function (g) { return g.id === id })
        var theirs = accountsOf(accounts, provenance, id)
        for (var t = 0; t < theirs.length; ++t) claimed[norm(theirs[t])] = true
        out.push(nodeOf(keyKind || "stranded", id, rec.length ? rec[0] : { id: id }, theirs, -1))
    }
    for (var m = 0; m < (nameIds || []).length; ++m)
        out.push(nodeOf("nameOnly", nameIds[m], { id: nameIds[m] }, [], -1))
    return out.concat(sectionNodes(accounts, provenance, claimed, notAdded))
}

// The sections are separate because each is a different truth, and folding any of them into
// "Imported" would state a fact about recoverability that is not known. Keys the Signer app was
// never told of come first, whatever their origin: they can't sign until each is added.
function sectionNodes(accounts, provenance, claimed, notAdded) {
    var bucket = { notAdded: [], imported: [], random: [], orphan: [], unrecorded: [] }
    var waiting = {}
    for (var w = 0; w < (notAdded || []).length; ++w) waiting[norm(notAdded[w])] = true
    var rest = (accounts || []).filter(function (a) { return !claimed[norm(a)] })
    for (var j = 0; j < rest.length; ++j) {
        var o = originOf(provenance, rest[j])
        if (waiting[norm(rest[j])] === true) bucket.notAdded.push(rest[j])
        else if (o === "imported-key" || o === "imported-json") bucket.imported.push(rest[j])
        else if (o === "random") bucket.random.push(rest[j])
        else if (o === "derived") bucket.orphan.push(rest[j])
        else bucket.unrecorded.push(rest[j])
    }
    var out = []
    var order = ["notAdded", "imported", "random", "orphan", "unrecorded"]
    for (var n = 0; n < order.length; ++n)
        if (bucket[order[n]].length > 0)
            out.push(nodeOf(order[n], order[n], null,
                            sortAccounts(provenance, bucket[order[n]]), -1))
    return out
}

// Provenance was refused, so nothing here can group anything. The wallets still render from
// their own read, without a count — a count computed from a read that failed is a claim.
function unreadableNodes(accounts, groups, keyIds, keyKind, nameIds) {
    var out = []
    var recorded = (groups || []).filter(function (g) { return !g.stranded })
    for (var i = 0; i < recorded.length; ++i) {
        var n = nodeOf("wallet", recorded[i].id, recorded[i], [],
                       parsePrefix(recorded[i].pathPrefix))
        n.countKnown = false
        out.push(n)
    }
    for (var s = 0; s < (keyIds || []).length; ++s) {
        var rec = (groups || []).filter(function (g) { return g.id === keyIds[s] })
        var t = nodeOf(keyKind || "stranded", keyIds[s],
                       rec.length ? rec[0] : { id: keyIds[s] }, [], -1)
        t.countKnown = false
        out.push(t)
    }
    for (var m = 0; m < (nameIds || []).length; ++m) {
        var l = nodeOf("nameOnly", nameIds[m], { id: nameIds[m] }, [], -1)
        l.countKnown = false
        out.push(l)
    }
    if ((accounts || []).length > 0)
        out.push(nodeOf("flat", "flat", null, (accounts || []).slice(), -1))
    return out
}

// Which nodes to show, given which of the reads behind them answered. A refusal travels with
// the node instead of being inferred from an empty list, because an empty list is also what
// an empty keystore looks like — and "No accounts" is then a failed read stated as a fact
// about the wallet. `reads` is `{ accounts, groups, provenance }`; absent means it answered.
// `addAgain` is the keystore's list of older builds' wallets the Signer app can't open yet.
function treeOf(accounts, provenance, groups, derivationKeys, reads, names, addAgain) {
    var r = reads || {}
    var groupsKnown = r.groups !== false
    var keyIds = keyFrameIdsOf(groups, derivationKeys, groupsKnown)
    var keyKind = keyFrameKind(groupsKnown)
    var nameIds = nameFrameIdsOf(groups, names, keyIds, groupsKnown)
    var accountsKnown = r.accounts !== false
    var mine = accountsKnown ? (accounts || []) : []
    var out = (accountsKnown && r.provenance !== false)
        ? buildNodes(mine, provenance, groups, keyIds, keyKind, nameIds, keysToAdd(addAgain))
        : unreadableNodes(mine, groups, keyIds, keyKind, nameIds)
    for (var i = 0; i < out.length; ++i) {
        if (!accountsKnown) out[i].countKnown = false
        out[i].groupsKnown = groupsKnown
    }
    return out
}

// The accounts of older builds' keys the Signer app was never told of: added with a password.
function keysToAdd(addAgain) {
    var out = []
    ;(addAgain || []).forEach(function (a) {
        if (a && a.needs === "password") out = out.concat(a.accounts || [])
    })
    return out
}

// A seed is above its coin-specific wallets. Legacy wallets remain separate until a phrase
// proves their common origin; imported private keys and unreadable records retain their nodes.
function seedGroupsOf(nodes) {
    var result = [], byId = Object.create(null)
    nodes.forEach(function(n) {
        if (n.kind !== "wallet") {
            result.push({ id: n.id, seed: false, nodes: [n] })
            return
        }
        var key = n.group.seedId || ("unlinked:" + n.id)
        var group = byId[key]
        if (!group) {
            group = { id: key, seed: true, linked: !!n.group.seedId, needsPhrase: false, nodes: [] }
            byId[key] = group
            result.push(group)
        }
        // Added before wallets could be locked: it can't sign until its phrase comes again.
        if (n.group.needsPhrase === true) group.needsPhrase = true
        group.nodes.push(n)
    })
    return result
}
