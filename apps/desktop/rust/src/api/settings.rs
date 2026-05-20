// FFI surface for Phase 7 settings.

#[derive(Debug, Clone)]
pub struct Settings {
    pub theme: String,
    pub font_family: String,
    pub font_size: f32,
    pub quake_hotkey: String,
    pub locale: String,
    pub local_shell: String,
    pub local_shell_cwd: String,
    pub local_shell_env: String,
}

impl From<tindra_core::store::Settings> for Settings {
    fn from(s: tindra_core::store::Settings) -> Self {
        Settings {
            theme: s.theme,
            font_family: s.font_family,
            font_size: s.font_size,
            quake_hotkey: s.quake_hotkey,
            locale: s.locale,
            local_shell: s.local_shell,
            local_shell_cwd: s.local_shell_cwd,
            local_shell_env: s.local_shell_env,
        }
    }
}

impl From<Settings> for tindra_core::store::Settings {
    fn from(s: Settings) -> Self {
        tindra_core::store::Settings {
            theme: if s.theme.is_empty() {
                "dark".into()
            } else {
                s.theme
            },
            font_family: if s.font_family.is_empty() {
                "Consolas".into()
            } else {
                s.font_family
            },
            font_size: if s.font_size <= 0.0 {
                13.0
            } else {
                s.font_size
            },
            quake_hotkey: s.quake_hotkey,
            locale: if s.locale.is_empty() {
                "system".into()
            } else {
                s.locale
            },
            local_shell: s.local_shell,
            local_shell_cwd: s.local_shell_cwd,
            local_shell_env: s.local_shell_env,
        }
    }
}

pub async fn load_settings() -> Result<Settings, String> {
    tindra_core::store::load_settings()
        .await
        .map(Settings::from)
        .map_err(|e| e.to_string())
}

pub async fn save_settings(settings: Settings) -> Result<(), String> {
    tindra_core::store::save_settings(settings.into())
        .await
        .map_err(|e| e.to_string())
}

pub fn settings_path() -> Result<String, String> {
    tindra_core::store::settings_file_path()
        .map(|p| p.to_string_lossy().to_string())
        .map_err(|e| e.to_string())
}

pub fn expected_log_dir() -> Result<String, String> {
    tindra_core::store::expected_log_dir()
        .map(|p| p.to_string_lossy().to_string())
        .map_err(|e| e.to_string())
}

pub fn secret_backend() -> String {
    tindra_core::store::secret_backend().to_string()
}

pub async fn save_secret(name: String, secret: String) -> Result<(), String> {
    tindra_core::store::save_secret(name, secret)
        .await
        .map_err(|e| e.to_string())
}

pub async fn load_secret(name: String) -> Result<Option<String>, String> {
    tindra_core::store::load_secret(name)
        .await
        .map_err(|e| e.to_string())
}

pub async fn delete_secret(name: String) -> Result<(), String> {
    tindra_core::store::delete_secret(name)
        .await
        .map_err(|e| e.to_string())
}
