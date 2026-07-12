use serde::{Deserialize, Serialize};

pub const CURRENT_CONFIG_VERSION: u32 = 1;

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct AppConfig {
    pub version: u32,
    pub window: WindowConfig,
    #[serde(default)]
    pub sandbox: SandboxConfig,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            version: CURRENT_CONFIG_VERSION,
            window: WindowConfig::default(),
            sandbox: SandboxConfig::default(),
        }
    }
}

impl AppConfig {
    pub fn validate(&self) -> Result<(), String> {
        if self.version != CURRENT_CONFIG_VERSION {
            return Err(format!(
                "unsupported config version {}; expected {}",
                self.version, CURRENT_CONFIG_VERSION
            ));
        }

        self.window.validate()?;
        self.sandbox.validate()
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct SandboxConfig {
    pub enabled: bool,
    pub allow_network: bool,
    pub allow_process: bool,
    pub max_module_bytes: u64,
    pub max_commands_per_extension: usize,
}

impl Default for SandboxConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            allow_network: false,
            allow_process: false,
            max_module_bytes: 16 * 1024 * 1024,
            max_commands_per_extension: 128,
        }
    }
}

impl SandboxConfig {
    fn validate(&self) -> Result<(), String> {
        if !self.enabled {
            return Err("sandbox.enabled must remain true".to_owned());
        }
        if self.max_module_bytes == 0 {
            return Err("sandbox.max_module_bytes must be greater than zero".to_owned());
        }
        if self.max_commands_per_extension == 0 {
            return Err("sandbox.max_commands_per_extension must be greater than zero".to_owned());
        }
        Ok(())
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct WindowConfig {
    pub size_ratio: f64,
    pub always_on_top: bool,
    pub resizable: bool,
}

impl Default for WindowConfig {
    fn default() -> Self {
        Self {
            size_ratio: 0.75,
            always_on_top: true,
            resizable: false,
        }
    }
}

impl WindowConfig {
    fn validate(&self) -> Result<(), String> {
        if !self.size_ratio.is_finite() || !(0.25..=1.0).contains(&self.size_ratio) {
            return Err("window.size_ratio must be between 0.25 and 1.0".to_owned());
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_are_valid() {
        AppConfig::default().validate().unwrap();
    }

    #[test]
    fn rejects_unknown_versions() {
        let config = AppConfig {
            version: CURRENT_CONFIG_VERSION + 1,
            ..AppConfig::default()
        };

        assert!(config
            .validate()
            .unwrap_err()
            .contains("unsupported config version"));
    }

    #[test]
    fn rejects_invalid_window_ratios() {
        for size_ratio in [f64::NAN, 0.0, 0.24, 1.01] {
            let mut config = AppConfig::default();
            config.window.size_ratio = size_ratio;

            assert!(config.validate().is_err());
        }
    }

    #[test]
    fn rejects_disabled_or_unbounded_sandbox_configuration() {
        let mut config = AppConfig::default();
        config.sandbox.enabled = false;
        assert!(config.validate().is_err());

        config.sandbox.enabled = true;
        config.sandbox.max_module_bytes = 0;
        assert!(config.validate().is_err());
    }
}
