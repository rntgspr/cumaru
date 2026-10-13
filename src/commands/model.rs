//! Explicit model discovery and download, independent of adopter projects.

use clap::{Args, Subcommand};
use std::process::ExitCode;

use crate::models;

#[derive(Args)]
pub struct ModelArgs {
    #[command(subcommand)]
    action: Action,
}

#[derive(Subcommand)]
enum Action {
    /// Read the fixed supported-model catalog from GitHub main.
    List,
    /// Download and enable a catalog model, reusing a verified local package.
    Pull { name: String },
    /// Disable the cached encoder without deleting its files; use lightweight ranking.
    Release,
}

/// Dispatches explicit model operations without initializing context or modifying adopter data.
pub fn run(args: ModelArgs) -> ExitCode {
    let result = (|| {
        if let Action::Release = &args.action {
            let released = models::release(&models::cache_root()?)?;
            println!(
                "{}; context uses lightweight ranking",
                if released {
                    "model released"
                } else {
                    "no model enabled"
                }
            );

            return Ok(());
        }

        if let Action::Pull { name } = &args.action {
            models::known(name)?;
        }

        let (revision, catalog) = models::remote_catalog()?;

        match args.action {
            Action::List => {
                println!("source: main ({revision})");
                println!("Name\tBytes\tLicense");

                for entry in catalog.models {
                    println!(
                        "{}\t{}\t{}",
                        entry.name,
                        entry.artifacts.iter().map(|a| a.bytes).sum::<usize>(),
                        entry.license
                    );
                }
            }
            Action::Pull { name } => {
                let entry = catalog
                    .models
                    .iter()
                    .find(|entry| entry.name == name)
                    .ok_or("model is not in the remote catalog")?;
                let root = models::cache_root()?;
                let installed = models::install(&root, entry, crate::distribution::download)?;
                println!(
                    "{}: {}",
                    if installed {
                        "installed"
                    } else {
                        "enabled cached model"
                    },
                    root.join(name).display()
                );
            }
            Action::Release => unreachable!("release returns before remote catalog access"),
        }

        Ok::<_, String>(())
    })();

    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("cumaru model: {error}");
            ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use clap::Parser;

    #[derive(Parser)]
    struct Cli {
        #[command(flatten)]
        args: ModelArgs,
    }

    /// Require a name for pull, no arguments for release, and reject the retired push spelling.
    #[test]
    fn model_command_arguments() {
        assert!(matches!(
            Cli::try_parse_from(["model", "pull", "bge-micro-v2"])
                .unwrap()
                .args
                .action,
            Action::Pull { .. }
        ));
        assert!(matches!(
            Cli::try_parse_from(["model", "release"])
                .unwrap()
                .args
                .action,
            Action::Release
        ));
        assert!(Cli::try_parse_from(["model", "pull"]).is_err());
        assert!(Cli::try_parse_from(["model", "release", "bge-micro-v2"]).is_err());
        assert!(Cli::try_parse_from(["model", "push", "bge-micro-v2"]).is_err());
    }
}
