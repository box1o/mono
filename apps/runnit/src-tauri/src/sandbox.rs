use std::path::{Component, Path, PathBuf};

use thiserror::Error;

use crate::config::SandboxConfig;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Permission {
    Network,
    Process,
    StorageRead,
    StorageWrite,
}

#[derive(Debug, Error, Eq, PartialEq)]
pub enum SandboxError {
    #[error("the extension sandbox cannot be disabled")]
    Disabled,
    #[error("permission denied: {0:?}")]
    PermissionDenied(Permission),
    #[error("extension id must contain only lowercase ASCII letters, digits, dots, or hyphens")]
    InvalidExtensionId,
    #[error("extension path must be relative and cannot contain parent traversal")]
    InvalidRelativePath,
    #[error("module is {actual} bytes; configured maximum is {maximum} bytes")]
    ModuleTooLarge { actual: u64, maximum: u64 },
    #[error("extension declares {actual} commands; configured maximum is {maximum}")]
    TooManyCommands { actual: usize, maximum: usize },
    #[error("extension module is not a supported WebAssembly 1 binary")]
    InvalidWasmModule,
}

#[derive(Clone, Debug)]
pub struct SandboxPolicy {
    config: SandboxConfig,
    data_root: PathBuf,
}

impl SandboxPolicy {
    pub fn new(config: SandboxConfig, data_root: PathBuf) -> Result<Self, SandboxError> {
        if !config.enabled {
            return Err(SandboxError::Disabled);
        }
        Ok(Self { config, data_root })
    }

    pub fn authorize(&self, permission: Permission) -> Result<(), SandboxError> {
        let allowed = match permission {
            Permission::Network => self.config.allow_network,
            Permission::Process => self.config.allow_process,
            Permission::StorageRead | Permission::StorageWrite => true,
        };

        allowed
            .then_some(())
            .ok_or(SandboxError::PermissionDenied(permission))
    }

    pub fn validate_manifest_limits(
        &self,
        module_bytes: u64,
        command_count: usize,
    ) -> Result<(), SandboxError> {
        if module_bytes > self.config.max_module_bytes {
            return Err(SandboxError::ModuleTooLarge {
                actual: module_bytes,
                maximum: self.config.max_module_bytes,
            });
        }
        if command_count > self.config.max_commands_per_extension {
            return Err(SandboxError::TooManyCommands {
                actual: command_count,
                maximum: self.config.max_commands_per_extension,
            });
        }
        Ok(())
    }

    pub fn validate_wasm_module(&self, module: &[u8]) -> Result<(), SandboxError> {
        self.validate_manifest_limits(module.len() as u64, 0)?;
        const WASM_V1_HEADER: &[u8; 8] = b"\0asm\x01\0\0\0";
        if !module.starts_with(WASM_V1_HEADER) {
            return Err(SandboxError::InvalidWasmModule);
        }
        Ok(())
    }

    pub fn storage_path(
        &self,
        extension_id: &str,
        relative_path: &Path,
    ) -> Result<PathBuf, SandboxError> {
        validate_extension_id(extension_id)?;
        validate_relative_path(relative_path)?;
        Ok(self.data_root.join(extension_id).join(relative_path))
    }
}

fn validate_extension_id(extension_id: &str) -> Result<(), SandboxError> {
    let valid = !extension_id.is_empty()
        && extension_id.len() <= 128
        && extension_id.bytes().all(|byte| {
            byte.is_ascii_lowercase() || byte.is_ascii_digit() || matches!(byte, b'.' | b'-')
        });
    valid.then_some(()).ok_or(SandboxError::InvalidExtensionId)
}

fn validate_relative_path(path: &Path) -> Result<(), SandboxError> {
    let valid = !path.as_os_str().is_empty()
        && !path.is_absolute()
        && path
            .components()
            .all(|component| matches!(component, Component::Normal(_)));
    valid.then_some(()).ok_or(SandboxError::InvalidRelativePath)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn policy() -> SandboxPolicy {
        SandboxPolicy::new(SandboxConfig::default(), PathBuf::from("/data/extensions")).unwrap()
    }

    #[test]
    fn denies_powerful_permissions_by_default() {
        let policy = policy();
        assert_eq!(
            policy.authorize(Permission::Network),
            Err(SandboxError::PermissionDenied(Permission::Network))
        );
        assert_eq!(
            policy.authorize(Permission::Process),
            Err(SandboxError::PermissionDenied(Permission::Process))
        );
        assert!(policy.authorize(Permission::StorageRead).is_ok());
        assert!(policy.authorize(Permission::StorageWrite).is_ok());
    }

    #[test]
    fn confines_storage_to_the_extension_directory() {
        let policy = policy();
        assert_eq!(
            policy.storage_path("dev.runnit.notes", Path::new("items/data.json")),
            Ok(PathBuf::from(
                "/data/extensions/dev.runnit.notes/items/data.json"
            ))
        );
        assert!(policy
            .storage_path("dev.runnit.notes", Path::new("../secrets"))
            .is_err());
        assert!(policy
            .storage_path("../invalid", Path::new("data.json"))
            .is_err());
    }

    #[test]
    fn enforces_resource_limits() {
        let policy = policy();
        assert!(policy.validate_manifest_limits(1024, 2).is_ok());
        assert!(matches!(
            policy.validate_manifest_limits(17 * 1024 * 1024, 2),
            Err(SandboxError::ModuleTooLarge { .. })
        ));
        assert!(matches!(
            policy.validate_manifest_limits(1024, 129),
            Err(SandboxError::TooManyCommands { .. })
        ));
    }

    #[test]
    fn admits_only_version_one_wasm_modules() {
        let policy = policy();
        assert!(policy.validate_wasm_module(b"\0asm\x01\0\0\0").is_ok());
        assert_eq!(
            policy.validate_wasm_module(b"not wasm"),
            Err(SandboxError::InvalidWasmModule)
        );
        assert_eq!(
            policy.validate_wasm_module(b"\0asm\x02\0\0\0"),
            Err(SandboxError::InvalidWasmModule)
        );
    }
}
