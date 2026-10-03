---
name: checkout-node24-runtime
description: Update the CI checkout action to a supported Node.js 24 release and remove the Node.js 20 deprecation warning
status: open
priority: medium
---

# Issue 138: Update checkout to the supported Node.js 24 runtime

[GitHub issue 16](https://github.com/rntgspr/cumaru/issues/16).

`.github/workflows/tests.yml` uses `actions/checkout@v4`. GitHub warns that its
Node.js 20 runtime is deprecated and forces execution on Node.js 24. Update the
action reference rather than suppressing the warning or opting into an obsolete
runtime. This issue records the work; it does not modify the workflow.

## Risk

- CI relies on a forced runtime migration instead of the action's declared runtime.
- Suppressing the warning can hide an unsupported action/runtime combination.

## Required invariant

Every checkout invocation uses a supported action release declaring Node.js 24,
and the native Rust CI completes without the Node.js 20 deprecation warning.

## Work

1. Audit checkout references across `.github/workflows/`. Currently the only
   occurrence is `.github/workflows/tests.yml:20`.
2. Select a supported checkout release after reviewing its action metadata,
   release notes, runner requirements, and credential behavior. At issue creation,
   the latest published release is v7.0.1 and its `action.yml` declares `node24`;
   recheck before implementation rather than mechanically adopting an old major.
3. Update the checkout reference while preserving workflow triggers, permissions,
   runner selection, concurrency, and native verification steps.
4. Verify a fresh GitHub Actions run. Do not add insecure runtime opt-outs or
   warning-suppression environment variables as the fix.

## Tests

- No workflow retains `actions/checkout@v4` or another Node.js 20 checkout action.
- The selected action metadata declares `runs.using: node24` and its runner
   requirements are satisfied by this workflow.
- A fresh CI run passes formatting, native tests, mirror checks, release build,
   and binary smokes without the reported Node.js 20 warning.
- Report local inspection separately from actual remote execution evidence.

## References

- [Workflow](../../.github/workflows/tests.yml)
- [Testing contract](../specs/testing.md)
- [GitHub Node.js 20 deprecation notice](https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/)
- [Checkout v7.0.1 release](https://github.com/actions/checkout/releases/tag/v7.0.1)
- [Checkout v7.0.1 runtime declaration](https://github.com/actions/checkout/blob/v7.0.1/action.yml)
