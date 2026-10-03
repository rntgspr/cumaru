# Authentication and session lifecycle

The login endpoint validates credentials, creates a session cookie, and rotates
the refresh token. Logout invalidates the session. Password reset tokens expire
after fifteen minutes and may be consumed only once.

See [session implementation](src/auth/session.ts) and `rotate_refresh_token`.
