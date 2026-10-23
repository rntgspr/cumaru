---
human_revised: false
name: separation-of-concerns
applies-when: implementing, reviewing, or refactoring code where responsibilities, module boundaries, or dependency direction are being chosen or changed
strictness: 9/10
summary: Separate independently changing concerns through cohesive ownership and explicit boundaries without speculative layers.
---

# Separation of concerns

**Gate:** keep code that serves one concern together; separate concerns that
change for independent reasons. A boundary must isolate a real responsibility,
not merely shorten a function or increase the number of files.

## Cycle

1. **Identify ownership** - inspect the existing code, callers, and contracts.
   Name the concerns involved and which existing unit owns each one.
2. **Keep responsibilities cohesive** - separate presentation, domain policy,
   persistence, and external integration when their independent changes would
   otherwise force unrelated edits. Keep helpers private and close to their
   only consumer unless they own a distinct concern.
3. **Make boundaries explicit** - pass only the data and operations a consumer
   needs. Keep transport, storage, and framework details at their owning
   boundary; avoid leaking them into domain decisions or presentation code.
4. **Check dependencies** - make dependency direction deliberate and avoid
   cycles or access to another unit's private implementation. Use the smallest
   concrete function or module boundary that solves the present coupling.
5. **Verify isolation** - inspect affected callers and verify observable
   behavior across changed boundaries. Apply `test-driven-development` and
   `verification` for test order and evidence; avoid tests coupled to private
   structure.

Use `solid` for single responsibility and dependency inversion, and `kiss` /
`yagni` to reject unnecessary layers. Separation does not require a new file,
interface, service, or repository for every function or operation.

## Red flags

- One unit mixes unrelated UI state, business rules, storage, and network I/O.
- Changing one concern requires editing another's internal implementation.
- A generic manager or utility module collects unrelated responsibilities.
- Shared mutable state or cyclic imports bypass an explicit boundary.
- Splitting cohesive code by line count or creating layers for imagined reuse.
