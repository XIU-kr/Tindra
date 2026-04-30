# Toolchain setup

Install these once. Versions noted are the minimum we test against in CI.

## 1. Rust (stable, ≥ 1.78)

Recommended: [rustup](https://rustup.rs/).

**Windows (PowerShell):**
```powershell
winget install Rustlang.Rustup
# or download rustup-init.exe from https://rustup.rs/
rustup default stable
rustup component add rustfmt clippy
```

**macOS / Linux:**
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup default stable
rustup component add rustfmt clippy
```

Verify:
```bash
rustc --version   # rustc 1.78+ stable
cargo --version
```

## 2. Flutter (stable channel)

[https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install)

**Windows (winget):**
```powershell
winget install Flutter.Flutter
```

**macOS (Homebrew):**
```bash
brew install --cask flutter
```

**Linux:** download the SDK tarball and add `flutter/bin` to `PATH`.

After install:
```bash
flutter doctor          # follow any prompts
flutter config --enable-windows-desktop --enable-macos-desktop --enable-linux-desktop
```

Verify:
```bash
flutter --version       # 3.24+ on stable
dart --version
```

## 3. Android toolchain (only needed for `apps/mobile` Android target)

- **Android Studio** — provides SDK + NDK + emulator manager.
  - Open SDK Manager → install **Android SDK Platform 34** (or latest).
  - Open SDK Manager → SDK Tools tab → install **NDK (Side by side)** version `r26d` or newer.
- **Java 17** (Temurin recommended) — Android Gradle Plugin 8.x requires JDK 17.
- Add Rust Android targets:
  ```bash
  rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
  ```
- Set `ANDROID_NDK_HOME` (or `ANDROID_NDK_ROOT`) to the NDK install path.

`flutter doctor` will guide you through any missing pieces.

## 4. iOS toolchain (only needed for `apps/mobile` iOS target — macOS only)

iOS builds require macOS. On Windows or Linux, you can develop the rest and rely on CI's macOS runner for iOS verification.

- **Xcode** (latest stable) — install from the Mac App Store.
- **Command Line Tools**: `xcode-select --install`
- **CocoaPods**:
  ```bash
  brew install cocoapods
  ```
- **Apple Developer Program** ($99/year) for distribution. Local simulator/device development works without a paid account.
- Add Rust iOS targets:
  ```bash
  rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
  ```
- Accept Xcode license: `sudo xcodebuild -license accept`
- Open the iOS simulator once: `open -a Simulator`

Tindra's iOS build packages the Rust core as an `xcframework` containing slices for device (`aarch64-apple-ios`) and simulator (`aarch64-apple-ios-sim` and `x86_64-apple-ios`). The `scripts/build-ios-xcframework.sh` helper (added in Phase 0 wiring) automates this.

Note: iOS builds disable the `plugins` cargo feature (App Store Review Guideline 2.5.2 — no runtime-loaded executable code).

## 5. flutter_rust_bridge codegen

```bash
cargo install flutter_rust_bridge_codegen --version "^2"
```

To regenerate Dart bindings after editing `core/crates/tindra-core/src/api/`:
```bash
cd bridge
flutter_rust_bridge_codegen generate
```

## 6. Optional: SQLCipher / OpenSSL system deps

Most things vendor or build from source, but SQLCipher (used by `tindra-store`) compiles faster with system OpenSSL:

- **Linux:** `sudo apt install libssl-dev libsqlcipher-dev pkg-config`
- **macOS:** `brew install openssl@3 sqlcipher pkg-config`
- **Windows:** the `bundled-sqlcipher` rusqlite feature is recommended; no system install needed.

## Sanity check

After everything is installed, from the repo root:

```bash
# Rust workspace compiles
( cd core && cargo check --workspace )

# Flutter desktop app initialises (after `flutter create` per apps/README.md)
( cd apps/desktop && flutter pub get && flutter analyze )
```

If both succeed, you're ready to start Phase 0 work.
