//! Fixed project-relative locations shared by every command.
//!
//! Mirrors `src/common.sh`: the framework tree has one fixed location and is
//! never read from the environment, so write-capable commands cannot be
//! redirected by an inherited variable.

/// The framework tree, relative to the project directory.
pub const CUMARU_DIR: &str = ".cumaru";

/// The installed configuration file name inside `CUMARU_DIR`.
pub const CONFIG_FILE: &str = "config.yaml";
