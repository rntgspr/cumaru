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
    /// Download a catalog model into ~/.cumaru/<name>/; never upload.
    Push { name: String },
}

/// Dispatches explicit model operations without initializing context or modifying adopter data.
pub fn run(args: ModelArgs) -> ExitCode {
    let result = (|| {
        if let Action::Push { name } = &args.action {
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
            Action::Push { name } => {
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
                        "already installed"
                    },
                    root.join(name).display()
                );
            }
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
