# Local document

This introduction belongs to the adopter and sits outside the tag delimiters.
It helps verify that surrounding prose is not mistaken for part of the body.

<!-- cumaru:notes -->
This adopter-owned body contains multiple paragraphs. Its content must remain
byte-identical even when the surrounding tag structure is invalid.

The second paragraph makes the body boundary visible and confirms that blank
lines and prose are not lost before validation reports the mismatched pair.
<!-- /cumaru:decisions -->

Because `notes` never closes, the foreign closing marker and this paragraph are
still part of its body. No partial merge may rewrite any of this content.
