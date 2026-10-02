use std::process::ExitCode;

use clap::{Parser, Subcommand};

mod commands;
mod config;
mod markdown;
mod paths;
mod text;
mod tsv;
mod walk;

/// Cumaru CLI.
#[derive(Parser)]
#[command(version)]
struct Cli {
    #[command(subcommand)]
    command: Option<Command>,
}

/// Supported subcommands.
#[derive(Subcommand)]
enum Command {
    /// Print the installed distribution version.
    Version,

    /// List filesystem candidates and their summaries.
    Tree(commands::tree::TreeArgs),

    /// Move, copy, create, or remove one path inside .cumaru/ with guardrails.
    Fs(commands::fs::FsArgs),
}

/// Entry point for the Rust Cumaru CLI; parses argv, runs the selected subcommand, and returns its exit code.
fn main() -> ExitCode {
    let cli = Cli::parse();

    match cli.command {
        Some(Command::Version) => {
            commands::version::run();
            ExitCode::SUCCESS
        }
        Some(Command::Tree(args)) => commands::tree::run(args),
        Some(Command::Fs(args)) => commands::fs::run(args),
        None => {
            println!("Hello Cumaru!");
            ExitCode::SUCCESS
        }
    }
}
