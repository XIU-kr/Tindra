// SPDX-License-Identifier: Apache-2.0
//
// Phase 0 smoke test. Verifies the full Rust → flutter_rust_bridge → Dart
// round-trip works on every target platform before any real work is done.
//
// To remove once Phase 1 starts.

use flutter_rust_bridge::frb;

/// Returns a greeting from the Rust core. The frb codegen will produce a
/// matching `echo(msg: String) -> String` in Dart.
#[frb(sync)]
pub fn echo(msg: String) -> String {
    format!("Tindra core says: {msg}")
}

/// Reports the tindra-core crate version. Used by the desktop "About" dialog
/// and by CI to verify the loaded native library matches the source tree.
#[frb(sync)]
pub fn core_version() -> String {
    crate::version().to_string()
}
