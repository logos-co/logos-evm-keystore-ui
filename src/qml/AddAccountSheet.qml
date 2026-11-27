import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme
import "tree.js" as Tree

// Add an account to ONE wallet — the one whose row this sheet was opened from, which is why
// there is no picker in here. Advanced previews what a path would produce before writing it.
//
// Purpose 44' and coin 60' are fixed: a path whose coin type can be changed is a way to make
// funds unrecoverable, dressed as a feature. The title is a literal because LogosDialog renders
// `title` as AutoText, and the wallet's name is user-typed.
LogosDialog {
    id: sheetRoot
    objectName: "addAccountSheet"
    title: "Add an account"

    property var backend: null
    property var view: null
    property var group: null
    property bool advanced: false
    property var previewRows: []

    function num(t) { var v = parseInt(t, 10); return isNaN(v) ? -1 : v }
    function rows(json) { try { return JSON.parse(json && json.length ? json : "[]") } catch (e) { return [] } }
    function shortAddr(a) { return (!a || a.length < 12) ? (a || "") : a.substring(0, 6) + "…" + a.substring(a.length - 4) }
    function accountOf(g) { return Math.max(0, Tree.parsePrefix(g ? g.pathPrefix : "")) }

    readonly property int acct: num(acctField.text)
    readonly property int chg: num(changeField.text)
    readonly property int idx: num(indexField.text)
    readonly property bool pathValid: acct >= 0 && (chg === 0 || chg === 1) && idx >= 0
    // The stored key is an ACCOUNT key and the BIP-44 account level is hardened, so it cannot
    // reach a different one. Said here rather than left as an opaque refusal.
    readonly property bool accountMismatch: group !== null && acct >= 0 && acct !== accountOf(group)
    readonly property bool derivable: group !== null && group.derivable === true

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 620)

    onOpened: {
        sheetError.clear()
        advanced = false
        previewRows = []
        walletPw.text = ""; accountPw.text = ""
        changeField.text = "0"
        followWallet()
    }
    onClosed: { walletPw.text = ""; accountPw.text = ""; previewRows = []; sheetError.clear() }

    // The path fields follow the wallet: another wallet's account level and next index mean
    // nothing here, and offering them would be an invitation to derive the wrong path.
    function followWallet() {
        acctField.text = String(accountOf(group))
        indexField.text = String(Tree.nextIndexOf(group))
    }
    onGroupChanged: followWallet()

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText {
            objectName: "addAccountWallet"
            Layout.fillWidth: true
            visible: sheetRoot.derivable
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.typography.subtitleText
            text: sheetRoot.view ? sheetRoot.view.walletTitleOf(sheetRoot.group) : ""
        }

        // Reachable when the wallet stops being derivable while this is open — a key deleted
        // from another surface, or an import that turned out to have kept nothing.
        LogosText {
            objectName: "noDerivableWalletNotice"
            Layout.fillWidth: true
            visible: !sheetRoot.derivable
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: "This wallet does not keep a derivation key, so the next account cannot be "
                  + "worked out without its recovery phrase. Import the phrase again, choosing "
                  + "to keep one — it produces the same accounts."
        }

        LogosText {
            objectName: "nextPathLine"
            Layout.fillWidth: true
            visible: sheetRoot.derivable
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: sheetRoot.derivable
                  ? "The next free account of this wallet is m/44'/60'/"
                    + sheetRoot.accountOf(sheetRoot.group) + "'/0/" + Tree.nextIndexOf(sheetRoot.group)
                  : ""
        }

        LogosTextField {
            id: walletPw
            objectName: "walletPasswordField"
            Layout.fillWidth: true
            visible: sheetRoot.derivable
            echoMode: TextInput.Password
            placeholderText: "Wallet password — the one that opens its derivation key"
        }
        LogosTextField {
            id: accountPw
            objectName: "newAccountPasswordField"
            Layout.fillWidth: true
            visible: sheetRoot.derivable
            echoMode: TextInput.Password
            placeholderText: "Password for the new account"
        }
        LogosButton {
            objectName: "deriveNextConfirm"
            visible: sheetRoot.derivable
            text: "Add account"
            enabled: sheetRoot.derivable && walletPw.text.length > 0 && accountPw.text.length > 0
            onClicked: {
                sheetError.clear()
                logos.watch(sheetRoot.backend.deriveNextAccount(sheetRoot.group.id, walletPw.text, accountPw.text),
                    function (good) { if (good) sheetRoot.close(); else sheetError.take(sheetRoot.backend, "The account was not added.") },
                    function () { sheetError.lost() })
            }
        }

        Rectangle {
            visible: sheetRoot.derivable
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.palette.borderSubtle
        }

        LogosButton {
            objectName: "advancedToggle"
            visible: sheetRoot.derivable
            text: sheetRoot.advanced ? "Hide advanced" : "Advanced"
            onClicked: sheetRoot.advanced = !sheetRoot.advanced
        }

        // ── Choose a path ──────────────────────────────────────────────────────────
        LogosText {
            visible: sheetRoot.advanced && sheetRoot.derivable
            text: "Choose a path"
            color: Theme.palette.textSecondary
        }
        RowLayout {
            visible: sheetRoot.advanced && sheetRoot.derivable
            spacing: Theme.spacing.tiny
            LogosText { text: "m / 44' / 60' /"; color: Theme.palette.textSecondary }
            LogosTextField {
                id: acctField
                objectName: "bip44AccountField"
                Layout.preferredWidth: 70
                text: "0"
                validator: IntValidator { bottom: 0; top: 2147483647 }
            }
            LogosText { text: "' /"; color: Theme.palette.textSecondary }
            LogosTextField {
                id: changeField
                objectName: "changeField"
                Layout.preferredWidth: 50
                text: "0"
                validator: IntValidator { bottom: 0; top: 1 }
            }
            LogosText { text: "/"; color: Theme.palette.textSecondary }
            LogosTextField {
                id: indexField
                objectName: "indexField"
                Layout.preferredWidth: 90
                validator: IntValidator { bottom: 0; top: 2147483647 }
            }
        }
        LogosText {
            objectName: "chosenPathLine"
            visible: sheetRoot.advanced && sheetRoot.derivable
            textFormat: Text.PlainText
            text: sheetRoot.pathValid
                  ? "m/44'/60'/" + sheetRoot.acct + "'/" + sheetRoot.chg + "/" + sheetRoot.idx
                  : "purpose and coin are fixed; change is 0 or 1"
            color: sheetRoot.pathValid ? Theme.palette.text : Theme.palette.textSecondary
        }
        LogosText {
            objectName: "accountMismatchNotice"
            Layout.fillWidth: true
            visible: sheetRoot.advanced && sheetRoot.accountMismatch
            wrapMode: Text.WordWrap
            color: Theme.palette.warning
            text: sheetRoot.group
                  ? "This wallet kept the key for account " + sheetRoot.accountOf(sheetRoot.group)
                    + "'. That level is hardened, so its key cannot reach account "
                    + sheetRoot.acct + "' — import the phrase again for that one."
                  : ""
        }
        RowLayout {
            visible: sheetRoot.advanced && sheetRoot.derivable
            spacing: Theme.spacing.tiny
            LogosButton {
                objectName: "previewButton"
                text: "Preview"
                enabled: sheetRoot.pathValid && !sheetRoot.accountMismatch && walletPw.text.length > 0
                onClicked: {
                    sheetError.clear()
                    logos.watch(sheetRoot.backend.previewAddresses(sheetRoot.group.id, walletPw.text, sheetRoot.chg, sheetRoot.idx, 10),
                        function (json) {
                            sheetRoot.previewRows = sheetRoot.rows(json)
                            if (!json) sheetError.take(sheetRoot.backend, "Could not preview the addresses.")
                        }, function () { sheetError.lost() })
                }
            }
            LogosButton {
                objectName: "deriveAtConfirm"
                text: "Add the account at this path"
                enabled: sheetRoot.pathValid && !sheetRoot.accountMismatch
                         && walletPw.text.length > 0 && accountPw.text.length > 0
                onClicked: {
                    sheetError.clear()
                    logos.watch(sheetRoot.backend.deriveAccountAt(sheetRoot.group.id, walletPw.text, accountPw.text,
                                                              sheetRoot.acct, sheetRoot.chg, sheetRoot.idx),
                        function (good) { if (good) sheetRoot.close(); else sheetError.take(sheetRoot.backend, "The account was not added.") },
                        function () { sheetError.lost() })
                }
            }
        }
        LogosListView {
            objectName: "previewList"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(sheetRoot.previewRows.length * 22, 160)
            visible: sheetRoot.advanced && sheetRoot.previewRows.length > 0
            model: sheetRoot.previewRows
            delegate: RowLayout {
                width: ListView.view ? ListView.view.width : 0
                LogosText {
                    objectName: "preview_" + modelData.index
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    font.pixelSize: Theme.typography.secondaryText
                    text: modelData.index + "   " + sheetRoot.shortAddr(modelData.address)
                }
                LogosText {
                    textFormat: Text.PlainText
                    font.pixelSize: Theme.typography.secondaryText
                    color: modelData.present ? Theme.palette.textSecondary : Theme.palette.success
                    text: modelData.present ? "already here" : "free"
                }
            }
        }

        SheetError { id: sheetError; objectName: "addAccountError" }
        LogosButton { objectName: "addAccountClose"; text: "Close"; onClicked: sheetRoot.close() }
    }
}
