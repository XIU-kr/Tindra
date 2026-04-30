# Security model

> **Status:** Stub. To be filled in during Phase 0–1.

## Threat model

In scope:
- Theft of a device storing Tindra data (encrypted at rest).
- Compromise of the sync relay (must see only ciphertext).
- Malicious plugins (sandboxed by default, explicit grants required).
- Network attackers between client and SSH host (mitigated by SSH host key verification).

Out of scope (initially):
- A compromised host operating system — if your OS is rooted, no app-level defence is sufficient.
- Side-channel attacks against the SQLCipher database file.
- Targeted attacks against the Tindra binary itself (we ship signed releases but don't claim attestation).

## Secrets handling

- Master passphrase: never persisted. Used to derive the master key via Argon2id.
- Master key (age `X25519` keypair): held in OS keystore (Keychain/DPAPI/libsecret/Android Keystore).
- In-memory secrets: `zeroize` on drop.
- Local store: SQLCipher with the master key.

## Sync

- All payloads are age-encrypted on the device before upload.
- The sync server (whether self-hosted or BYO cloud) sees only ciphertext + opaque metadata (record IDs, version vectors).
- Conflict resolution is local; server cannot influence resolution.

## Host-key verification

- Trust on first use, with explicit warning.
- Subsequent fingerprint changes require explicit user re-approval.
- `known_hosts` interop is supported on import.

## Plugins

- Default deny on every capability.
- Explicit user grant per plugin per capability (`terminal:read`, `terminal:write`, `network:host=*.example.com`, `profiles:read`).
- Capability prompts include the plugin's signed manifest, verified against the publisher's key.

(More to come.)
