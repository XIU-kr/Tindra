# apps/

Flutter applications. Three packages:

| Package | Purpose | Targets |
|---|---|---|
| `desktop/` | Desktop entrypoint (terminal-first UI) | macOS, Windows, Linux |
| `mobile/` | Mobile entrypoint (mobile-tailored UI) | Android + iOS |
| `shared_ui/` | Shared widgets, themes, terminal renderer, bridge consumers | Dart package, depended on by both |

## Bootstrap (one-time, requires Flutter installed — see `../scripts/SETUP.md`)

The Flutter packages aren't yet generated because `flutter create` produces a lot of platform-specific scaffolding (Xcode/Gradle projects, runner.exe configs, etc.) that's best produced by the Flutter CLI itself.

Run these once after installing Flutter:

```bash
# from repo root
flutter create --org sh.tindra --project-name tindra_desktop \
  --platforms=windows,macos,linux \
  apps/desktop

flutter create --org sh.tindra --project-name tindra_mobile \
  --platforms=android,ios \
  apps/mobile

flutter create --template=package --project-name tindra_shared_ui \
  apps/shared_ui
```

Then wire the dependency in each app's `pubspec.yaml`:

```yaml
dependencies:
  tindra_shared_ui:
    path: ../shared_ui
```

## Why three packages?

- `desktop` and `mobile` keep their own `main.dart`, window/activity setup, and platform-specific build configs (e.g. Windows MSIX, Android manifest, iOS Info.plist + entitlements, AdMob keys for mobile only, StoreKit/Play Billing IDs).
- `shared_ui` holds everything platform-agnostic: terminal grid widget, profile editor screens, theme system, the FFI consumer layer.
- Keeping the desktop free of `google_mobile_ads`, StoreKit, and other mobile-only deps avoids build complexity and dead weight.

## iOS-specific notes

- iOS builds disable the WASM plugin SDK (`plugins` cargo feature off in `core/crates/tindra-plug`). App Store Review Guideline 2.5.2 forbids loading user-supplied executable code at runtime. Android and desktop keep plugins enabled.
- iOS does **not** keep SSH sessions alive in the background. Apple's `BGTaskScheduler` isn't designed for long-lived TCP sockets. The UI surfaces this clearly: sessions disconnect when the app backgrounds, with an obvious reconnect button.
- Subscriptions on iOS go through StoreKit (Apple takes 15–30%); Android uses Play Billing; desktop uses Stripe. The Flutter UI is unified; the payment provider is selected at runtime per platform.
- iOS builds require a Mac (Xcode) and an Apple Developer Program membership ($99/year).

## After bootstrap

1. Re-enable the `flutter-*` jobs in `.github/workflows/ci.yml` (remove `if: false`).
2. Run the frb hello-world (see `bridge/README.md`).
3. Verify the matrix: `flutter build` on all desktop hosts + Android emulator.
