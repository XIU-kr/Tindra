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
