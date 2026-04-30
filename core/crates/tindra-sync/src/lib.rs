// SPDX-License-Identifier: Apache-2.0
//
// tindra-sync — E2E encrypted device sync.
// Two transport backends share the same CRDT layer:
//   1. Hosted relay (WebSocket, Tindra Cloud — paid plan)
//   2. User-supplied cloud folder (iCloud Drive, Google Drive — free)
// All payloads are pre-encrypted with age before leaving the device.
// Conflict resolution: automerge for documents, last-writer-wins for metadata.
