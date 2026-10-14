import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Icons
import Logos.Theme

// One node of the accounts tree: a header saying what these accounts have in common, and the
// accounts nested inside it. The frame is the structural fix — two wallets listed above a flat
// list of addresses say nothing about which address came from which, and indentation does not
// say it either.
//
// Every string a node shows that this view did not author is PlainText: LogosText is a bare
// Text, i.e. Qt AutoText, and a wallet's name is user-typed.
LogosFrame {
    id: node

    property var view: null
    property string nodeId: ""
    property string title: ""
    property string subtitle: ""
    property string note: ""
    property color noteColor: Theme.palette.warning
    // [{ name, text, color }] — header badges, in the order given.
    property var badges: []
    property var addresses: []
    property var bitcoinGroup: null
    // The account level the header carries, -1 for none. A child recorded at another level
    // shows its whole path rather than borrowing this one.
    property int prefix: -1
    // Whether this node's rows carry the leftmost ordinal column at all. Per node, never per
    // row: a column that appears on some rows and not others is the ragged edge itself.
    property bool ordinals: false
    // One width for the whole node, from the widest thing the column can hold, so the
    // addresses beside it line up whatever each row's ordinal turns out to be.
    readonly property int ordinalWidth:
        Math.ceil(ordinalMetric.width) + 2 * Theme.spacing.small + 2
    // Shown in place of the children when a node genuinely holds none. `unreadLine` is the
    // other case, and they are two properties because they are two different sentences: one
    // reports the wallet, the other reports the read.
    property string emptyLine: ""
    property string unreadLine: ""
    property bool addVisible: false
    property bool addEnabled: false
    property string addBlockedLine: ""
    property bool manageVisible: false
    property bool manageEnabled: false
    property bool deleteKeyVisible: false
    property bool deleteKeyEnabled: false
    property bool expanded: true

    signal toggleRequested()
    signal addRequested()
    signal manageWalletRequested()
    signal manageAccountRequested(string address)
    signal forgetKeyRequested()

    backgroundColor: Theme.palette.surface
    borderColor: Theme.palette.borderSubtle
    radius: Theme.spacing.radiusSmall
    padding: Theme.spacing.small

    contentItem: ColumnLayout {
        spacing: Theme.spacing.tiny

        // LogosBadge's own label font, so the reserved width matches what a badge renders.
        // The family is half of that: its label is a LogosText, i.e. Public Sans, and
        // measuring in the default face under-reserves by more than the slack allows.
        TextMetrics {
            id: ordinalMetric
            font.family: Theme.typography.publicSans
            font.pixelSize: 11
            font.letterSpacing: 0.22
            font.capitalization: Font.AllUppercase
            font.weight: Theme.typography.weightMedium
            text: "CHANGE #88"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            LogosIconButton {
                objectName: "nodeDisclosure_" + node.nodeId
                flat: true
                size: 24
                iconSize: 12
                iconColor: Theme.palette.textSecondary
                iconSource: node.expanded ? LogosIcons.triangleUp : LogosIcons.triangleDown
                Accessible.name: node.expanded ? "Hide accounts" : "Show accounts"
                onClicked: node.toggleRequested()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                LogosText {
                    objectName: "nodeTitle_" + node.nodeId
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.pixelSize: Theme.typography.subtitleText
                    text: node.title
                }
                LogosText {
                    objectName: "nodeSubtitle_" + node.nodeId
                    Layout.fillWidth: true
                    visible: node.subtitle.length > 0
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.family: Theme.typography.mono
                    font.pixelSize: Theme.typography.secondaryText
                    color: Theme.palette.textSecondary
                    text: node.subtitle
                }
            }

            Repeater {
                model: node.badges
                delegate: LogosBadge {
                    objectName: modelData.name
                    text: modelData.text
                    color: modelData.color
                }
            }

            LogosButton {
                objectName: "nodeAdd_" + node.nodeId
                visible: node.addVisible
                enabled: node.addEnabled
                text: "Add account"
                onClicked: node.addRequested()
            }
            LogosButton {
                objectName: "nodeManage_" + node.nodeId
                visible: node.manageVisible
                enabled: node.manageEnabled
                text: "Manage…"
                onClicked: node.manageWalletRequested()
            }
        }

        LogosText {
            objectName: "nodeNote_" + node.nodeId
            Layout.fillWidth: true
            visible: node.note.length > 0
            wrapMode: Text.WordWrap
            color: node.noteColor
            text: node.note
        }

        // Said where the button would be, so a wallet that cannot add one says why in its
        // own row rather than leaving a gap the user has to interpret.
        LogosText {
            objectName: "nodeAddBlocked_" + node.nodeId
            Layout.fillWidth: true
            visible: node.addBlockedLine.length > 0
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            text: node.addBlockedLine
        }

        // No password: this is the key nobody can open, and needing one to delete it is what
        // made it permanent. The custodian gate authorises; the checkbox is the intent.
        RowLayout {
            Layout.fillWidth: true
            visible: node.deleteKeyVisible
            spacing: Theme.spacing.small
            Item { Layout.fillWidth: true }
            LogosCheckbox {
                id: forgetAck
                objectName: "strandedConfirm_" + node.nodeId
                text: "I want this deleted"
            }
            LogosButton {
                objectName: "strandedForget_" + node.nodeId
                text: "Delete this derivation key"
                enabled: node.deleteKeyEnabled && forgetAck.checked
                onClicked: { forgetAck.checked = false; node.forgetKeyRequested() }
            }
        }

        LogosText {
            objectName: "nodeUnread_" + node.nodeId
            Layout.fillWidth: true
            visible: node.unreadLine.length > 0
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.warning
            text: node.unreadLine
        }

        LogosText {
            objectName: "nodeEmpty_" + node.nodeId
            Layout.fillWidth: true
            visible: node.expanded && node.emptyLine.length > 0 && node.addresses.length === 0 && !node.bitcoinGroup
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            text: node.emptyLine
        }

        ColumnLayout {
            visible: node.expanded && node.bitcoinGroup !== null
            Layout.fillWidth: true
            Layout.leftMargin: Theme.spacing.large + Theme.spacing.xlarge
            spacing: Theme.spacing.tiny
            LogosText {
                objectName: "bitcoinPath_" + node.nodeId
                textFormat: Text.PlainText
                color: Theme.palette.textSecondary
                text: "Derivation path: " + ((node.bitcoinGroup || {}).pathPrefix || "Not recorded")
            }
            RowLayout {
                readonly property var preview: (node.bitcoinGroup || {}).preview || ({})
                LogosText {
                    text: (node.bitcoinGroup || {}).chain === "test" ? "First receiving address (testnet/signet, 0/0):" : "First receiving address (0/0):"
                    color: Theme.palette.textSecondary
                }
                LogosCopyableText {
                    objectName: "bitcoinAddress_" + node.nodeId
                    visible: !!parent.preview.address
                    text: node.view.shortAddr(parent.preview.address)
                    copyText: parent.preview.address || ""
                }
                LogosText {
                    visible: !parent.preview.address
                    text: "Address unavailable"
                    color: Theme.palette.textSecondary
                }
            }
        }

        Repeater {
            model: node.expanded ? node.addresses : []
            delegate: RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacing.large + Theme.spacing.xlarge
                spacing: Theme.spacing.small

                readonly property var badge: node.view.badgeFor(modelData, node.prefix)
                // Empty unless this badge abbreviates a path. It is what decides whether the
                // badge is hoverable at all, so a badge with nothing to complete says nothing.
                readonly property string pathTip: node.view.pathTipFor(modelData, node.prefix)
                readonly property string ordinal: node.view.ordinalFor(modelData, node.prefix)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.tiny
                    LogosText {
                        objectName: "accountName_" + modelData
                        visible: text.length > 0
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        text: node.view.labelFor(modelData)
                    }
                    LogosText {
                        objectName: "path_" + modelData
                        textFormat: Text.PlainText
                        color: Theme.palette.textSecondary
                        text: "Derivation path: " + (node.view.hdPath((node.view.provFor(modelData) || {}).path) || "Not recorded")
                    }
                    RowLayout {
                        LogosText { text: "Address:"; color: Theme.palette.textSecondary }
                        LogosCopyableText {
                            objectName: "account_" + modelData
                            text: node.view.shortAddr(modelData)
                            copyText: modelData
                        }
                    }
                    LogosBadge {
                        objectName: "provenance_" + modelData
                        visible: badge.kind === "imported"
                        text: badge.text
                        color: node.view.badgeColor(badge.kind)
                    }
                }
                Item { Layout.fillWidth: true }
                LogosButton {
                    objectName: "manage_" + modelData
                    text: "Manage"
                    enabled: node.view.custodian
                    onClicked: node.manageAccountRequested(modelData)
                }
            }
        }
    }
}
