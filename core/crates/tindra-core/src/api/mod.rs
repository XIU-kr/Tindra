// SPDX-License-Identifier: Apache-2.0
//
// Public Dart-facing API.
// flutter_rust_bridge codegen walks the entire `api/` tree, so each submodule
// here corresponds to a domain area of the bridge surface. Keep modules small
// and focused — one per coherent capability.
//
// As Phase 1+ lands, expect additional modules:
//   sessions.rs   open/write/read SSH sessions
//   profiles.rs   profile CRUD
//   sftp.rs       SFTP operations and transfer queue
//   sync.rs       pair, push, pull, conflicts
//   mcp.rs        list/call MCP tools
//   ai.rs         run AI prompt against shell context
//   plugins.rs    plugin install/grant/invoke
//
// For Phase 0 we only ship a smoke test:

pub mod hello;
