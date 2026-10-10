//! The app half of the keys app's end-to-end proof.
//!
//!   1. name the keystore's and the manager's roles (ungated)
//!   2. import a regtest Bitcoin wallet           (the keystore's custodian, for this run)
//!   3. request_open for any native segwit wallet on regtest, and wait
//!   4. request_unlock for that wallet, two signatures, each confirmed, and wait
//!
//! The person decides 3 and 4 in the keys app; this module only asks, and prints what it was
//! handed with its receipt. It runs on its own thread, so the first outbound call cannot
//! re-enter the host while this module is still initialising.

use serde_json::{json, Value};
use std::time::Duration;

type Shared = std::sync::Arc<std::sync::Mutex<Value>>;

/// Foundry's published test phrase: never fund it.
const PHRASE: &str = "test test test test test test test test test test test junk";
const VAULT_PASSWORD: &str = "doctest-pw";
const MARK: &str = "KEYS_PROBE";

/// The keystore: the keys app administers it, this fixture imports the wallet, and only the
/// manager may have it sign. The manager: the keys app decides open and unlock requests.
const KEYSTORE_ROLES: &str =
    r#"{"custodians":["evm_keystore_ui","keys_probe"],"managers":"signer_manager_module"}"#;
const MANAGER_ROLES: &str =
    r#"{"approvers":"evm_signer_ui","custodians":"evm_keystore_ui","signers":"keystore_module"}"#;

pub trait KeysProbeModule: Send + 'static {
    /// What the probe has got so far: `{ ok, state, … }`. Ungated: a fixture holding nothing secret.
    fn status(&mut self) -> String;
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
fn ask_and_wait(what: &str, reply: Result<String, String>) -> Result<Value, String> {
    let v = ok_value(reply)?;
    let (handle, receipt) = (text(&v, "handle"), text(&v, "receipt"));
    println!("{MARK}_{what}_REQUESTED: {handle}");
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

    let import = json!({ "phrase": PHRASE, "family": "bitcoin", "chain": "test",
                         "password": VAULT_PASSWORD, "label": "Regtest wallet" });
    let group = match ok_value(modules().keystore_module.import_bitcoin(&import.to_string())) {
        Ok(v) => text(&v, "group"),
        Err(e) => {
            println!("{MARK}_ERROR: import failed: {e}");
            set!(json!({ "ok": false, "state": "import_failed", "error": e }));
            return;
        }
    };
    println!("{MARK}_WALLET: {group}");

    let open = json!({ "family": "bitcoin", "network": "regtest", "reason": "Doc-test: open the regtest wallet" });
    match ask_and_wait("OPEN", modules().signer_manager_module.request_open(&open.to_string()).map_err(|e| format!("{e:?}"))) {
        Ok(v) => {
            let key_len = text(&v, "databaseKey").len();
            println!("{MARK}_OPENED: {} databaseKey={key_len} hex chars", text(&v, "external"));
            set!(json!({ "ok": true, "state": "opened", "group": text(&v, "group") }));
        }
        Err(e) => {
            println!("{MARK}_ERROR: open: {e}");
            set!(json!({ "ok": false, "state": "open_failed", "error": e }));
            return;
        }
    }

    let unlock = json!({ "account": group, "count": 2, "confirm": true, "apps": ["keys_probe"],
                         "reason": "Doc-test: two signatures" });
    match ask_and_wait("UNLOCK", modules().signer_manager_module.request_unlock(&unlock.to_string()).map_err(|e| format!("{e:?}"))) {
        Ok(v) => {
            println!("{MARK}_UNLOCKED: {}", v.get("terms").cloned().unwrap_or(Value::Null));
            set!(json!({ "ok": true, "state": "unlocked" }));
        }
        Err(e) => {
            println!("{MARK}_ERROR: unlock: {e}");
            set!(json!({ "ok": false, "state": "unlock_failed", "error": e }));
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
}

#[no_mangle]
pub extern "Rust" fn logos_module_install() {
    install::<KeysProbeModuleImpl>();
}
