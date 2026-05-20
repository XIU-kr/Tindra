# tindra_shared_ui

Shared Flutter/Dart foundation for Tindra clients.

This package is for platform-neutral UI and workflow models that should behave
the same on Windows, macOS, Android, and later iOS.

Current contents:
- Terminal paste risk assessment, bracket-aware copy policy, and text search models.
- SFTP transfer queue item/status/progress models.
- Platform-neutral profile/session view models.
- Secret-backend identifiers for DPAPI, Keychain, libsecret, and Android Keystore adapters.

Keep out:
- Desktop window management and global hotkeys.
- Platform-specific secret storage.
- Generated Rust FFI bindings.
