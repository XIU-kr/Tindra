// SPDX-License-Identifier: Apache-2.0
//
// tindra-ssh — SSH transport built on `russh`.
//
// Public surface:
//   - `run_command_pubkey()` (Phase 1.0): one-shot SSH exec.
//   - `open_shell_pubkey()` / `shell_write()` / `shell_resize()` /
//     `shell_close()` (Phase 1.1): long-lived interactive shell session
//     with a PTY, output streamed via tokio mpsc and input fed back in.
//
// Future phases will add port forwarding, host-key verification against
// known_hosts, jump-host chains, agent-proxied auth, password fallback.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, OnceLock};
use std::time::Duration;

use async_trait::async_trait;
use russh::client::Handle;
use russh::{client, ChannelMsg, Disconnect};
use tokio::sync::{mpsc, Mutex};

#[derive(Debug, thiserror::Error)]
pub enum SshError {
    #[error("ssh transport: {0}")]
    Russh(#[from] russh::Error),
    #[error("key load: {0}")]
    Key(#[from] russh::keys::Error),
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("authentication failed")]
    AuthFailed,
    #[error("session {0} not found or already closed")]
    SessionNotFound(u64),
}

/// Output of a one-shot remote command (`run_command_pubkey`).
#[derive(Debug, Clone)]
pub struct CommandOutput {
    pub exit_code: i32,
    pub stdout: String,
    pub stderr: String,
}

// ---------------------------------------------------------------------------
// Phase 1.0 — one-shot exec
// ---------------------------------------------------------------------------

/// Run a single command on a remote host using ed25519/RSA private-key auth.
pub async fn run_command_pubkey(
    host: String,
    port: u16,
    username: String,
    private_key_path: PathBuf,
    passphrase: Option<String>,
    command: String,
) -> Result<CommandOutput, SshError> {
    let key_pair = russh::keys::load_secret_key(&private_key_path, passphrase.as_deref())?;
    let config = Arc::new(client::Config {
        inactivity_timeout: Some(Duration::from_secs(60)),
        ..Default::default()
    });

    let mut session: Handle<TofuHandler> =
        client::connect(config, (host.as_str(), port), TofuHandler).await?;
    let authed = session
        .authenticate_publickey(username, Arc::new(key_pair))
        .await?;
    if !authed {
        return Err(SshError::AuthFailed);
    }

    let mut channel = session.channel_open_session().await?;
    channel.exec(true, command).await?;

    let mut stdout = String::new();
    let mut stderr = String::new();
    let mut exit_code: Option<i32> = None;

    // Drain channel until it closes naturally. Don't break on Eof/Close —
    // Windows OpenSSH sends Eof BEFORE ExitStatus.
    while let Some(msg) = channel.wait().await {
        match msg {
            ChannelMsg::Data { ref data } => {
                stdout.push_str(&String::from_utf8_lossy(data));
            }
            ChannelMsg::ExtendedData { ref data, ext: _ } => {
                stderr.push_str(&String::from_utf8_lossy(data));
            }
            ChannelMsg::ExitStatus { exit_status } => {
                exit_code = Some(exit_status as i32);
            }
            _ => {}
        }
    }

    let _ = session
        .disconnect(Disconnect::ByApplication, "", "en")
        .await;

    Ok(CommandOutput {
        exit_code: exit_code.unwrap_or(-1),
        stdout,
        stderr,
    })
}

// ---------------------------------------------------------------------------
// Phase 1.1 — interactive shell session
// ---------------------------------------------------------------------------

/// Internal command sent from the public API into a session's worker task.
enum ShellCommand {
    Data(Vec<u8>),
    Resize { cols: u32, rows: u32 },
    Close,
}

/// State held in the global registry for an active shell.
struct ActiveShell {
    write_tx: mpsc::UnboundedSender<ShellCommand>,
    /// Output receiver. Taken out exactly once by `take_output_receiver`
    /// (called from the bridge crate when Dart subscribes to the stream).
    /// `None` after subscription.
    output_rx: Mutex<Option<mpsc::UnboundedReceiver<Vec<u8>>>>,
    /// Worker task owns the russh Handle and Channel; we keep its
    /// JoinHandle so it survives until the session is closed.
    _task: tokio::task::JoinHandle<()>,
}

fn registry() -> &'static Mutex<HashMap<u64, ActiveShell>> {
    static REGISTRY: OnceLock<Mutex<HashMap<u64, ActiveShell>>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(HashMap::new()))
}

fn next_session_id() -> u64 {
    static N: AtomicU64 = AtomicU64::new(1);
    N.fetch_add(1, Ordering::SeqCst)
}

/// Open an interactive shell session over SSH. Returns a session id used by
/// `shell_write`, `shell_resize`, `shell_close`, and `take_output_receiver`.
///
/// Output is buffered in an unbounded mpsc until the caller takes the
/// receiver (typically from the bridge crate, which then pumps it into a
/// Dart `Stream`). Buffering means a slow subscriber doesn't lose data,
/// at the cost of unbounded memory if Dart never subscribes.
pub async fn open_shell_pubkey(
    host: String,
    port: u16,
    username: String,
    private_key_path: PathBuf,
    passphrase: Option<String>,
    cols: u32,
    rows: u32,
) -> Result<u64, SshError> {
    let (output_tx, output_rx) = mpsc::unbounded_channel::<Vec<u8>>();
    let key_pair = russh::keys::load_secret_key(&private_key_path, passphrase.as_deref())?;
    let config = Arc::new(client::Config {
        inactivity_timeout: Some(Duration::from_secs(300)),
        ..Default::default()
    });

    let mut handle: Handle<TofuHandler> =
        client::connect(config, (host.as_str(), port), TofuHandler).await?;
    let authed = handle
        .authenticate_publickey(username, Arc::new(key_pair))
        .await?;
    if !authed {
        return Err(SshError::AuthFailed);
    }

    let mut channel = handle.channel_open_session().await?;
    channel
        .request_pty(false, "xterm-256color", cols, rows, 0, 0, &[])
        .await?;
    channel.request_shell(false).await?;

    let (write_tx, mut write_rx) = mpsc::unbounded_channel::<ShellCommand>();
    let id = next_session_id();

    let task = tokio::spawn(async move {
        loop {
            tokio::select! {
                msg = channel.wait() => {
                    match msg {
                        Some(ChannelMsg::Data { data }) => {
                            if output_tx.send(data.to_vec()).is_err() { break; }
                        }
                        Some(ChannelMsg::ExtendedData { data, .. }) => {
                            if output_tx.send(data.to_vec()).is_err() { break; }
                        }
                        Some(ChannelMsg::Eof) | Some(ChannelMsg::Close) | None => break,
                        _ => {}
                    }
                }
                Some(cmd) = write_rx.recv() => {
                    match cmd {
                        ShellCommand::Data(data) => {
                            if channel.data(&data[..]).await.is_err() { break; }
                        }
                        ShellCommand::Resize { cols, rows } => {
                            let _ = channel.window_change(cols, rows, 0, 0).await;
                        }
                        ShellCommand::Close => break,
                    }
                }
            }
        }

        // Final marker so the UI can show "[disconnected]".
        let _ = output_tx.send(b"\r\n[connection closed]\r\n".to_vec());
        let _ = handle
            .disconnect(Disconnect::ByApplication, "", "en")
            .await;
    });

    registry().lock().await.insert(
        id,
        ActiveShell {
            write_tx,
            output_rx: Mutex::new(Some(output_rx)),
            _task: task,
        },
    );
    Ok(id)
}

/// Take the output receiver for a session. Returns `None` if the session
/// doesn't exist or another caller has already taken it. Intended to be
/// called once, by the FFI bridge layer, immediately after `open_shell_pubkey`.
pub async fn take_output_receiver(
    session_id: u64,
) -> Option<mpsc::UnboundedReceiver<Vec<u8>>> {
    let guard = registry().lock().await;
    let session = guard.get(&session_id)?;
    let mut rx_guard = session.output_rx.lock().await;
    rx_guard.take()
}

/// Write user input bytes into the shell's stdin.
pub async fn shell_write(session_id: u64, data: Vec<u8>) -> Result<(), SshError> {
    let guard = registry().lock().await;
    let session = guard
        .get(&session_id)
        .ok_or(SshError::SessionNotFound(session_id))?;
    session
        .write_tx
        .send(ShellCommand::Data(data))
        .map_err(|_| SshError::SessionNotFound(session_id))?;
    Ok(())
}

/// Tell the remote side the terminal was resized. PTY-bound apps like vim
/// listen for SIGWINCH and reflow.
pub async fn shell_resize(session_id: u64, cols: u32, rows: u32) -> Result<(), SshError> {
    let guard = registry().lock().await;
    let session = guard
        .get(&session_id)
        .ok_or(SshError::SessionNotFound(session_id))?;
    session
        .write_tx
        .send(ShellCommand::Resize { cols, rows })
        .map_err(|_| SshError::SessionNotFound(session_id))?;
    Ok(())
}

/// Close a shell session. Idempotent — closing an unknown id is a no-op.
pub async fn shell_close(session_id: u64) -> Result<(), SshError> {
    let mut guard = registry().lock().await;
    if let Some(session) = guard.remove(&session_id) {
        let _ = session.write_tx.send(ShellCommand::Close);
        // We deliberately don't await the task; the disconnect handshake
        // can take a few hundred ms and we don't want to block the caller.
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// Server-key handler
// ---------------------------------------------------------------------------

/// Trust-on-first-use handler. Phase 1 hardening will replace this with a
/// known_hosts-backed implementation that prompts on fingerprint changes.
struct TofuHandler;

#[async_trait]
impl client::Handler for TofuHandler {
    type Error = russh::Error;

    async fn check_server_key(
        &mut self,
        _server_public_key: &russh::keys::key::PublicKey,
    ) -> Result<bool, Self::Error> {
        Ok(true)
    }
}
