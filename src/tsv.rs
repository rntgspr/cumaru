use std::io::{self, Write};

/// Writes fields separated by tabs and terminates the row with a newline; callers supply fields without tabs or newlines.
pub(crate) fn write_row<'a>(
    out: &mut impl Write,
    fields: impl IntoIterator<Item = &'a str>,
) -> io::Result<()> {
    let mut fields = fields.into_iter();

    if let Some(first) = fields.next() {
        out.write_all(first.as_bytes())?;
    }

    for field in fields {
        out.write_all(b"\t")?;
        out.write_all(field.as_bytes())?;
    }

    out.write_all(b"\n")
}
