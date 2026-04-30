// SPDX-License-Identifier: Apache-2.0
//
// tindra-plug — WASM plugin host.
// Loads plugin components defined by the WIT interface in `plugins/sdk/`.
// Permissions: explicit grants per plugin (terminal:read, terminal:write,
// network:host=*.example.com, profiles:read). Default deny.
//
// Compile-time gate: `plugins` feature.
//   - On  (default on Android, desktop): full wasmtime-backed host.
//   - Off (iOS): API surface intact, every operation returns `Error::Unsupported`
//     so callers can present a consistent UX without per-platform branches.

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("plugin host not available on this build")]
    Unsupported,
    #[error("plugin error: {0}")]
    Other(String),
}

pub const PLUGINS_ENABLED: bool = cfg!(feature = "plugins");
