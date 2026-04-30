// FFI surface for Phase 7 settings.

#[derive(Debug, Clone)]
pub struct Settings {
    pub theme: String,
    pub font_family: String,
    pub font_size: f32,
    pub quake_hotkey: String,
}

impl From<tindra_core::store::Settings> for Settings {
    fn from(s: tindra_core::store::Settings) -> Self {
        Settings {
            theme: s.theme,
            font_family: s.font_family,
            font_size: s.font_size,
            quake_hotkey: s.quake_hotkey,
        }
    }
}

impl From<Settings> for tindra_core::store::Settings {
    fn from(s: Settings) -> Self {
        tindra_core::store::Settings {
            theme: if s.theme.is_empty() { "dark".into() } else { s.theme },
            font_family: if s.font_family.is_empty() {
                "Consolas".into()
            } else {
                s.font_family
            },
            font_size: if s.font_size <= 0.0 { 13.0 } else { s.font_size },
            quake_hotkey: s.quake_hotkey,
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
