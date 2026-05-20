// SPDX-License-Identifier: Apache-2.0
//
// Public Dart-facing API.
// flutter_rust_bridge codegen walks the entire `api/` tree, so each submodule
// here corresponds to a domain area of the bridge surface. Keep modules small
// and focused — one per coherent capability.
//
// The active desktop FRB shim lives in apps/desktop/rust. This shared facade
// stays intentionally small until common cross-client APIs are promoted here.

pub mod hello;
