//! Text inspection and diagnostic formatting shared by CLI commands.

/// True for C0 control characters and DEL.
pub(crate) fn is_control(c: char) -> bool {
    c < ' ' || c == '\x7f'
}

/// True when any character of the value is a C0 control character or DEL.
pub(crate) fn has_control(value: &str) -> bool {
    value.chars().any(is_control)
}

/// Quotes a path for diagnostics like bash `printf %q`, so control characters never reach stderr raw.
pub(crate) fn shell_quote(value: &str) -> String {
    if value.is_empty() {
        return "''".to_string();
    }

    if has_control(value) {
        let mut quoted = String::from("$'");
        for c in value.chars() {
            match c {
                '\n' => quoted.push_str("\\n"),
                '\t' => quoted.push_str("\\t"),
                '\r' => quoted.push_str("\\r"),
                '\'' => quoted.push_str("\\'"),
                '\\' => quoted.push_str("\\\\"),
                c if is_control(c) => quoted.push_str(&format!("\\{:03o}", c as u32)),
                c => quoted.push(c),
            }
        }
        quoted.push('\'');
        return quoted;
    }

    let mut quoted = String::new();
    for (index, c) in value.chars().enumerate() {
        let safe = !c.is_ascii()
            || c.is_ascii_alphanumeric()
            || "_-./:@%+=~".contains(c)
            || (c == '#' && index > 0);
        if safe {
            quoted.push(c);
        } else {
            quoted.push('\\');
            quoted.push(c);
        }
    }

    quoted
}
