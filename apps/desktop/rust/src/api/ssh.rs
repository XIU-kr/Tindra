// FFI surface for SSH operations. Forwards into tindra-core (which forwards
// into tindra-ssh / russh). The bridge crate keeps its own CommandOutput so
// flutter_rust_bridge codegen has a local type to map to Dart.

use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct CommandOutput {
    pub exit_code: i32,
    pub stdout: String,
    pub stderr: String,
}

/// Connect to an SSH server with an OpenSSH private key, run one command,
/// return its combined output and exit code.
///
/// Errors surface as Dart exceptions with the message intact.
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
