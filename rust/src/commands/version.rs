use crate::release::VERSION;

/// Runs `cumaru version`: prints the distribution version baked in at build time.
pub fn run() {
    println!("version:  {VERSION}");
}
