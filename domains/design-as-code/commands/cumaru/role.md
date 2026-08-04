---
version: 1
description: Start local Cumaru context and assume a domain role. Validates the requested role from `.cumaru/roles/` before loading its instructions.
allowed-tools: Bash, Read
argument-hint: <role>
summary: Start local Cumaru context and assume a validated domain role.
---

# `/cumaru:role <role>`

Use this command to start or reset work in a declared role. In OpenCode's nested command path, invoke it as `/cumaru/role <role>`.

1. **Require a role argument.** If absent, run `cumaru tree roles --rows`, list the available roles, and ask the user to choose one. Do not guess a default.
2. **Load the local bootstrap context in order:**
   - `.cumaru/index.md`
   - `.cumaru/domain.md`
   - `cumaru tree . --rows`
3. **Validate the role.** The argument must be a plain role name whose file exists at `.cumaru/roles/<role>.md`. If it does not exist, list `cumaru tree roles --rows` and ask again. Never derive a role from a filename outside `.cumaru/roles/`.
4. **Assume the role.** Load `.cumaru/roles/<role>.md` and apply its responsibilities, restrictions, ownership boundaries, and `Initial load` rules for the rest of the session.
5. **Report the active role** and the local root candidates from step 2. Do not preload role-optional pillars or task entities; follow the selected role's loading rule and the user's task.

Hard rules:

- This command changes agent context only. It does not write a persistent role setting or modify `.cumaru/`.
- Reload local bootstrap context on every invocation; a role command may begin after a compacted or resumed session.
- A role never grants capabilities outside its own file. When work needs another role, ask the user to switch with this command rather than silently merging permissions.
