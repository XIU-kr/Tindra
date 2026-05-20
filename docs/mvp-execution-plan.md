# Tindra MVP execution plan

Last updated: 2026-05-20

## 1. Code structure

Goal: reduce the single-file desktop app risk without changing behavior.

Current execution:
- Added `apps/desktop/lib/src/session_status.dart` for session state policy.
- Added `apps/desktop/lib/src/ui/typography.dart` as the first `part` split from `main.dart`.
- Kept the existing private UI helpers available through the same Dart library to avoid a broad rename.

Completed:
- Moved palette/sidebar widgets to `src/ui/shell_chrome.dart`.
- Moved session pane/terminal widgets to `src/session/session_pane.dart`.
- Moved profile list/dialog widgets to `src/profiles/profile_views.dart`.
- Moved SFTP browser widgets to `src/files/sftp_view.dart`.

## 2. SSH authentication and host-key UX

Goal: make first connection and authentication failures explicit and recoverable.

Current state:
- Key auth, agent auth, and non-persisted password auth exist.
- Host keys require explicit first-connect approval before shell/SFTP connections.
- Changed host keys are blocked by default and show trusted/presented fingerprints.
- Keyboard-interactive auth is available as a password fallback for common prompt-based servers.

Current execution:
- Added non-mutating host-key probe/check primitives and explicit `trustHostKey`.
- Shell and SFTP open paths no longer auto-trust new host keys.
- Added direct and jump-host target host-key probing.
- Added profile auth method value `password` with a session-only password prompt.
- Added keyboard-interactive shell/SFTP session helpers and password fallback.

Implementation notes:
- Do not silently expand auth methods only in Flutter. The Rust API must expose a typed pending-auth or auth-request result so desktop, macOS, and Android can share the same security behavior.
- Host-key approval needs three UI states: first-seen approval, changed-key hard stop, and trusted-key removal. Changed keys must remain blocking by default.

## 3. Terminal UX

Goal: raise terminal interaction quality before broad feature expansion.

Current execution:
- Added shared paste-risk assessment in `apps/shared_ui`.
- Desktop now asks for confirmation before pasting multiline or large clipboard payloads into an active session.
- Added shared terminal text-search match calculation with line/column offsets.
- Desktop session metabar shows snapshot search state.
- Copy policy prefers selected terminal text and falls back to screen text.

Completed:
- Bracketed paste mode and basic mouse reporting mode are detected from terminal output.
- Paste uses bracketed paste sequences when the remote side enables bracketed paste.
- Basic SGR mouse click reporting is sent when mouse reporting mode is active.
- Windows Korean/IME checks are documented as a manual verification checklist.

## 4. SFTP UX

Goal: move from primitive browser to trustworthy file-transfer workflow.

Current state:
- SFTP open/list/upload/download/mkdir/remove primitives exist.
- UI has a browser and a transfer panel.

Current execution:
- Added shared transfer queue item/status/progress models in `apps/shared_ui`.
- Desktop transfer panel now reads queue state instead of hard-coded idle-only UI.
- Added retry requeue policy for failed transfer items.
- Added row download action, manual upload action, overwrite confirmation, cancel state, and retry wiring.

Completed:
- Download/upload can stream progress events into the desktop transfer queue.

## 5. Windows packaging and app polish

Goal: make the Windows build present as a real product.

Current execution:
- Updated Windows resource metadata to `Tindra` / `Tindra SSH Client`.
- Updated the native Windows window title from `tindra_desktop` to `Tindra`.
- Verified `flutter build windows`.
- Added `docs/windows-packaging.md` with versioning, installer, and diagnostics targets.
- App versioning policy is tied to `apps/desktop/pubspec.yaml`.
- Settings diagnostics show app version, Rust core version, profiles path, settings path, and expected log directory.

## 6. macOS and Android readiness

Goal: make cross-platform scope honest and actionable.

Current state:
- `apps/desktop` currently has Windows runner only.
- `apps/mobile` documents Android-first runner boundaries before scaffold generation.
- `apps/shared_ui` contains platform-neutral terminal paste/search/copy and SFTP transfer models.
- `apps/mobile/README.md` documents Android scaffold commands and macOS runner checklist.

Completed:
- Added platform-neutral profile/session models to `apps/shared_ui`.
- Added secret-backend identifiers for DPAPI, Keychain, libsecret, and Android Keystore adapters.
