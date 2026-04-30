// SPDX-License-Identifier: Apache-2.0
//
// tindra-sftp — SFTP client built on russh-sftp.
//
// Phase 6 ships a single-session SFTP browser (open + list + download +
// upload + mkdir + delete). Pause/resume + concurrent transfer queue is
// future work.
//
// One SFTP session = one fresh SSH connection over which we request the
// `sftp` subsystem. We deliberately don't share a connection with the
// shell session: keeping them separate avoids head-of-line blocking
// between interactive output and SFTP transfers, at the cost of one extra
// SSH handshake.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::OnceLock;

use russh_sftp::client::SftpSession;
use tokio::io::AsyncWriteExt;
use tindra_ssh::{open_session_agent, open_session_pubkey, JumpParams, SshError, SshHandle};
use tokio::sync::Mutex;

#[derive(Debug, thiserror::Error)]
pub enum SftpError {
    #[error("ssh: {0}")]
    Ssh(#[from] SshError),
    #[error("sftp: {0}")]
    Sftp(#[from] russh_sftp::client::error::Error),
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("russh: {0}")]
    Russh(#[from] russh::Error),
    #[error("session {0} not found")]
    NotFound(u64),
}

/// One row in a directory listing.
#[derive(Debug, Clone)]
pub struct DirEntry {
    pub name: String,
    pub is_dir: bool,
    pub is_symlink: bool,
    pub size: u64,
    /// Unix epoch seconds when known; 0 otherwise.
    pub mtime: u64,
    /// Unix permission bits when known; 0 otherwise.
    pub permissions: u32,
}

struct ActiveSftp {
    sftp: SftpSession,
    /// Keep these alive so the underlying SSH session stays open.
    _ssh_handle: SshHandle,
    _jump_handle: Option<SshHandle>,
}

fn registry() -> &'static Mutex<HashMap<u64, ActiveSftp>> {
    static R: OnceLock<Mutex<HashMap<u64, ActiveSftp>>> = OnceLock::new();
    R.get_or_init(|| Mutex::new(HashMap::new()))
}

fn next_id() -> u64 {
    static N: AtomicU64 = AtomicU64::new(1);
    N.fetch_add(1, Ordering::SeqCst)
}

async fn start_sftp(
    handle: SshHandle,
    jump_handle: Option<SshHandle>,
) -> Result<u64, SftpError> {
    let channel = handle.channel_open_session().await?;
    channel.request_subsystem(true, "sftp").await?;
    let stream = channel.into_stream();
    let sftp = SftpSession::new(stream).await?;
    let id = next_id();
    registry().lock().await.insert(
        id,
        ActiveSftp {
            sftp,
            _ssh_handle: handle,
            _jump_handle: jump_handle,
        },
    );
    Ok(id)
}

pub async fn open_sftp_pubkey(
    host: String,
    port: u16,
    username: String,
    private_key_path: PathBuf,
    passphrase: Option<String>,
    jump: Option<JumpParams>,
) -> Result<u64, SftpError> {
    let (handle, jump_handle) =
        open_session_pubkey(host, port, username, private_key_path, passphrase, jump).await?;
    start_sftp(handle, jump_handle).await
}

pub async fn open_sftp_agent(
    host: String,
    port: u16,
    username: String,
    jump: Option<JumpParams>,
) -> Result<u64, SftpError> {
    let (handle, jump_handle) = open_session_agent(host, port, username, jump).await?;
    start_sftp(handle, jump_handle).await
}

pub async fn list_dir(session_id: u64, path: String) -> Result<Vec<DirEntry>, SftpError> {
    let guard = registry().lock().await;
    let session = guard.get(&session_id).ok_or(SftpError::NotFound(session_id))?;
    let read = session.sftp.read_dir(path).await?;
    let mut out = Vec::new();
    for entry in read {
        let meta = entry.metadata();
        let ft = meta.file_type();
        out.push(DirEntry {
            name: entry.file_name(),
            is_dir: ft.is_dir(),
            is_symlink: ft.is_symlink(),
            size: meta.size.unwrap_or(0),
            mtime: meta.mtime.unwrap_or(0) as u64,
            permissions: meta.permissions.unwrap_or(0),
        });
    }
    out.sort_by(|a, b| match (a.is_dir, b.is_dir) {
        (true, false) => std::cmp::Ordering::Less,
        (false, true) => std::cmp::Ordering::Greater,
        _ => a.name.to_lowercase().cmp(&b.name.to_lowercase()),
    });
    Ok(out)
}

pub async fn download(
    session_id: u64,
    remote_path: String,
    local_path: PathBuf,
) -> Result<u64, SftpError> {
    let bytes = {
        let guard = registry().lock().await;
        let session = guard.get(&session_id).ok_or(SftpError::NotFound(session_id))?;
        session.sftp.read(remote_path).await?
    };
    if let Some(parent) = local_path.parent() {
        tokio::fs::create_dir_all(parent).await?;
    }
    let len = bytes.len() as u64;
    tokio::fs::write(&local_path, bytes).await?;
    Ok(len)
}

pub async fn upload(
    session_id: u64,
    local_path: PathBuf,
    remote_path: String,
) -> Result<u64, SftpError> {
    let bytes = tokio::fs::read(&local_path).await?;
    let len = bytes.len() as u64;
    let guard = registry().lock().await;
    let session = guard.get(&session_id).ok_or(SftpError::NotFound(session_id))?;
    // sftp.write() opens with WRITE only, so it can't create new files.
    // Use create() which truncates and creates as needed.
    let mut file = session.sftp.create(remote_path).await?;
    file.write_all(&bytes).await?;
    file.shutdown().await?;
    Ok(len)
}

pub async fn make_dir(session_id: u64, path: String) -> Result<(), SftpError> {
    let guard = registry().lock().await;
    let session = guard.get(&session_id).ok_or(SftpError::NotFound(session_id))?;
    session.sftp.create_dir(path).await?;
    Ok(())
}

pub async fn remove(session_id: u64, path: String, is_dir: bool) -> Result<(), SftpError> {
    let guard = registry().lock().await;
    let session = guard.get(&session_id).ok_or(SftpError::NotFound(session_id))?;
    if is_dir {
        session.sftp.remove_dir(path).await?;
    } else {
        session.sftp.remove_file(path).await?;
    }
    Ok(())
}

pub async fn close(session_id: u64) -> Result<(), SftpError> {
    if let Some(session) = registry().lock().await.remove(&session_id) {
        let _ = session.sftp.close().await;
    }
    Ok(())
}

/// Best-effort: ask the server for the user's home directory.
pub async fn home_dir(session_id: u64) -> Result<String, SftpError> {
    let guard = registry().lock().await;
    let session = guard.get(&session_id).ok_or(SftpError::NotFound(session_id))?;
    Ok(session.sftp.canonicalize(".".to_string()).await?)
}
