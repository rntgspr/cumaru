# Local document

This fixture opens a second marker-like sequence before closing the first tag.

<!-- cumaru:first -->
The first body starts with adopter prose.

<!-- cumaru:second -->
These lines are opaque content inside `first` until its exact close appears.
<!-- /cumaru:first -->

After `first` closes, this unmatched closing marker is structurally invalid.
<!-- /cumaru:second -->
