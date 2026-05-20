// SPDX-License-Identifier: Apache-2.0
//
// tindra-pty — local PTY for "Local Shell" tabs.
// Wraps wezterm's portable-pty so callers see a single ergonomic API
// regardless of ConPTY (Win 10+), winpty (legacy Win), or POSIX PTY.

use std::collections::HashMap;
use std::io::{Read, Write};
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex as StdMutex, OnceLock};

use portable_pty::{native_pty_system, CommandBuilder, MasterPty, PtySize};
use tokio::sync::{mpsc, Mutex};

#[derive(Debug, thiserror::Error)]
pub enum PtyError {
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("pty: {0}")]
    Pty(String),
    #[error("local shell {0} not found")]
    NotFound(u64),
}

struct ActiveLocalShell {
    master: Box<dyn MasterPty + Send>,
    writer: Arc<StdMutex<Box<dyn Write + Send>>>,
    output_rx: Mutex<Option<mpsc::UnboundedReceiver<Vec<u8>>>>,
    _reader_thread: std::thread::JoinHandle<()>,
    child: Box<dyn portable_pty::Child + Send + Sync>,
}

#[derive(Debug, Clone, Default)]
pub struct LocalShellOptions {
    pub shell: Option<String>,
    pub cwd: Option<PathBuf>,
    pub env: Vec<(String, String)>,
}

fn registry() -> &'static Mutex<HashMap<u64, ActiveLocalShell>> {
    static R: OnceLock<Mutex<HashMap<u64, ActiveLocalShell>>> = OnceLock::new();
    R.get_or_init(|| Mutex::new(HashMap::new()))
}

fn next_id() -> u64 {
    static N: AtomicU64 = AtomicU64::new(1_000_000);
    N.fetch_add(1, Ordering::SeqCst)
}

fn default_shell() -> String {
    #[cfg(windows)]
    {
        // Prefer PowerShell over COMSPEC/cmd.exe: ConPTY exposes Unicode text
        // cleanly and Korean input/output behaves much better than an OEM
        // codepage cmd session. Users can still pass an explicit shell path.
        "powershell.exe".to_string()
    }
    #[cfg(not(windows))]
    {
        std::env::var("SHELL").unwrap_or_else(|_| "/bin/sh".to_string())
    }
}

#[cfg(windows)]
fn configure_windows_shell(cmd: &mut CommandBuilder, shell: &str) {
    let lower = shell.to_lowercase();
    if lower.ends_with("powershell.exe")
        || lower.ends_with("pwsh.exe")
        || lower == "powershell"
        || lower == "pwsh"
    {
        cmd.arg("-NoLogo");
        // Make native PowerShell commands and common child tools prefer UTF-8.
        // This is especially important for Korean paths/output on Windows.
        cmd.env("PYTHONUTF8", "1");
        cmd.env("DOTNET_SYSTEM_CONSOLE_ALLOW_ANSI_COLOR_REDIRECTION", "1");
    } else if lower.ends_with("cmd.exe") || lower == "cmd" {
        // If a caller explicitly asks for cmd, switch to UTF-8 codepage before
        // yielding control. `/k` keeps the shell interactive.
        cmd.arg("/k");
        cmd.arg("chcp 65001 > nul");
    }
}

#[cfg(not(windows))]
fn configure_windows_shell(_cmd: &mut CommandBuilder, _shell: &str) {}

/// Open a local interactive shell backed by the platform PTY implementation
/// (Windows ConPTY/winpty, POSIX PTY elsewhere). Empty `shell` means platform
/// default: `%COMSPEC%`/PowerShell on Windows, `$SHELL`/`/bin/sh` on Unix.
pub async fn open_local_shell(
    shell: Option<String>,
    cols: u32,
    rows: u32,
) -> Result<u64, PtyError> {
    open_local_shell_with_options(
        LocalShellOptions {
            shell,
            cwd: None,
            env: Vec::new(),
        },
        cols,
        rows,
    )
    .await
}

pub async fn open_local_shell_with_options(
    options: LocalShellOptions,
    cols: u32,
    rows: u32,
) -> Result<u64, PtyError> {
    let shell = options
        .shell
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(default_shell);
    let pty_system = native_pty_system();
    let pair = pty_system
        .openpty(PtySize {
            rows: rows as u16,
            cols: cols as u16,
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(|e| PtyError::Pty(e.to_string()))?;

    let mut cmd = CommandBuilder::new(shell.clone());
    configure_windows_shell(&mut cmd, &shell);
    if let Some(cwd) = options.cwd {
        cmd.cwd(cwd);
    }
    for (name, value) in options.env {
        if !name.trim().is_empty() {
            cmd.env(name, value);
        }
    }
    let child = pair
        .slave
        .spawn_command(cmd)
        .map_err(|e| PtyError::Pty(e.to_string()))?;
    drop(pair.slave);

    let mut reader = pair
        .master
        .try_clone_reader()
        .map_err(|e| PtyError::Pty(e.to_string()))?;
    let writer = Arc::new(StdMutex::new(
        pair.master
            .take_writer()
            .map_err(|e| PtyError::Pty(e.to_string()))?,
    ));
    let (output_tx, output_rx) = mpsc::unbounded_channel::<Vec<u8>>();

    let reader_thread = std::thread::spawn(move || {
        let mut buf = [0u8; 8192];
        loop {
            match reader.read(&mut buf) {
                Ok(0) => break,
                Ok(n) => {
                    if output_tx.send(buf[..n].to_vec()).is_err() {
                        break;
                    }
                }
                Err(_) => break,
            }
        }
        let _ = output_tx.send(b"\r\n[local shell closed]\r\n".to_vec());
    });

    let id = next_id();
    registry().lock().await.insert(
        id,
        ActiveLocalShell {
            master: pair.master,
            writer,
            output_rx: Mutex::new(Some(output_rx)),
            _reader_thread: reader_thread,
            child,
        },
    );
    Ok(id)
}

pub async fn take_output_receiver(session_id: u64) -> Option<mpsc::UnboundedReceiver<Vec<u8>>> {
    let guard = registry().lock().await;
    let session = guard.get(&session_id)?;
    let mut rx_guard = session.output_rx.lock().await;
    rx_guard.take()
}

pub async fn local_shell_write(session_id: u64, data: Vec<u8>) -> Result<(), PtyError> {
    let guard = registry().lock().await;
    let session = guard
        .get(&session_id)
        .ok_or(PtyError::NotFound(session_id))?;
    let mut writer = session
        .writer
        .lock()
        .map_err(|_| PtyError::Pty("local shell writer lock poisoned".into()))?;
    writer.write_all(&data)?;
    writer.flush()?;
    Ok(())
}

pub async fn local_shell_resize(session_id: u64, cols: u32, rows: u32) -> Result<(), PtyError> {
    let guard = registry().lock().await;
    let session = guard
        .get(&session_id)
        .ok_or(PtyError::NotFound(session_id))?;
    session
        .master
        .resize(PtySize {
            rows: rows as u16,
            cols: cols as u16,
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(|e| PtyError::Pty(e.to_string()))?;
    Ok(())
}

pub async fn local_shell_close(session_id: u64) -> Result<(), PtyError> {
    if let Some(mut session) = registry().lock().await.remove(&session_id) {
        let _ = session.child.kill();
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// Phase 8d framework — ZMODEM detection
// ---------------------------------------------------------------------------

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
