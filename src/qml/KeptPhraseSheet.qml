import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// A kept recovery phrase: shown again with its own password, behind the warning, or forgotten.
// The words are held in this sheet only, and cleared on close.
LogosDialog {
    id: sheet
    objectName: "keptPhraseSheet"
    title: "Kept recovery phrase"

    property var backend: null
    // `{ id, groups, staged }`.
    property var kept: null
    property string words: ""

    onOpened: { words = ""; pw.text = "" }
    onClosed: { words = ""; pw.text = "" }

    anchors.centerIn: parent
    width: Math.min(parent.width - 40, 560)

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        LogosText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
            text: !sheet.kept ? ""
                  : (sheet.kept.groups || []).length === 0
                    ? "No wallet here was made from it any more. It is still kept until you forget it."
                    : "Used by " + sheet.kept.groups.length + " wallet(s) here."
        }
        LogosText {
            objectName: "phraseShowRisk"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.warning
            text: "Anyone who sees it owns every account it makes. Check that no camera or person can see your screen."
        }
        LogosTextField {
            id: pw
            objectName: "phrasePasswordField"
            visible: sheet.words.length === 0
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "The kept phrase's password"
            Component.onCompleted: textInput.passwordMaskDelay = 0
        }
        LogosText {
            objectName: "phraseWords"
            visible: sheet.words.length > 0
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: sheet.words
        }

        RowLayout {
            Layout.fillWidth: true
            LogosButton {
                objectName: "phraseForgetButton"
                text: "Forget phrase"
                onClicked: logos.watch(sheet.backend.forgetPhrase(sheet.kept.id),
                                       function (good) { if (good) sheet.close() })
            }
            Item { Layout.fillWidth: true }
            LogosButton { objectName: "phraseCloseButton"; text: "Close"; onClicked: sheet.close() }
            LogosButton {
                objectName: "phraseShowButton"
                visible: sheet.words.length === 0
                enabled: pw.text.length > 0
                text: "Show"
                onClicked: {
                    logos.watch(sheet.backend.showPhrase(sheet.kept.id, pw.text),
                                function (w) { sheet.words = w || "" })
                    pw.text = ""
                }
            }
        }
    }
}
