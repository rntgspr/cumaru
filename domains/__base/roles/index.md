---
human_revised: false
summary: Available framework roles and their permissions for maintaining Cumaru projects.
apps: [meta]
---


# Roles

Agent role definitions. Each role describes responsibilities, permissions, and the expected behavior of an LLM acting in that capacity.

## Available roles

- [admin.md](admin.md) — full access. Owns the framework installation, schema, roles, and templates. Starting point for any custom domain.

## When to use

The user signals the role at the start of a session (e.g., "as Admin, …"). The matching role file is loaded then. Outside that signal, role files are not read by default.

## Adding roles for your domain

This base ships only the `admin` role. Domain-specific roles (e.g., `lead`, `dev`, `ghost` in the SDLC domain) are defined by the domain and override or extend this set. Add a `<role>.md` file here and register it in the table above.
