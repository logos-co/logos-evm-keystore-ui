import QtQuick 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// Keeping a wallet's recovery phrase: off unless asked, with what it risks said before the
// password for it is asked. One place for the words, whichever kind of wallet is being made.
ColumnLayout {
    id: keep

    // Each sheet names its own, so a test finds the one on screen.
    property string namePrefix: "keep"
    readonly property bool checked: box.checked
    readonly property string password: box.checked ? pw.text : ""
    readonly property bool complete: !box.checked || pw.text.length > 0

    function reset() { box.checked = false; pw.text = "" }

    spacing: Theme.spacing.small

    LogosCheckbox {
        id: box
        objectName: keep.namePrefix + "KeepPhrase"
        text: "Keep the recovery phrase"
    }
    LogosText {
        objectName: keep.namePrefix + "KeepRisk"
        visible: box.checked
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Theme.palette.warning
        text: "You can see the phrase again and add wallets without typing it. Someone with a copy of "
              + "this keystore and this password gets every account of every coin this phrase makes, "
              + "including ones never created here. Keep it only if you would keep the paper copy on "
              + "this computer too."
    }
    LogosTextField {
        id: pw
        objectName: keep.namePrefix + "KeepPasswordField"
        visible: box.checked
        Layout.fillWidth: true
        echoMode: TextInput.Password
        placeholderText: "A password for the kept phrase"
    }
}
