// FFI surface for SSH operations. Forwards into tindra-core (which forwards
// into tindra-ssh / russh). The bridge crate keeps its own CommandOutput so
// flutter_rust_bridge codegen has a local type to map to Dart.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::OnceLock;

use crate::frb_generated::StreamSink;
use tindra_core::term::vt100::Parser;
use tindra_core::term::Snapshot;
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
// Phase 1.1/1.2 — interactive shell with VT parsing
// ---------------------------------------------------------------------------

/// One frame of terminal state, ready to be rendered as monospace text.
#[derive(Debug, Clone)]
pub struct TerminalSnapshot {
    pub rows: u32,
    pub cols: u32,
    pub text: String,
    pub cursor_row: u32,
    pub cursor_col: u32,
    pub cursor_visible: bool,
}

impl From<Snapshot> for TerminalSnapshot {
    fn from(s: Snapshot) -> Self {
        TerminalSnapshot {
            rows: s.rows,
            cols: s.cols,
            text: s.text,
            cursor_row: s.cursor_row,
            cursor_col: s.cursor_col,
            cursor_visible: s.cursor_visible,
        }
    }
}

/// Per-session metadata held in the bridge crate (separate from tindra-ssh's
/// registry). Today it just remembers the geometry the session was opened
/// with so `shell_output_stream` can size its vt100 parser correctly.
struct SessionMeta {
    cols: u32,
    rows: u32,
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
    meta_registry()
        .lock()
        .await
        .insert(id, SessionMeta { cols, rows });
    Ok(id)
}

/// Stream of terminal snapshots. Bytes from the SSH session are fed into a
/// per-call `vt100::Parser`, and after each chunk a fresh `TerminalSnapshot`
/// is pushed to the sink. Call this exactly once per session.
pub async fn shell_output_stream(
    session_id: u64,
    sink: StreamSink<TerminalSnapshot>,
) -> Result<(), String> {
    let (cols, rows) = {
        let reg = meta_registry().lock().await;
        let meta = reg
            .get(&session_id)
            .ok_or_else(|| format!("session {session_id} unknown geometry"))?;
        (meta.cols, meta.rows)
    };
    let mut rx = tindra_core::ssh::take_output_receiver(session_id)
        .await
        .ok_or_else(|| {
            format!("session {session_id} not found or already subscribed")
        })?;

    let mut parser = Parser::new(rows as u16, cols as u16, 1000);

    while let Some(chunk) = rx.recv().await {
        parser.process(&chunk);
        let snapshot: TerminalSnapshot = Snapshot::from_parser(&parser).into();
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

pub async fn shell_resize(session_id: u64, cols: u32, rows: u32) -> Result<(), String> {
    // NB: doesn't yet resize the bridge-side vt100 Parser. Phase 1.3 wiring.
    tindra_core::ssh::shell_resize(session_id, cols, rows)
        .await
        .map_err(|e| e.to_string())?;
    if let Some(meta) = meta_registry().lock().await.get_mut(&session_id) {
        meta.cols = cols;
        meta.rows = rows;
    }
    Ok(())
}

pub async fn shell_close(session_id: u64) -> Result<(), String> {
    let _ = meta_registry().lock().await.remove(&session_id);
    tindra_core::ssh::shell_close(session_id)
        .await
        .map_err(|e| e.to_string())
}
