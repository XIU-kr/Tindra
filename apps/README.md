# apps/

Flutter applications and shared UI packages.

| Package | Purpose | Targets |
|---|---|---|
| `desktop/` | Desktop entrypoint with terminal-first UI and Rust bridge | Windows now; macOS/Linux later |
| `mobile/` | Mobile entrypoint | Android first; iOS later |
| `shared_ui/` | Platform-neutral UI/workflow models | Dart/Flutter package |

## Current State

- `desktop/` is an active Flutter app with a Windows runner.
- `mobile/` documents Android-first scaffold boundaries before runner generation.
- `shared_ui/` is an active package for shared terminal and SFTP workflow models.

## Scaffold Targets

Run these only after checking the current tree for local changes:

```bash
# from repo root
flutter create --org sh.tindra --project-name tindra_desktop \
  --platforms=macos,linux \
  apps/desktop

flutter create --org sh.tindra --project-name tindra_mobile \
  --platforms=android \
  apps/mobile
```

The desktop app already depends on shared UI:

```yaml
dependencies:
  tindra_shared_ui:
    path: ../shared_ui
```

## Boundaries

- Keep desktop window management, global hotkeys, and native runner code in `desktop/`.
- Keep Android activity, lifecycle, and mobile background-session behavior in `mobile/`.
- Put platform-neutral terminal, SFTP transfer, profile/session, theme, and localization models in `shared_ui`.
- Keep platform secret storage behind interfaces: DPAPI on Windows, Keychain on macOS/iOS, Keystore on Android.

## iOS Notes

- iOS builds require macOS, Xcode, and an Apple Developer Program membership.
- iOS is scaffolded after Android is stable.
- iOS cannot keep SSH sessions alive indefinitely in the background; the app must make reconnect behavior explicit.
