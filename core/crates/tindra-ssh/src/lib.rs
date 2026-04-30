// SPDX-License-Identifier: Apache-2.0
//
// tindra-ssh — SSH transport. Wraps russh to expose:
//   - Session open/close lifecycle
//   - Channel multiplexing (shell, exec, port-forward)
//   - Key auth (ed25519, RSA, ed25519-sk) and agent-proxied auth
//   - Jump host chain
//
// Public surface is minimal until Phase 1.
