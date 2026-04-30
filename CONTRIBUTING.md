# Contributing to Tindra

Thanks for your interest in Tindra. This document covers the practicalities; the architectural decisions live in [`docs/architecture.md`](docs/architecture.md).

## Licensing

Tindra is dual-licensed:

- **Client code** (`apps/`, `bridge/`, `plugins/`, and most crates under `core/crates/`) is Apache-2.0.
- **Sync backend code** (anything under `core/crates/tindra-sync-server/` and any future `server/` directory) is AGPL-3.0.

By submitting a contribution you agree to license it under the same license that governs the file or directory you're modifying. We use the inbound=outbound model (Apache-2.0 §5 and AGPL-3.0 §5); no separate CLA is required.

If you copy code from another open-source project, ensure the license is compatible (Apache-2.0-compatible for client, AGPL-3.0-compatible for backend) and add an entry to `NOTICE`.

## Development setup

See [`scripts/SETUP.md`](scripts/SETUP.md) for toolchain installation. Briefly: Rust stable, Flutter stable, Android NDK if you're touching mobile.

## Branches

- `main` — protected, always green.
- `release/<version>` — release branches.
- Feature branches off `main`, named `feat/<short-desc>` or `fix/<short-desc>`.

## Commit messages

Conventional Commits style:

```
feat(ssh): add agent forwarding support
fix(pty): handle ConPTY resize race on Windows
docs: clarify plugin permission model
```

## Pull requests

- Keep PRs focused; smaller is better.
- Include tests for new behavior.
- Update docs if user-visible behavior changes.
- Run `cargo fmt && cargo clippy --all-targets` and `dart format .` before pushing.

## Security

Do not file public issues for security vulnerabilities. Follow [`SECURITY.md`](SECURITY.md) (TBD) for responsible disclosure.

## Code of conduct

We follow the Contributor Covenant 2.1. By participating you agree to abide by it.
