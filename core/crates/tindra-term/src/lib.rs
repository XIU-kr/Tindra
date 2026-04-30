// SPDX-License-Identifier: Apache-2.0
//
// tindra-term — terminal emulator state machine.
//
// Phase 1.2 uses the `vt100` crate as a quick path to a working grid
// model. Phase 2+ may swap to `alacritty_terminal` for full xterm-256
// fidelity, scrollback queries, hyperlink/OSC handling, and ligatures.
//
// Public surface today:
//   - `vt100::Parser` re-exported via `tindra_term::vt100`
//   - `Snapshot` — a serialisable grid snapshot suitable for FFI

pub use vt100;

/// Plain-text snapshot of a terminal screen at a moment in time.
/// Suitable for shipping over an FFI boundary and rendering as monospace
/// text plus a cursor overlay.
#[derive(Debug, Clone)]
pub struct Snapshot {
    pub rows: u32,
    pub cols: u32,
    /// Screen contents with `\n` between rows. Trailing whitespace on
    /// each row is preserved so cursor columns align.
    pub text: String,
    pub cursor_row: u32,
    pub cursor_col: u32,
    pub cursor_visible: bool,
}

impl Snapshot {
    /// Build a Snapshot from a `vt100::Parser`'s current screen.
    pub fn from_parser(parser: &vt100::Parser) -> Self {
        let screen = parser.screen();
        let (rows, cols) = screen.size();
        let (cur_row, cur_col) = screen.cursor_position();
        Snapshot {
            rows: rows as u32,
            cols: cols as u32,
            text: screen.contents(),
            cursor_row: cur_row as u32,
            cursor_col: cur_col as u32,
            cursor_visible: !screen.hide_cursor(),
        }
    }
}
