// FFI surface for SSH operations. Forwards into tindra-core (which forwards
// into tindra-ssh / russh). The bridge crate keeps its own CommandOutput so
// flutter_rust_bridge codegen has a local type to map to Dart.

use std::path::PathBuf;

use crate::frb_generated::StreamSink;

// ---------------------------------------------------------------------------
// Phase 1.0 — one-shot exec
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct CommandOutput {
    pub exit_code: i32,
    pub stdout: String,
    pub stderr: String,
}

/// Connect, run one command, return its combined output and exit code.
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
// Phase 1.1 — interactive shell (split into two functions because frb
// collapses any function with a StreamSink param to return Stream<T>,
// dropping the actual return value. So we open in one call, then subscribe
// to output in a separate call.)
// ---------------------------------------------------------------------------

/// Open a long-lived shell over SSH with a PTY. Returns a session id; subscribe
/// to output by calling `shell_output_stream(session_id)`.
pub async fn open_shell_pubkey(
    host: String,
    port: u16,
    username: String,
    private_key_path: String,
    passphrase: Option<String>,
    cols: u32,
    rows: u32,
) -> Result<u64, String> {
    tindra_core::ssh::open_shell_pubkey(
        host,
        port,
        username,
        PathBuf::from(private_key_path),
        passphrase,
        cols,
        rows,
    )
    .await
    .map_err(|e| e.to_string())
}

/// Stream of bytes coming out of the remote shell (stdout + stderr merged).
/// Call this exactly once per session, immediately after `open_shell_pubkey`.
/// The stream ends when the SSH session closes.
pub async fn shell_output_stream(
    session_id: u64,
    sink: StreamSink<Vec<u8>>,
) -> Result<(), String> {
    let mut rx = tindra_core::ssh::take_output_receiver(session_id)
        .await
        .ok_or_else(|| {
            format!("session {session_id} not found or already subscribed")
        })?;
    while let Some(chunk) = rx.recv().await {
        if sink.add(chunk).is_err() {
            break;
        }
    }
    Ok(())
}

/// Write input bytes (typed characters, \r, control codes) to a shell.
pub async fn shell_write(session_id: u64, data: Vec<u8>) -> Result<(), String> {
    tindra_core::ssh::shell_write(session_id, data)
        .await
        .map_err(|e| e.to_string())
}

/// Tell the remote PTY the terminal was resized.
pub async fn shell_resize(session_id: u64, cols: u32, rows: u32) -> Result<(), String> {
    tindra_core::ssh::shell_resize(session_id, cols, rows)
        .await
        .map_err(|e| e.to_string())
}

/// Close a shell session. Idempotent.
pub async fn shell_close(session_id: u64) -> Result<(), String> {
    tindra_core::ssh::shell_close(session_id)
        .await
        .map_err(|e| e.to_string())
}
