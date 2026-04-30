# Tindra

Modern cross-platform SSH client. A spiritual successor to Tabby (formerly Terminus) that also runs on Android and iOS, with end-to-end encrypted device sync, AI/MCP integration, and a WASM plugin SDK.

> **Status:** Early development. Phase 0 — bootstrapping. Not yet usable.

## Why Tindra?

Tabby is excellent on the desktop but doesn't run on mobile. Termius covers mobile but is closed-source. Tindra aims for the best of both:

- **Desktop-first**, with Android and iOS as first-class mobile companions.
- **One codebase** across platforms — Rust core + Flutter UI.
- **Open source** — Apache-2.0 client, AGPL-3.0 sync backend.
- **Modern essentials** — GPU-accelerated terminal, visual SFTP, jump-host topology, port-forwarding UI.
- **Optional cloud** — E2E-encrypted profile/key/snippet sync (paid plan); offline-only and BYO-cloud (iCloud/Drive folder) modes are always free.
- **AI-native** — built-in AI assist with shell context and a [Model Context Protocol](https://modelcontextprotocol.io/) server/client.
- **Plugins** — sandboxed WebAssembly plugin SDK with explicit permission grants.

## Repository layout

```
apps/
  desktop/        Flutter app for macOS / Windows / Linux
  mobile/         Flutter app for Android + iOS
  shared_ui/      Shared widgets, themes, terminal renderer
core/             Rust workspace
  crates/
    tindra-core   Public FFI surface
    tindra-ssh    SSH transport (russh)
    tindra-pty    PTY abstraction (portable-pty)
    tindra-sftp   SFTP (russh-sftp)
    tindra-term   VT parser + grid (alacritty_terminal)
    tindra-store  Encrypted profile store (SQLCipher + age)
    tindra-sync   E2E sync engine (CRDT + age)
    tindra-mcp    Model Context Protocol server/client
    tindra-ai     LLM provider abstraction (BYOK)
    tindra-plug   Plugin host (wasmtime + WIT)
bridge/           flutter_rust_bridge codegen
plugins/
  sdk/            Plugin SDK (WIT definitions, host ABI)
  examples/       Sample plugins
scripts/          Build/codegen helpers, toolchain setup
docs/             Architecture, security model, plugin SDK
```

## Building

- **Windows-only quickstart** (skip Android/iOS/Linux/macOS): [`scripts/SETUP-WINDOWS.md`](scripts/SETUP-WINDOWS.md)
- **Full multi-platform setup**: [`scripts/SETUP.md`](scripts/SETUP.md)

TL;DR you need Rust (stable), Flutter (stable), and a C++ toolchain. Android NDK and Xcode only when targeting those platforms.

```bash
# After installing toolchains
cd core && cargo build           # Rust core
cd ../apps/desktop && flutter build  # Flutter desktop
```

End-to-end build verification (5-platform matrix) runs in CI.

## License

- Everything currently in this repository is licensed under **Apache-2.0** — see [`LICENSE-APACHE`](LICENSE-APACHE).
- The forthcoming sync backend (planned for `core/crates/tindra-sync-server/` or a separate repository) will be licensed under **AGPL-3.0** to prevent SaaS forks. The canonical license text will be added when that code lands. See [`LICENSE-AGPL`](LICENSE-AGPL) for the placeholder.

By contributing you agree to license your contributions under the same terms (see [`CONTRIBUTING.md`](CONTRIBUTING.md)).

## Roadmap

See [`docs/architecture.md`](docs/architecture.md) for the phased roadmap.
