---
name: audit-test-scope-and-skill-contracts
description: Audit deterministic test coverage for duplication, brittle assertions, and missing behavior
status: open
priority: medium
---

# Issue 065: Audit test scope and skill contracts

The ShellSpec suite covers CLI behavior, updates, adapters, migration, shipped
artifacts, and skill text. Its testing specification already excludes LLM and
provider API calls. Some skill tests assert exact phrases or repeated mirrors;
those checks can fail on harmless wording changes without proving that an agent
would follow the skill. The suite needs a careful coverage and maintenance audit,
not an assumed reduction in test count.

## Risk

- Duplicate or wording-bound assertions increase maintenance cost and obscure
  which behavior failed.
- A passing textual skill check may be mistaken for proof of agent behavior.
- Removing tests by count alone could lose regression coverage of CLI data
  preservation, version gates, or adapter installation.

## Required invariant

Automated tests remain deterministic and offline, with no LLM, agent execution,
or provider API dependency. Each retained test protects a distinct observable
contract or a justified edge case; skill tests state clearly whether they prove
distribution, structure, or a textual policy requirement.

## Work

1. Inventory the suite by command, contract, fixture, and assertion type.
   Map each example to a production behavior and identify duplicate cases,
   implementation-mirroring checks, exact-wording assertions, and expensive
   scenarios that add no distinct protection.
2. Review skill coverage separately: universal/domain mirroring, adapter
   installation and refresh, command launchers, declared dependencies, and
   content checks. Identify what is structurally testable and what remains an
   unverified semantic instruction; do not simulate an agent with keyword
   searches or add AI-backed tests.
3. Consolidate or remove only demonstrably redundant/brittle checks. Prefer
   black-box CLI behavior and stable file/schema invariants over copied prose.
   Keep focused negative cases for data loss, unauthorized mutation, and version
   boundaries.
4. Update the testing specification to record the coverage map, the limits of
   deterministic skill testing, and any semantic evaluation reserved for manual
   review. Report before/after example count and runtime with rationale for
   each material consolidation.

## Tests

- The focused suites and `bash tests/run.sh --ci` pass after consolidation;
  random-order execution remains independent.
- The test runner and CI still invoke no LLM, agent harness, or provider API.
- A deliberate missing skill, broken launcher, or broken adapter distribution
  still fails a deterministic test; a harmless skill wording change does not
  fail unless that exact text is itself a documented machine-consumed contract.

## References

- [Testing specification](../specs/testing.md)
- [Test runner](../../tests/run.sh)
- [Skill contract tests](../../tests/spec/contracts)
- [Adapter integration tests](../../tests/spec/integration/agent_adapters_spec.sh)
- [Update tests](../../tests/spec/update)
