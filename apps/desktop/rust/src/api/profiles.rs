// FFI surface for connection profiles. Forwards into tindra-core::store.

#[derive(Debug, Clone)]
pub struct Profile {
    /// Stable id. Empty string when calling upsert for a brand-new profile —
    /// the store will assign one and return it in the result.
    pub id: String,
    pub name: String,
    pub host: String,
    pub port: u16,
    pub username: String,
    pub private_key_path: String,
    pub notes: String,
    /// "key" or "agent". Defaults to "key" when reading older profiles.
    pub auth_method: String,
    /// Optional jump host. Empty `jump_host` means no jump.
    pub jump_host: String,
    pub jump_port: u16,
    pub jump_username: String,
    pub jump_private_key_path: String,
    /// "ssh" (default) or "telnet".
    pub transport: String,
}

impl From<tindra_core::store::Profile> for Profile {
    fn from(p: tindra_core::store::Profile) -> Self {
        Profile {
            id: p.id,
            name: p.name,
            host: p.host,
            port: p.port,
            username: p.username,
            private_key_path: p.private_key_path,
            notes: p.notes,
            auth_method: p.auth_method,
            jump_host: p.jump_host,
            jump_port: p.jump_port,
            jump_username: p.jump_username,
            jump_private_key_path: p.jump_private_key_path,
            transport: p.transport,
        }
    }
}

impl From<Profile> for tindra_core::store::Profile {
    fn from(p: Profile) -> Self {
        tindra_core::store::Profile {
            id: p.id,
            name: p.name,
            host: p.host,
            port: p.port,
            username: p.username,
            private_key_path: p.private_key_path,
            notes: p.notes,
            auth_method: if p.auth_method.is_empty() {
                "key".to_string()
            } else {
                p.auth_method
            },
            jump_host: p.jump_host,
            jump_port: if p.jump_port == 0 { 22 } else { p.jump_port },
            jump_username: p.jump_username,
            jump_private_key_path: p.jump_private_key_path,
            transport: if p.transport.is_empty() {
                "ssh".to_string()
            } else {
                p.transport
            },
        }
    }
}

/// All saved profiles, sorted by name.
pub async fn list_profiles() -> Result<Vec<Profile>, String> {
    tindra_core::store::list_profiles()
        .await
        .map(|v| v.into_iter().map(Profile::from).collect())
        .map_err(|e| e.to_string())
}

/// Create a new profile (when `id` is empty) or overwrite an existing one.
pub async fn upsert_profile(profile: Profile) -> Result<Profile, String> {
    tindra_core::store::upsert_profile(profile.into())
        .await
        .map(Profile::from)
        .map_err(|e| e.to_string())
}

/// Delete a profile by id. Idempotent — deleting a missing id is a no-op.
pub async fn delete_profile(id: String) -> Result<(), String> {
    tindra_core::store::delete_profile(id)
        .await
        .map_err(|e| e.to_string())
}

/// Filesystem path of the on-disk profiles file (for diagnostics).
pub async fn profiles_path() -> Result<String, String> {
    tindra_core::store::store_path()
        .await
        .map(|p| p.to_string_lossy().to_string())
        .map_err(|e| e.to_string())
}

#[derive(Debug, Clone)]
pub struct HostKey {
    pub host: String,
    pub port: u16,
    pub fingerprint: String,
    pub first_seen_unix_ms: u128,
    pub last_seen_unix_ms: u128,
}

impl From<tindra_core::store::HostKeyEntry> for HostKey {
    fn from(k: tindra_core::store::HostKeyEntry) -> Self {
        HostKey {
            host: k.host,
            port: k.port,
            fingerprint: k.fingerprint,
            first_seen_unix_ms: k.first_seen_unix_ms,
            last_seen_unix_ms: k.last_seen_unix_ms,
        }
    }
}

/// Trusted SSH host keys stored by trust-on-first-use.
pub async fn list_host_keys() -> Result<Vec<HostKey>, String> {
    tindra_core::store::list_host_keys()
        .await
        .map(|v| v.into_iter().map(HostKey::from).collect())
        .map_err(|e| e.to_string())
}

/// Remove a trusted host key so the next connection can trust a new key.
pub async fn delete_host_key(host: String, port: u16) -> Result<(), String> {
    tindra_core::store::delete_host_key(host, port)
        .await
        .map_err(|e| e.to_string())
}
