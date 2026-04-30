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
}

fn default_auth_method() -> String {
    "key".to_string()
}

#[derive(Debug, Serialize, Deserialize, Default)]
struct OnDisk {
    #[serde(default)]
    profiles: Vec<Profile>,
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
