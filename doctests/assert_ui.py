#!/usr/bin/env python3
"""Assertions for evm_keystore_ui's accounts tree.

Two halves, and the split is the point.

Section 0 opens no socket and needs no app: `--grep-only` runs it alone. It covers the claims
a source file can answer for — which Theme tokens exist, which strings reach an AutoText
control, which controls were removed — plus doctests/tree_table.mjs, which runs the view's own
src/qml/tree.js against a case table. Every rule that decides which node an account belongs to
and what its badge claims lives in that file precisely so a table can run it: a rule expressed
only as a QML binding can be checked by nothing but a running app, and this screen's defects
were all claims about where an account came from.

Sections 1 and up drive a live app over the QML inspector on port 3768 and are READ-ONLY —
they open sheets and toggle a disclosure, and press no confirm button. Port 3768 is also
Basecamp's inspector port. Only ever point this at a fixture app you started yourself.

Run against a `logos-standalone-app` started with QT_QPA_PLATFORM=offscreen and
QML_INSPECTOR_PORT=3768, with keystore_module and evm_keystore_ui staged as the -dev variant, and a
keystore holding at least two derivable wallets — the whole subject of this screen is two
wallets whose first accounts sit at the same path.

A source assertion here names the SITE it is about, never a region: asking whether
`Text.PlainText` appears anywhere in a 600-line file is answered by the first item that sets
it, and the item that does not is the one that matters.
"""

import json, re, subprocess, sys, time
from pathlib import Path

QML = Path(__file__).resolve().parent.parent / "src" / "qml"
SRC = QML.parent
FAIL = []

def check(label, got, want, mode="eq"):
    ok = (got == want) if mode == "eq" else (str(want) in str(got))
    print(("  PASS  " if ok else "  FAIL  ") + label + ("" if ok else f"   got={got!r}"))
    if not ok:
        FAIL.append(label)

def text(name):
    return (QML / name).read_text()

def srctext(name):
    """The C++/`.rep` half. Three of the four claims below are settled between the two: the
    view can only tell a refusal from an empty answer if the backend reports one."""
    return (SRC / name).read_text()

def block(src, anchor, lines=14):
    """The `lines` lines that follow `anchor`, so an assertion is about ONE item."""
    i = src.find(anchor)
    return "" if i < 0 else "\n".join(src[i:].splitlines()[:lines])

def code(src):
    """The file without its comments. Every check below is about what SHIPS, and a comment
    naming the control it forbids answered three of these checks before this existed."""
    return "\n".join(l for l in src.splitlines() if not l.strip().startswith("//"))

def speech(src):
    """The file with adjacent string literals joined, so a sentence broken across a `+` at
    the margin is still one string to search for. Nine safety paragraphs wrap that way."""
    return re.sub(r'"\s*\+\s*"', "", code(src))

def dialog_titles(src):
    """Every `title:` that belongs to a dialog — the one title Qt renders as AutoText.
    A node's `title` is a declared property of a Frame and is asserted PlainText below.

    Matched as a pattern, not as the literal "LogosDialog": LogosWarningDialog does not
    contain that substring, so its title would have been the one nothing here looked at."""
    out = []
    lines = code(src).splitlines()
    for i, line in enumerate(lines):
        if not re.search(r"\bLogos\w*Dialog\s*\{", line):
            continue
        for follow in lines[i:i + 10]:
            m = re.match(r"\s*title:\s*(.+)$", follow)
            if m:
                out.append(m.group(1).strip())
                break
    return out


# ── 0) no app, no socket ───────────────────────────────────────────────────────────
print("0) Theme tokens — Theme.palette is a var, so a wrong name is invisible until load")
# Read from the design system when the workspace has it beside us; otherwise the pinned set
# below, taken from logos-design-system/src/qml/Logos/Theme on 2026-08-31. A token dropped
# upstream would break at load either way; this catches the typo, which nothing else does.
DS = QML.parent.parent.parent / "logos-design-system" / "src" / "qml" / "Logos" / "Theme"
PINNED = {
    "palette": {"background", "backgroundSecondary", "backgroundTertiary", "backgroundElevated",
                "backgroundMuted", "backgroundBlack", "backgroundInset", "backgroundButton",
                "surface", "surfaceRaised", "surfaceInteractiveHover", "surfaceRecessed",
                "surfaceContrast", "text", "textSecondary", "textSubtle", "textTertiary",
                "textPlaceholder", "textMuted", "border", "borderSecondary", "borderTertiary",
                "borderTertiaryMuted", "borderSubtle", "borderHairline", "borderInteractive",
                "borderDark", "borderStrong", "primary", "primaryHover", "primaryPressed",
                "primarySoft", "success", "successHover", "successPressed", "error", "errorHover",
                "errorPressed", "warning", "warningHover", "info", "notification", "accentOrange",
                "accentOrangeMid", "accentOrangeDeep", "accentBurntOrange", "accentYellowSoft",
                "hover", "pressed", "disabled", "focus", "glassOverlay", "glassStrong",
                "overlayDark", "overlayLight", "overlayOrange", "scrim"},
    "typography": {"publicSansRegular", "publicSansMedium", "publicSansBold", "publicSans", "mono",
                   "weightRegular", "weightMedium", "weightBold", "mainTitleText", "pageTitleText",
                   "titleText", "panelTitleText", "subtitleText", "primaryText", "secondaryText",
                   "badgeText"},
    "spacing": {"tiny", "small", "medium", "large", "xlarge", "xxlarge", "radiusSmall",
                "radiusMedium", "radiusLarge", "radiusXlarge", "radiusPill"},
}
KNOWN, source = dict(PINNED), "pinned"
if DS.is_dir():
    files = {"palette": "DarkTheme.qml", "typography": "Typography.qml", "spacing": "Spacing.qml"}
    read = {}
    for group, fname in files.items():
        f = DS / fname
        if not f.is_file():
            read = {}
            break
        read[group] = set(re.findall(r"property\s+\S+\s+(\w+)\s*:", f.read_text()))
    if all(read.get(g) for g in files):
        KNOWN, source = read, "logos-design-system"
print(f"  (token names read from: {source})")
unknown = []
for f in sorted(QML.glob("*.qml")):
    for n, line in enumerate(f.read_text().splitlines(), 1):
        if line.strip().startswith("//"):
            continue
        for group, token in re.findall(r"Theme\.(palette|typography|spacing)\.(\w+)", line):
            if token not in KNOWN[group]:
                unknown.append(f"{f.name}:{n}: Theme.{group}.{token}")
check("every Theme token resolves", unknown, [])

print("0a) a wallet's NAME is the first user-typed string this view shows")
# LogosBadge, LogosComboBox, LogosItemDelegate, LogosGroupBox and LogosDialog's title all
# render through a bare LogosText, i.e. Qt AutoText. A name must reach none of them.
titles = [t for f in QML.glob("*.qml") for t in dialog_titles(f.read_text())]
check("every dialog title is a literal", [t for t in titles if not t.startswith('"')], [])
check("no LogosComboBox anywhere",
      [f.name for f in QML.glob("*.qml") if "LogosComboBox" in code(f.read_text())], [])
check("no LogosItemDelegate or LogosGroupBox",
      [f.name for f in QML.glob("*.qml")
       if re.search(r"LogosItemDelegate|LogosGroupBox", code(f.read_text()))], [])
node = text("AccountGroupNode.qml")
check("the node's title is PlainText",
      "textFormat: Text.PlainText" in block(node, 'objectName: "nodeTitle_"'), True)
check("the node's subtitle is PlainText",
      "textFormat: Text.PlainText" in block(node, 'objectName: "nodeSubtitle_"'), True)
# The address moved into LogosCopyableText, which hardcodes PlainText via
# LogosSelectableText. What still needs saying so is the NAME — the user-typed half.
check("an account's name is PlainText",
      "textFormat: Text.PlainText" in block(node, 'objectName: "accountName_" + modelData'), True)
check("and the wallet named in the removal confirmation is too",
      "textFormat: Text.PlainText" in block(text("KeystoreView.qml"),
                                            'objectName: "removeWalletName"'), True)
check("the wallet named in the add sheet is PlainText",
      "textFormat: Text.PlainText" in block(text("AddAccountSheet.qml"),
                                            'objectName: "addAccountWallet"'), True)
check("the wallet named in the manage sheet is PlainText",
      "textFormat: Text.PlainText" in block(text("ManageWalletSheet.qml"),
                                            'objectName: "manageWalletName"'), True)

print("0b) the badge that named the path within a wallet is gone")
view = text("KeystoreView.qml")
# Two wallets both badged `HD 0'/0/0`: the one piece of provenance on screen said the same
# thing about both, because the path WITHIN a wallet is the same for every wallet's first.
check("no chipText", "chipText" in view, False)
check("no HD badge", '"HD ' in view, False)
# "UNKNOWN" fired both for an account with no record and for a REFUSED provenance read, so a
# failed read rendered as a claim about every account on screen.
check("no UNKNOWN badge", "UNKNOWN" in view, False)
check("a refused read is a screen state",
      "unreadableNodes" in (QML / "tree.js").read_text() and "refusedReads" in view, True)

print("0c) add account belongs to a wallet, and says which by where it is")
check("no global add button", "addAccountButton" in view, False)
check("the button is on the node", 'objectName: "nodeAdd_"' in node, True)
check("and the sheet no longer picks a wallet",
      "walletPicker" in text("AddAccountSheet.qml"), False)
check("creating a key from randomness is not offered on this screen",
      "unrelatedKeyButton" in view or "UnrelatedAccountSheet" in view, False)
check("and the sheet behind it is gone, not merely unreachable",
      (QML / "UnrelatedAccountSheet.qml").exists(), False)
# A QtRO slot with no caller is still an invocable surface on the replica in the shell
# process, so the way to remove the option is to remove the slot as well.
check("as is the slot that reached it",
      "createUnrelatedAccount" in srctext("evm_keystore_ui.rep")
      or "createUnrelatedAccount" in srctext("evm_keystore_ui_backend.cpp"), False)
check("and it never hid inside the add sheet either",
      "createUnrelatedConfirm" in text("AddAccountSheet.qml"), False)

print("0c1) a wallet operation is offered once per wallet, not once per account")
# It was in the per-account sheet, so a wallet with three accounts offered "stop keeping the
# derivation key" three times, each behind a different address and each doing the same thing.
check("forgetting a derivation key is a wallet action",
      "forgetDerivationConfirm" in code(text("ManageWalletSheet.qml")), True)
check("and not an account one", "forgetDerivationConfirm" in code(view), False)
# A stranded key had its own strip beside the list. It is a node now, and the one affordance
# that must survive is deleting it — without its password, which nobody has.
check("a stranded key is still deletable",
      all(k in code(node) for k in ("strandedConfirm_", "strandedForget_")), True)
check("and still asks for no password",
      "Password" in block(code(node), 'objectName: "strandedForget_"', 6), False)
# It said an interrupted import stops "any unrelated account" being created. No such guard is
# in the module — creation is gated on Tier D and the acknowledgement — and the option it
# spoke about is gone from this screen entirely.
staged = block(code(text("ManageWalletSheet.qml")), 'objectName: "forgetDerivationStaged"', 12)
check("a staged key claims no refusal about unrelated accounts",
      "unrelated" in staged, False)
check("and states the one the keystore does apply",
      "removing the wallet itself is refused" in staged, True)

print("0d) the flat list is gone and the tree replaced it")
check("no flat account list", "accountList" in view, False)
check("a tree", 'objectName: "accountTree"' in view, True)
check("nodes carry their accounts", "AccountGroupNode" in view, True)

print("0e) every password field still hides what is typed")
# Anchored at the FIELD, not at any item whose name mentions a password: "Change password"
# is a button, and letting it answer this check is how the field beside it goes unread.
leaks = []
for f in sorted(QML.glob("*.qml")):
    src = code(f.read_text())
    # From the match, not from find(): block() searches from the start of the file, so every
    # iteration re-read the FIRST field and no other password field on the screen was checked.
    for m in re.finditer(r"LogosTextField\s*\{", src):
        item = "\n".join(src[m.start():].splitlines()[:9])
        name = re.search(r'objectName:\s*"(\w*[Pp]assword\w*)"', item)
        # One regex for both: the reporting one carried a literal backslash-w and matched
        # nothing, so the first leak this ever found crashed instead of naming the field.
        if name and "echoMode: TextInput.Password" not in item:
            leaks.append(f"{f.name}: {name.group(1)}")
check("no password field renders in the clear", leaks, [])

print("0f) every safety string that moved is still said, verbatim")
ALL = "\n".join(speech(f.read_text()) for f in QML.glob("*.qml"))
for fragment in [
    "It is the only way to recover the account, it is shown",
    "they keep signing, they simply stop being",
    "be a live key for a whole wallet, and there is no way to tell without",
    # Both of these were the unrelated-key sheet's. The first has no screen left to be said
    # on; the second survives under two node headers, whose subject is "Their", not "its".
    "writing a recovery phrase down does not back them up",
    "only backup is a vault file you export and keep yourself",
    "it does not need the",
    "cannot add accounts, but it opens the whole wallet",
    "not the keystore's configured custodian",
    "starts or ends with a space, which counts as part of it",
]:
    check(f"still said: {fragment[:44]}…", fragment in ALL, True)

print("0b1) a tooltip may only assert a path where there IS one")
# The badge showed for every kind but `none` and `path`, and its tooltip called fullPathOf →
# hdPath("") → "an unrecognised path". Hovering PRIVATE KEY therefore asserted that the
# account has a path AND that it is broken; an imported key has path "" by construction.
check("the sentence that invented a path is gone", "an unrecognised path" in ALL, False)
check("and so is the function that produced it", "fullPathOf" in ALL, False)
check("the tip is decided in tree.js, where a table runs it",
      "function pathTipOf" in (QML / "tree.js").read_text(), True)
# Anchored on the ORDINAL now: the badges that abbreviate a path are the only ones that
# moved into the leftmost column, and it is the only item left with a tip to show.
tip = block(code(node), 'objectName: "index_" + modelData', 12)
check("the hover is gated on there being a path", "enabled: pathTip.length > 0" in tip, True)
check("and so is the tooltip", "visible: pathHover.hovered && pathTip.length > 0" in tip, True)
check("and the badge it left behind offers none at all",
      "pathHover" in block(code(node), 'objectName: "provenance_" + modelData', 8), False)
# Every other sentence on this screen that names a path: each must test the parse first.
check("the origin line does not call an unparsed path unrecognised",
      "The path recorded for it is not one this can read" in speech(view), True)
check("hdPath answers nothing rather than a failure word",
      'return m ? "m/44\'/60\'/" + m[0] + "\'/" + m[1] + "/" + m[2] : ""' in view, True)
# The wallet name now reaches the origin line, which is the one sentence that renders a name
# outside a title. LogosText is a bare Text, i.e. AutoText.
check("the origin line is PlainText",
      "textFormat: Text.PlainText" in block(view, 'objectName: "manageProvenance"'), True)

print("0b2) a refused read is not an empty answer")
rep, backend = srctext("evm_keystore_ui.rep"), srctext("evm_keystore_ui_backend.cpp")
# list_accounts can fail while list_groups succeeds — it goes through settle() and the vault
# scan. Every wallet frame then said "No accounts", which is the read failing, stated as a
# fact about the wallet. The view cannot see the difference unless the backend reports it.
check("the backend reports which reads answered", "readsJson" in rep, True)
check("and every read is recorded, not just surfaced",
      backend.count("read(QStringLiteral("), 6)
check("the view no longer infers a refusal from an empty list",
      "accounts.length === 0" in view, False)
check("a refusal names itself", 'objectName: "refusedReadsNotice"' in view, True)
check("an empty screen says which of the two it is",
      'objectName: "accountsUnreadable"' in view, True)
# ONE refused read out of six satisfied "nothing here could be read": with only `labels`
# refused on a keystore that genuinely has no accounts, the list WAS read, and IS empty.
check("an empty screen doubts itself only for the reads the tree is BUILT from",
      "root.treeReadRefused" in block(view, 'objectName: "accountsUnreadable"'), True)
check("and 'No accounts yet' is held back by those same reads",
      "!root.treeReadRefused" in block(view, 'objectName: "accountsEmpty"'), True)
check("which are the three that decide whether there is anything at all",
      sorted(set(re.findall(r"reads\.(\w+) === false",
                            block(view, "property bool treeReadRefused", 3)))),
      ["accounts", "derivationKeys", "groups"])
check("and it no longer says nothing at all could be read",
      "Nothing here could be read" in ALL, False)
# Two sentences, two items: one reports the wallet, the other reports the read.
check("a node can say its count is unknown", 'objectName: "nodeUnread_"' in node, True)
check("and that is not the same item as its empty line",
      'objectName: "nodeEmpty_"' in node and "property string unreadLine" in node, True)
check("the tree is built from what was read", "Tree.treeOf" in view, True)
# The frames were decided by absence from `groups`, which a refused read empties — so every
# healthy wallet became a frame badged NO RECORD, offering to delete its live key.
check("a key frame is decided with the wallet read in hand",
      "Tree.keyFrameIdsOf(groups, derivationKeys, groupsKnown)" in view, True)
check("and 'stranded' is claimed only where that read answered",
      "reads.groups !== false" in view and 'n.kind === "unreadKey"' in code(view), True)
check("a frame whose record was not read badges that instead of NO RECORD",
      "keyRecordUnread_" in view, True)
check("and is still nameable and still deletable",
      "deleteKeyVisible: root.isKeyFrame(modelData)" in code(view)
      and "|| root.isKeyFrame(modelData)" in block(code(view), "manageVisible:", 2), True)
check("every failed read is left readable, not just the last one",
      "lastError().isEmpty()" in backend, True)

print("0b3) a wallet is named, or it is the Nth wallet here — never its first account")
manage = text("ManageWalletSheet.qml")
# The default name was the surviving account with the smallest index, and delete_account
# retires that account's provenance entry — so deleting account #0 renamed the wallet.
check("no title is built from an account", "firstAddressOf" in (QML / "tree.js").read_text(), False)
check("nor from a shortened address", '"Wallet " + shortAddr' in view, False)
check("the ordinal comes from the wallet frames", "function walletFrameIds" in
      (QML / "tree.js").read_text(), True)
check("renaming is offered", "setWalletName" in rep and "setWalletName" in backend, True)
check("where the wallet is managed", 'objectName: "walletNameConfirm"' in manage, True)
check("prefilled with the stored name, not the ordinal standing in for it",
      "nameField.text = sheet.storedName" in manage, True)
check("and the sentence saying it could not be renamed is gone",
      "walletRenameUnavailable" in ALL or "no way to change one" in ALL, False)
check("the default is explained where it can be changed",
      "shown by their position in this list" in speech(manage), True)

print("0b4) two wallets given one name are still told apart")
# set_group_label has no uniqueness rule, by design. A name that names two wallets is not a
# name on screen, so the one fact that separates them for good is put beside it.
check("the duplicate is detected against the siblings",
      "walletQualifierOf" in view and "qualifier" in (QML / "tree.js").read_text(), True)
check("and said out loud", 'objectName: "walletNameDuplicate"' in manage, True)

print("0b5) one refusal does not overwrite the rest")
# `forgetDerivation` called setLastError outright after refresh(), discarding the six reads
# that refresh() had just appended — the overwrite the appending rule exists to prevent.
saybody = block(backend, "void EvmKeystoreUiBackend::say(", 4)
check("the helper appends", "lastError().isEmpty()" in saybody, True)
check("and every message on this screen goes through it",
      [l.strip() for l in backend.replace(saybody, "").splitlines()
       if "setLastError(" in l and "setLastError(QString())" not in l], [])
check("including the one that follows a refresh",
      'say(QStringLiteral("the derivation key is deleted' in backend, True)

print("0i) a note may say what the data shows, not assert a cause the data lacks")
# provenance_view falls back to Provenance::of("unknown") for anything with no entry, so a
# vault placed in the directory by hand lands under this title too — and it predates nothing.
check("the note no longer says these predate the record",
      "predate this keystore recording" in ALL, False)
check("it names what else lands there",
      "copied into the keystore directory by hand" in ALL, True)
check("and the title, which was right, is untouched", '"Origin not recorded"' in view, True)

print("0j) three more absences that were only refusals")
# The note under this section already said it; the origin line and the section HEADER both
# went on calling an unread list a wallet that is not listed.
check("an unread wallet list is not a wallet that is not listed",
      code(view).count("a wallet the list could not be read to name"), 2)
check("a wallet keeps no derivation key only where the key directory was read",
      "sheet.keysKnown" in block(text("ManageWalletSheet.qml"),
                                 'objectName: "walletNothingToManage"', 8), True)
check("and it says so where the claim would have been",
      'objectName: "walletKeysUnread"' in text("ManageWalletSheet.qml"), True)
check("an unreadable keystore.json is not a mis-deployed custodian",
      "identity.configError" in block(view, 'objectName: "notCustodianNotice"', 12), True)

print("0k) the ordinal is the leftmost column, and a row without one is not ragged")
# It sat after the address, so `#0` read as a property of that row rather than as its position
# among the wallet's accounts. Leftmost makes it a column — and a column present on some rows
# and absent on others IS the ragged edge, so its presence is decided per NODE, not per row.
check("the ordinal is its own item", 'objectName: "index_" + modelData' in code(node), True)
check("and it comes first in the row",
      code(node).index('objectName: "index_"')
      < code(node).index('objectName: "account_" + modelData'), True)
check("the column is a node-level decision",
      "property bool ordinals" in code(node)
      and "ordinals: Tree.showsOrdinals(modelData)" in code(view), True)
check("decided in tree.js, where a table runs it",
      all(("function " + f) in (QML / "tree.js").read_text()
          for f in ("showsOrdinals", "ordinalOf")), True)
check("the slot keeps its width where a row has no ordinal",
      "Layout.preferredWidth: node.ordinalWidth" in code(node), True)
width = block(code(node), "readonly property int ordinalWidth", 3)
check("and nothing in that width depends on the row", "modelData" in width, False)
# Measured from the widest thing the column can hold, not guessed: a constant here is how the
# reserved slot silently becomes no slot at all.
check("it is measured, not asserted", "ordinalMetric.width" in width, True)
# …and measured in the badge's OWN font. LogosBadge's label is a LogosText, i.e. Public Sans;
# every other font property was matched and the family was not, so a long badge under-reserved
# by more than the slack and bled left out of its slot.
metric = block(code(node), "TextMetrics {", 8)
for prop in ("font.family: Theme.typography.publicSans", "font.pixelSize: 11",
             "font.letterSpacing: 0.22", "font.capitalization: Font.AllUppercase",
             "font.weight: Theme.typography.weightMedium"):
    check("  in the badge's own " + prop.split(":")[0].strip(), prop in metric, True)
# An em-dash would be a glyph the data does not contain; those rows say what they are
# elsewhere in the row — the whole path, or their node's own header sentence.
check("the badge inside the slot shows only where there IS an ordinal",
      "visible: ordinal.length > 0" in code(node), True)
check("and nothing stands in for one where there is not",
      re.search(r'"\s*[\u2014\u2013-]\s*"', code(node)) is None, True)
ordinal = block(code(node), 'objectName: "index_" + modelData', 12)
check("the hover that completes a path moved with it",
      "enabled: pathTip.length > 0" in ordinal, True)
check("and so did its tooltip",
      "visible: pathHover.hovered && pathTip.length > 0" in ordinal, True)
check("what is left beside the address is only how the account ARRIVED",
      'visible: badge.kind === "imported"'
      in block(code(node), 'objectName: "provenance_" + modelData', 8), True)

print("0l) the address is copyable, and it is the whole one that gets copied")
check("the row uses the copy control", "LogosCopyableText" in code(node), True)
check("the shown address is the short form",
      "node.view.shortAddr(modelData)"
      in block(code(node), 'objectName: "account_" + modelData', 6), True)
check("and what it copies is the whole one", "copyText: modelData" in code(node), True)
check("the name is a separate item, because it is a separate string",
      'objectName: "accountName_" + modelData' in code(node), True)
check("the name elides; the address is a fixed 13 characters and does not",
      "elide: Text.ElideRight" in block(node, 'objectName: "accountName_" + modelData'), True)
# The Manage sheet shows all 42 characters and WRAPS. LogosSelectableText cannot wrap — it
# clips — so the button is added beside the text instead of the control being swapped.
check("the whole address is copyable where it is shown whole",
      'objectName: "manageAddressCopy"' in code(view), True)
check("and it is still wrapping text there, not a clipping one",
      "wrapMode: Text.WrapAnywhere" in block(view, 'objectName: "manageAddress"'), True)

print("0m) a name is a claim of custody, so setting one has to prove it")
# A name is the one string on this screen an attacker chooses and a human reads, and a wallet
# renders it in place of an address. It was the only mutation with no proof behind it.
check("the account rename carries a password",
      "setLabel(QString address, QString label, QString password)" in rep, True)
check("and the wallet rename carries one of its own accounts, with that account's password",
      "setWalletName(QString group, QString name, QString address, QString password)" in rep, True)
check("the field is on the account sheet", 'objectName: "renamePasswordField"' in code(view), True)
check("and on the wallet sheet", 'objectName: "walletNamePasswordField"' in code(manage), True)
# Clearing is exempt on purpose: it can only move the display TOWARD the raw address, and it
# is the one way to strip a stale name off an account whose password is lost.
check("clearing an account name still asks for nothing",
      "renameField.text.trim().length === 0 || renamePw.text.length > 0" in code(view), True)
check("and the wallet rename asks only where there is something to prove",
      "!sheet.needsCredential || credPw.text.length > 0" in code(manage), True)
# "Has no accounts" was read as "holds nothing", so a DERIVABLE wallet with none could be
# named by proving nothing — and the account it then derived was shown under that name.
check("which is whether the wallet HOLDS anything, not whether it has accounts today",
      "(sheet.provedByAccount || sheet.provedByKey) && nameField.text.trim().length > 0"
      in code(manage), True)
check("an account proves it where there are accounts",
      "readonly property bool provedByAccount: sheet.addresses.length > 0" in code(manage), True)
check("and the derivation key where there are none but a key is kept",
      "readonly property bool provedByKey: sheet.addresses.length === 0 && sheet.keptKey"
      in code(manage), True)
check("that key is looked for at BOTH paths, as removal looks for it",
      "function keptKeyOf" in code(view)
      and all(f in block(code(view), "function keptKeyOf", 5)
              for f in ("hasKeyOnDisk", "stagedKeys.indexOf", "staged === true")), True)
check("and the sheet is told, rather than guessing",
      "walletSheet.keptKey = root.keptKeyOf(modelData)" in code(view), True)
check("any of them will do, and the first is offered without a step to take",
      "sheet.addresses.length > 0 ? sheet.addresses[0]" in code(manage), True)
check("the address is sent only where an ACCOUNT is the proof",
      "sheet.provedByAccount ? sheet.credAddress" in code(manage), True)
check("and the password reaches the module without one",
      "if (!password.isEmpty())" in backend, True)
# The shape with no secret is said outright rather than left as a silent exemption.
check("a wallet that holds nothing says why it is not asked for one",
      'objectName: "walletNameNoSecret"' in code(manage), True)
check("'holds nothing' is one predicate, over all four facts",
      "readonly property bool holdsNothing:\n        sheet.countKnown && sheet.addresses.length "
      "=== 0 && sheet.keysKnown && !sheet.keptKey" in code(manage), True)
check("and the sentence is shown on exactly that",
      "visible: sheet.holdsNothing"
      in block(code(manage), 'objectName: "walletNameNoSecret"', 4), True)
# It used to assert the false half aloud: "a wallet that keeps no derivation key can never
# gain an account, so that stays true" — said over a wallet that kept one.
check("and it no longer claims a keyless wallet where the key was never checked",
      "keeps no derivation key can never gain an" in code(manage), False)
check("the account rename says which of the two it is doing",
      'objectName: "renameNeedsPassword"' in code(view), True)

print("0n) a wallet that holds nothing can be removed, and the confirmation says what is lost")
# forget_derivation removes the KEY and answers NotFound when there is none, so a wallet with
# a record, no key and no accounts had nothing that would remove it: the row was permanent.
check("removal is its own call", "removeWallet(QString group)" in rep, True)
check("and it reaches remove_group, not forget_derivation",
      "keystore_module.remove_group(" in backend, True)
check("offered from the wallet's own sheet", 'objectName: "removeWalletStart"' in code(manage), True)
check("only where the view can SHOW the wallet holds nothing", "function walletRemovable" in view, True)
guard = block(code(view), "function walletRemovable", 7)
for fact in ("countKnown === true", "addresses.length === 0", "root.keyDirectoryKnown",
             "!root.keptKeyOf(n)"):
    check("  with " + fact + " in hand", fact in guard, True)
# Already gone is not a refusal to report: the row this was pressed on is simply stale.
check("a wallet that is already gone refreshes instead of erroring",
      "no such group" in backend, True)
# The confirmation IS the safety property here; nothing behind it checks the user meant it.
check("it states what goes", 'objectName: "removeWalletLost"' in code(view), True)
check("that nothing signable is affected, and why no password is asked for",
      'objectName: "removeWalletNothingSignable"' in code(view), True)
check("and that re-importing the phrase does not bring the row back",
      'objectName: "removeWalletNotUndo"' in code(view), True)
check("with an intent gesture in front of it", 'objectName: "removeWalletAck"' in code(view), True)
# The dead end it replaces: true about the KEY, and useless to someone who wants the row gone.
check("the dead-end sentence is gone", "There is nothing stored here to remove" in ALL, False)
check("and what stands in the way is named where it stood",
      "removeBlockedLine" in code(manage), True)

print("0o) a name left standing over nothing is a row, so it can be removed")
# The keystore removes a name whose record and key have both gone. The tree was built from
# records and key ids alone, so no row was drawn and there was nothing to press.
check("its frame is decided with the wallet read in hand",
      "Tree.nameFrameIdsOf(groups, walletNames, keyFrames, groupsKnown)" in view, True)
check("and it reaches the tree", "Tree.treeOf(accounts, provenance, groups, derivationKeys, "
      "reads, walletNames)" in view, True)
check("the row says what is under it, which is nothing but the name",
      'n.kind === "nameOnly"' in code(view) and "Only a name is stored under this wallet"
      in code(view), True)
check("it is badged rather than passing as a wallet", "nameOnlyBadge_" in code(view), True)
check("its sheet is reachable", 'modelData.kind === "nameOnly"'
      in block(code(view), "manageVisible:", 2), True)
check("and removal is offered on it", 'n.kind === "nameOnly"'
      in block(code(view), "function walletRemovable", 7), True)
check("the sheet does not offer to manage a wallet that is not there",
      "!sheet.nameOnly" in block(code(manage), 'objectName: "walletNothingToManage"', 8), True)
check("it says what is left instead", 'objectName: "nameOnlyLeftover"' in code(manage), True)

print("0g) tree.js decides nothing about appearance, so the table asserts claims not colours")
check("no Theme in tree.js", "Theme" in code((QML / "tree.js").read_text()), False)
check("the view imports it", 'import "tree.js" as Tree' in view, True)

print("0h) the rules themselves — doctests/tree_table.mjs")
try:
    r = subprocess.run(["node", str(Path(__file__).resolve().parent / "tree_table.mjs")],
                       capture_output=True, text=True, timeout=120)
    print("\n".join("    " + l for l in r.stdout.strip().splitlines()[-3:]))
    check("the tree table passes", r.returncode, 0)
except FileNotFoundError:
    print("  SKIP  node not found — run `node doctests/tree_table.mjs` where it is")

if "--grep-only" in sys.argv:
    print("\n" + (f"{len(FAIL)} FAILED: {FAIL}" if FAIL else "all passed"))
    sys.exit(1 if FAIL else 0)


# ── 1 and up: a live app on 3768 ───────────────────────────────────────────────────
sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspector import call

def oid(n):
    m = (call("findByProperty", {"property": "objectName", "value": n}).get("matches") or [])
    return m[0]["id"] if m else None

def props(n):
    i = oid(n)
    if i is None:
        return {}
    raw = call("getProperties", {"objectId": i}).get("properties") or {}
    return {d["name"]: d.get("value") for d in raw} if isinstance(raw, list) else raw

def ev(expr):
    """Evaluate in the VIEW's own scope, so its properties and pure functions are in scope.

    `callMethod` answers `{"invoked": name}` and throws the return value away, so the tree the
    view actually built is unreachable any other way."""
    return call("evaluate", {"objectId": oid("keystoreRoot"), "expression": expr}).get("result")

def js(expr):
    try:
        return json.loads(ev(expr))
    except Exception:
        return None

def click(name):
    i = oid(name)
    if i is not None:
        call("callMethod", {"objectId": i, "method": "clicked", "args": []})
    time.sleep(0.4)
    return i

print("\n1) the view is up and reports which role it holds")
check("root", oid("keystoreRoot") is not None, True)
check("custodian badge", props("custodianBadge").get("text") in ("CUSTODIAN", "READ ONLY"), True)

print("2) every account hangs off a node — the tree the view actually built")
tree = js("JSON.stringify(nodes.map(function(n){return {kind:n.kind,id:n.id,"
          "n:n.addresses.length,prefix:n.prefix}}))") or []
print(f"    nodes: {tree}")
check("at least one node", len(tree) > 0, True)
check("accounts are covered",
      sum(n["n"] for n in tree), js("accounts.length") if js("accounts.length") is not None
      else sum(n["n"] for n in tree))
check("no node kind outside the taxonomy",
      [n["kind"] for n in tree
       if n["kind"] not in ("wallet", "stranded", "unreadKey", "imported", "random",
                            "orphan", "unrecorded", "flat")], [])

print("3) two wallets are told apart by their PARENT, not by a badge that names both alike")
wallets = [n for n in tree if n["kind"] == "wallet"]
titles = [ev(f'nodeTitle({{kind:"wallet",id:"{w["id"]}",group:groups.filter(function(g)'
             f'{{return g.id==="{w["id"]}"}})[0],addresses:[],countKnown:true}})')
          for w in wallets]
print(f"    wallet titles: {titles}")
check("no two wallets share a title", len(set(titles)), len(titles))
# A title is a name or an ordinal. It was the wallet's first account, and it was never the hex.
check("no title is a bare hex id",
      [t for t in titles if re.fullmatch(r"Wallet [0-9a-f]{8}", str(t))], [])
check("nor an address", [t for t in titles if "…" in str(t) or "0x" in str(t)], [])
check("and none is empty", [t for t in titles if not str(t).strip()], [])

print("4) a wallet's node carries the shared prefix; its children carry only what varies")
for w in wallets:
    sub = props(f"nodeSubtitle_{w['id']}").get("text") or ""
    check(f"{w['id'][:10]} names its path once", bool(re.search(r"m/44'/60'/\d+'", sub)), True)
kids = js("JSON.stringify(nodes.filter(function(n){return n.kind==='wallet'})"
          ".map(function(n){return n.addresses.map(function(a){return badgeFor(a,n.prefix)"
          ".text})}))") or []
print(f"    child badges: {kids}")
check("no child badge repeats a path",
      [b for row in kids for b in row if "/" in str(b)], [])

print("5) add account sits on the wallet it adds to")
check("no global add button", oid("addAccountButton") is None, True)
if wallets:
    w = wallets[0]
    check("the wallet's own add button", oid(f"nodeAdd_{w['id']}") is not None, True)
    click(f"nodeAdd_{w['id']}")
    check("the sheet opened", props("addAccountSheet").get("opened"), True)
    check("and it names the wallet it will add to",
          props("addAccountWallet").get("text"), titles[0])
    check("with no wallet picker", oid("walletPicker") is None, True)
    click("addAccountClose")

print("6) a node folds away, and takes its accounts with it")
if wallets and wallets[0]["n"] > 0:
    first = js(f"JSON.stringify(nodes.filter(function(n){{return n.id==='{wallets[0]['id']}'}})"
               "[0].addresses[0])")
    check("the account is on screen", props(f"account_{first}").get("visible"), True)
    click(f"nodeDisclosure_{wallets[0]['id']}")
    check("folded away", oid(f"account_{first}") is None, True)
    click(f"nodeDisclosure_{wallets[0]['id']}")
    check("and back", props(f"account_{first}").get("visible"), True)

print("7) creating a key from randomness is not reachable from this screen")
check("no toolbar action", oid("unrelatedKeyButton") is None, True)
check("and no sheet behind it", oid("unrelatedAccountSheet") is None, True)

print("8) a badge only offers a path where it abbreviates one")
# How the defect was measured: hovering PRIVATE KEY answered "an unrecognised path". Asked of
# the real keystore, of every badge on screen, rather than of a fixture.
tips = js("JSON.stringify(nodes.reduce(function(acc,n){return acc.concat("
          "n.addresses.map(function(a){return [badgeFor(a,n.prefix).kind,"
          "pathTipFor(a,n.prefix)]}))},[]))") or []
print(f"    badge kinds: {sorted(set(k for k, _ in tips))}")
check("nothing but #n and CHANGE #n completes into a path",
      [k for k, t in tips if t and k not in ("index", "change")], [])
check("and those that do complete into one this view rebuilt",
      [t for k, t in tips if k in ("index", "change") and not re.fullmatch(r"m/44'/60'/\d+'/\d+/\d+", str(t))], [])

print("9) a refused read is named, and no frame claims a count it did not read")
refused = js("JSON.stringify(refusedReads)") or []
print(f"    refused: {refused}")
check("the notice is shown exactly when something was refused",
      bool(props("refusedReadsNotice").get("visible")), len(refused) > 0)
unknown = js("JSON.stringify(nodes.filter(function(n){return n.countKnown===false})"
             ".map(function(n){return n.id}))") or []
check("a frame whose count was not read says so, and says nothing else",
      [i for i in unknown if (props(f"nodeEmpty_{i}").get("text") or "")
       or not (props(f"nodeUnread_{i}").get("text") or "")], [])

print("10) the ordinal column is per node, and every row of a node agrees with it")
cols = js("JSON.stringify(nodes.map(function(n){return {kind:n.kind,col:n.prefix>=0,"
          "ords:n.addresses.map(function(a){return ordinalFor(a,n.prefix)})}}))") or []
print(f"    columns: {[(c['kind'], c['col']) for c in cols]}")
check("only a wallet node carries the column",
      [c["kind"] for c in cols if c["col"] and c["kind"] != "wallet"], [])
check("and no node without it has a row that would fill one",
      [c["kind"] for c in cols if not c["col"] and [o for o in c["ords"] if o]], [])
check("what the column says is a position, never a path",
      [o for c in cols for o in c["ords"] if "/" in str(o)], [])
if wallets and wallets[0]["n"] > 0:
    one = js(f"JSON.stringify(nodes.filter(function(n){{return n.id==='{wallets[0]['id']}'}})"
             "[0].addresses[0])")
    check("the ordinal is its own item on the row", oid(f"index_{one}") is not None, True)
    check("and the address beside it is the copyable control",
          props(f"account_{one}").get("copyText"), one)

print("11) removing a wallet is offered only where the view can show it holds nothing")
offered = js("JSON.stringify(nodes.filter(function(n){return walletRemovable(n)})"
             ".map(function(n){return [n.id, n.addresses.length, n.countKnown]}))") or []
print(f"    removable: {offered}")
check("nothing holding accounts is offered removal", [o for o in offered if o[1] > 0], [])
check("nor anything whose account list was not read", [o for o in offered if o[2] is not True], [])
check("nor anything with a key still on disk",
      js("JSON.stringify(nodes.filter(function(n){return walletRemovable(n)"
         "&& hasKeyOnDisk(n.group)}).length)"), 0)

print("\n" + (f"{len(FAIL)} FAILED: {FAIL}" if FAIL else "all passed"))
sys.exit(1 if FAIL else 0)
