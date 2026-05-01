// SPDX-License-Identifier: Apache-2.0
//
// tindra-pty — local PTY for "Local Shell" tabs.
// Wraps wezterm's portable-pty so callers see a single ergonomic API
// regardless of ConPTY (Win 10+), winpty (legacy Win), or POSIX PTY.

// ---------------------------------------------------------------------------
// Phase 8d framework — ZMODEM detection
// ---------------------------------------------------------------------------
//
// The full ZMODEM upload/download flow needs three things we don't yet have:
//
//   1. PTY interception — when ZMODEM is active we have to suppress the
//      vt100 parser and feed raw bytes to zmodem2 instead.
//   2. State machine — drive zmodem2's event loop while reading from the
//      remote and writing back through shellWrite.
//   3. UI — a "Receive file" / "Send file" dialog that picks a local
//      destination and shows progress.
//
// This first cut just lands the dependency (zmodem2 0.5) and a tiny
// detector for the ZRQINIT header so the surrounding plumbing has
// something to call. The detector returns true the moment a sender
// starts the handshake, but actually handing the byte stream off to
// zmodem2 is left for the follow-up commit.

/// ZRQINIT byte signature: "**\x18B00" followed by hex CRC. We match the
/// stable prefix only, since the CRC and trailing CR/LF can vary.
const ZRQINIT_PREFIX: &[u8] = b"**\x18B00";

/// Returns true if `bytes` contains the start of a ZMODEM ZRQINIT header.
/// Callers should only treat this as a hint — the protocol involves
/// retransmission, so detection in mid-stream is a best-effort signal.
pub fn detect_zrqinit(bytes: &[u8]) -> bool {
    bytes
        .windows(ZRQINIT_PREFIX.len())
        .any(|w| w == ZRQINIT_PREFIX)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_clean_zrqinit() {
        let frame = b"some prompt\r\n**\x18B00000000000000\r\n";
        assert!(detect_zrqinit(frame));
    }

    #[test]
    fn ignores_random_data() {
        assert!(!detect_zrqinit(b"hello world"));
        assert!(!detect_zrqinit(b"**not zmodem"));
    }
}
