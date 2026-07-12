use std::{
    env,
    fs::{self, File, OpenOptions},
    io::{self, Write},
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

#[cfg(unix)]
use std::os::unix::fs::OpenOptionsExt;
use thiserror::Error;

use super::model::AppConfig;

const CONFIG_ENV: &str = "RUNNIT_CONFIG";
const CONFIG_DIRECTORY: &str = "runnit";
const CONFIG_FILENAME: &str = "config.yaml";
const GENERATED_HEADER: &str = "# Runnit configuration. Unknown keys are rejected.\n";

#[derive(Debug, Error)]
pub enum ConfigError {
    #[error("cannot determine the configuration directory; set XDG_CONFIG_HOME or HOME")]
    MissingConfigDirectory,

    #[error("cannot {operation} config path {path}: {source}")]
    Io {
        operation: &'static str,
        path: PathBuf,
        #[source]
        source: io::Error,
    },

    #[error("cannot parse config {path}: {source}")]
    Parse {
        path: PathBuf,
        #[source]
        source: Box<serde_saphyr::Error>,
    },

    #[error("invalid config {path}: {message}")]
    Validation { path: PathBuf, message: String },

    #[error("cannot serialize config: {0}")]
    Serialize(String),

    #[error("config path is not a regular file: {0}")]
    NotRegularFile(PathBuf),
}

#[derive(Clone, Debug)]
pub struct ConfigStore {
    path: PathBuf,
}

impl ConfigStore {
    pub fn discover() -> Result<Self, ConfigError> {
        if let Some(path) = nonempty_env(CONFIG_ENV) {
            return Ok(Self::at(path));
        }

        let base = nonempty_env("XDG_CONFIG_HOME")
            .or_else(|| nonempty_env("HOME").map(|home| home.join(".config")))
            .ok_or(ConfigError::MissingConfigDirectory)?;

        Ok(Self::at(base.join(CONFIG_DIRECTORY).join(CONFIG_FILENAME)))
    }

    pub fn at(path: impl Into<PathBuf>) -> Self {
        Self { path: path.into() }
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn load_or_create(&self) -> Result<AppConfig, ConfigError> {
        match fs::read_to_string(&self.path) {
            Ok(contents) => self.parse(&contents),
            Err(source) if source.kind() == io::ErrorKind::NotFound => {
                let config = AppConfig::default();
                config
                    .validate()
                    .map_err(|message| ConfigError::Validation {
                        path: self.path.clone(),
                        message,
                    })?;
                self.save(&config)?;
                Ok(config)
            }
            Err(source) => Err(self.io_error("read", &self.path, source)),
        }
    }

    pub fn save(&self, config: &AppConfig) -> Result<(), ConfigError> {
        config
            .validate()
            .map_err(|message| ConfigError::Validation {
                path: self.path.clone(),
                message,
            })?;

        self.reject_non_regular_target()?;

        let parent = self
            .path
            .parent()
            .ok_or(ConfigError::MissingConfigDirectory)?;
        fs::create_dir_all(parent)
            .map_err(|source| self.io_error("create directory for", parent, source))?;

        let yaml = serde_saphyr::to_string(config)
            .map_err(|source| ConfigError::Serialize(source.to_string()))?;
        let contents = format!("{GENERATED_HEADER}{yaml}");
        let temporary_path = self.temporary_path();

        let result = self.write_and_replace(parent, &temporary_path, contents.as_bytes());
        if result.is_err() {
            let _ = fs::remove_file(&temporary_path);
        }
        result
    }

    fn parse(&self, contents: &str) -> Result<AppConfig, ConfigError> {
        let config: AppConfig =
            serde_saphyr::from_str(contents).map_err(|source| ConfigError::Parse {
                path: self.path.clone(),
                source: Box::new(source),
            })?;

        config
            .validate()
            .map_err(|message| ConfigError::Validation {
                path: self.path.clone(),
                message,
            })?;

        Ok(config)
    }

    fn reject_non_regular_target(&self) -> Result<(), ConfigError> {
        match fs::symlink_metadata(&self.path) {
            Ok(metadata) if !metadata.file_type().is_file() => {
                Err(ConfigError::NotRegularFile(self.path.clone()))
            }
            Ok(_) => Ok(()),
            Err(source) if source.kind() == io::ErrorKind::NotFound => Ok(()),
            Err(source) => Err(self.io_error("inspect", &self.path, source)),
        }
    }

    fn write_and_replace(
        &self,
        parent: &Path,
        temporary_path: &Path,
        contents: &[u8],
    ) -> Result<(), ConfigError> {
        let mut options = OpenOptions::new();
        options.write(true).create_new(true);
        #[cfg(unix)]
        options.mode(0o600);

        let mut file = options
            .open(temporary_path)
            .map_err(|source| self.io_error("create temporary", temporary_path, source))?;
        file.write_all(contents)
            .map_err(|source| self.io_error("write temporary", temporary_path, source))?;
        file.sync_all()
            .map_err(|source| self.io_error("sync temporary", temporary_path, source))?;
        drop(file);

        fs::rename(temporary_path, &self.path)
            .map_err(|source| self.io_error("replace", &self.path, source))?;
        File::open(parent)
            .and_then(|directory| directory.sync_all())
            .map_err(|source| self.io_error("sync directory for", parent, source))?;

        Ok(())
    }

    fn temporary_path(&self) -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos();
        let filename = self
            .path
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or(CONFIG_FILENAME);

        self.path
            .with_file_name(format!(".{filename}.{}.{}.tmp", std::process::id(), nonce))
    }

    fn io_error(&self, operation: &'static str, path: &Path, source: io::Error) -> ConfigError {
        ConfigError::Io {
            operation,
            path: path.to_path_buf(),
            source,
        }
    }
}

fn nonempty_env(name: &str) -> Option<PathBuf> {
    env::var_os(name)
        .filter(|value| !value.is_empty())
        .map(PathBuf::from)
}

#[cfg(test)]
mod tests {
    use std::sync::atomic::{AtomicU64, Ordering};

    use super::*;

    static TEST_ID: AtomicU64 = AtomicU64::new(0);

    fn test_store(name: &str) -> ConfigStore {
        let id = TEST_ID.fetch_add(1, Ordering::Relaxed);
        let path = env::temp_dir()
            .join(format!("runnit-config-test-{}-{id}", std::process::id()))
            .join(name)
            .join(CONFIG_FILENAME);
        ConfigStore::at(path)
    }

    #[test]
    fn creates_and_round_trips_defaults() {
        let store = test_store("defaults");
        let config = store.load_or_create().unwrap();

        assert_eq!(config, AppConfig::default());
        assert_eq!(store.load_or_create().unwrap(), config);
        assert!(fs::read_to_string(store.path())
            .unwrap()
            .starts_with(GENERATED_HEADER));
    }

    #[test]
    fn rejects_unknown_fields() {
        let store = test_store("unknown-field");
        fs::create_dir_all(store.path().parent().unwrap()).unwrap();
        fs::write(
            store.path(),
            "version: 1\nwindow:\n  size_ratio: 0.75\n  always_on_top: true\n  resizable: false\n  typo: true\n",
        )
        .unwrap();

        assert!(matches!(
            store.load_or_create(),
            Err(ConfigError::Parse { .. })
        ));
    }

    #[test]
    fn preserves_invalid_files() {
        let store = test_store("invalid-file");
        fs::create_dir_all(store.path().parent().unwrap()).unwrap();
        fs::write(store.path(), "not: [valid").unwrap();

        assert!(store.load_or_create().is_err());
        assert_eq!(fs::read_to_string(store.path()).unwrap(), "not: [valid");
    }

    #[cfg(unix)]
    #[test]
    fn creates_private_config_files() {
        use std::os::unix::fs::PermissionsExt;

        let store = test_store("permissions");
        store.load_or_create().unwrap();

        let mode = fs::metadata(store.path()).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode, 0o600);
    }
}
