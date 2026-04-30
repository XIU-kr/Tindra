# Tindra architecture

This document is the working architectural reference. The full multi-page design plan lives in the user's Claude planning area (`~/.claude/plans/federated-cooking-wadler.md`); this file is the in-repo summary.

## Goals

A single codebase delivering:
- **Tabby-grade desktop UX** (tabs, splits, themes, GPU-accelerated rendering, jump hosts, port-forwarding, ZModem, SFTP).
- **First-class Android and iOS companions** with the full SSH feature set, packaged for store distribution.
- **End-to-end encrypted device sync** as a paid offering (free tier supports BYO cloud folders).
- **AI assist + MCP** built in (Tindra is both an MCP server and an MCP client).
- **WebAssembly plugin SDK** with explicit per-plugin permissions.
- **Offline-first** — every core feature works without network or sync.

## Stack

```
┌──────────────────────────────────────────────────┐
│  Flutter UI (Dart) — Desktop / Android+iOS       │
│   apps/desktop  apps/mobile  apps/shared_ui      │
├──────────────────────────────────────────────────┤
│  flutter_rust_bridge 2.x                         │
├──────────────────────────────────────────────────┤
│  Rust workspace (core/crates/*)                  │
│   tindra-ssh    russh                            │
│   tindra-pty    portable-pty                     │
│   tindra-sftp   russh-sftp                       │
│   tindra-term   alacritty_terminal (VT parser)   │
│   tindra-store  SQLCipher + age                  │
│   tindra-sync   automerge CRDT + age E2E         │
│   tindra-mcp    MCP server + client              │
│   tindra-ai     LLM provider abstraction (BYOK)  │
│   tindra-plug   wasmtime + WIT plugin host       │
│   tindra-core   public FFI surface               │
├──────────────────────────────────────────────────┤
│  Platform adapters                               │
│   Win:    ConPTY, DPAPI, OpenSSH-Agent, Pageant  │
│   macOS:  Keychain, NSWorkspace, Bonjour         │
│   Linux:  libsecret, SSH_AUTH_SOCK               │
│   Android: Keystore, ForegroundService, WorkMgr  │
│   iOS:    Keychain, BGTaskScheduler, StoreKit    │
└──────────────────────────────────────────────────┘
```

### Why Rust + Flutter?

- One UI codebase covers all five platforms (Tabby's Electron approach can't reach mobile; per-platform native is too much surface area for a small team).
- Rust core gives us the libraries that already exist for SSH/PTY/VT (`russh`, `portable-pty`, `alacritty_terminal`), high-quality crypto (`age`, `argon2`), and WASM hosting (`wasmtime`).
- `flutter_rust_bridge` handles streaming primitives (PTY output → Dart `Stream`) cleanly, which a hand-written FFI would struggle with.

## Crates

| Crate | Responsibility |
|---|---|
| `tindra-core` | Public FFI surface. The only crate `flutter_rust_bridge` sees. Re-exports types from sibling crates. |
| `tindra-ssh` | SSH transport. Sessions, channels, key auth, jump-host chains, port forwarding. |
| `tindra-pty` | Local PTY for "Local Shell" tabs (ConPTY/winpty/POSIX). |
| `tindra-sftp` | SFTP client and transfer queue (concurrent, pause/resume). |
| `tindra-term` | VT/ANSI parser and terminal grid model (snapshot + diff). |
| `tindra-store` | Encrypted local DB for profiles/keys/snippets/host fingerprints (SQLCipher + age). |
| `tindra-sync` | E2E sync engine (automerge CRDT + age payload encryption). |
| `tindra-mcp` | Model Context Protocol server and client. |
| `tindra-ai` | LLM provider abstraction; shell-context capture from `tindra-term`. |
| `tindra-plug` | WASM plugin host (`wasmtime` + WIT component model). |

## Roadmap (phased)

| Phase | Outcome |
|---|---|
| **0. Discovery** | Repo + CI + frb hello-world echo; 5-platform build matrix verified (macOS/Windows/Linux/Android/iOS). |
| **1. Desktop MVP** | One SSH session, VT/UTF-8, tabs/splits, local profiles, ed25519/RSA/agent, jump host, local port-forwarding. |
| **2. Desktop 1.0** | SFTP browser, SOCKS/remote forwarding, serial/Telnet, ZModem, themes/fonts/Quake mode, Pageant/Keychain integration. |
| **3. Mobile companion (Android + iOS)** | Mobile SSH; soft-keyboard helpers; Android ForegroundService; iOS foreground-only sessions; pairing entry point; StoreKit/Play Billing scaffolding. |
| **4. E2E sync** | age master key; CRDT sync; QR pairing; dual backend (self-host WS / iCloud-Drive folder). |
| **5. AI + MCP** | Shell context capture; BYOK LLMs; MCP server (`run_command`, `read_screen`); MCP client. |
| **6. Plugin SDK** | wasmtime + WIT host; permission manifests; example plugins; plugin index. **iOS builds disable the `plugins` cargo feature** (App Store Review Guideline 2.5.2). |

Estimated 7–10 months to 1.0; 9–13 months to 1.2.

## Business model

- Open source (Apache-2.0 client, AGPL-3.0 sync backend when added).
- Paid plan = Tindra Cloud Sync. Free users get full SSH/SFTP/forwarding/AI(BYOK)/plugins; Cloud Sync and multi-device pairing are paywalled.
- Mobile free tier (Android + iOS) shows AdMob ads. Desktop is ad-free (technical: AdMob doesn't support desktop; product: engineers strongly dislike ads in tools).
- Payment providers: iOS = StoreKit (Apple 15–30%), Android = Play Billing, desktop = Stripe. Single Flutter UI, provider selected at runtime.

## Platform-specific constraints

| Platform | Plugin SDK | Background sessions | Payment |
|---|---|---|---|
| macOS / Windows / Linux | ✅ Enabled | ✅ Until app quit | Stripe |
| Android | ✅ Enabled | ✅ ForegroundService + WakeLock | Play Billing |
| iOS | ❌ Disabled (Guideline 2.5.2) | ❌ Foreground only | StoreKit |

## Security model

See [`security-model.md`](security-model.md) (TBD).

## Plugin SDK

See [`plugin-sdk.md`](plugin-sdk.md) (TBD).
