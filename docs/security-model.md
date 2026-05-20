# Security Model

This document records the current desktop security posture and the intended boundaries for future sync and plugin surfaces.

## Threat Model

In scope:

- Theft of a device storing Tindra local data.
- Network attackers between the client and SSH host.
- SSH host-key changes after a key has already been trusted.
- Accidental persistence of interactive authentication secrets.

Out of scope:

- A compromised host operating system.
- Attestation of the Tindra binary itself.
- Malicious remote SSH servers beyond what SSH protocol and UI warnings can surface.

## Secrets Handling

- SSH passwords and keyboard-interactive responses are entered at connection time and are not saved into profiles.
- Private-key passphrases are connection-time inputs.
- Profile, settings, and trusted host-key metadata are stored locally as JSON.
- Secret storage uses platform facilities where implemented:
  - Windows: DPAPI-protected local secret records.
  - macOS/iOS: Keychain through the Rust store layer.
  - Linux: libsecret through the Rust store layer.
  - Android: backend identifier is reserved until the Android runner bridge is generated.
- In-memory secret types use `zeroize` where the surrounding model supports it.

## Host-Key Verification

- SSH and SFTP connections perform host-key preflight before opening a session.
- Unknown host keys are shown to the user and saved only after explicit approval.
- Trusted host keys connect without prompting.
- Changed host keys are blocked by default and show both the old and new fingerprints.
- Replacing a changed key requires an explicit replace action; it is not automatic TOFU.

## Sync Boundary

The current desktop app is local-first. Sync crates and roadmap documents exist, but a hosted sync backend is not part of the current Windows desktop implementation.

Future sync payloads must be encrypted on the device before upload, and the relay must not receive plaintext profile, key, snippet, or secret values.

## Plugin Boundary

The plugin crate is a boundary placeholder. Any future plugin runtime must keep default-deny capability grants and must not expose terminal output, profile data, network access, or filesystem access without explicit user approval.
