# Tindra Architecture

This document is the in-repo architectural reference for the current desktop implementation and the platform boundaries that will be reused by mobile and macOS/Linux runners.

## Goals

- One Rust core shared by desktop and future mobile clients.
- Flutter UI with desktop-first workflows: tabs, splits, terminal interaction, SFTP, forwarding, profiles, and settings.
- Local-first storage with explicit SSH host-key approval and no persisted interactive passwords.
- Platform-specific adapters isolated behind Rust/Flutter bridge APIs.

## Current Stack

```text
apps/
  desktop/      Flutter desktop app, Windows runner, and active FRB bindings
  mobile/       Android-first scaffold notes and platform boundary docs
  shared_ui/    Platform-neutral models for terminal policy, transfers, profiles, and sessions

core/crates/
  tindra-core   Shared facade and version/diagnostics surface
  tindra-ssh    SSH sessions, auth, jump hosts, local/remote/SOCKS forwarding, raw TCP
  tindra-pty    Local shell PTY support
  tindra-sftp   SFTP operations and progress-capable transfer helpers
  tindra-term   Terminal parsing helpers
  tindra-store  Profiles, settings, trusted host keys, and OS-backed secret APIs
  tindra-sync   Sync boundary crate
  tindra-mcp    MCP boundary crate
  tindra-ai     AI boundary crate
  tindra-plug   Plugin boundary crate
```

The active desktop bridge is `apps/desktop/rust`. It exposes the app-facing APIs to Dart and calls into `tindra-core` plus the lower-level crates.

## Platform Adapters

| Platform | Current boundary |
|---|---|
| Windows | Runner exists; ConPTY/winpty via `portable-pty`; DPAPI-backed secret records; Windows build verified. |
| macOS | Runner generation is gated by the checklist; Keychain secret adapter exists in the Rust store layer. |
| Linux | Runner generation is gated by the checklist; libsecret adapter exists in the Rust store layer. |
| Android | Scaffold is documented in `apps/mobile/README.md`; Android Keystore bridge is reserved for runner generation. |
| iOS | Scaffold is deferred; Keychain secret adapter exists in the Rust store layer. |

## Storage

- Profiles, settings, and trusted host-key fingerprints are JSON-backed under the platform data directory.
- SSH passwords, keyboard-interactive responses, and private-key passphrases are not stored in profile JSON.
- Secret APIs delegate to Windows DPAPI, macOS/iOS Keychain, or Linux libsecret where the platform target is available.

## Implemented Desktop Surface

- SSH private-key, agent, password, and keyboard-interactive auth.
- Explicit host-key preflight with `new`, `trusted`, and `changed` states.
- Interactive shell sessions with PTY resize, terminal search, scrollback, bracketed paste, selection-first copy, and basic mouse reporting.
- Local shell tabs.
- SFTP browser with upload/download, overwrite confirmation, retry, hard cancel signaling, bounded concurrent scheduling, streaming progress, and download resume on retry.
- Local, remote, and SOCKS5 forwarding.
- Settings diagnostics and Windows packaging verification.

## Roadmap Boundaries

The current repository keeps boundary crates for sync, MCP, AI, and plugins so public ownership lines remain stable. Those product surfaces should not be wired into the desktop UI until their security and permission models are implemented.

Current implementation status is tracked in [`status.md`](status.md). The completed desktop execution slice is recorded in [`mvp-execution-plan.md`](mvp-execution-plan.md).
