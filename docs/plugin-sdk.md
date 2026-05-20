# Plugin SDK

The plugin SDK is a product boundary, not part of the current desktop completion path. The repository keeps the `tindra-plug` crate so the core layout remains stable while terminal, SFTP, forwarding, storage, and packaging work continue.

## Goals

- Plugins should not crash or block the host process.
- Plugins should not read terminal output unless granted.
- Plugins should be language-agnostic once the runtime is introduced.
- Distribution should use a signed manifest plus a plugin artifact.

## Capability Model

The intended model is default-deny:

- `terminal:read`
- `terminal:write`
- `profiles:read`
- `profiles:write`
- `network:host=<pattern>`
- `filesystem:path=<path>`

Capability prompts must include the plugin name, publisher identity, requested operation, and persistence scope.

## Current Repository Boundary

`core/crates/tindra-plug` intentionally exposes a small placeholder API while the runtime is absent. It should remain isolated from the desktop terminal/SFTP/session code until a real WASM component host and permission UI are introduced.
