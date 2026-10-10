import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

// An unlock's terms, in one place so an app's request and the person's own unlock read alike.
// The person decides every one of them, whatever an app asked for, and what each choice risks
// is said next to it before it is made.
ColumnLayout {
    id: terms

    // Prefill from what an app asked: `{ ttlMs?, count?, apps?, confirm? }`.
    function load(asked) {
        var t = asked || {}
        // An app may ask for terms off these choices: offer them as asked, chosen until changed.
        askedTtl = (t.ttlMs === undefined || t.ttlMs === null || t.ttlMs === 900000 || t.ttlMs === 3600000)
                   ? null : t.ttlMs
        askedCount = (t.count === undefined || t.count === null || t.count === 1 || t.count === 10)
                     ? null : t.count
        ttlGroup.checkedButton = askedTtl !== null ? ttlAsked
                                 : t.ttlMs === 900000 ? ttlShort : t.ttlMs === 3600000 ? ttlHour
                                 : t.ttlMs === undefined && t.count === undefined ? ttlShort : ttlUntilLocked
        countGroup.checkedButton = askedCount !== null ? countAsked
                                   : t.count === 1 || t.count === undefined ? countOne
                                   : t.count === 10 ? countTen : countAny
        (t.confirm === false ? withoutAsking : confirmEach).checked = true
        appsField.text = (t.apps || []).join(", ")
    }
    property var askedTtl: null
    property var askedCount: null

    function defaultApps(name) {
        if (appsField.text.trim() === "") appsField.text = name
    }

    readonly property var ttlMs: ttlShort.checked ? 900000 : ttlHour.checked ? 3600000
                                 : ttlAsked.checked ? askedTtl : null
    readonly property var count: countOne.checked ? 1 : countTen.checked ? 10
                                 : countAsked.checked ? askedCount : null
    readonly property var apps: appsField.text.split(",").map(function (a) { return a.trim() })
                                                .filter(function (a) { return a.length > 0 })
    readonly property bool anyApp: apps.indexOf("*") !== -1
    // "Any app" without confirmation would let every module sign; the manager refuses it too.
    readonly property bool complete: apps.length > 0 && !(anyApp && withoutAsking.checked)
    readonly property var value: ({ ttlMs: terms.ttlMs, count: terms.count, apps: terms.apps,
                                    confirm: confirmEach.checked })

    readonly property string untilWords: ttlShort.checked ? "For the next 15 minutes"
                                         : ttlHour.checked ? "For the next hour"
                                         : ttlAsked.checked ? "For the next " + Math.round(askedTtl / 60000) + " minutes"
                                         : "Until you lock it"
    readonly property string countWords: countOne.checked ? "one signature"
                                         : countTen.checked ? "up to ten signatures"
                                         : countAsked.checked ? "up to " + askedCount + " signatures"
                                         : "any number of signatures"
    readonly property string appWords: anyApp ? "any app" : apps.join(", ")

    spacing: Theme.spacing.tiny

    LogosText { text: "How long"; color: Theme.palette.textSecondary }
    ButtonGroup { id: ttlGroup }
    RowLayout {
        LogosRadioButton { id: ttlShort; objectName: "unlockTtlShort"; ButtonGroup.group: ttlGroup; text: "15 minutes"; checked: true }
        LogosRadioButton { id: ttlHour; objectName: "unlockTtlHour"; ButtonGroup.group: ttlGroup; text: "An hour" }
        LogosRadioButton { id: ttlUntilLocked; objectName: "unlockTtlUntilLocked"; ButtonGroup.group: ttlGroup; text: "Until I lock it" }
        LogosRadioButton {
            id: ttlAsked
            objectName: "unlockTtlAsked"
            ButtonGroup.group: ttlGroup
            visible: terms.askedTtl !== null
            text: "As asked: " + Math.round((terms.askedTtl || 0) / 60000) + " minutes"
        }
    }

    LogosText { text: "How many signatures"; color: Theme.palette.textSecondary }
    ButtonGroup { id: countGroup }
    RowLayout {
        LogosRadioButton { id: countOne; objectName: "unlockCountOne"; ButtonGroup.group: countGroup; text: "One"; checked: true }
        LogosRadioButton { id: countTen; objectName: "unlockCountTen"; ButtonGroup.group: countGroup; text: "Up to ten" }
        LogosRadioButton { id: countAny; objectName: "unlockCountAny"; ButtonGroup.group: countGroup; text: "No limit" }
        LogosRadioButton {
            id: countAsked
            objectName: "unlockCountAsked"
            ButtonGroup.group: countGroup
            visible: terms.askedCount !== null
            text: "As asked: " + terms.askedCount
        }
    }

    LogosText { text: "Apps it covers"; color: Theme.palette.textSecondary }
    LogosTextField {
        id: appsField
        objectName: "unlockAppsField"
        Layout.fillWidth: true
        placeholderText: "Module names, separated by commas — * for any app"
    }

    ButtonGroup { id: confirmGroup }
    LogosRadioButton {
        id: confirmEach
        objectName: "unlockConfirmEach"
        ButtonGroup.group: confirmGroup
        checked: true
        text: "Confirm each signature, no password"
    }
    LogosText {
        objectName: "unlockConfirmRisk"
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacing.xlarge
        visible: confirmEach.checked
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.palette.textSecondary
        text: terms.untilWords + ", " + (terms.appWords || "these apps") + " can have "
              + terms.countWords + ", each confirmed by you with no password. Anyone at this "
              + "computer could confirm them."
    }
    LogosRadioButton {
        id: withoutAsking
        objectName: "unlockWithoutAsking"
        ButtonGroup.group: confirmGroup
        enabled: !terms.anyApp
        text: "Sign without asking"
    }
    LogosText {
        objectName: "unlockWithoutAskingRisk"
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacing.xlarge
        visible: withoutAsking.checked
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.palette.warning
        text: terms.untilWords + ", " + (terms.appWords || "these apps") + " can have "
              + terms.countWords + " made without showing them to you. Choose it only for apps "
              + "you would trust with this account's funds."
    }
}
