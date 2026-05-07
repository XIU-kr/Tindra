// SPDX-License-Identifier: Apache-2.0
//
// tindra-store — encrypted local store.
//
// Phase 2 ships a plain-JSON profile store at the platform's user-data dir.
// Phase 4 will migrate this to SQLCipher with the user's age master key.
//
// Storage layout:
//   <data_dir>/Tindra/profiles.json    — list of saved connection profiles
//
// where <data_dir> is:
//   Windows: %APPDATA%
//   macOS:   ~/Library/Application Support
//   Linux:   ~/.config

use std::path::PathBuf;
use std::sync::OnceLock;
use std::time::{SystemTime, UNIX_EPOCH};

use serde::{Deserialize, Serialize};
use tokio::sync::Mutex;

#[derive(Debug, thiserror::Error)]
pub enum StoreError {
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("json: {0}")]
    Json(#[from] serde_json::Error),
    #[error("no platform data directory available")]
    NoDataDir,
    #[error("profile {0} not found")]
    NotFound(String),
    #[error("host key changed for {host}:{port}: expected {expected}, got {actual}")]
    HostKeyChanged {
        host: String,
        port: u16,
        expected: String,
        actual: String,
    },
}

/// User-editable settings: theme, terminal font, and shortcut bindings.
/// Persisted alongside profiles in the same data dir as `settings.json`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Settings {
    /// "dark" (default), "light", or "system".
    #[serde(default = "default_theme")]
    pub theme: String,
    /// Monospaced font family for the terminal grid.
    #[serde(default = "default_font_family")]
    pub font_family: String,
    /// Terminal font size in logical pixels.
    #[serde(default = "default_font_size")]
    pub font_size: f32,
    /// Quake mode global hotkey (e.g. "F12"). Empty disables.
    #[serde(default)]
    pub quake_hotkey: String,
    /// "system" (default), "en", or "ko".
    #[serde(default = "default_locale")]
    pub locale: String,
}

impl Default for Settings {
    fn default() -> Self {
        Settings {
            theme: default_theme(),
            font_family: default_font_family(),
            font_size: default_font_size(),
            quake_hotkey: String::new(),
            locale: default_locale(),
        }
    }
}

fn default_theme() -> String {
    "dark".to_string()
}
fn default_font_family() -> String {
    "Consolas".to_string()
}
fn default_font_size() -> f32 {
    13.0
}
fn default_locale() -> String {
    "system".to_string()
}

/// One saved SSH connection. Passphrases are NOT persisted — Phase 4 will add
/// per-profile passphrase entries in the OS keychain.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Profile {
    /// Stable id (`p_<unix_ms>_<counter>`). Set automatically on first save.
    pub id: String,
    /// User-facing label, e.g. "prod web 1".
    pub name: String,
    pub host: String,
    pub port: u16,
    pub username: String,
    pub private_key_path: String,
    /// Optional free-form notes.
    #[serde(default)]
    pub notes: String,
    /// "key" (default) uses `private_key_path`; "agent" uses the local
    /// SSH agent. Other values are reserved.
    #[serde(default = "default_auth_method")]
    pub auth_method: String,
    /// Optional jump host. Empty `jump_host` means no jump.
    #[serde(default)]
    pub jump_host: String,
    #[serde(default = "default_port")]
    pub jump_port: u16,
    #[serde(default)]
    pub jump_username: String,
    #[serde(default)]
    pub jump_private_key_path: String,
    /// "ssh" (default), "telnet". "serial" reserved for future work.
    #[serde(default = "default_transport")]
    pub transport: String,
}

fn default_transport() -> String {
    "ssh".to_string()
}

fn default_auth_method() -> String {
    "key".to_string()
}

fn default_port() -> u16 {
    22
}

/// Trust-on-first-use host key record. `fingerprint` is the stable SHA256
/// string produced by russh/ssh-key, e.g. `SHA256:...`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HostKeyEntry {
    pub host: String,
    pub port: u16,
    pub fingerprint: String,
    pub first_seen_unix_ms: u128,
    pub last_seen_unix_ms: u128,
}

#[derive(Debug, Serialize, Deserialize, Default)]
struct OnDisk {
    #[serde(default)]
    profiles: Vec<Profile>,
    #[serde(default)]
    host_keys: Vec<HostKeyEntry>,
}

struct Inner {
    path: PathBuf,
    data: OnDisk,
}

fn store() -> &'static Mutex<Option<Inner>> {
    static S: OnceLock<Mutex<Option<Inner>>> = OnceLock::new();
    S.get_or_init(|| Mutex::new(None))
}

fn default_path() -> Result<PathBuf, StoreError> {
    let dir = dirs::data_dir().ok_or(StoreError::NoDataDir)?;
    let app_dir = dir.join("Tindra");
    Ok(app_dir.join("profiles.json"))
}

async fn ensure_loaded() -> Result<tokio::sync::MutexGuard<'static, Option<Inner>>, StoreError> {
    let mut guard = store().lock().await;
    if guard.is_none() {
        let path = default_path()?;
        if let Some(parent) = path.parent() {
            tokio::fs::create_dir_all(parent).await?;
        }
        let data: OnDisk = match tokio::fs::read(&path).await {
            Ok(bytes) => serde_json::from_slice(&bytes)?,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => OnDisk::default(),
            Err(e) => return Err(e.into()),
        };
        *guard = Some(Inner { path, data });
    }
    Ok(guard)
}

async fn persist(inner: &Inner) -> Result<(), StoreError> {
    let bytes = serde_json::to_vec_pretty(&inner.data)?;
    // Atomic-ish: write to temp then rename.
    let tmp = inner.path.with_extension("json.tmp");
    tokio::fs::write(&tmp, &bytes).await?;
    tokio::fs::rename(&tmp, &inner.path).await?;
    Ok(())
}

fn fresh_id() -> String {
    static COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
    let ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0);
    let n = COUNTER.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
    format!("p_{ms}_{n}")
}

/// Return all saved profiles, sorted by name.
pub async fn list_profiles() -> Result<Vec<Profile>, StoreError> {
    let guard = ensure_loaded().await?;
    let mut out = guard.as_ref().unwrap().data.profiles.clone();
    out.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    Ok(out)
}

/// Insert a new profile (if `id` is empty) or overwrite an existing one.
/// Returns the profile as stored (with assigned id).
pub async fn upsert_profile(mut profile: Profile) -> Result<Profile, StoreError> {
    let mut guard = ensure_loaded().await?;
    let inner = guard.as_mut().unwrap();
    if profile.id.is_empty() {
        profile.id = fresh_id();
    }
    if let Some(existing) = inner.data.profiles.iter_mut().find(|p| p.id == profile.id) {
        *existing = profile.clone();
    } else {
        inner.data.profiles.push(profile.clone());
    }
    persist(inner).await?;
    Ok(profile)
}

/// Delete a profile by id. Idempotent.
pub async fn delete_profile(id: String) -> Result<(), StoreError> {
    let mut guard = ensure_loaded().await?;
    let inner = guard.as_mut().unwrap();
    let before = inner.data.profiles.len();
    inner.data.profiles.retain(|p| p.id != id);
    if inner.data.profiles.len() != before {
        persist(inner).await?;
    }
    Ok(())
}

/// Path of the JSON file (for diagnostics / "open data dir" UI).
pub async fn store_path() -> Result<PathBuf, StoreError> {
    let guard = ensure_loaded().await?;
    Ok(guard.as_ref().unwrap().path.clone())
}

// ---------------------------------------------------------------------------
// Host key trust-on-first-use store
// ---------------------------------------------------------------------------

fn now_unix_ms() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0)
}

/// Verify a server key fingerprint using trust-on-first-use semantics.
///
/// - First time seeing `host:port`: stores the fingerprint and returns Ok.
/// - Subsequent matching key: updates `last_seen_unix_ms` and returns Ok.
/// - Changed key: returns `HostKeyChanged` and does not overwrite.
pub async fn verify_or_trust_host_key(
    host: String,
    port: u16,
    fingerprint: String,
) -> Result<(), StoreError> {
    let mut guard = ensure_loaded().await?;
    let inner = guard.as_mut().unwrap();
    if let Some(existing) = inner
        .data
        .host_keys
        .iter_mut()
        .find(|k| k.host == host && k.port == port)
    {
        if existing.fingerprint != fingerprint {
            return Err(StoreError::HostKeyChanged {
                host,
                port,
                expected: existing.fingerprint.clone(),
                actual: fingerprint,
            });
        }
        existing.last_seen_unix_ms = now_unix_ms();
    } else {
        let now = now_unix_ms();
        inner.data.host_keys.push(HostKeyEntry {
            host,
            port,
            fingerprint,
            first_seen_unix_ms: now,
            last_seen_unix_ms: now,
        });
    }
    persist(inner).await?;
    Ok(())
}

pub async fn list_host_keys() -> Result<Vec<HostKeyEntry>, StoreError> {
    let guard = ensure_loaded().await?;
    let mut out = guard.as_ref().unwrap().data.host_keys.clone();
    out.sort_by(|a, b| (a.host.to_lowercase(), a.port).cmp(&(b.host.to_lowercase(), b.port)));
    Ok(out)
}

pub async fn delete_host_key(host: String, port: u16) -> Result<(), StoreError> {
    let mut guard = ensure_loaded().await?;
    let inner = guard.as_mut().unwrap();
    let before = inner.data.host_keys.len();
    inner
        .data
        .host_keys
        .retain(|k| !(k.host == host && k.port == port));
    if inner.data.host_keys.len() != before {
        persist(inner).await?;
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// Phase 7 — settings (theme / font / hotkeys)
// ---------------------------------------------------------------------------

fn settings_path() -> Result<PathBuf, StoreError> {
    let dir = dirs::data_dir().ok_or(StoreError::NoDataDir)?;
    Ok(dir.join("Tindra").join("settings.json"))
}

pub async fn load_settings() -> Result<Settings, StoreError> {
    let path = settings_path()?;
    if let Some(parent) = path.parent() {
        tokio::fs::create_dir_all(parent).await?;
    }
    match tokio::fs::read(&path).await {
        Ok(bytes) => Ok(serde_json::from_slice(&bytes)?),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(Settings::default()),
        Err(e) => Err(e.into()),
    }
}

pub async fn save_settings(settings: Settings) -> Result<(), StoreError> {
    let path = settings_path()?;
    if let Some(parent) = path.parent() {
        tokio::fs::create_dir_all(parent).await?;
    }
    let bytes = serde_json::to_vec_pretty(&settings)?;
    let tmp = path.with_extension("json.tmp");
    tokio::fs::write(&tmp, &bytes).await?;
    tokio::fs::rename(&tmp, &path).await?;
    Ok(())
}
