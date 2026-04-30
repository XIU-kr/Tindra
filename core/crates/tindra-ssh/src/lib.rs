// SPDX-License-Identifier: Apache-2.0
//
// tindra-ssh — SSH transport built on `russh`.
//
// Phase 1.0 surface: a single `run_command` entry point that opens an SSH
// session, authenticates with an ed25519/RSA private key, runs one command
// via `exec`, and returns the combined stdout+stderr plus the exit code.
//
// Future phases will add:
//   - long-lived sessions with shell + PTY channels (interactive terminal)
//   - input streaming from Flutter
//   - port forwarding (local/remote/SOCKS)
//   - host-key verification against ~/.ssh/known_hosts (today: TOFU=Ok(true))
//   - jump-host chains, agent-proxied auth, password fallback

use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use russh::client::Handle;
use russh::{client, ChannelMsg, Disconnect};

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
}

/// Output of a one-shot remote command.
#[derive(Debug, Clone)]
pub struct CommandOutput {
    pub exit_code: i32,
    pub stdout: String,
    pub stderr: String,
}

/// Run a single command on a remote host using ed25519/RSA private-key auth.
/// Returns once the channel reports `ExitStatus` (or EOF).
///
/// `host` may be an IP, DNS name, or alias resolved by the OS.
/// `private_key_path` is a filesystem path to an OpenSSH-format private key.
/// `passphrase` decrypts an encrypted key; pass `None` for unencrypted keys.
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
    // some servers (notably Windows OpenSSH) send Eof BEFORE ExitStatus, and
    // breaking early would leave exit_code unset.
    while let Some(msg) = channel.wait().await {
        match msg {
            ChannelMsg::Data { ref data } => {
                stdout.push_str(&String::from_utf8_lossy(data));
            }
            // ext == 1 → SSH_EXTENDED_DATA_STDERR
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

    // Some servers omit ExitStatus entirely (rare but legal — RFC 4254
    // doesn't require it). Surface -1 as "unknown" and let the caller decide.
    Ok(CommandOutput {
        exit_code: exit_code.unwrap_or(-1),
        stdout,
        stderr,
    })
}

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
