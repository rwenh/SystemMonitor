// This file goes in: src/config/mod.rs

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Settings {
    pub update_ms: u64,
    pub process_limit: usize,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            update_ms: 1000,
            process_limit: 15,
        }
    }
}

impl Settings {
    pub fn load() -> anyhow::Result<Self> {
        let path = Self::config_path()?;
        if !path.exists() {
            let s = Self::default();
            s.save()?;
            return Ok(s);
        }
        let content = std::fs::read_to_string(&path)?;
        Ok(toml::from_str(&content)?)
    }

    pub fn save(&self) -> anyhow::Result<()> {
        let path = Self::config_path()?;
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::write(&path, toml::to_string_pretty(self)?)?;
        Ok(())
    }

    fn config_path() -> anyhow::Result<PathBuf> {
        Ok(dirs::config_dir()
            .ok_or_else(|| anyhow::anyhow!("No config dir"))?
            .join("system-monitor")
            .join("config.toml"))
    }
}
