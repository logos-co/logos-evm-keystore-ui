#!/usr/bin/env node
// The accounts tree, run as a table. No app, no inspector, no Qt.
//
// src/qml/tree.js is plain JavaScript behind a `.pragma library` line, so it is loaded here by
// stripping that line and evaluating the rest — the SAME text the view imports, not a copy of
// it. A copy is what drifts, and every defect this file is about is a claim the screen makes
// about where an account came from.
//
// Run: node doctests/tree_table.mjs

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, "..", "src", "qml", "tree.js"), "utf8")
    .replace(/^\s*\.pragma\s+library\s*$/m, "");
const names = [...src.matchAll(/^function\s+(\w+)\s*\(/gm)].map((m) => m[1]);
const T = new Function(`${src}\nreturn { ${names.join(", ")} };`)();

let failed = 0;
function check(label, got, want) {
    const g = JSON.stringify(got), w = JSON.stringify(want);
    const ok = g === w;
    if (!ok) failed++;
    console.log(`  ${ok ? "PASS" : "FAIL"}  ${label}${ok ? "" : `\n        got  ${g}\n        want ${w}`}`);
}

// Two wallets whose first account sits at the same path. This is the shape from the report:
// both once badged "HD 0'/0/0", which named the path WITHIN a wallet and so said nothing.
const G1 = "g_" + "0c3b03fe".padEnd(32, "0");
const G2 = "g_" + "c9b81031".padEnd(32, "1");
const A1 = "0x9992000000000000000000000000000000000001";
const A2 = "0xC80d000000000000000000000000000000000002";
const A3 = "0x41c7000000000000000000000000000000000003";
const IMP = "0x7bD9000000000000000000000000000000000004";
const OLD = "0xa1E2000000000000000000000000000000000005";

const wallet = (id, over) => Object.assign({
    id, storage: "extkey", pathPrefix: "m/44'/60'/0'", nextIndex: 1, usedIndices: [0],
    retiredIndices: [], usedPassphrase: false, label: "", accountCount: 1,
    derivable: true, stranded: false, staged: false,
}, over || {});
const derived = (group, path, index) => ({ origin: "derived", group, path, index, derivable: true });

const groups = [wallet(G1), wallet(G2, { usedPassphrase: true })];
// get_group_labels answers from its own document, which is what the view reads first; a row's
// own `label` is the same name mirrored, and the fallback when that document could not be read.
const NAMES = { [G2]: "Trezor backup" };
const accounts = [A1, A2, A3, IMP, OLD];
const prov = {
    [A1]: derived(G1, "m/44'/60'/0'/0/0", 0),
    [A2]: derived(G2, "m/44'/60'/0'/0/0", 0),
    [A3]: derived(G1, "m/44'/60'/0'/0/1", 1),
    [IMP]: { origin: "imported-key", group: "", path: "", index: null, derivable: false },
    [OLD]: { origin: "unknown", group: "", path: "", index: null, derivable: false },
};

console.log("1) every account hangs off exactly one node, and the nodes are ordered");
const nodes = T.buildNodes(accounts, prov, groups, []);
check("node kinds", nodes.map((n) => n.kind), ["wallet", "wallet", "imported", "unrecorded"]);
check("wallet 1 children", T.buildNodes(accounts, prov, groups, [])[0].addresses, [A1, A3]);
check("wallet 2 children", nodes[1].addresses, [A2]);
check("imported section", nodes[2].addresses, [IMP]);
check("unrecorded section", nodes[3].addresses, [OLD]);
check("no account is orphaned", nodes.reduce((n, x) => n + x.addresses.length, 0), accounts.length);

console.log("2) the badge names what VARIES — the defect was two wallets badged alike");
check("wallet 1 first account", T.badgeOf(prov, A1, 0), { kind: "index", text: "#0" });
check("wallet 2 first account", T.badgeOf(prov, A2, 0), { kind: "index", text: "#0" });
check("second account of wallet 1", T.badgeOf(prov, A3, 0), { kind: "index", text: "#1" });
// The two are told apart by their PARENT, which is the whole point of the tree.
check("parents differ", [nodes[0].id !== nodes[1].id,
      T.walletTitle(groups, [], NAMES, G1).text !== T.walletTitle(groups, [], NAMES, G2).text],
      [true, true]);

console.log("3) a change address keeps its 1, and no prefix means the whole path");
const chg = { [A1]: derived(G1, "m/44'/60'/0'/1/3", 3) };
check("change address", T.badgeOf(chg, A1, 0), { kind: "change", text: "CHANGE #3" });
check("no parent prefix", T.badgeOf(chg, A1, -1), { kind: "path", text: "m/44'/60'/0'/1/3" });

console.log("3a) a child only drops the account level its PARENT carries");
// Reachable only from a hand-edited accounts.json, which this file already treats as
// adversarial. The badge read `#3` under a header saying m/44'/60'/1' — the one surface that
// disagreed with the hover and the origin line, both of which print the true path.
const STRAY = { [A1]: derived(G1, "m/44'/60'/5'/0/3", 3) };
check("another account level is shown whole, not abbreviated under this one",
      T.badgeOf(STRAY, A1, 1), { kind: "path", text: "m/44'/60'/5'/0/3" });
check("under its own parent it abbreviates", T.badgeOf(STRAY, A1, 5),
      { kind: "index", text: "#3" });
check("a change address at another level too",
      T.badgeOf({ [A1]: derived(G1, "m/44'/60'/5'/1/2", 2) }, A1, 1),
      { kind: "path", text: "m/44'/60'/5'/1/2" });
check("a parentless node asks with -1, which is no level at all",
      T.badgeOf(prov, A1, -1), { kind: "path", text: "m/44'/60'/0'/0/0" });
check("and the wallet node carries the level it parsed",
      T.buildNodes(accounts, prov, groups, [])[0].prefix, 0);

console.log("4) imported says how it arrived; random and unrecorded claim nothing");
check("private key", T.badgeOf(prov, IMP, -1), { kind: "imported", text: "PRIVATE KEY" });
check("vault file", T.badgeOf({ x: { origin: "imported-json" } }, "x", -1),
      { kind: "imported", text: "VAULT FILE" });
check("random has no badge", T.badgeOf({ x: { origin: "random" } }, "x", -1),
      { kind: "none", text: "" });
// The bug this replaces: an account with no record was badged UNKNOWN, which reads as an error
// about the account rather than as the absence of a record.
check("unrecorded has no badge", T.badgeOf(prov, OLD, 0), { kind: "none", text: "" });
check("an unparseable path claims nothing",
      T.badgeOf({ x: { origin: "derived", path: "m/0/1", index: 1 } }, "x", 0),
      { kind: "none", text: "" });

console.log("5) a wallet is named, or it is the Nth wallet here — never its first account");
check("named from the names document", T.walletTitle(groups, [], NAMES, G2),
      { id: G2, kind: "label", text: "Trezor backup", ordinal: 2, qualifier: "" });
check("a name the record still carries is read too",
      T.walletTitle([wallet(G1, { label: "Old phone" })], [], {}, G1).text, "Old phone");
check("and the document wins, because a rename moves the name out of the record",
      T.walletTitle([wallet(G1, { label: "Old phone" })], [], { [G1]: "New phone" }, G1).text,
      "New phone");
check("unnamed is an ordinal, not an address", T.walletTitle(groups, [], NAMES, G1),
      { id: G1, kind: "ordinal", text: "Wallet 1", ordinal: 1, qualifier: "" });
check("a whitespace name is not a name",
      T.walletTitle([wallet(G1, { label: "   " })], [], { [G1]: "  " }, G1).text, "Wallet 1");

// The defect: the title was the surviving account with the smallest index. delete_account
// retires that account's provenance entry, so deleting account #0 renamed the wallet in the
// node header, both sheets and the origin line — everywhere it appeared.
const withoutFirst = Object.assign({}, prov);
delete withoutFirst[A1];
const titlesFor = (acc, pv) => T.treeOf(acc, pv, groups, [], {})
    .filter((n) => n.kind === "wallet")
    .map((n) => T.walletTitle(groups, [], {}, n.id).text);
check("deleting account #0 renames nothing",
      titlesFor(accounts.filter((a) => a !== A1), withoutFirst), titlesFor(accounts, prov));
check("no title is an account", titlesFor(accounts, prov).filter((t) => /0x|…/.test(t)), []);

check("a stranded key is a wallet frame and shares the numbering",
      T.walletTitles([wallet(G1)], [G2], {}).map((t) => t.text), ["Wallet 1", "Wallet 2"]);
check("and keeps the name its record no longer holds",
      T.walletTitle([], [G2], { [G2]: "Old phone" }, G2).text, "Old phone");
check("a group no frame carries is unlisted, and its id is never shown",
      T.walletTitle(groups, [], {}, "g_deadbeef"),
      { id: "g_deadbeef", kind: "unlisted", text: "", ordinal: 0, qualifier: "" });
check("a wallet id that is not one is still only a position",
      T.walletTitle([{ id: "../etc" }], [], {}, "../etc").text, "Wallet 1");

console.log("5a) two wallets may carry one name, so the screen qualifies both");
// set_group_label has no uniqueness rule, by design. A name that names two wallets is not a
// name on screen, so the one fact that tells them apart for good is put beside it.
const DUP = { [G1]: "Cold storage", [G2]: "Cold storage" };
check("both are qualified", T.walletTitles(groups, [], DUP).map((t) => [t.text, t.qualifier]),
      [["Cold storage", "0c3b03fe"], ["Cold storage", "c9b81031"]]);
check("a name only one wallet carries is not",
      T.walletTitles(groups, [], { [G1]: "Cold storage" }).map((t) => t.qualifier), ["", ""]);
check("a typed name that collides with an ordinal is caught as well",
      T.walletTitles(groups, [], { [G2]: "Wallet 1" }).map((t) => t.qualifier),
      ["0c3b03fe", "c9b81031"]);
check("a wallet named __proto__ is counted, not asked of Object.prototype",
      T.walletTitles(groups, [], { [G1]: "__proto__", [G2]: "__proto__" })
       .map((t) => t.qualifier.length > 0), [true, true]);
check("an unqualifiable id falls back to its position",
      T.walletTitles([{ id: "../a" }, { id: "../b" }], [], {})
       .map((t) => t.text), ["Wallet 1", "Wallet 2"]);

console.log("6) children sort by derivation index, not by address");
// list_accounts is sorted by lowercase hex, which under a wallet is an order nobody can
// explain: 0x41c7… is account #1 and would otherwise sit above account #0.
check("index order", T.accountsOf([A3, A1], prov, G1), [A1, A3]);
check("hex order is the tiebreak only", T.sortAccounts({}, [A2, A1]), [A1, A2]);

console.log("7) a wallet whose record is gone is a node, and it keeps its accounts");
const stranded = T.buildNodes([A1], { [A1]: derived(G2, "m/44'/60'/0'/0/0", 0) }, [], [G2]);
check("kinds", stranded.map((n) => n.kind), ["stranded"]);
check("its accounts nest under it", stranded[0].addresses, [A1]);
check("and it has no prefix to complete", stranded[0].prefix, -1);
// groups.json unreadable: list_groups answers [] while the key directory still names the key.
// Losing the node here is what would make a live whole-wallet key undeletable.
check("survives an empty group list", T.buildNodes([], {}, [], [G1]).map((n) => n.id), [G1]);

console.log("8) a derived account whose wallet is in neither list gets its own node");
const orphan = T.buildNodes([A1], { [A1]: derived("g_deadbeef", "m/44'/60'/0'/0/0", 0) }, [], []);
check("kind", orphan.map((n) => n.kind), ["orphan"]);
check("and shows the whole path, since no parent carries the prefix",
      T.badgeOf({ [A1]: derived("g_deadbeef", "m/44'/60'/0'/0/0", 0) }, A1, orphan[0].prefix),
      { kind: "path", text: "m/44'/60'/0'/0/0" });

console.log("9) a refused provenance read is a screen state, not a finding about the accounts");
const blind = T.unreadableNodes(accounts, groups, []);
check("wallets still render", blind.slice(0, 2).map((n) => n.kind), ["wallet", "wallet"]);
check("but claim no count", blind.slice(0, 2).map((n) => n.countKnown), [false, false]);
check("and the accounts are one flat node", blind[2], {
    kind: "flat", id: "flat", group: null, addresses: accounts, prefix: -1, countKnown: true });
check("no accounts, no flat node", T.unreadableNodes([], groups, []).length, 2);

console.log("9a) …and a REFUSED read is not an empty answer, whichever read it was");
// list_accounts can fail while list_groups succeeds — it goes through settle() and the vault
// scan, and list_groups reads only provenance. Every wallet frame then said "No accounts",
// which is the read failing, stated as a fact about the wallet.
check("everything answered: the tree is the tree",
      T.treeOf(accounts, prov, groups, [], {}).map((n) => n.kind),
      ["wallet", "wallet", "imported", "unrecorded"]);
const refusedAccounts = T.treeOf([], prov, groups, [], { accounts: false });
check("a refused account list still lists the wallets",
      refusedAccounts.map((n) => n.kind), ["wallet", "wallet"]);
check("but not one of them claims a count",
      refusedAccounts.map((n) => n.countKnown), [false, false]);
check("an empty keystore still reads as empty", T.treeOf([], {}, [], [], {}), []);
check("a refused provenance read is still the flat node",
      T.treeOf(accounts, {}, groups, [], { provenance: false }).map((n) => n.kind),
      ["wallet", "wallet", "flat"]);
check("both refused: the wallets, and no claim about any of them",
      T.treeOf([], {}, groups, [], { accounts: false, provenance: false })
       .map((n) => [n.kind, n.countKnown]), [["wallet", false], ["wallet", false]]);
// An unreadable groups.json empties list_groups, so every derived account falls into the
// orphan section — whose note says the wallet RECORD is gone. It is not; it was not read.
check("an unreadable wallet list travels to the nodes that would explain it",
      T.treeOf(accounts, prov, [], [], { groups: false }).map((n) => [n.kind, n.groupsKnown]),
      [["imported", false], ["orphan", false], ["unrecorded", false]]);
check("and an answered one says so too",
      T.treeOf(accounts, prov, groups, [], {}).map((n) => n.groupsKnown),
      [true, true, true, true]);

console.log("9b) a key on disk is STRANDED only where the wallet list said so");
// The defect: the frames were decided by absence from `groups`, which a refused list empties.
// Every healthy wallet then became a frame badged NO RECORD, offering to delete its key.
const KEYS = [G1, G2];
check("the list answered: only the key it does not account for is a frame",
      T.keyFrameIdsOf([wallet(G1)], KEYS, true), [G2]);
check("a record marked stranded is one as well",
      T.keyFrameIdsOf([wallet(G1, { stranded: true }), wallet(G2)], KEYS, true), [G1]);
check("the list refused: every key is a frame, so none becomes undeletable",
      T.keyFrameIdsOf([], KEYS, false), KEYS);
// A list that was not read accounts for nothing, even where one is still in hand: whatever
// `groups` holds then is what the view had BEFORE the refusal, not an answer to it.
check("and a list still in hand accounts for nothing once its read failed",
      T.keyFrameIdsOf([wallet(G1), wallet(G2)], KEYS, false), KEYS);
check("but 'stranded' is a claim about that list, so it is not made",
      [T.keyFrameKind(true), T.keyFrameKind(false)], ["stranded", "unreadKey"]);
const refusedGroups = T.treeOf(accounts, prov, [], KEYS, { groups: false });
check("and no frame in the tree claims it",
      refusedGroups.map((n) => n.kind), ["unreadKey", "unreadKey", "imported", "unrecorded"]);
check("the accounts still nest under the key they name", refusedGroups[0].addresses, [A1, A3]);
check("while an answered list still strands what it does not account for",
      T.treeOf(accounts, prov, [wallet(G1)], KEYS, {}).map((n) => n.kind),
      ["wallet", "stranded", "imported", "unrecorded"]);
check("both refused reads travel together",
      T.treeOf([], {}, [], KEYS, { groups: false, accounts: false })
       .map((n) => [n.kind, n.countKnown, n.groupsKnown]),
      [["unreadKey", false, false], ["unreadKey", false, false]]);

console.log("10) the next index is the keystore's own high-water mark");
check("from nextIndex", T.nextIndexOf(wallet(G1, { nextIndex: 4, usedIndices: [] })), 4);
check("a used index above it still wins",
      T.nextIndexOf(wallet(G1, { nextIndex: 1, usedIndices: [0, 7] })), 8);
check("no wallet", T.nextIndexOf(null), 0);

console.log("11) paths and ids are parsed, never taken on trust");
check("a good path", T.parsePath("m/44'/60'/2'/1/9"), [2, 1, 9]);
check("markup is not a path", T.parsePath("<b>m/44'/60'/0'/0/0</b>"), null);
check("a different coin is not this path", T.parsePath("m/44'/61'/0'/0/0"), null);
check("a good prefix", T.parsePrefix("m/44'/60'/3'"), 3);
check("a full path is not a prefix", T.parsePrefix("m/44'/60'/3'/0/0"), -1);
check("a good id", T.isGroupId(G1), true);
check("an id with markup", T.isGroupId("g_" + "0".repeat(31) + "<"), false);

console.log("12) an address is matched case- and 0x-insensitively");
check("mixed case", T.originOf({ "9992000000000000000000000000000000000001": { origin: "random" } },
                               A1), "random");
check("absent is unknown, never guessed", T.originOf({}, A1), "unknown");

console.log("13) a name with nothing left under it is a row of its own, so it can be removed");
// The keystore removes a name whose record and key have both gone; the tree built its nodes
// from records and key ids alone, so that row was never drawn and the call could not be aimed.
const LEFT = "g_" + "beef1234".padEnd(32, "2");
check("a name with no record and no key gets a frame",
      T.nameFrameIdsOf(groups, { [LEFT]: "Old phone" }, [], true), [LEFT]);
check("a name over a recorded wallet does not", T.nameFrameIdsOf(groups, NAMES, [], true), []);
check("nor one over a key on disk",
      T.nameFrameIdsOf([], { [LEFT]: "Old phone" }, [LEFT], true), []);
check("nor a name of spaces", T.nameFrameIdsOf([], { [LEFT]: "   " }, [], true), []);
check("nor anything that is not a group id",
      T.nameFrameIdsOf([], { __proto__: "x", "../etc": "x" }, [], true), []);
// Absence from a list that was not read is not an absence — the same rule `stranded` follows.
check("and never while the wallet list is unread",
      T.nameFrameIdsOf([], { [LEFT]: "Old phone" }, [], false), []);

const leftover = T.treeOf([], {}, [], [], {}, { [LEFT]: "Old phone" });
check("it reaches the tree", leftover.map((n) => [n.kind, n.id]), [["nameOnly", LEFT]]);
check("holding nothing", [leftover[0].addresses, leftover[0].countKnown], [[], true]);
check("and it is titled by its own name, not by an empty frame",
      T.walletTitle([], [], { [LEFT]: "Old phone" }, LEFT, [LEFT]).text, "Old phone");
check("without the frame it has no title at all",
      T.walletTitle([], [], { [LEFT]: "Old phone" }, LEFT, []).kind, "unlisted");
// An ordinal is a position among the frames, so a leftover takes the last one, never a
// wallet's: renaming what is on screen must not renumber the wallets above it.
check("it takes the last ordinal", T.walletFrameIds(groups, [G1], [LEFT]).slice(-1), [LEFT]);

console.log("14) wallets from the same seed share a parent across chains");
const seedNodes = [
  {kind: "wallet", id: "eth", group: {seedId: "seed1", family: null}},
  {kind: "wallet", id: "legacy", group: {}},
  {kind: "wallet", id: "btc", group: {seedId: "seed1", family: "bitcoin"}},
  {kind: "wallet", id: "other", group: {seedId: "seed2"}},
  {kind: "loose", id: "key"}
];
check("group across families without merging unknown or different seeds",
  T.seedGroupsOf(seedNodes).map(g => [g.seed, !!g.linked, g.nodes.map(n => n.id)]),
  [[true, true, ["eth", "btc"]], [true, false, ["legacy"]],
   [true, true, ["other"]], [false, false, ["key"]]]);
check("empty keystores have no seed groups", T.seedGroupsOf([]), []);

console.log("15) an older build's wallet the Signer app can't open says what it needs");
// A file that keeps no unlock root marks its seed; an older imported key, whatever its recorded
// origin, gets a section of its own ahead of the rest, so its button is where it is read.
check("a file that needs its phrase marks its seed",
  T.seedGroupsOf([{kind: "wallet", id: "asd", group: {needsPhrase: true}},
                  {kind: "wallet", id: "eth", group: {seedId: "seed1"}}]).map(g => [g.id, g.needsPhrase]),
  [["unlinked:asd", true], ["seed1", false]]);
const again = [{ seed: "k_1", needs: "password", groups: [], accounts: [OLD.toLowerCase()] },
               { seed: "g_2", needs: "phrase", groups: [G1], accounts: [A1] }];
const older = T.treeOf(accounts, prov, groups, [], {}, NAMES, again);
check("a key to add again leaves its old section for one of its own",
  older.filter(n => !n.group).map(n => [n.kind, n.addresses]),
  [["notAdded", [OLD]], ["imported", [IMP]]]);
check("a wallet's accounts stay with their wallet",
  older.filter(n => n.kind === "wallet").map(n => n.addresses.length), [2, 1]);
check("without the list nothing moves",
  T.treeOf(accounts, prov, groups, [], {}, NAMES).filter(n => !n.group).map(n => n.kind),
  ["imported", "unrecorded"]);

console.log(failed ? `\n${failed} FAILED` : "\nall passed");
process.exit(failed ? 1 : 0);
