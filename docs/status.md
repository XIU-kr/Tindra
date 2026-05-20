# Tindra implementation status

Last updated: 2026-05-20

## Current state

The Windows desktop app uses `apps/desktop/rust` as the Flutter Rust Bridge shim and delegates reusable behavior to `tindra-core` and the lower-level core crates.

## Implemented

- Rust workspace builds and tests successfully.
- Flutter desktop app uses `apps/desktop/rust` as the current `flutter_rust_bridge` shim into `tindra-core`.
- SSH private-key auth and SSH-agent auth.
- Trust-on-first-use host-key verification with fingerprint persistence and changed-key rejection.
- Interactive SSH shell sessions with PTY resize.
- Local shell tabs backed by portable-pty (Windows ConPTY/winpty, POSIX PTY elsewhere), with Windows default PowerShell, configurable startup command/directory/environment, explicit process termination, and UTF-8-friendly Korean output handling.
- Single-hop jump host via `direct-tcpip`.
- Local port forwarding (`-L`), remote port forwarding (`-R`), and SOCKS5 dynamic forwarding (`-D`).
- Raw TCP/Telnet-style sessions.
- SFTP browser primitives: open, list, upload, download, mkdir, remove, close, home directory, streaming progress, retry, overwrite confirmation, bounded concurrent scheduling, hard cancel signaling, and resumed downloads on retry.
- VT100 terminal snapshots with per-cell color/attributes and cursor state.
- Desktop UI for profiles, tabs, splits, settings, trusted host-key management, SFTP, port forwards, terminal scrollback, quake hotkey, copy-screen, paste, reconnect, Korean-capable terminal font fallback, initial localization framework with English/Korean resources, refreshed glass/gradient visual design, and custom Tindra app icon.
- JSON-backed local profile/settings store.
- OS-backed secret storage: Windows DPAPI local encrypted records, macOS/iOS Keychain, and Linux libsecret.
- ZMODEM ZRQINIT detection hook.

## Platform validation

- Selection copy, snapshot search, scrollback UI, bracketed paste, basic mouse reporting, and Korean-capable terminal font fallback are implemented in the desktop terminal path.
- Session and SFTP errors are surfaced in the UI with reconnect/retry actions where the underlying transport can recover.
- macOS/iOS Keychain and Linux libsecret adapters are implemented in the Rust store layer. Android reports the `android-keystore` backend identifier until the Android runner bridge is generated.
- macOS, Linux, Android, and iOS runner generation is intentionally gated behind the platform-scaffold checklist in `apps/mobile/README.md` and `apps/README.md` so the current Windows runner and FRB/Cargokit setup are not overwritten.

## Immediate maintenance notes

- `flutter analyze` excludes vendored Cargokit tooling under `apps/desktop/rust_builder/cargokit/**` because it has its own pubspec and dependency graph.
- Default Flutter counter test was replaced with a Tindra settings smoke test.
- `tindra-core` allows the `frb_expand` cfg emitted by `flutter_rust_bridge` macros.
