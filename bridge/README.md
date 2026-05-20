# bridge/

This directory keeps the legacy/shared `flutter_rust_bridge` configuration for the reusable `tindra-core` facade.

The active desktop application currently uses `apps/desktop/rust` as its Flutter Rust Bridge shim and delegates reusable behavior to `tindra-core` and the lower-level core crates. When adding desktop-facing APIs, edit `apps/desktop/rust/src/api/*.rs` and regenerate from `apps/desktop`.

## Desktop Workflow

```powershell
cd apps\desktop
flutter_rust_bridge_codegen generate
```

Generated bindings are committed under:

- `apps/desktop/lib/src/rust/`
- `apps/desktop/rust/src/frb_generated.rs`

## Shared-Core Config

`bridge/flutter_rust_bridge.yaml` remains as a reference config for exposing `core/crates/tindra-core/src/api/**/*.rs` directly to shared UI code later. It is not the current desktop app's primary bridge path.
