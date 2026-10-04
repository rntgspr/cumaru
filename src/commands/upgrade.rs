//! Binary upgrade dispatch and explicit read-only release checks.

use std::process::ExitCode;

use clap::Args;

use crate::distribution;
use crate::release::{VERSION, release_parts};

/// Arguments for the global upgrade command.
#[derive(Args)]
pub struct UpgradeArgs {
    /// Compare the installed binary version with release tags without installing anything.
    #[arg(long)]
    check: bool,
}

/// Checks release freshness or installs the latest release binary, reporting failures on stderr.
pub fn run(args: UpgradeArgs) -> ExitCode {
    let result = if args.check {
        check()
    } else {
        distribution::install()
    };

    match result {
        Ok(code) => code,
        Err(message) => {
            eprintln!("cumaru upgrade: {message}");
            ExitCode::FAILURE
        }
    }
}

/// Lists remote release tags and compares them numerically with the binary's build-time version.
fn check() -> Result<ExitCode, String> {
    println!("installed: {VERSION}");

    let latest = distribution::latest_release()?;
    println!("latest:    {latest}");

    let installed = release_parts(VERSION)
        .ok_or_else(|| "cannot check: binary version is not an X.Y.Z release".to_string())?;
    let status = if installed >= release_parts(&latest).unwrap() {
        "up to date"
    } else {
        "behind"
    };
    println!("status:    {status}");
    println!("upgrade:   cumaru upgrade");

    Ok(ExitCode::SUCCESS)
}
