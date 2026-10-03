# Refresh token rotation

```rust
fn rotate_refresh_token(session: &mut Session) -> Result<Token> {
    session.invalidate_previous_token();
    session.issue_refresh_token()
}
```

The session repository prevents reuse of a rotated token. The authentication
middleware rejects expired cookies.
