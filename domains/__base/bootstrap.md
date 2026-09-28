---
summary: Universal post-install bootstrap steps shared by every domain.
---

## Universal rules

Run these after `cumaru install`, before any domain step below.

- **Ask, do not assume.** Ask the user one topic at a time and write only what
  they answer. Never seed a plausible default or infer an answer from the
  repository, tickets, or conversation. A domain step may allow a proposal;
  write it only once the user confirms. An unanswered topic stays empty.
- **Use the CLI.** Discover with `cumaru tree` and `cumaru map`, read and write
  tag blocks with `cumaru tag`, move, copy, create, or remove files with
  `cumaru fs`, and validate with `cumaru doctor`.
- **Keep canonical prose.** Record local facts only inside
  `<!-- cumaru:NAME -->` tags; the prose outside them is framework-owned.
- **Report.** Finish with `cumaru doctor`, then list which topics the user
  answered and which remain empty.
