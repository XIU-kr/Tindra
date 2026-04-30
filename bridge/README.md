# bridge/

This directory holds the [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) codegen configuration that wires `tindra-core` (Rust) to the Flutter apps in `apps/`.

## Workflow

1. Edit the API surface in `core/crates/tindra-core/src/api/*.rs` (annotate types/functions with `#[frb(...)]` as needed).
2. Run codegen:

   ```bash
   cd bridge
   flutter_rust_bridge_codegen generate
   ```

3. Generated Dart lands in `apps/shared_ui/lib/src/bridge/` and is consumed by the Flutter apps.

## Why a separate `bridge/` directory?

- Keeps codegen config and scripts out of both the Rust workspace and the Flutter apps.
- Scripts that wrap `flutter_rust_bridge_codegen` (e.g. CI invocations) live here.
- Generated Dart is committed to `apps/shared_ui/` (the consumer), not here, so flutter pub get works without codegen.

## Phase 0 status

The `core/crates/tindra-core/src/api/` directory is empty. The first task in Phase 0 is to add a `hello.rs` module with a single `pub async fn echo(s: String) -> String` and verify codegen + Flutter consumption end-to-end.
