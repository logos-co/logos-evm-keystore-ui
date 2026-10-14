import QtQuick
import QtQuick.Controls

// keys_probe's face. The probe asks the signer manager; this sends the person to the keys app
// with each request's handle, through Basecamp's intent, the way a wallet app does.
Item {
    id: root
    objectName: "keysProbeRoot"
    property string asked: ""
    property string answer: ""
    property bool polling: false

    function poll() {
        if (root.polling) return
        root.polling = true
        logos.callModuleAsync("keys_probe", "status", [], function (payload) {
            root.polling = false
            var s = null
            try { s = JSON.parse(payload); if (typeof s === "string") s = JSON.parse(s) } catch (e) { return }
            if (!s || s.state !== "asking" || !s.handle || s.handle === root.asked) return
            root.asked = s.handle
            root.answer = ""
            logos.request("keystore.accounts.open", ({ handle: s.handle }), function (res) {
                root.answer = res.ok ? "ok" : String(res.error)
            })
        }, 5000)
    }
    Timer { interval: 500; running: true; repeat: true; onTriggered: root.poll() }

    Column {
        anchors.centerIn: parent
        spacing: 12
        Text {
            text: root.asked === "" ? "keys_probe has not asked yet."
                                    : "keys_probe asked the keys app to decide " + root.asked + "."
        }
        // A wallet the person makes in the keys app, from this app's request.
        Button {
            objectName: "askNewWallet"
            text: "Ask for a new wallet"
            onClicked: logos.callModuleAsync("keys_probe", "ask_new_wallet", [], function () {}, 5000)
        }
    }
}
