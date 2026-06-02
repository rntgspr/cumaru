---
name: cumaru-rename-session
description: "Session state — rename llm → cumaru (2026-07-03). Branch rename-cumaru, 7/8 tasks done, pending smoke test."
type: session
status: paused
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

## Pending

- **Smoke test**: install num bench (ex: gitboiler) + doctor + ciclo básico.

## Key decisions (Renato)

- Nome escolhido: **cumaru**.
- Sem suporte a prefixo `llm:` no parser — só `cumaru:`.
- `cumaru migrate` é a única via de migração de projetos legados.
- Historical repo naming is handled manually by Renato.
- `cumaru update` faz limpeza de resíduo da skill de migração.
