# Local document

The adopter file declares the same top-level tag twice. Both bodies are valid
adopter data and must be folded into the first occurrence in document order.

<!-- cumaru:notes -->
The first body records an architectural decision.

It remains first in the merged body.
<!-- /cumaru:notes -->

Local prose separates both occurrences.

<!-- cumaru:notes -->
The second body records a different operational decision.

It follows the first body after exactly one blank line.
<!-- /cumaru:notes -->

This local paragraph appears after the duplicate occurrence. It proves that the
second tag has a complete boundary and that folding it does not consume or move
unrelated content that follows it.
