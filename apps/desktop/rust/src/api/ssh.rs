// FFI surface for SSH operations. Forwards into tindra-core (which forwards
// into tindra-ssh / russh + tindra-term / vt100).

use std::collections::HashMap;
use std::future::Future;
use std::path::PathBuf;
use std::sync::{Arc, OnceLock};
use std::time::Duration;

use crate::frb_generated::StreamSink;
use tindra_core::pty::detect_zrqinit;
use tindra_core::term::{vt100::Parser, Snapshot as CoreSnapshot};
use tokio::sync::{broadcast, Mutex};

const SSH_CONNECT_TIMEOUT: Duration = Duration::from_secs(20);
const SSH_CONNECT_TIMEOUT_MESSAGE: &str = "connection timed out after 20 seconds";

async fn with_connect_timeout<T, E, Fut>(future: Fut) -> Result<T, String>
where
    Fut: Future<Output = Result<T, E>>,
    E: std::fmt::Display,
{
    tokio::time::timeout(SSH_CONNECT_TIMEOUT, future)
        .await
        .map_err(|_| SSH_CONNECT_TIMEOUT_MESSAGE.to_string())?
        .map_err(|e| e.to_string())
}

/// Phase 8d framework hook — best-effort detection of the ZMODEM ZRQINIT
/// header in raw remote output. Returns true when a sender is starting a
/// transfer; callers can use this to surface a "ZMODEM transfer detected"
/// notification while the full receiver lands.
pub fn looks_like_zmodem(bytes: Vec<u8>) -> bool {
    detect_zrqinit(&bytes)
}

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
    pub bracketed_paste_mode: bool,
    pub mouse_reporting_mode: bool,
    pub scrollback_position: u32,
    pub bell: bool,
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
            bracketed_paste_mode: false,
            mouse_reporting_mode: false,
            scrollback_position: 0,
            bell: false,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SessionBackend {
    Ssh,
    LocalPty,
}

/// Per-session metadata held in the bridge crate.
struct SessionMeta {
    /// vt100 parser for this session's screen state. Shared so shell_resize
    /// can update its dimensions while shell_output_stream keeps reading.
    parser: Arc<Mutex<Parser>>,
    backend: SessionBackend,
    snapshots: broadcast::Sender<TerminalSnapshot>,
}

fn meta_registry() -> &'static Mutex<HashMap<u64, SessionMeta>> {
    static R: OnceLock<Mutex<HashMap<u64, SessionMeta>>> = OnceLock::new();
    R.get_or_init(|| Mutex::new(HashMap::new()))
}

async fn register_session_meta(id: u64, rows: u32, cols: u32, backend: SessionBackend) {
    let parser = Arc::new(Mutex::new(Parser::new(rows as u16, cols as u16, 1000)));
    let (snapshots, _) = broadcast::channel(256);
    meta_registry().lock().await.insert(
        id,
        SessionMeta {
            parser: parser.clone(),
            backend,
            snapshots: snapshots.clone(),
        },
    );
    tokio::spawn(pump_session_output(id, parser, backend, snapshots));
}

fn chunk_has_terminal_bell(chunk: &[u8]) -> bool {
    chunk.contains(&0x07)
}

async fn pump_session_output(
    session_id: u64,
    parser: Arc<Mutex<Parser>>,
    backend: SessionBackend,
    snapshots: broadcast::Sender<TerminalSnapshot>,
) {
    let Some(mut rx) = (match backend {
        SessionBackend::Ssh => tindra_core::ssh::take_output_receiver(session_id).await,
        SessionBackend::LocalPty => tindra_core::pty::take_output_receiver(session_id).await,
    }) else {
        meta_registry().lock().await.remove(&session_id);
        return;
    };

    let mut bracketed_paste_mode = false;
    let mut mouse_reporting_mode = false;
    while let Some(chunk) = rx.recv().await {
        let bell = chunk_has_terminal_bell(&chunk);
        let mut snapshot: TerminalSnapshot = {
            let mut p = parser.lock().await;
            p.process(&chunk);
            CoreSnapshot::from_parser(&p).into()
        };
        let chunk_text = String::from_utf8_lossy(&chunk);
        if chunk_text.contains("\u{1b}[?2004h") {
            bracketed_paste_mode = true;
        }
        if chunk_text.contains("\u{1b}[?2004l") {
            bracketed_paste_mode = false;
        }
        if chunk_text.contains("\u{1b}[?1000h")
            || chunk_text.contains("\u{1b}[?1002h")
            || chunk_text.contains("\u{1b}[?1003h")
            || chunk_text.contains("\u{1b}[?1006h")
        {
            mouse_reporting_mode = true;
        }
        if chunk_text.contains("\u{1b}[?1000l")
            || chunk_text.contains("\u{1b}[?1002l")
            || chunk_text.contains("\u{1b}[?1003l")
            || chunk_text.contains("\u{1b}[?1006l")
        {
            mouse_reporting_mode = false;
        }
        snapshot.bracketed_paste_mode = bracketed_paste_mode;
        snapshot.mouse_reporting_mode = mouse_reporting_mode;
        snapshot.bell = bell;
        snapshot.scrollback_position = {
            let p = parser.lock().await;
            p.screen().scrollback() as u32
        };
        let _ = snapshots.send(snapshot);
    }

    meta_registry().lock().await.remove(&session_id);
}

/// One hop in a jump chain. Empty `host` means "no jump" (sent that way
/// because frb 2.x optional structs are awkward across the bridge).
#[derive(Debug, Clone)]
pub struct JumpHost {
    pub host: String,
    pub port: u16,
    pub username: String,
    pub private_key_path: String,
    pub passphrase: Option<String>,
}

fn jump_to_core(j: JumpHost) -> Option<tindra_core::ssh::JumpParams> {
    jump_to_core_pub(j)
}

/// Re-exported so other FFI modules (e.g. sftp.rs) can convert without
/// duplicating the empty-host check. `pub(crate)` so frb codegen doesn't
/// surface JumpParams to Dart — it stays an internal helper.
pub(crate) fn jump_to_core_pub(j: JumpHost) -> Option<tindra_core::ssh::JumpParams> {
    if j.host.is_empty() {
        None
    } else {
        Some(tindra_core::ssh::JumpParams {
            host: j.host,
            port: j.port,
            username: j.username,
            private_key_path: PathBuf::from(j.private_key_path),
            passphrase: j.passphrase,
        })
    }
}

pub async fn open_shell_pubkey(
    host: String,
    port: u16,
    username: String,
    private_key_path: String,
    passphrase: Option<String>,
    cols: u32,
    rows: u32,
    jump: JumpHost,
) -> Result<u64, String> {
    let id = with_connect_timeout(tindra_core::ssh::open_shell_pubkey(
        host,
        port,
        username,
        PathBuf::from(private_key_path),
        passphrase,
        cols,
        rows,
        jump_to_core(jump),
    ))
    .await?;
    register_session_meta(id, rows, cols, SessionBackend::Ssh).await;
    Ok(id)
}

pub async fn probe_host_key(
    host: String,
    port: u16,
) -> Result<crate::api::profiles::HostKeyCheck, String> {
    with_connect_timeout(tindra_core::ssh::probe_host_key(host, port))
        .await
        .map(|c| crate::api::profiles::HostKeyCheck {
            status: c.status,
            expected: c.expected,
            actual: c.actual,
        })
}

pub async fn probe_host_key_via_jump(
    host: String,
    port: u16,
    jump: JumpHost,
) -> Result<crate::api::profiles::HostKeyCheck, String> {
    let jump = jump_to_core(jump).ok_or_else(|| "jump host is required".to_string())?;
    with_connect_timeout(tindra_core::ssh::probe_host_key_via_jump(jump, host, port))
        .await
        .map(|c| crate::api::profiles::HostKeyCheck {
            status: c.status,
            expected: c.expected,
            actual: c.actual,
        })
}

pub async fn open_shell_password(
    host: String,
    port: u16,
    username: String,
    password: String,
    cols: u32,
    rows: u32,
    jump: JumpHost,
) -> Result<u64, String> {
    let id = with_connect_timeout(tindra_core::ssh::open_shell_password(
        host,
        port,
        username,
        password,
        cols,
        rows,
        jump_to_core(jump),
    ))
    .await?;
    register_session_meta(id, rows, cols, SessionBackend::Ssh).await;
    Ok(id)
}

pub async fn open_shell_keyboard_interactive(
    host: String,
    port: u16,
    username: String,
    responses: Vec<String>,
    cols: u32,
    rows: u32,
    jump: JumpHost,
) -> Result<u64, String> {
    let id = with_connect_timeout(tindra_core::ssh::open_shell_keyboard_interactive(
        host,
        port,
        username,
        responses,
        cols,
        rows,
        jump_to_core(jump),
    ))
    .await?;
    register_session_meta(id, rows, cols, SessionBackend::Ssh).await;
    Ok(id)
}

/// Open a local shell using the platform PTY (Windows ConPTY/winpty,
/// POSIX PTY elsewhere). Empty `shell` uses the platform default.
pub async fn open_local_shell(shell: Option<String>, cols: u32, rows: u32) -> Result<u64, String> {
    let id = tindra_core::pty::open_local_shell(shell, cols, rows)
        .await
        .map_err(|e| e.to_string())?;
    register_session_meta(id, rows, cols, SessionBackend::LocalPty).await;
    Ok(id)
}

#[derive(Debug, Clone)]
pub struct LocalShellEnvVar {
    pub name: String,
    pub value: String,
}

pub async fn open_local_shell_with_options(
    shell: Option<String>,
    cwd: Option<String>,
    env: Vec<LocalShellEnvVar>,
    cols: u32,
    rows: u32,
) -> Result<u64, String> {
    let id = tindra_core::pty::open_local_shell_with_options(
        tindra_core::pty::LocalShellOptions {
            shell,
            cwd: cwd.and_then(|p| {
                let trimmed = p.trim();
                if trimmed.is_empty() {
                    None
                } else {
                    Some(PathBuf::from(trimmed))
                }
            }),
            env: env
                .into_iter()
                .filter(|e| !e.name.trim().is_empty())
                .map(|e| (e.name, e.value))
                .collect(),
        },
        cols,
        rows,
    )
    .await
    .map_err(|e| e.to_string())?;
    register_session_meta(id, rows, cols, SessionBackend::LocalPty).await;
    Ok(id)
}

/// Phase 8c — open a Telnet (raw TCP) session.
pub async fn open_shell_telnet(
    host: String,
    port: u16,
    cols: u32,
    rows: u32,
) -> Result<u64, String> {
    let id = tindra_core::ssh::open_shell_telnet(host, port, cols, rows)
        .await
        .map_err(|e| e.to_string())?;
    register_session_meta(id, rows, cols, SessionBackend::Ssh).await;
    Ok(id)
}

/// Phase 4.0 — open a shell using the local SSH agent for authentication.
pub async fn open_shell_agent(
    host: String,
    port: u16,
    username: String,
    cols: u32,
    rows: u32,
    jump: JumpHost,
) -> Result<u64, String> {
    let id = with_connect_timeout(tindra_core::ssh::open_shell_agent(
        host,
        port,
        username,
        cols,
        rows,
        jump_to_core(jump),
    ))
    .await?;
    register_session_meta(id, rows, cols, SessionBackend::Ssh).await;
    Ok(id)
}

/// Stream of terminal snapshots. A background pump owns the single core output
/// receiver and broadcasts parsed snapshots, so multiple Flutter windows can
/// subscribe to the same live session.
pub async fn shell_output_stream(
    session_id: u64,
    sink: StreamSink<TerminalSnapshot>,
) -> Result<(), String> {
    let mut rx = {
        let reg = meta_registry().lock().await;
        let meta = reg
            .get(&session_id)
            .ok_or_else(|| format!("session {session_id} unknown"))?;
        meta.snapshots.subscribe()
    };

    loop {
        let snapshot = match rx.recv().await {
            Ok(snapshot) => snapshot,
            Err(broadcast::error::RecvError::Lagged(_)) => continue,
            Err(broadcast::error::RecvError::Closed) => break,
        };
        if sink.add(snapshot).is_err() {
            break;
        }
    }
    Ok(())
}

pub async fn shell_set_scrollback(session_id: u64, rows: u32) -> Result<TerminalSnapshot, String> {
    let parser = {
        let reg = meta_registry().lock().await;
        reg.get(&session_id)
            .map(|m| m.parser.clone())
            .ok_or_else(|| format!("session {session_id} unknown"))?
    };
    let mut p = parser.lock().await;
    p.screen_mut().set_scrollback(rows as usize);
    let mut snapshot: TerminalSnapshot = CoreSnapshot::from_parser(&p).into();
    snapshot.scrollback_position = p.screen().scrollback() as u32;
    snapshot.bell = false;
    Ok(snapshot)
}

pub async fn shell_write(session_id: u64, data: Vec<u8>) -> Result<(), String> {
    let backend = {
        let reg = meta_registry().lock().await;
        reg.get(&session_id)
            .map(|m| m.backend)
            .unwrap_or(SessionBackend::Ssh)
    };
    match backend {
        SessionBackend::Ssh => tindra_core::ssh::shell_write(session_id, data)
            .await
            .map_err(|e| e.to_string()),
        SessionBackend::LocalPty => tindra_core::pty::local_shell_write(session_id, data)
            .await
            .map_err(|e| e.to_string()),
    }
}

/// Resize the remote PTY *and* the local vt100 parser so the next snapshot
/// reflects the new geometry.
pub async fn shell_resize(session_id: u64, cols: u32, rows: u32) -> Result<(), String> {
    let backend = {
        let reg = meta_registry().lock().await;
        reg.get(&session_id)
            .map(|m| m.backend)
            .unwrap_or(SessionBackend::Ssh)
    };
    match backend {
        SessionBackend::Ssh => tindra_core::ssh::shell_resize(session_id, cols, rows)
            .await
            .map_err(|e| e.to_string())?,
        SessionBackend::LocalPty => tindra_core::pty::local_shell_resize(session_id, cols, rows)
            .await
            .map_err(|e| e.to_string())?,
    }
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
    let backend = meta_registry()
        .lock()
        .await
        .remove(&session_id)
        .map(|m| m.backend)
        .unwrap_or(SessionBackend::Ssh);
    match backend {
        SessionBackend::Ssh => tindra_core::ssh::shell_close(session_id)
            .await
            .map_err(|e| e.to_string()),
        SessionBackend::LocalPty => tindra_core::pty::local_shell_close(session_id)
            .await
            .map_err(|e| e.to_string()),
    }
}

#[cfg(test)]
mod tests {
    use super::chunk_has_terminal_bell;

    #[test]
    fn detects_terminal_bell_control_byte() {
        assert!(chunk_has_terminal_bell(b"build complete\x07"));
        assert!(chunk_has_terminal_bell(&[0x1b, b']', b'0', 0x07]));
    }

    #[test]
    fn ignores_chunks_without_terminal_bell() {
        assert!(!chunk_has_terminal_bell(b"plain output"));
        assert!(!chunk_has_terminal_bell(&[0x1b, b'[', b'?']));
    }
}
