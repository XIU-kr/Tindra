// SPDX-License-Identifier: Apache-2.0
//
// tindra-store: local profile/settings/host-key store and OS-backed secrets.
//
// Profiles, settings, and host keys are stored as JSON under the platform data
// directory. Interactive passwords and passphrases are not persisted in
// profiles; secret APIs delegate to OS-backed storage where available.
//
// Storage layout:
//   <data_dir>/Tindra/profiles.json    list of saved connection profiles
//   <data_dir>/Tindra/settings.json    user-editable settings
//   <data_dir>/Tindra/host_keys.json   trusted SSH host-key fingerprints
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
    #[error("secret storage is unsupported on this platform")]
    SecretStorageUnsupported,
    #[error("secret storage failed: {0}")]
    SecretStorage(String),
    #[error("store was not loaded after initialization")]
    StoreNotLoaded,
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
    /// Optional local shell executable/command. Empty uses platform default.
    #[serde(default)]
    pub local_shell: String,
    /// Optional working directory for local shell tabs.
    #[serde(default)]
    pub local_shell_cwd: String,
    /// Newline-separated NAME=VALUE entries for local shell tabs.
    #[serde(default)]
    pub local_shell_env: String,
}

impl Default for Settings {
    fn default() -> Self {
        Settings {
            theme: default_theme(),
            font_family: default_font_family(),
            font_size: default_font_size(),
            quake_hotkey: String::new(),
            locale: default_locale(),
            local_shell: String::new(),
            local_shell_cwd: String::new(),
            local_shell_env: String::new(),
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

/// Passwords, keyboard-interactive responses, and private-key passphrases are
/// not persisted in profiles.
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
    /// SSH agent, or a session-only password prompt.
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
    /// "ssh" (default) or "telnet".
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

#[derive(Debug, Clone)]
pub struct HostKeyCheck {
    /// "new", "trusted", or "changed".
    pub status: String,
    pub expected: String,
    pub actual: String,
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
    let inner = guard.as_ref().ok_or(StoreError::StoreNotLoaded)?;
    let mut out = inner.data.profiles.clone();
    out.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    Ok(out)
}

/// Insert a new profile (if `id` is empty) or overwrite an existing one.
/// Returns the profile as stored (with assigned id).
pub async fn upsert_profile(mut profile: Profile) -> Result<Profile, StoreError> {
    let mut guard = ensure_loaded().await?;
    let inner = guard.as_mut().ok_or(StoreError::StoreNotLoaded)?;
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
    let inner = guard.as_mut().ok_or(StoreError::StoreNotLoaded)?;
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
    Ok(guard
        .as_ref()
        .ok_or(StoreError::StoreNotLoaded)?
        .path
        .clone())
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

/// Verify a server key fingerprint using the explicit trust store.
///
/// - Matching trusted key: updates `last_seen_unix_ms` and returns Ok.
/// - New key: returns `HostKeyChanged` with an empty expected fingerprint.
/// - Changed key: returns `HostKeyChanged` and does not overwrite.
pub async fn verify_trusted_host_key(
    host: String,
    port: u16,
    fingerprint: String,
) -> Result<(), StoreError> {
    let mut guard = ensure_loaded().await?;
    let inner = guard.as_mut().ok_or(StoreError::StoreNotLoaded)?;
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
        return Err(StoreError::HostKeyChanged {
            host,
            port,
            expected: String::new(),
            actual: fingerprint,
        });
    }
    persist(inner).await?;
    Ok(())
}

/// Explicitly trust a host key after the UI has shown it to the user.
///
/// This stores new keys and refreshes matching existing keys. Changed keys are
/// still rejected; callers must delete the old key before trusting a different
/// fingerprint.
pub async fn trust_host_key(
    host: String,
    port: u16,
    fingerprint: String,
) -> Result<(), StoreError> {
    let mut guard = ensure_loaded().await?;
    let inner = guard.as_mut().ok_or(StoreError::StoreNotLoaded)?;
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

/// Check a server key fingerprint without mutating trusted-key storage.
///
/// This is the safe preflight primitive for an explicit host-key approval UI:
/// the caller can show "first key seen" or "changed key" before deciding
/// whether to trust or reject. The existing TOFU verifier remains available for
/// current connection paths until the UI-driven flow is wired end to end.
pub async fn check_host_key(
    host: String,
    port: u16,
    fingerprint: String,
) -> Result<HostKeyCheck, StoreError> {
    let guard = ensure_loaded().await?;
    let inner = guard.as_ref().ok_or(StoreError::StoreNotLoaded)?;
    let existing = inner
        .data
        .host_keys
        .iter()
        .find(|k| k.host == host && k.port == port);
    Ok(match existing {
        Some(existing) if existing.fingerprint == fingerprint => HostKeyCheck {
            status: "trusted".to_string(),
            expected: existing.fingerprint.clone(),
            actual: fingerprint,
        },
        Some(existing) => HostKeyCheck {
            status: "changed".to_string(),
            expected: existing.fingerprint.clone(),
            actual: fingerprint,
        },
        None => HostKeyCheck {
            status: "new".to_string(),
            expected: String::new(),
            actual: fingerprint,
        },
    })
}

pub async fn list_host_keys() -> Result<Vec<HostKeyEntry>, StoreError> {
    let guard = ensure_loaded().await?;
    let inner = guard.as_ref().ok_or(StoreError::StoreNotLoaded)?;
    let mut out = inner.data.host_keys.clone();
    out.sort_by(|a, b| (a.host.to_lowercase(), a.port).cmp(&(b.host.to_lowercase(), b.port)));
    Ok(out)
}

pub async fn delete_host_key(host: String, port: u16) -> Result<(), StoreError> {
    let mut guard = ensure_loaded().await?;
    let inner = guard.as_mut().ok_or(StoreError::StoreNotLoaded)?;
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
// Phase 7 ??settings (theme / font / hotkeys)
// ---------------------------------------------------------------------------

fn settings_path() -> Result<PathBuf, StoreError> {
    let dir = dirs::data_dir().ok_or(StoreError::NoDataDir)?;
    Ok(dir.join("Tindra").join("settings.json"))
}

pub fn settings_file_path() -> Result<PathBuf, StoreError> {
    settings_path()
}

pub fn expected_log_dir() -> Result<PathBuf, StoreError> {
    let dir = dirs::data_local_dir()
        .or_else(dirs::data_dir)
        .ok_or(StoreError::NoDataDir)?;
    Ok(dir.join("Tindra").join("logs"))
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

#[derive(Debug, Serialize, Deserialize)]
struct SecretRecord {
    backend: String,
    ciphertext: Vec<u8>,
}

#[cfg(any(target_os = "macos", target_os = "ios", target_os = "linux"))]
const SECRET_SERVICE_NAME: &str = "Tindra";

#[cfg(windows)]
fn secrets_dir() -> Result<PathBuf, StoreError> {
    let dir = dirs::data_dir().ok_or(StoreError::NoDataDir)?;
    Ok(dir.join("Tindra").join("secrets"))
}

#[cfg(windows)]
fn secret_path(name: &str) -> Result<PathBuf, StoreError> {
    let safe: String = name
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '-' || c == '_' || c == '.' {
                c
            } else {
                '_'
            }
        })
        .collect();
    Ok(secrets_dir()?.join(format!("{safe}.json")))
}

#[cfg(windows)]
pub async fn save_secret(name: String, secret: String) -> Result<(), StoreError> {
    let encrypted = protect_secret(secret.as_bytes())?;
    let path = secret_path(&name)?;
    if let Some(parent) = path.parent() {
        tokio::fs::create_dir_all(parent).await?;
    }
    let record = SecretRecord {
        backend: secret_backend().to_string(),
        ciphertext: encrypted,
    };
    let bytes = serde_json::to_vec_pretty(&record)?;
    let tmp = path.with_extension("json.tmp");
    tokio::fs::write(&tmp, &bytes).await?;
    tokio::fs::rename(&tmp, &path).await?;
    Ok(())
}

#[cfg(any(target_os = "macos", target_os = "ios", target_os = "linux"))]
pub async fn save_secret(name: String, secret: String) -> Result<(), StoreError> {
    let entry = keyring::Entry::new(SECRET_SERVICE_NAME, &name)
        .map_err(|e| StoreError::SecretStorage(e.to_string()))?;
    entry
        .set_password(&secret)
        .map_err(|e| StoreError::SecretStorage(e.to_string()))
}

#[cfg(not(any(windows, target_os = "macos", target_os = "ios", target_os = "linux")))]
pub async fn save_secret(_name: String, _secret: String) -> Result<(), StoreError> {
    Err(StoreError::SecretStorageUnsupported)
}

#[cfg(windows)]
pub async fn load_secret(name: String) -> Result<Option<String>, StoreError> {
    let path = secret_path(&name)?;
    let bytes = match tokio::fs::read(&path).await {
        Ok(bytes) => bytes,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(e) => return Err(e.into()),
    };
    let record: SecretRecord = serde_json::from_slice(&bytes)?;
    if record.backend != secret_backend() {
        return Err(StoreError::SecretStorage(format!(
            "secret backend mismatch: stored {}, current {}",
            record.backend,
            secret_backend()
        )));
    }
    let plaintext = unprotect_secret(&record.ciphertext)?;
    Ok(Some(
        String::from_utf8(plaintext).map_err(|e| StoreError::SecretStorage(e.to_string()))?,
    ))
}

#[cfg(any(target_os = "macos", target_os = "ios", target_os = "linux"))]
pub async fn load_secret(name: String) -> Result<Option<String>, StoreError> {
    let entry = keyring::Entry::new(SECRET_SERVICE_NAME, &name)
        .map_err(|e| StoreError::SecretStorage(e.to_string()))?;
    match entry.get_password() {
        Ok(secret) => Ok(Some(secret)),
        Err(keyring::Error::NoEntry) => Ok(None),
        Err(e) => Err(StoreError::SecretStorage(e.to_string())),
    }
}

#[cfg(not(any(windows, target_os = "macos", target_os = "ios", target_os = "linux")))]
pub async fn load_secret(_name: String) -> Result<Option<String>, StoreError> {
    Err(StoreError::SecretStorageUnsupported)
}

#[cfg(windows)]
pub async fn delete_secret(name: String) -> Result<(), StoreError> {
    let path = secret_path(&name)?;
    match tokio::fs::remove_file(path).await {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(e.into()),
    }
}

#[cfg(any(target_os = "macos", target_os = "ios", target_os = "linux"))]
pub async fn delete_secret(name: String) -> Result<(), StoreError> {
    let entry = keyring::Entry::new(SECRET_SERVICE_NAME, &name)
        .map_err(|e| StoreError::SecretStorage(e.to_string()))?;
    match entry.delete_credential() {
        Ok(()) | Err(keyring::Error::NoEntry) => Ok(()),
        Err(e) => Err(StoreError::SecretStorage(e.to_string())),
    }
}

#[cfg(not(any(windows, target_os = "macos", target_os = "ios", target_os = "linux")))]
pub async fn delete_secret(_name: String) -> Result<(), StoreError> {
    Err(StoreError::SecretStorageUnsupported)
}

pub fn secret_backend() -> &'static str {
    #[cfg(windows)]
    {
        "dpapi"
    }
    #[cfg(target_os = "macos")]
    {
        "keychain"
    }
    #[cfg(target_os = "ios")]
    {
        "ios-keychain"
    }
    #[cfg(target_os = "linux")]
    {
        "libsecret"
    }
    #[cfg(target_os = "android")]
    {
        "android-keystore"
    }
    #[cfg(not(any(
        windows,
        target_os = "macos",
        target_os = "ios",
        target_os = "linux",
        target_os = "android"
    )))]
    {
        "unsupported"
    }
}

#[cfg(windows)]
fn protect_secret(secret: &[u8]) -> Result<Vec<u8>, StoreError> {
    use windows_sys::Win32::Foundation::LocalFree;
    use windows_sys::Win32::Security::Cryptography::{
        CryptProtectData, CRYPTPROTECT_UI_FORBIDDEN, CRYPT_INTEGER_BLOB,
    };

    let mut input = CRYPT_INTEGER_BLOB {
        cbData: secret.len() as u32,
        pbData: secret.as_ptr() as *mut u8,
    };
    let mut output = CRYPT_INTEGER_BLOB {
        cbData: 0,
        pbData: std::ptr::null_mut(),
    };
    let ok = unsafe {
        CryptProtectData(
            &mut input,
            std::ptr::null(),
            std::ptr::null(),
            std::ptr::null(),
            std::ptr::null(),
            CRYPTPROTECT_UI_FORBIDDEN,
            &mut output,
        )
    };
    if ok == 0 {
        return Err(StoreError::SecretStorage(
            std::io::Error::last_os_error().to_string(),
        ));
    }
    let bytes =
        unsafe { std::slice::from_raw_parts(output.pbData, output.cbData as usize) }.to_vec();
    unsafe {
        LocalFree(output.pbData as *mut core::ffi::c_void);
    }
    Ok(bytes)
}

#[cfg(windows)]
fn unprotect_secret(ciphertext: &[u8]) -> Result<Vec<u8>, StoreError> {
    use windows_sys::Win32::Foundation::LocalFree;
    use windows_sys::Win32::Security::Cryptography::{
        CryptUnprotectData, CRYPTPROTECT_UI_FORBIDDEN, CRYPT_INTEGER_BLOB,
    };

    let mut input = CRYPT_INTEGER_BLOB {
        cbData: ciphertext.len() as u32,
        pbData: ciphertext.as_ptr() as *mut u8,
    };
    let mut output = CRYPT_INTEGER_BLOB {
        cbData: 0,
        pbData: std::ptr::null_mut(),
    };
    let ok = unsafe {
        CryptUnprotectData(
            &mut input,
            std::ptr::null_mut(),
            std::ptr::null(),
            std::ptr::null(),
            std::ptr::null(),
            CRYPTPROTECT_UI_FORBIDDEN,
            &mut output,
        )
    };
    if ok == 0 {
        return Err(StoreError::SecretStorage(
            std::io::Error::last_os_error().to_string(),
        ));
    }
    let bytes =
        unsafe { std::slice::from_raw_parts(output.pbData, output.cbData as usize) }.to_vec();
    unsafe {
        LocalFree(output.pbData as *mut core::ffi::c_void);
    }
    Ok(bytes)
}
