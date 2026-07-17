---
name: cumaru-rename-session
description: "Completed session record — rename llm → cumaru; legacy naming remains supported only as migration input"
type: session
status: completed
---

## Done

1. **Branch `rename-cumaru`** created from main.
2. **CLI entry**: `llm` → `cumaru`, help text, dispatch pro `migrate`.
3. **Paths**: legacy project dir → `.cumaru/`, legacy install dir → `~/.cumaru`, legacy env var → `CUMARU_DIR`.
4. **Skills/commands**: 41 dirs `llm-*` → `cumaru-*`, 5 `commands/llm/` → `commands/cumaru/`.
5. **Marcadores**: parser aceita apenas `cumaru:` — sem dualidade com `llm:`.
6. **context-loader.sh**: sem fallback pra `.llm/` ou `llm` command.
7. **install.sh**: sem symlink legado `llm`.
8. **`cumaru migrate`**: subcomando que migra projetos legados (.llm/ → .cumaru/, marcadores, skills).
9. **`cumaru update`**: limpa `.agents/skills/cumaru-migrate/` se existir.
10. **Docs/.memory/README**: zero referências ao nome legado fora de contextos de migração e histórico do repo.
11. **Parser**: `common.sh` e `cmd_tag.sh` — só `cumaru:` como prefixo válido.

## Completion

- Subsequent domain installation smoke tests and the v6 migration/doctor regression fixtures covered the renamed CLI, `.cumaru/` tree, agent artifacts, and legacy migration input.
- The v6 package was committed on `main` as `5e791b4`; this session has no remaining action.

## Key decisions (Renato)

- Nome escolhido: **cumaru**.
- Sem suporte a prefixo `llm:` no parser — só `cumaru:`.
- `cumaru migrate` é a única via de migração de projetos legados.
- Historical repo naming is handled manually by Renato.
- `cumaru update` faz limpeza de resíduo da skill de migração.
