// FFI surface for Phase 6 SFTP browser.

use std::path::PathBuf;

use crate::api::ssh::{jump_to_core_pub, JumpHost};

#[derive(Debug, Clone)]
pub struct SftpEntry {
    pub name: String,
    pub is_dir: bool,
    pub is_symlink: bool,
    pub size: u64,
    pub mtime: u64,
    pub permissions: u32,
}

impl From<tindra_core::sftp::DirEntry> for SftpEntry {
    fn from(e: tindra_core::sftp::DirEntry) -> Self {
        SftpEntry {
            name: e.name,
            is_dir: e.is_dir,
            is_symlink: e.is_symlink,
            size: e.size,
            mtime: e.mtime,
            permissions: e.permissions,
        }
    }
}

pub async fn open_sftp_pubkey(
    host: String,
    port: u16,
    username: String,
    private_key_path: String,
    passphrase: Option<String>,
    jump: JumpHost,
) -> Result<u64, String> {
    tindra_core::sftp::open_sftp_pubkey(
        host,
        port,
        username,
        PathBuf::from(private_key_path),
        passphrase,
        jump_to_core_pub(jump),
    )
    .await
    .map_err(|e| e.to_string())
}

pub async fn open_sftp_agent(
    host: String,
    port: u16,
    username: String,
    jump: JumpHost,
) -> Result<u64, String> {
    tindra_core::sftp::open_sftp_agent(host, port, username, jump_to_core_pub(jump))
        .await
        .map_err(|e| e.to_string())
}

pub async fn sftp_list(session_id: u64, path: String) -> Result<Vec<SftpEntry>, String> {
    tindra_core::sftp::list_dir(session_id, path)
        .await
        .map(|v| v.into_iter().map(SftpEntry::from).collect())
        .map_err(|e| e.to_string())
}

pub async fn sftp_download(
    session_id: u64,
    remote_path: String,
    local_path: String,
) -> Result<u64, String> {
    tindra_core::sftp::download(session_id, remote_path, PathBuf::from(local_path))
        .await
        .map_err(|e| e.to_string())
}

pub async fn sftp_upload(
    session_id: u64,
    local_path: String,
    remote_path: String,
) -> Result<u64, String> {
    tindra_core::sftp::upload(session_id, PathBuf::from(local_path), remote_path)
        .await
        .map_err(|e| e.to_string())
}

pub async fn sftp_make_dir(session_id: u64, path: String) -> Result<(), String> {
    tindra_core::sftp::make_dir(session_id, path)
        .await
        .map_err(|e| e.to_string())
}

pub async fn sftp_remove(session_id: u64, path: String, is_dir: bool) -> Result<(), String> {
    tindra_core::sftp::remove(session_id, path, is_dir)
        .await
        .map_err(|e| e.to_string())
}

pub async fn sftp_close(session_id: u64) -> Result<(), String> {
    tindra_core::sftp::close(session_id)
        .await
        .map_err(|e| e.to_string())
}

pub async fn sftp_home(session_id: u64) -> Result<String, String> {
    tindra_core::sftp::home_dir(session_id)
        .await
        .map_err(|e| e.to_string())
}
