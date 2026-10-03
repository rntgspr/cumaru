use std::process::ExitCode;

use clap::{Parser, Subcommand};

mod adapter;
mod artifacts;
mod commands;
mod config;
mod config_tree;
mod distribution;
mod markdown;
mod paths;
mod references;
mod release;
mod tags;
mod text;
mod tsv;
mod walk;

/// Cumaru CLI.
#[derive(Parser)]
#[command(version, disable_help_subcommand = true)]
struct Cli {
    #[command(subcommand)]
    command: Option<Command>,
}

/// Supported subcommands.
#[derive(Subcommand)]
enum Command {
    /// Show CLI help, command help, or the domains available at main HEAD.
    Help(commands::help::HelpArgs),

    /// Validate the installed configuration, Markdown tree, references, and agent instructions.
    Doctor(commands::doctor::DoctorArgs),
    /// Print CLI identity and check the adopter config version and drift against main HEAD.
    Version,

    /// Install a domain from the main HEAD into the current project.
    Install(commands::install::InstallArgs),

    /// Remove the project installation and every Cumaru-owned adapter artifact.
    Uninstall(commands::uninstall::UninstallArgs),

    /// Preview or apply a same-version project refresh from the main HEAD.
    Update(commands::update::UpdateArgs),

    /// Print the post-install bootstrap steps for this project's domain.
    Bootstrap(commands::bootstrap::BootstrapArgs),

    /// Print the current read-only migration instructions for this project.
    Migrate(commands::migrate::MigrateArgs),

    /// List filesystem candidates and their summaries.
    Tree(commands::tree::TreeArgs),

    /// List H1-H6 Markdown headings with their markers in a directory or exact file.
    Map(commands::map::MapArgs),

    /// Read, write, and audit balanced semantic tags in Markdown files.
    Tag(commands::tag::TagArgs),

    /// Report which Git-tracked source files the durable specification references.
    Coverage(commands::coverage::CoverageArgs),

    /// Move, copy, create, or remove one path inside .cumaru/ with guardrails.
    Fs(commands::fs::FsArgs),

    /// Install the latest global Cumaru binary, or check release freshness with --check.
    Upgrade(commands::upgrade::UpgradeArgs),
}

/// Entry point for the Rust Cumaru CLI; parses argv, runs the selected subcommand, and returns its exit code.
fn main() -> ExitCode {
    let cli = Cli::parse();

    match cli.command {
        Some(Command::Help(args)) => commands::help::run(args),
        Some(Command::Doctor(args)) => commands::doctor::run(args),
        Some(Command::Version) => commands::version::run(),
        Some(Command::Tree(args)) => commands::tree::run(args),
        Some(Command::Install(args)) => commands::install::run(args),
        Some(Command::Uninstall(args)) => commands::uninstall::run(args),
        Some(Command::Update(args)) => commands::update::run(args),
        Some(Command::Bootstrap(args)) => commands::bootstrap::run(args),
        Some(Command::Migrate(args)) => commands::migrate::run(args),
        Some(Command::Map(args)) => commands::map::run(args),
        Some(Command::Tag(args)) => commands::tag::run(args),
        Some(Command::Coverage(args)) => commands::coverage::run(args),
        Some(Command::Fs(args)) => commands::fs::run(args),
        Some(Command::Upgrade(args)) => commands::upgrade::run(args),
        None => commands::doctor::run(commands::doctor::DoctorArgs::default()),
    }
}
