// SPDX-License-Identifier: Apache-2.0
//
// tindra-store — encrypted local store.
// Schema:
//   profiles        connection profiles (host, port, auth refs, options)
//   keys            ssh private keys (encrypted blob), public counterparts
//   groups          profile grouping/folders
//   snippets        reusable command snippets
//   host_keys       known-host fingerprints (TOFU + manual approve)
//   sync_meta       per-record CRDT actor IDs and version vectors
// Storage: SQLCipher; master key derived via Argon2id from user passphrase.
