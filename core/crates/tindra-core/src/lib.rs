// SPDX-License-Identifier: Apache-2.0
//
// tindra-core — public FFI surface.
// This crate re-exports the high-level types that flutter_rust_bridge
// codegens to Dart. It is the only crate the bridge sees.

pub mod api;

pub use tindra_ssh as ssh;
pub use tindra_pty as pty;
pub use tindra_sftp as sftp;
pub use tindra_term as term;
pub use tindra_store as store;
pub use tindra_sync as sync;
pub use tindra_mcp as mcp;
pub use tindra_ai as ai;
pub use tindra_plug as plug;

#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("not yet implemented: {0}")]
    Unimplemented(&'static str),
}

pub fn version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}
