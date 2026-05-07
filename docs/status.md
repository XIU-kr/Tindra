# Tindra implementation status

Last updated: 2026-05-07

## Current state

The repository is beyond the original Phase 0 bootstrap. The desktop app has a working Rust + Flutter bridge and an early desktop SSH client implementation.

## Implemented

- Rust workspace builds and tests successfully.
- Flutter desktop app uses `apps/desktop/rust` as the current `flutter_rust_bridge` shim into `tindra-core`.
- SSH private-key auth and SSH-agent auth.
- Trust-on-first-use host-key verification with fingerprint persistence and changed-key rejection.
- Interactive SSH shell sessions with PTY resize.
- Local shell tabs backed by portable-pty (Windows ConPTY/winpty, POSIX PTY elsewhere), with Windows default PowerShell and UTF-8-friendly Korean output handling.
- Single-hop jump host via `direct-tcpip`.
- Local port forwarding (`-L`).
- Raw TCP/Telnet-style sessions.
- SFTP browser primitives: open, list, upload, download, mkdir, remove, close, home directory.
- VT100 terminal snapshots with per-cell color/attributes and cursor state.
- Desktop UI for profiles, tabs, splits, settings, trusted host-key management, SFTP, port forwards, quake hotkey, copy-screen, paste, reconnect, Korean-capable terminal font fallback, initial localization framework with English/Korean resources, refreshed glass/gradient visual design, and custom Tindra app icon.
- JSON-backed local profile/settings store.
- ZMODEM ZRQINIT detection hook.

## Known gaps before Desktop MVP quality

1. Explicit first-connect host-key approval prompts. Backend TOFU persistence and trusted-key inspection/removal UI are implemented.
2. Password authentication and keyboard-interactive auth.
3. Local shell polish: configurable shell command/profiles, startup directory, environment editor, and graceful process termination.
4. Terminal selection, scrollback, search, mouse reporting, bracketed paste, and IME behavior. Basic copy-screen/paste shortcuts are implemented.
5. Better error surfaces and reconnect flow.
6. SFTP transfer queue with progress, cancellation, resume, and large-file streaming.
7. Remote/SOCKS port forwarding.
8. Keychain/DPAPI/libsecret storage for secrets.
9. FFI layout cleanup: long-term docs say `tindra-core` is the only bridge surface, but the desktop app currently uses `apps/desktop/rust` as the practical bridge crate.
10. CI/analyzer hygiene for generated/vendored code.

## Immediate maintenance notes

- `flutter analyze` should exclude vendored Cargokit tooling under `apps/desktop/rust_builder/cargokit/**` because it has its own pubspec and dependency graph.
- Default Flutter counter test was replaced with a Tindra settings smoke test.
- `tindra-core` allows the `frb_expand` cfg emitted by `flutter_rust_bridge` macros.
