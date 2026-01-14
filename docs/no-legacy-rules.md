# No-legacy Rules

## Policy

Unless explicitly requested by the user, do not introduce or keep legacy interfaces.

### Invites

- Do **not** support `invite_code`.
- Use `invite_token` (and invite-links) only.

## Rationale

This prevents legacy compatibility from constraining product evolution and keeps the API surface minimal.
