// SPDX-License-Identifier: Apache-2.0
//
// Tiny diagnostics surface for FRB health checks and version display.
// Kept as a tiny diagnostics surface for bridge health checks and version display.

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
