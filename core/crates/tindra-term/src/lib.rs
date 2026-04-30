// SPDX-License-Identifier: Apache-2.0
//
// tindra-term — terminal emulator state machine.
//
// Phase 1.2 used the `vt100` crate as a quick path to a working grid model.
// Phase 1.3 adds per-cell color and attribute capture so the UI can render
// `ls --color`, error highlights, vim themes, etc.

pub use vt100;

/// 24-bit color or "use the theme default".
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ColorVal {
    pub default: bool,
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl ColorVal {
    pub const DEFAULT: ColorVal = ColorVal {
        default: true,
        r: 0,
        g: 0,
        b: 0,
    };

    pub fn from_vt100(c: vt100::Color) -> Self {
        match c {
            vt100::Color::Default => ColorVal::DEFAULT,
            vt100::Color::Rgb(r, g, b) => ColorVal {
                default: false,
                r,
                g,
                b,
            },
            vt100::Color::Idx(i) => {
                let (r, g, b) = palette_256(i);
                ColorVal {
                    default: false,
                    r,
                    g,
                    b,
                }
            }
        }
    }
}

/// One cell in the screen grid.
#[derive(Debug, Clone)]
pub struct Cell {
    /// The cell's grapheme — usually a single char, occasionally a base+combining
    /// sequence. Empty string for the right half of a wide-character pair.
    pub ch: String,
    pub fg: ColorVal,
    pub bg: ColorVal,
    /// Packed attribute bitfield: 1=bold, 2=italic, 4=underline, 8=inverse, 16=dim.
    pub attrs: u8,
}

pub const ATTR_BOLD: u8 = 1;
pub const ATTR_ITALIC: u8 = 2;
pub const ATTR_UNDERLINE: u8 = 4;
pub const ATTR_INVERSE: u8 = 8;
pub const ATTR_DIM: u8 = 16;

/// Plain-text + styled snapshot of a terminal screen at a moment in time.
#[derive(Debug, Clone)]
pub struct Snapshot {
    pub rows: u32,
    pub cols: u32,
    /// Plain-text mirror, with `\n` between rows. Useful for selection,
    /// search, and anything that doesn't need styling.
    pub text: String,
    /// Per-cell grid, row-major, length = rows * cols.
    pub cells: Vec<Cell>,
    pub cursor_row: u32,
    pub cursor_col: u32,
    pub cursor_visible: bool,
}

impl Snapshot {
    /// Build a Snapshot from a `vt100::Parser`'s current screen.
    pub fn from_parser(parser: &vt100::Parser) -> Self {
        let screen = parser.screen();
        let (rows, cols) = screen.size();
        let mut cells: Vec<Cell> = Vec::with_capacity((rows as usize) * (cols as usize));
        let mut text = String::with_capacity((rows as usize) * (cols as usize + 1));

        for r in 0..rows {
            for c in 0..cols {
                let cell = screen.cell(r, c);
                let pushed_cell = match cell {
                    Some(cell) => {
                        let ch = if cell.is_wide_continuation() {
                            // The base character lives in the previous cell;
                            // emit an empty grapheme here so the grid index
                            // and column number stay aligned.
                            String::new()
                        } else if cell.has_contents() {
                            cell.contents().to_string()
                        } else {
                            " ".to_string()
                        };
                        // Build text mirror — substitute spaces for empties so
                        // column counts in the text match the grid.
                        if ch.is_empty() {
                            text.push(' ');
                        } else {
                            text.push_str(&ch);
                        }

                        let mut attrs: u8 = 0;
                        if cell.bold() {
                            attrs |= ATTR_BOLD;
                        }
                        if cell.italic() {
                            attrs |= ATTR_ITALIC;
                        }
                        if cell.underline() {
                            attrs |= ATTR_UNDERLINE;
                        }
                        if cell.inverse() {
                            attrs |= ATTR_INVERSE;
                        }
                        if cell.dim() {
                            attrs |= ATTR_DIM;
                        }
                        Cell {
                            ch,
                            fg: ColorVal::from_vt100(cell.fgcolor()),
                            bg: ColorVal::from_vt100(cell.bgcolor()),
                            attrs,
                        }
                    }
                    None => {
                        text.push(' ');
                        Cell {
                            ch: " ".to_string(),
                            fg: ColorVal::DEFAULT,
                            bg: ColorVal::DEFAULT,
                            attrs: 0,
                        }
                    }
                };
                cells.push(pushed_cell);
            }
            if r + 1 < rows {
                text.push('\n');
            }
        }

        let (cur_row, cur_col) = screen.cursor_position();
        Snapshot {
            rows: rows as u32,
            cols: cols as u32,
            text,
            cells,
            cursor_row: cur_row as u32,
            cursor_col: cur_col as u32,
            cursor_visible: !screen.hide_cursor(),
        }
    }
}

/// Resolve an xterm 256-color index into 24-bit RGB.
/// 0..=15 are the ANSI 16, 16..=231 the 6x6x6 cube, 232..=255 grayscale ramp.
pub fn palette_256(i: u8) -> (u8, u8, u8) {
    // Standard xterm 16-color palette.
    const ANSI16: [(u8, u8, u8); 16] = [
        (0, 0, 0),       // 0  black
        (205, 0, 0),     // 1  red
        (0, 205, 0),     // 2  green
        (205, 205, 0),   // 3  yellow
        (0, 0, 238),     // 4  blue
        (205, 0, 205),   // 5  magenta
        (0, 205, 205),   // 6  cyan
        (229, 229, 229), // 7  white
        (127, 127, 127), // 8  bright black
        (255, 0, 0),     // 9  bright red
        (0, 255, 0),     // 10 bright green
        (255, 255, 0),   // 11 bright yellow
        (92, 92, 255),   // 12 bright blue
        (255, 0, 255),   // 13 bright magenta
        (0, 255, 255),   // 14 bright cyan
        (255, 255, 255), // 15 bright white
    ];
    // Non-linear ramp xterm uses for the 6x6x6 cube.
    const RAMP: [u8; 6] = [0, 95, 135, 175, 215, 255];

    if i < 16 {
        ANSI16[i as usize]
    } else if i < 232 {
        let n = i - 16;
        let r = RAMP[(n / 36) as usize];
        let g = RAMP[((n / 6) % 6) as usize];
        let b = RAMP[(n % 6) as usize];
        (r, g, b)
    } else {
        // Grayscale ramp: 8, 18, 28, ..., 238 (24 levels)
        let v = (i - 232) * 10 + 8;
        (v, v, v)
    }
}
