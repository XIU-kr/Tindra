# Tindra Mobile

This directory documents the Android-first Flutter client boundary.

Current status:
- Android is the first target when platform runners are generated.
- iOS is validated on macOS after Android is stable.
- Platform-neutral models live in `apps/shared_ui` before runner generation.

Scaffold target:

```powershell
flutter create --platforms=android apps/mobile
```

Shared code policy:
- Put platform-neutral session, terminal, SFTP transfer, theme, and localization models in `apps/shared_ui`.
- Keep platform secret storage behind a shared interface: DPAPI on Windows, Keychain on macOS/iOS, and Keystore on Android.
- Do not copy desktop-only window manager, hotkey, or Win32 runner assumptions into mobile.

macOS runner checklist before scaffolding desktop support:
- Preserve any pending Windows runner changes before running `flutter create`.
- Confirm Rust bridge and cargokit settings for macOS in `apps/desktop/rust_builder/macos`.
- Confirm `apps/shared_ui` contains only platform-neutral models and no desktop-only dependencies.
- Generate platform scaffolds in a clean branch so Flutter template churn can be reviewed separately.
