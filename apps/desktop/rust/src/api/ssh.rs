// FFI surface for SSH operations. Forwards into tindra-core (which forwards
// into tindra-ssh / russh + tindra-term / vt100).

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, OnceLock};

use crate::frb_generated::StreamSink;
use tindra_core::term::{vt100::Parser, Snapshot as CoreSnapshot};
use tokio::sync::Mutex;

// ---------------------------------------------------------------------------
// Phase 1.0 — one-shot exec
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct CommandOutput {
    pub exit_code: i32,
    pub stdout: String,
    pub stderr: String,
}

pub async fn run_command_pubkey(
    host: String,
    port: u16,
    username: String,
    private_key_path: String,
    passphrase: Option<String>,
    command: String,
) -> Result<CommandOutput, String> {
    let out = tindra_core::ssh::run_command_pubkey(
        host,
        port,
        username,
        PathBuf::from(private_key_path),
        passphrase,
        command,
    )
    .await
    .map_err(|e| e.to_string())?;

    Ok(CommandOutput {
        exit_code: out.exit_code,
        stdout: out.stdout,
        stderr: out.stderr,
    })
}

// ---------------------------------------------------------------------------
// Phase 1.1–1.3 — interactive shell with VT parsing, color, and resize
// ---------------------------------------------------------------------------

/// 24-bit color or default. Mirrors tindra_core::term::ColorVal so frb codegen
/// has a local Dart type.
#[derive(Debug, Clone)]
pub struct Color {
    pub default: bool,
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

/// One cell in the terminal grid.
#[derive(Debug, Clone)]
pub struct Cell {
    pub ch: String,
    pub fg: Color,
    pub bg: Color,
    /// Bitfield: 1=bold, 2=italic, 4=underline, 8=inverse, 16=dim.
    pub attrs: u8,
}

/// One frame of terminal state.
#[derive(Debug, Clone)]
pub struct TerminalSnapshot {
    pub rows: u32,
    pub cols: u32,
    /// Plain-text mirror with `\n` between rows (for selection/search).
    pub text: String,
    /// Per-cell grid, row-major, length = rows * cols.
    pub cells: Vec<Cell>,
    pub cursor_row: u32,
    pub cursor_col: u32,
    pub cursor_visible: bool,
}

impl From<CoreSnapshot> for TerminalSnapshot {
    fn from(s: CoreSnapshot) -> Self {
        TerminalSnapshot {
            rows: s.rows,
            cols: s.cols,
            text: s.text,
            cells: s
                .cells
                .into_iter()
                .map(|c| Cell {
                    ch: c.ch,
                    fg: Color {
                        default: c.fg.default,
                        r: c.fg.r,
                        g: c.fg.g,
                        b: c.fg.b,
                    },
                    bg: Color {
                        default: c.bg.default,
                        r: c.bg.r,
                        g: c.bg.g,
                        b: c.bg.b,
                    },
                    attrs: c.attrs,
                })
                .collect(),
            cursor_row: s.cursor_row,
            cursor_col: s.cursor_col,
            cursor_visible: s.cursor_visible,
        }
    }
}

/// Per-session metadata held in the bridge crate.
struct SessionMeta {
    /// vt100 parser for this session's screen state. Shared so shell_resize
    /// can update its dimensions while shell_output_stream keeps reading.
    parser: Arc<Mutex<Parser>>,
}

fn meta_registry() -> &'static Mutex<HashMap<u64, SessionMeta>> {
    static R: OnceLock<Mutex<HashMap<u64, SessionMeta>>> = OnceLock::new();
    R.get_or_init(|| Mutex::new(HashMap::new()))
}

pub async fn open_shell_pubkey(
    host: String,
    port: u16,
    username: String,
    private_key_path: String,
    passphrase: Option<String>,
    cols: u32,
    rows: u32,
) -> Result<u64, String> {
    let id = tindra_core::ssh::open_shell_pubkey(
        host,
        port,
        username,
        PathBuf::from(private_key_path),
        passphrase,
        cols,
        rows,
    )
    .await
    .map_err(|e| e.to_string())?;
    let parser = Arc::new(Mutex::new(Parser::new(rows as u16, cols as u16, 1000)));
    meta_registry()
        .lock()
        .await
        .insert(id, SessionMeta { parser });
    Ok(id)
}

/// Phase 4.0 — open a shell using the local SSH agent for authentication.
pub async fn open_shell_agent(
    host: String,
    port: u16,
    username: String,
    cols: u32,
    rows: u32,
) -> Result<u64, String> {
    let id = tindra_core::ssh::open_shell_agent(host, port, username, cols, rows)
        .await
        .map_err(|e| e.to_string())?;
    let parser = Arc::new(Mutex::new(Parser::new(rows as u16, cols as u16, 1000)));
    meta_registry()
        .lock()
        .await
        .insert(id, SessionMeta { parser });
    Ok(id)
}

/// Stream of terminal snapshots. Bytes from the SSH session are fed into a
/// per-session vt100::Parser; after each chunk a fresh `TerminalSnapshot` is
/// pushed. Call this exactly once per session.
pub async fn shell_output_stream(
    session_id: u64,
    sink: StreamSink<TerminalSnapshot>,
) -> Result<(), String> {
    let parser = {
        let reg = meta_registry().lock().await;
        let meta = reg
            .get(&session_id)
            .ok_or_else(|| format!("session {session_id} unknown"))?;
        meta.parser.clone()
    };
    let mut rx = tindra_core::ssh::take_output_receiver(session_id)
        .await
        .ok_or_else(|| {
            format!("session {session_id} not found or already subscribed")
        })?;

    while let Some(chunk) = rx.recv().await {
        let snapshot: TerminalSnapshot = {
            let mut p = parser.lock().await;
            p.process(&chunk);
            CoreSnapshot::from_parser(&p).into()
        };
        if sink.add(snapshot).is_err() {
            break;
        }
    }

    meta_registry().lock().await.remove(&session_id);
    Ok(())
}

pub async fn shell_write(session_id: u64, data: Vec<u8>) -> Result<(), String> {
    tindra_core::ssh::shell_write(session_id, data)
        .await
        .map_err(|e| e.to_string())
}

/// Resize the remote PTY *and* the local vt100 parser so the next snapshot
/// reflects the new geometry.
pub async fn shell_resize(session_id: u64, cols: u32, rows: u32) -> Result<(), String> {
    tindra_core::ssh::shell_resize(session_id, cols, rows)
        .await
        .map_err(|e| e.to_string())?;
    if let Some(meta) = meta_registry().lock().await.get(&session_id) {
        meta.parser
            .lock()
            .await
            .screen_mut()
            .set_size(rows as u16, cols as u16);
    }
    Ok(())
}

pub async fn shell_close(session_id: u64) -> Result<(), String> {
    let _ = meta_registry().lock().await.remove(&session_id);
    tindra_core::ssh::shell_close(session_id)
        .await
        .map_err(|e| e.to_string())
}
