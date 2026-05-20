# Tindra

Modern cross-platform SSH client. Tindra is built with a Rust core and Flutter UI, with a desktop-first implementation and documented mobile/macOS preparation paths.

> **Status:** Desktop implementation is active and usable on Windows. The current app includes SSH shell sessions, explicit host-key approval, profile/settings storage, SFTP browsing and transfers, port forwarding, terminal search/scrollback, diagnostics, and Windows packaging verification. Android/macOS/iOS runners are prepared by scaffold checklists rather than generated in this tree yet.

## Why Tindra?

- **Desktop-first**, with Android and iOS planned as mobile companions.
- **One codebase** across platforms: Rust core plus Flutter UI.
- **Open source**: Apache-2.0 client, with AGPL-3.0 reserved for a future hosted sync backend.
- **Modern essentials**: terminal tabs/splits, visual SFTP, jump hosts, host-key verification, and port-forwarding UI.
- **Local-first storage**: JSON profile/settings storage, trusted host-key persistence, and OS-backed secret storage.
- **AI/MCP and plugins**: crate boundaries and design documents are present for later product surfaces.

## Repository Layout

```text
apps/
  desktop/        Flutter desktop app and current Windows runner
  mobile/         Mobile scaffold notes and platform boundary docs
  shared_ui/      Platform-neutral UI/workflow models
core/             Rust workspace
  crates/
    tindra-core   Shared Rust facade
    tindra-ssh    SSH transport, shell sessions, forwarding, Telnet/raw TCP
    tindra-pty    Local PTY abstraction
    tindra-sftp   SFTP operations and progress hooks
    tindra-term   Terminal parsing helpers
    tindra-store  Profiles, settings, host keys, and OS-backed secrets
    tindra-sync   Sync boundary crate
    tindra-mcp    MCP boundary crate
    tindra-ai     AI boundary crate
    tindra-plug   Plugin boundary crate
bridge/           Legacy/shared FRB config notes
scripts/          Build and setup helpers
docs/             Architecture, packaging, security, and execution notes
```

## Building

- **Windows quickstart**: [`scripts/SETUP-WINDOWS.md`](scripts/SETUP-WINDOWS.md)
- **Full multi-platform setup**: [`scripts/SETUP.md`](scripts/SETUP.md)

TL;DR you need Rust stable, Flutter stable, and the platform C++ toolchain. Android NDK and Xcode are only needed when targeting those platforms.

```powershell
cd core
cargo check

cd ..\apps\desktop
flutter analyze
flutter test
flutter build windows
```

Current local verification uses `cargo check`, `flutter analyze`, `flutter test`, and `flutter build windows`.

## License

- Current client code is licensed under **Apache-2.0**. See [`LICENSE-APACHE`](LICENSE-APACHE).
- A future hosted sync backend may use **AGPL-3.0**. See [`LICENSE-AGPL`](LICENSE-AGPL).

By contributing you agree to license your contributions under the same terms. See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Status

Current implementation status is tracked in [`docs/status.md`](docs/status.md).
