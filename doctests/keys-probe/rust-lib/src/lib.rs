//! keys_probe — the keys app doc-test's requester.
//!
//! An app that asks the signer manager to open a Bitcoin wallet for it, and then to unlock it.
//! The person decides both in the keys app; this only asks, and reports what it was handed.
#[cfg(feature = "logos_module")]
mod glue;
