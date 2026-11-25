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

    onOpened: { words = ""; pw.text = ""; sheetError.clear() }
    onClosed: { words = ""; pw.text = ""; sheetError.clear() }

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
                    ? "No account file here was made from it any more. It is still kept until you forget it."
                    : "Used by " + sheet.kept.groups.length + " account file(s) here."
        }
        LogosText {
            objectName: "phraseShowRisk"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.palette.textSecondary
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
        // The words as a numbered table, the same one Create shows them in.
        GridLayout {
            objectName: "phraseWords"
            visible: sheet.words.length > 0
            Layout.fillWidth: true
            columns: width < 380 ? 1 : 2
            columnSpacing: Theme.spacing.small
            rowSpacing: Theme.spacing.small
            Repeater {
                model: sheet.words ? sheet.words.split(" ") : []
                delegate: Frame {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    padding: 6
                    background: Rectangle { radius: 6; color: Theme.palette.backgroundMuted }
                    contentItem: RowLayout {
                        spacing: Theme.spacing.small
                        LogosText { text: (index + 1) + "."; Layout.preferredWidth: 26; color: Theme.palette.textSecondary }
                        LogosText { Layout.fillWidth: true; text: modelData; textFormat: Text.PlainText }
                    }
                }
            }
        }

        SheetError { id: sheetError; objectName: "phraseError" }
        RowLayout {
            Layout.fillWidth: true
            LogosButton {
                objectName: "phraseForgetButton"
                text: "Forget phrase"
                onClicked: {
                    sheetError.clear()
                    logos.watch(sheet.backend.forgetPhrase(sheet.kept.id),
                                function (good) { if (good) sheet.close(); else sheetError.take(sheet.backend, "The phrase is still kept.") },
                                function () { sheetError.lost() })
                }
            }
            Item { Layout.fillWidth: true }
            LogosButton { objectName: "phraseCloseButton"; text: "Close"; onClicked: sheet.close() }
            LogosButton {
                objectName: "phraseShowButton"
                visible: sheet.words.length === 0
                enabled: pw.text.length > 0
                text: "Show"
                onClicked: {
                    sheetError.clear()
                    logos.watch(sheet.backend.showPhrase(sheet.kept.id, pw.text),
                                function (w) {
                                    sheet.words = w || ""
                                    if (!w) sheetError.take(sheet.backend, "The phrase was not shown.")
                                }, function () { sheetError.lost() })
                    pw.text = ""
                }
            }
        }
    }
}
