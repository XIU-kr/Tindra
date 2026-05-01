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
    #[error("ssh-agent unavailable: {0}")]
    AgentUnavailable(String),
    #[error("ssh-agent has no identities — run `ssh-add` first")]
    AgentNoIdentities,
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
// Phase 4.1 — jump host (proxy via direct-tcpip)
// ---------------------------------------------------------------------------

/// One hop in a jump-host chain. The current implementation supports a
/// single hop. Authentication is private-key only — a future revision may
/// allow agent-based jump auth.
#[derive(Debug, Clone)]
pub struct JumpParams {
    pub host: String,
    pub port: u16,
    pub username: String,
    pub private_key_path: PathBuf,
    pub passphrase: Option<String>,
}

/// Open an SSH connection through a jump host. The jump session must stay
/// alive for as long as the target session — the caller is responsible for
/// keeping the returned `(jump_handle, target_handle)` together.
async fn connect_via_jump(
    jump: JumpParams,
    target_host: String,
    target_port: u16,
    config: Arc<client::Config>,
) -> Result<(Handle<TofuHandler>, Handle<TofuHandler>), SshError> {
    let jump_key = russh::keys::load_secret_key(&jump.private_key_path, jump.passphrase.as_deref())?;
    let mut jump_handle: Handle<TofuHandler> =
        client::connect(config.clone(), (jump.host.as_str(), jump.port), TofuHandler).await?;
    let authed = jump_handle
        .authenticate_publickey(jump.username, Arc::new(jump_key))
        .await?;
    if !authed {
        return Err(SshError::AuthFailed);
    }

    let channel = jump_handle
        .channel_open_direct_tcpip(target_host, target_port as u32, "127.0.0.1", 0)
        .await?;
    let stream = channel.into_stream();
    let target_handle: Handle<TofuHandler> =
        client::connect_stream(config, stream, TofuHandler).await?;
    Ok((jump_handle, target_handle))
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
    /// When the connection went through a jump host, we keep its handle
    /// alive here — dropping it tears down the proxied stream.
    _jump_handle: Option<Handle<TofuHandler>>,
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
/// `jump` makes the connection traverse a jump host via direct-tcpip; pass
/// `None` for a direct connection.
pub async fn open_shell_pubkey(
    host: String,
    port: u16,
    username: String,
    private_key_path: PathBuf,
    passphrase: Option<String>,
    cols: u32,
    rows: u32,
    jump: Option<JumpParams>,
) -> Result<u64, SshError> {
    let key_pair = russh::keys::load_secret_key(&private_key_path, passphrase.as_deref())?;
    let config = Arc::new(client::Config {
        inactivity_timeout: Some(Duration::from_secs(300)),
        ..Default::default()
    });

    let (mut handle, jump_handle) = match jump {
        Some(j) => {
            let (jh, th) = connect_via_jump(j, host.clone(), port, config).await?;
            (th, Some(jh))
        }
        None => (
            client::connect(config, (host.as_str(), port), TofuHandler).await?,
            None,
        ),
    };

    let authed = handle
        .authenticate_publickey(username, Arc::new(key_pair))
        .await?;
    if !authed {
        return Err(SshError::AuthFailed);
    }

    spawn_shell_worker(handle, jump_handle, cols, rows).await
}

/// Common tail of every open_shell_*: open a session channel, request PTY +
/// shell, spawn the read/write select loop, and register the result.
async fn spawn_shell_worker(
    handle: Handle<TofuHandler>,
    jump_handle: Option<Handle<TofuHandler>>,
    cols: u32,
    rows: u32,
) -> Result<u64, SshError> {
    let mut channel = handle.channel_open_session().await?;
    channel
        .request_pty(false, "xterm-256color", cols, rows, 0, 0, &[])
        .await?;
    channel.request_shell(false).await?;

    let (output_tx, output_rx) = mpsc::unbounded_channel::<Vec<u8>>();
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
            _jump_handle: jump_handle,
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
// Reusable connect+auth helpers (used by tindra-ssh and tindra-sftp)
// ---------------------------------------------------------------------------

/// Returns an authenticated SSH session, optionally going through a jump
/// host. `jump_handle` (the second tuple element) must be kept alive for
/// the session's lifetime when present — dropping it tears down the proxy.
pub async fn open_session_pubkey(
    host: String,
    port: u16,
    username: String,
    private_key_path: PathBuf,
    passphrase: Option<String>,
    jump: Option<JumpParams>,
) -> Result<(Handle<TofuHandler>, Option<Handle<TofuHandler>>), SshError> {
    let key_pair = russh::keys::load_secret_key(&private_key_path, passphrase.as_deref())?;
    let config = Arc::new(client::Config {
        inactivity_timeout: Some(Duration::from_secs(300)),
        ..Default::default()
    });
    let (mut handle, jump_handle) = match jump {
        Some(j) => {
            let (jh, th) = connect_via_jump(j, host, port, config).await?;
            (th, Some(jh))
        }
        None => (
            client::connect(config, (host.as_str(), port), TofuHandler).await?,
            None,
        ),
    };
    if !handle.authenticate_publickey(username, Arc::new(key_pair)).await? {
        return Err(SshError::AuthFailed);
    }
    Ok((handle, jump_handle))
}

pub async fn open_session_agent(
    host: String,
    port: u16,
    username: String,
    jump: Option<JumpParams>,
) -> Result<(Handle<TofuHandler>, Option<Handle<TofuHandler>>), SshError> {
    let config = Arc::new(client::Config {
        inactivity_timeout: Some(Duration::from_secs(300)),
        ..Default::default()
    });
    let (mut handle, jump_handle) = match jump {
        Some(j) => {
            let (jh, th) = connect_via_jump(j, host, port, config).await?;
            (th, Some(jh))
        }
        None => (
            client::connect(config, (host.as_str(), port), TofuHandler).await?,
            None,
        ),
    };
    authenticate_via_agent(&mut handle, &username).await?;
    Ok((handle, jump_handle))
}

// Re-export for downstream crates that want to plug into the same handler.
pub type SshHandle = Handle<TofuHandler>;

// ---------------------------------------------------------------------------
// Phase 5 — local port forwarding (-L)
// ---------------------------------------------------------------------------

/// One active local-forward listener. Cancelling its task tears down the
/// TcpListener and drops the SSH session held in the worker.
pub struct ForwardInfo {
    pub id: u64,
    pub local_addr: String,
    pub local_port: u16,
    pub remote_host: String,
    pub remote_port: u16,
}

struct ActiveForward {
    info: ForwardInfo,
    cancel: tokio::sync::oneshot::Sender<()>,
}

fn forward_registry() -> &'static Mutex<HashMap<u64, ActiveForward>> {
    static R: OnceLock<Mutex<HashMap<u64, ActiveForward>>> = OnceLock::new();
    R.get_or_init(|| Mutex::new(HashMap::new()))
}

fn next_forward_id() -> u64 {
    static N: AtomicU64 = AtomicU64::new(1);
    N.fetch_add(1, Ordering::SeqCst)
}

/// Start a local-forward: anything that connects to (local_addr, local_port)
/// gets its bytes shovelled to (remote_host, remote_port) via the SSH server.
/// `handle` and `jump_handle` are kept alive inside the background task.
pub async fn start_local_forward(
    handle: SshHandle,
    jump_handle: Option<SshHandle>,
    local_addr: String,
    local_port: u16,
    remote_host: String,
    remote_port: u16,
) -> Result<u64, SshError> {
    let listener = tokio::net::TcpListener::bind(format!("{local_addr}:{local_port}"))
        .await?;
    let actual_port = listener.local_addr()?.port();
    let (cancel_tx, mut cancel_rx) = tokio::sync::oneshot::channel::<()>();
    let id = next_forward_id();
    let remote_host_clone = remote_host.clone();
    let shared_handle = Arc::new(handle);

    tokio::spawn(async move {
        let _keep_jump = jump_handle;
        loop {
            tokio::select! {
                _ = &mut cancel_rx => break,
                accept = listener.accept() => {
                    let (stream, peer) = match accept {
                        Ok(v) => v,
                        Err(_) => break,
                    };
                    let h = shared_handle.clone();
                    let host = remote_host_clone.clone();
                    tokio::spawn(async move {
                        let channel = match h
                            .channel_open_direct_tcpip(
                                host,
                                remote_port as u32,
                                peer.ip().to_string(),
                                peer.port() as u32,
                            )
                            .await
                        {
                            Ok(c) => c,
                            Err(_) => return,
                        };
                        let mut ch_stream = channel.into_stream();
                        let mut tcp_stream = stream;
                        let _ = tokio::io::copy_bidirectional(
                            &mut tcp_stream,
                            &mut ch_stream,
                        )
                        .await;
                    });
                }
            }
        }
    });

    forward_registry().lock().await.insert(
        id,
        ActiveForward {
            info: ForwardInfo {
                id,
                local_addr,
                local_port: actual_port,
                remote_host,
                remote_port,
            },
            cancel: cancel_tx,
        },
    );
    Ok(id)
}

pub async fn list_forwards() -> Vec<ForwardInfo> {
    let guard = forward_registry().lock().await;
    guard
        .values()
        .map(|f| ForwardInfo {
            id: f.info.id,
            local_addr: f.info.local_addr.clone(),
            local_port: f.info.local_port,
            remote_host: f.info.remote_host.clone(),
            remote_port: f.info.remote_port,
        })
        .collect()
}

pub async fn stop_forward(id: u64) -> Result<(), SshError> {
    if let Some(f) = forward_registry().lock().await.remove(&id) {
        let _ = f.cancel.send(());
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// Phase 4.0 — agent-based auth
// ---------------------------------------------------------------------------

/// Open an interactive shell using the local SSH agent for authentication.
///
/// Windows: connects to the OpenSSH Agent named pipe
/// (`\\.\pipe\openssh-ssh-agent`). The `ssh-agent` service must be running
/// and at least one key must have been `ssh-add`ed.
///
/// Unix: uses `SSH_AUTH_SOCK`.
pub async fn open_shell_agent(
    host: String,
    port: u16,
    username: String,
    cols: u32,
    rows: u32,
    jump: Option<JumpParams>,
) -> Result<u64, SshError> {
    let config = Arc::new(client::Config {
        inactivity_timeout: Some(Duration::from_secs(300)),
        ..Default::default()
    });

    let (mut handle, jump_handle) = match jump {
        Some(j) => {
            let (jh, th) = connect_via_jump(j, host.clone(), port, config).await?;
            (th, Some(jh))
        }
        None => (
            client::connect(config, (host.as_str(), port), TofuHandler).await?,
            None,
        ),
    };

    authenticate_via_agent(&mut handle, &username).await?;
    spawn_shell_worker(handle, jump_handle, cols, rows).await
}

/// Walks every identity the local agent advertises and tries each one against
/// the server. Returns Ok on the first success; AuthFailed if none work.
async fn authenticate_via_agent(
    handle: &mut Handle<TofuHandler>,
    username: &str,
) -> Result<(), SshError> {
    #[cfg(windows)]
    let mut agent = {
        use russh::keys::agent::client::AgentClient;
        use tokio::net::windows::named_pipe::ClientOptions;
        // Retry briefly: ERROR_PIPE_BUSY (231) is common when something else
        // is mid-handshake with the agent.
        let mut last_err: Option<std::io::Error> = None;
        let mut stream = None;
        for _ in 0..5 {
            match ClientOptions::new().open(r"\\.\pipe\openssh-ssh-agent") {
                Ok(s) => { stream = Some(s); break; }
                Err(e) if e.raw_os_error() == Some(231) => {
                    tokio::time::sleep(Duration::from_millis(50)).await;
                    last_err = Some(e);
                }
                Err(e) => { last_err = Some(e); break; }
            }
        }
        let stream = stream.ok_or_else(|| {
            SshError::AgentUnavailable(
                last_err
                    .map(|e| e.to_string())
                    .unwrap_or_else(|| "openssh-ssh-agent named pipe not available".into()),
            )
        })?;
        AgentClient::connect(stream)
    };
    #[cfg(unix)]
    let mut agent = {
        use russh::keys::agent::client::AgentClient;
        AgentClient::connect_env()
            .await
            .map_err(|e| SshError::AgentUnavailable(e.to_string()))?
    };

    let identities = agent
        .request_identities()
        .await
        .map_err(|e| SshError::AgentUnavailable(e.to_string()))?;
    if identities.is_empty() {
        return Err(SshError::AgentNoIdentities);
    }

    for key in identities {
        let (returned_agent, result) = handle
            .authenticate_future(username.to_string(), key, agent)
            .await;
        agent = returned_agent;
        if matches!(result, Ok(true)) {
            return Ok(());
        }
    }
    Err(SshError::AuthFailed)
}

// ---------------------------------------------------------------------------
// Server-key handler
// ---------------------------------------------------------------------------

/// Trust-on-first-use handler. Phase 1 hardening will replace this with a
/// known_hosts-backed implementation that prompts on fingerprint changes.
pub struct TofuHandler;

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
