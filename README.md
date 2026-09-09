# evm_keystore_ui

The one place accounts are created, imported, exported and deleted.

Every other surface only reads which accounts exist. Wallets request signatures and render an
account picker; `evm_signer_ui` shows what is being signed and takes the password to authorise it.
Neither can change the keystore, and that is enforced by the keystore itself — this module is
its configured **custodian**, and Tier D admits nobody else.

## Screens

| Screen | Keystore method |
|---|---|
| Accounts | `list_accounts`, `get_labels`, `list_groups`, `list_derivation_keys`, `get_provenance`, `get_group_labels` *(all ungated)* |
| Create | `create_mnemonic` → shown once → confirmed → `import_mnemonic` |
| Import phrase | `import_mnemonic` |
| Import private key | `import_private_key` |
| Import vault | `import_keystore_json` |
| Add account *(on a wallet's own row)* | `derive_next_account` |
| Add account → Advanced | `preview_addresses`, `derive_account_at` |
| Manage wallet | `set_group_label`, `forget_derivation`, `remove_group` |
| Rename an account | `set_label` |
| Change password | `change_password` |
| Export | `export_keystore_json` |
| Delete a stranded derivation key | `list_derivation_keys` → `forget_derivation` |
| Delete | `delete_account` |

There is no plain "create account" button, and no way here to a key generated from randomness
rather than derived from a phrase. `create_unrelated_account` stays on the keystore's contract —
it is the only acknowledged door to such a key, and its `Unrecoverable` acknowledgement is what
let `new_account` be deleted — but no shipped screen reaches it. Accounts on this screen come
from a phrase, an import, or a wallet that keeps its derivation key. Accounts that arrived the
other way still render, under a header that says what they are.

## The tree

Accounts are shown nested under the thing they came from, not as a flat list with a line of
wallet metadata above it. Six kinds of top-level node, in a fixed order:

| Node | Source |
|---|---|
| A wallet | `list_groups`, `stranded: false` |
| A key no wallet record accounts for | the key directory — see below |
| A key whose record could not be read | the key directory, with `list_groups` refused |
| Imported | `origin` is `imported-key` or `imported-json` |
| Created here, not from a phrase | `origin` is `random` |
| Derived from a wallet not listed here | `origin` is `derived`, and its group is in neither list |
| Origin not recorded | `origin` is `unknown` |

The last four are separate because each is a different truth, and folding any of them together
would state something about recoverability that is not known. `unknown` means exactly that
nothing on record says: `provenance_view` falls back to `Provenance::of("unknown")` for any
account with no entry, so a vault copied into the directory by hand lands there beside one that
predates the record. The keystore never guesses which, and neither does this.

**The parent carries the shared prefix; the child carries only what varies.** A wallet's row
shows `m/44'/60'/0'` once; its accounts show `#0`, `#1`, `CHANGE #0`. A node carries the account
level it parsed, and a child recorded at a *different* one shows its whole path instead — `#3`
under a header reading `m/44'/60'/0'` would name a path that account does not have. The badge used to be the
path *within* a wallet, which is the same for every wallet's first account — so two wallets
both read `HD 0'/0/0` and the one piece of provenance on screen said nothing. A wallet with no
recorded prefix has nothing to complete, so its children carry the whole path instead, as
monospaced text rather than an uppercased badge.

That ordinal is the **leftmost column** of an account row, not a chip after the address: `#0`
placed second reads as a property of that row, and placed first it reads as its position among
the wallet's accounts. A column that appears on some rows and not others would be worse than
either, so its presence is decided **per node** — `prefix >= 0`, which only a wallet node has —
and a row inside such a node that carries no ordinal (a hand-edited path at another account
level) leaves the slot blank at its full width. Blank, not an em-dash: a dash is a glyph the
data does not contain, and that row is already showing its whole path further along.

**The address is copyable, and what gets copied is the whole one.** The row shows
`0x1234…abcd`; `LogosCopyableText` carries the full 42 characters as `copyText`. The name beside
it is a separate item because it is a separate string — the name is user-typed and elides, the
short address is a fixed 13 characters and does not. In the Manage sheet, where the whole
address is shown and wrapped, a `LogosCopyButton` is added beside the text instead:
`LogosSelectableText` cannot wrap, it clips.

**A wallet is identified by its name, and otherwise by its position here.** A name is set at
import (`groupLabel`) or changed afterwards with `set_group_label`, and is read back from
`get_group_labels` — its own document, so a wallet whose record is gone keeps its name. An
unnamed wallet is `Wallet 1`, `Wallet 2`, numbered down the list of wallet frames.

It was the wallet's first account, which is where the name went wrong: `delete_account` retires
that account's provenance entry, so deleting account #0 silently renamed the wallet in the node
header, in both sheets and in every origin line at once. An ordinal cannot move for anything an
account does. It *can* move when another wallet is imported, which is what the Manage sheet says
where the name is typed — the shipped pattern elsewhere is exactly this, an editable placeholder
over a stable ordinal.

**Two wallets may carry one name**, deliberately: `set_group_label` has no uniqueness rule. A
name that names two wallets is not a name, so when it is shared both frames show the first eight
characters of their id beside it — the one fact that separates them for good. `usedPassphrase`
stays a badge and is part of a wallet's identity: it is what tells two wallets from the same
phrase apart.

**"Add account" sits on the wallet it adds to.** With two derivable wallets a global button
cannot say which one it means, and a picker inside the sheet adds a step to answer a question
the layout answers for free. A wallet that cannot derive says so where its button would be.

**A refused read is a screen state, not a finding about the accounts.** It used to render as
`UNKNOWN` on every row while the error line above said provenance could not be read. Now the
wallets still render from their own read, without a count, and the accounts appear as one flat
node that says the grouping could not be worked out.

**Stranded is a claim about the wallet list, so it needs that list to have answered.** Which
keys on disk no record accounts for was decided by absence from `list_groups` — which a refused
read empties, so every healthy wallet became a frame badged `NO RECORD` offering to delete its
live key. The frames still appear when that read fails (the key must stay deletable) and say
`RECORD NOT READ` instead. The empty screen draws the same line: only `list_accounts`,
`list_groups` and `list_derivation_keys` decide whether there is anything at all, so a refused
`get_labels` alone no longer turns an empty keystore into one that could not be read.

The same distinction covers every read behind this screen, because each one empties what it
feeds and each of those empty answers is *also* a truthful screen for some keystore. Only the
reader knows which, so `readsJson` says outright which reads answered rather than leaving the
view to infer a refusal from an absence. `list_accounts` can fail while `list_groups` succeeds —
it goes through `settle()` and the vault scan — and every wallet frame then claimed "No
accounts", which is the read failing stated as a fact about the wallet. A frame whose count was
not read says so in its own line, and the empty screen says which of the two it is.

**A tooltip may only assert a path where there is one.** The provenance badge completes into the
full path on hover — but only the badges that *abbreviate* one, `#0` and `CHANGE #0`. `PRIVATE
KEY` and `VAULT FILE` name how a key arrived; an imported key has `path: ""` by construction, and
hovering it used to answer "an unrecognised path", asserting both that the account had a path and
that it was broken.

**Two hazards the QML is written around.** A `.rep` SLOT with a return type answers a
`QRemoteObjectPendingReply`, not the value — using the return directly compiles, runs and is
always truthy, so a failed import looks like a successful one; every such call goes through
`logos.watch(...)`. And `LogosText` is a bare `Text`, i.e. Qt `AutoText`: every string this view
did not author sets `textFormat: Text.PlainText`, and a wallet's name — the one user-typed
string here — never reaches a badge, a combo box or a dialog title, all of which render through
a bare `LogosText`.

**The rules live in `src/qml/tree.js`, not in bindings.** Which node an account belongs to,
what its badge claims and what names a wallet are pure functions, so `doctests/tree_table.mjs`
runs them against a case table with no app, no inspector and no Qt — it loads the view's own
file, not a copy. `doctests/assert_ui.py --grep-only` adds the claims a source file can answer
for, including that every `Theme` token used actually exists: `Theme.palette` is a `var`, so a
misspelt token is invisible until load.

## Eight deliberate choices

**Secrets are returned from methods, never published as properties.** A generated phrase, an
exported vault and a list of previewed addresses come back from a SLOT and are cleared when the
sheet closes. A PROP would be cached in the shell process and broadcast to every connected
replica — strictly worse than the thing it would be carrying. Provenance and the wallet list
*are* PROPs, correctly: a derivation path is public the moment its address is.

**Creating an account requires confirming three words of the phrase** before anything is
stored. An unwritten phrase is an unrecoverable account, and the moment to catch that is
before the account exists, not after.

**Whether to keep a derivation key is chosen once per wallet, not per account.** It cannot
honestly be per account: the key that derives account 3 derives account 5 as well. The choice
is worded as what someone who copies the vault directory gets — one account, or every account
under the wallet including ones not created yet — because that is the only part of it the
person choosing can weigh. The default is to keep nothing, and it can be given up later
(*Stop keeping the derivation key*) but never taken back up without the phrase.

**A derivation key with no wallet record is shown, not hidden.** It is a node of the tree like
any other wallet, with whatever accounts still name it nested inside. `list_derivation_keys`
reads the key directory alone, so the node still appears when `groups.json` is unreadable and
`list_groups` answers nothing. Such a key cannot add accounts — there is no recorded path to derive against —
but it still opens a whole wallet, and hiding it is what would make it undeletable. The strip
says what deleting it costs: the accounts already derived **keep working exactly as they do
now**; they simply stop being extendable without the recovery phrase.

**Deleting a derivation key asks for a confirmation, not its password.** A key whose password
is lost, or whose bytes are corrupt, is exactly the key worth removing — and while it sits on
disk it goes on refusing every new account, so requiring the password to delete it left the
user unable to derive *and* unable to stop being derivable. The custodian gate is the
authorisation; the checkbox is the intent. A wallet is offered the control whenever a key for
it exists in the key directory, which is a different question from `derivable` (that one is a
promise about *adding* accounts, and it is false for a key nobody can open). Two states get
their own words: **INTERRUPTED IMPORT** for a copy left at the staging path — it cannot add
accounts but opens the whole wallet — and a strip naming any file in the key directory this
keystore did not write, because that also refuses a new account and a refusal whose cause is
invisible is a wedge.

**A name is a claim of custody, so setting one proves it.** Neither `set_label` nor
`set_group_label` took a password: renaming was the one mutation on this screen with no proof
behind it, while delete, export and change-password each ask for one. A name is also the one
string here that an attacker chooses and a human reads, and a wallet renders it *in place of*
an address in its account picker. Setting an account name now needs that account's own vault
password. Setting a wallet name needs the password of **one of its accounts** — any one: holding
an account is exactly the claim the header makes about the accounts beneath it, and the group
password would prove only that you can *make* accounts, not that you own the ones it names.

Where the wallet has **no** accounts but still keeps a derivation key, that rejection has
nothing to reach — there are no accounts to own, and the only thing the name will come to stand
for is the ones that key mints — so the **key's own password** is what proves it. The sheet asks
for it by that name, and the view looks for the key at both paths, the live one and the copy an
interrupted import leaves, exactly as removal does.

Two exemptions, both said on screen rather than left silent. **Clearing a name asks for
nothing**: it can only move the display toward the raw address, which is ground truth, and it is
the one way to strip a stale name off an account whose password is lost. **A wallet that holds
nothing asks for nothing either** — no accounts *and* no key — because it names nothing and,
with no key, can never gain anything for the name to come to stand over. That is the same
precondition removal refuses on, and it replaced "has no accounts", which was true of a
derivable wallet that had simply not been used yet. Against the caller Tier D is about this is
defence in depth, not a boundary: anything that can call `set_label` at all *is* the custodian
UI. What it buys is parity with the other three mutations, against a human at an unlocked
machine.

**A wallet that holds nothing can be removed.** `forget_derivation` removes the *key* and
answers `NotFound` when there is none, so a wallet with a record, no key and no accounts had
nothing anywhere that would remove it — the row was permanent by construction, and the Manage
sheet's "there is nothing stored here to remove" was true about the key and useless to someone
who wanted the row gone. `remove_group` removes the record and the name, and refuses while the
wallet holds a derivation key (live or staged) or an account. Refusing rather than re-parenting
is the point: dropping the record would push those accounts into *Derived from a wallet not
listed here*, and rewriting their provenance to `unknown` would delete a true fact to make a row
disappear. Because the precondition is "holds nothing", removal can never destroy anything
signable — which is why it needs no password, and the confirmation says so. It also says what
*is* lost (the name, the path prefix, the index bookkeeping) and that re-importing the phrase
makes a new wallet rather than bringing this one back. The button is offered only where the view
can show the precondition holds; every part of that is a read that can fail, and an unread
answer is not a yes.

**Paths and wallet ids are re-rendered from their parsed parts.** `m/44'/60'/…` and `g_…`
arrive from the keystore; this view matches them against the shape it expects and rebuilds the
string it shows, so a hand-edited `accounts.json` cannot put anything on screen this view did
not author. Purpose `44'` and coin `60'` are shown fixed and are not editable — a path whose
coin type can be changed is a way to make funds unrecoverable, dressed as a feature.

If this build is not the configured custodian it says so once, plainly, instead of letting
every button fail one screen later — and if `keystore.json` could not be read at all it says
*that* instead, because an unreadable config empties both roles rather than reverting to the
defaults, and blaming the deployment for a torn file is a different bug to go looking for.

## Testing

```bash
python3 doctests/assert_ui.py --grep-only   # no app, no socket
node doctests/tree_table.mjs                # the tree rules, as a table
python3 doctests/assert_ui.py               # the rest, against an app on port 3768
```

## Building

```bash
nix build .#lgx-portable   # for Basecamp / logosctl
nix build .#install        # the dev variant, for logos-standalone-app
```
