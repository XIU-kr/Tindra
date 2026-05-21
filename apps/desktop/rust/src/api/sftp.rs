// FFI surface for Phase 6 SFTP browser.

use std::collections::HashMap;
use std::future::Future;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, MutexGuard, OnceLock};
use std::time::Duration;

use crate::api::ssh::{jump_to_core_pub, JumpHost};
use crate::frb_generated::StreamSink;

const SFTP_CONNECT_TIMEOUT: Duration = Duration::from_secs(20);
const SFTP_CONNECT_TIMEOUT_MESSAGE: &str = "connection timed out after 20 seconds";

async fn with_connect_timeout<T, E, Fut>(future: Fut) -> Result<T, String>
where
    Fut: Future<Output = Result<T, E>>,
    E: std::fmt::Display,
{
    tokio::time::timeout(SFTP_CONNECT_TIMEOUT, future)
        .await
        .map_err(|_| SFTP_CONNECT_TIMEOUT_MESSAGE.to_string())?
        .map_err(|e| e.to_string())
}

fn transfer_cancellations() -> &'static Mutex<HashMap<String, Arc<AtomicBool>>> {
    static CANCELLATIONS: OnceLock<Mutex<HashMap<String, Arc<AtomicBool>>>> = OnceLock::new();
    CANCELLATIONS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn transfer_cancellations_lock() -> MutexGuard<'static, HashMap<String, Arc<AtomicBool>>> {
    transfer_cancellations()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

fn register_transfer(id: String) -> Arc<AtomicBool> {
    let flag = Arc::new(AtomicBool::new(false));
    transfer_cancellations_lock().insert(id, flag.clone());
    flag
}

fn unregister_transfer(id: &str) {
    transfer_cancellations_lock().remove(id);
}

pub fn cancel_sftp_transfer(transfer_id: String) -> bool {
    let flag = transfer_cancellations_lock().get(&transfer_id).cloned();
    if let Some(flag) = flag {
        flag.store(true, Ordering::SeqCst);
        true
    } else {
        false
    }
}

#[derive(Debug, Clone)]
pub struct SftpEntry {
    pub name: String,
    pub is_dir: bool,
    pub is_symlink: bool,
    pub size: u64,
    pub mtime: u64,
    pub permissions: u32,
}

#[derive(Debug, Clone)]
pub struct SftpTransferProgress {
    pub bytes_transferred: u64,
    pub total_bytes: u64,
    pub done: bool,
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
    with_connect_timeout(tindra_core::sftp::open_sftp_pubkey(
        host,
        port,
        username,
        PathBuf::from(private_key_path),
        passphrase,
        jump_to_core_pub(jump),
    ))
    .await
}

pub async fn open_sftp_agent(
    host: String,
    port: u16,
    username: String,
    jump: JumpHost,
) -> Result<u64, String> {
    with_connect_timeout(tindra_core::sftp::open_sftp_agent(
        host,
        port,
        username,
        jump_to_core_pub(jump),
    ))
    .await
}

pub async fn open_sftp_password(
    host: String,
    port: u16,
    username: String,
    password: String,
    jump: JumpHost,
) -> Result<u64, String> {
    with_connect_timeout(tindra_core::sftp::open_sftp_password(
        host,
        port,
        username,
        password,
        jump_to_core_pub(jump),
    ))
    .await
}

pub async fn open_sftp_keyboard_interactive(
    host: String,
    port: u16,
    username: String,
    responses: Vec<String>,
    jump: JumpHost,
) -> Result<u64, String> {
    with_connect_timeout(tindra_core::sftp::open_sftp_keyboard_interactive(
        host,
        port,
        username,
        responses,
        jump_to_core_pub(jump),
    ))
    .await
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

pub async fn sftp_download_with_progress(
    transfer_id: String,
    session_id: u64,
    remote_path: String,
    local_path: String,
    resume: bool,
    sink: StreamSink<SftpTransferProgress>,
) -> Result<(), String> {
    let cancel_flag = register_transfer(transfer_id.clone());
    let sink_for_progress = sink.clone();
    let transferred = tindra_core::sftp::download_with_progress(
        session_id,
        remote_path,
        PathBuf::from(local_path),
        resume,
        move |bytes_transferred, total_bytes| {
            if cancel_flag.load(Ordering::SeqCst) {
                return false;
            }
            sink_for_progress
                .add(SftpTransferProgress {
                    bytes_transferred,
                    total_bytes,
                    done: false,
                })
                .is_ok()
        },
    )
    .await
    .map_err(|e| {
        unregister_transfer(&transfer_id);
        e.to_string()
    })?;
    unregister_transfer(&transfer_id);
    let _ = sink.add(SftpTransferProgress {
        bytes_transferred: transferred,
        total_bytes: transferred,
        done: true,
    });
    Ok(())
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

pub async fn sftp_upload_with_progress(
    transfer_id: String,
    session_id: u64,
    local_path: String,
    remote_path: String,
    sink: StreamSink<SftpTransferProgress>,
) -> Result<(), String> {
    let cancel_flag = register_transfer(transfer_id.clone());
    let sink_for_progress = sink.clone();
    let transferred = tindra_core::sftp::upload_with_progress(
        session_id,
        PathBuf::from(local_path),
        remote_path,
        move |bytes_transferred, total_bytes| {
            if cancel_flag.load(Ordering::SeqCst) {
                return false;
            }
            sink_for_progress
                .add(SftpTransferProgress {
                    bytes_transferred,
                    total_bytes,
                    done: false,
                })
                .is_ok()
        },
    )
    .await
    .map_err(|e| {
        unregister_transfer(&transfer_id);
        e.to_string()
    })?;
    unregister_transfer(&transfer_id);
    let _ = sink.add(SftpTransferProgress {
        bytes_transferred: transferred,
        total_bytes: transferred,
        done: true,
    });
    Ok(())
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
