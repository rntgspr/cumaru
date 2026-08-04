# Canonical collision pair

This source revision deliberately places two names that collided in the old
temporary-file encoding next to each other.

<!-- cumaru:a:b -->
The colon-qualified body records an application boundary.

It must never receive content from the double-underscore tag.
<!-- /cumaru:a:b -->

The framework may safely update prose between both tags.

<!-- cumaru:a__b -->
The double-underscore body records a migration note.

Its bytes must remain distinct from the application boundary above.
<!-- /cumaru:a__b -->
