//! The app half of the keys app's end-to-end proof.
//!
//!   1. name the keystore's and the manager's roles (ungated)
//!   2. request_open for any native segwit wallet on regtest, and wait: the person adds one
//!   3. request_unlock for that wallet, two signatures, each confirmed: the keys app offers
//!      only Reject for it now, so the person refuses and this goes on
//!   4. request_open for the mock device's wallet, and wait
//!   5. when keys_probe_ui asks, request_open for a regtest taproot wallet: the person creates one
//!
//! The person decides 2 to 5 in the keys app, which keys_probe_ui sends them to; this module
//! only asks, and prints what it was handed with its receipt. It runs on its own thread, so the
//! first outbound call cannot re-enter the host while this module is still initialising.

use serde_json::{json, Value};
use std::time::Duration;

type Shared = std::sync::Arc<std::sync::Mutex<Value>>;

const MARK: &str = "KEYS_PROBE";

/// The keystore: the keys app administers it, and only the manager may have it sign. The
/// manager: the keys app decides open requests, and a mock device signs beside the keystore.
const KEYSTORE_ROLES: &str = r#"{"custodians":"evm_keystore_ui","managers":"signer_manager_module"}"#;
const MANAGER_ROLES: &str = r#"{"approvers":"evm_signer_ui","custodians":"evm_keystore_ui","signers":["keystore_module","mock_device_signer"]}"#;

pub trait KeysProbeModule: Send + 'static {
    /// What the probe has got so far: `{ ok, state, handle? }`. Ungated: a fixture holding nothing secret.
    fn status(&mut self) -> String;
    /// Ask to open a regtest taproot wallet, which the person creates; answers at once. Ungated.
    fn ask_new_wallet(&mut self) -> String;
    fn on_context_ready(&mut self, _ctx: &RustModuleContext) {}
}

include!(concat!(env!("CARGO_MANIFEST_DIR"), "/generated/provider_gen.rs"));

#[derive(Default)]
struct KeysProbeModuleImpl {
    state: Shared,
}

fn ok_value(reply: Result<String, impl std::fmt::Debug>) -> Result<Value, String> {
    let raw = reply.map_err(|e| format!("{e:?}"))?;
    let v: Value = serde_json::from_str(&raw).map_err(|e| e.to_string())?;
    if v.get("ok").and_then(Value::as_bool) == Some(true) {
        Ok(v)
    } else {
        Err(v.get("error").and_then(Value::as_str).unwrap_or("call failed").to_string())
    }
}

fn text(v: &Value, key: &str) -> String {
    v.get(key).and_then(Value::as_str).unwrap_or_default().to_string()
}

/// Ask, then wait for the person: the result collected with the receipt, or why there is none.
/// The pending handle goes in `status`, so keys_probe_ui can send the person to the keys app.
fn ask_and_wait(state: &Shared, what: &str, reply: Result<String, String>) -> Result<Value, String> {
    let v = ok_value(reply)?;
    let (handle, receipt) = (text(&v, "handle"), text(&v, "receipt"));
    println!("{MARK}_{what}_REQUESTED: {handle}");
    *state.lock().unwrap() = json!({ "ok": true, "state": "asking", "kind": what, "handle": handle });
    for _ in 0..1200 {
        std::thread::sleep(Duration::from_millis(250));
        let Ok(s) = ok_value(modules().signer_manager_module.approval_status(&handle, &receipt)) else { continue };
        if text(&s, "state") != "settled" {
            continue;
        }
        let reason = text(&s, "reason");
        if reason != "approved" {
            return Err(format!("settled without approval: {reason}"));
        }
        let got = ok_value(modules().signer_manager_module.fetch_result(&handle, &receipt))?;
        let _ = modules().signer_manager_module.ack_result(&handle, &receipt);
        return Ok(got.get("result").cloned().unwrap_or(Value::Null));
    }
    Err("nobody decided".into())
}

fn drive(state: Shared) {
    macro_rules! set { ($v:expr) => { *state.lock().unwrap() = $v; } }
    std::thread::sleep(Duration::from_millis(1500));

    let configured = ok_value(modules().keystore_module.configure(KEYSTORE_ROLES))
        .and_then(|_| ok_value(modules().signer_manager_module.configure(MANAGER_ROLES)));
    if let Err(e) = configured {
        println!("{MARK}_ERROR: configure failed: {e}");
        set!(json!({ "ok": false, "state": "configure_failed", "error": e }));
        return;
    }

    // No wallet exists yet: the person adds one from the request itself.
    let open = json!({ "family": "bitcoin", "network": "regtest", "reason": "Doc-test: open a regtest wallet" });
    let group = match ask_and_wait(&state, "OPEN", modules().signer_manager_module.request_open(&open.to_string()).map_err(|e| format!("{e:?}"))) {
        Ok(v) => {
            let key_len = text(&v, "databaseKey").len();
            println!("{MARK}_WALLET: {}", text(&v, "group"));
            println!("{MARK}_OPENED: {} databaseKey={key_len} hex chars", text(&v, "external"));
            println!("{MARK}_STARTS: origin={} birthday={}", text(&v, "origin"), text(&v, "birthday"));
            set!(json!({ "ok": true, "state": "opened", "group": text(&v, "group") }));
            text(&v, "group")
        }
        Err(e) => {
            println!("{MARK}_ERROR: open: {e}");
            set!(json!({ "ok": false, "state": "open_failed", "error": e }));
            return;
        }
    };

    let unlock = json!({ "account": group, "count": 2, "confirm": true, "apps": ["keys_probe"],
                         "reason": "Doc-test: two signatures" });
    match ask_and_wait(&state, "UNLOCK", modules().signer_manager_module.request_unlock(&unlock.to_string()).map_err(|e| format!("{e:?}"))) {
        Ok(v) => println!("{MARK}_UNLOCKED: {}", v.get("terms").cloned().unwrap_or(Value::Null)),
        Err(e) => println!("{MARK}_UNLOCK_REFUSED: {e}"),
    }

    // A wallet whose key is on the mock device: its first open sets the password of its data.
    let device = json!({ "group": "mock-segwit", "network": "regtest", "reason": "Doc-test: open the device's wallet" });
    match ask_and_wait(&state, "DEVICE_OPEN", modules().signer_manager_module.request_open(&device.to_string()).map_err(|e| format!("{e:?}"))) {
        Ok(v) => {
            println!(
                "{MARK}_DEVICE_OPENED: origin={} birthday={} databaseKey={} hex chars",
                text(&v, "origin"),
                text(&v, "birthday"),
                text(&v, "databaseKey").len()
            );
            set!(json!({ "ok": true, "state": "device_opened" }));
        }
        Err(e) => {
            println!("{MARK}_ERROR: device open: {e}");
            set!(json!({ "ok": false, "state": "device_open_failed", "error": e }));
            return;
        }
    }
}

/// A wallet made in the keys app: its history starts the day it was made.
fn new_wallet(state: Shared) {
    let ask = json!({ "family": "bitcoin_taproot", "network": "regtest", "reason": "Doc-test: open a new wallet" });
    match ask_and_wait(&state, "NEW_OPEN", modules().signer_manager_module.request_open(&ask.to_string()).map_err(|e| format!("{e:?}"))) {
        Ok(v) => {
            println!("{MARK}_NEW_STARTS: origin={} birthday={}", text(&v, "origin"), text(&v, "birthday"));
            *state.lock().unwrap() = json!({ "ok": true, "state": "new_opened" });
        }
        Err(e) => {
            println!("{MARK}_ERROR: new open: {e}");
            *state.lock().unwrap() = json!({ "ok": false, "state": "new_open_failed", "error": e });
        }
    }
}

impl KeysProbeModule for KeysProbeModuleImpl {
    fn on_context_ready(&mut self, _ctx: &RustModuleContext) {
        let state = std::sync::Arc::clone(&self.state);
        *state.lock().unwrap() = json!({ "ok": true, "state": "starting" });
        std::thread::spawn(move || drive(state));
    }

    fn status(&mut self) -> String {
        self.state.lock().unwrap().to_string()
    }

    fn ask_new_wallet(&mut self) -> String {
        let state = std::sync::Arc::clone(&self.state);
        std::thread::spawn(move || new_wallet(state));
        json!({ "ok": true }).to_string()
    }
}

#[no_mangle]
pub extern "Rust" fn logos_module_install() {
    install::<KeysProbeModuleImpl>();
}
