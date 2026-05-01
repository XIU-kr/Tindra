// FFI surface for Phase 5 port forwarding (local -L only for the MVP).

use std::path::PathBuf;

use crate::api::ssh::{jump_to_core_pub, JumpHost};

#[derive(Debug, Clone)]
pub struct PortForward {
    pub id: u64,
    pub local_addr: String,
    pub local_port: u16,
    pub remote_host: String,
    pub remote_port: u16,
}

impl From<tindra_core::ssh::ForwardInfo> for PortForward {
    fn from(f: tindra_core::ssh::ForwardInfo) -> Self {
        PortForward {
            id: f.id,
            local_addr: f.local_addr,
            local_port: f.local_port,
            remote_host: f.remote_host,
            remote_port: f.remote_port,
        }
    }
}

pub async fn open_local_forward_pubkey(
    host: String,
    port: u16,
    username: String,
    private_key_path: String,
    passphrase: Option<String>,
    jump: JumpHost,
    local_addr: String,
    local_port: u16,
    remote_host: String,
    remote_port: u16,
) -> Result<u64, String> {
    let (handle, jump_handle) = tindra_core::ssh::open_session_pubkey(
        host,
        port,
        username,
        PathBuf::from(private_key_path),
        passphrase,
        jump_to_core_pub(jump),
    )
    .await
    .map_err(|e| e.to_string())?;
    tindra_core::ssh::start_local_forward(
        handle,
        jump_handle,
        local_addr,
        local_port,
        remote_host,
        remote_port,
    )
    .await
    .map_err(|e| e.to_string())
}

pub async fn open_local_forward_agent(
    host: String,
    port: u16,
    username: String,
    jump: JumpHost,
    local_addr: String,
    local_port: u16,
    remote_host: String,
    remote_port: u16,
) -> Result<u64, String> {
    let (handle, jump_handle) =
        tindra_core::ssh::open_session_agent(host, port, username, jump_to_core_pub(jump))
            .await
            .map_err(|e| e.to_string())?;
    tindra_core::ssh::start_local_forward(
        handle,
        jump_handle,
        local_addr,
        local_port,
        remote_host,
        remote_port,
    )
    .await
    .map_err(|e| e.to_string())
}

pub async fn list_forwards() -> Vec<PortForward> {
    tindra_core::ssh::list_forwards()
        .await
        .into_iter()
        .map(PortForward::from)
        .collect()
}

pub async fn stop_forward(id: u64) -> Result<(), String> {
    tindra_core::ssh::stop_forward(id)
        .await
        .map_err(|e| e.to_string())
}
