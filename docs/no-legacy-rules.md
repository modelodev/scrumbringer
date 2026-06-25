# No-legacy Rules

## Policy

Unless explicitly requested by the user, do not introduce or keep legacy interfaces.

Compatibility code is allowed only at a strictly external boundary, such as
public API decoding, persisted data repair, or URL redirects for already-shipped
links. Each exception must have an owner, tests, and product justification.
Internal domain, repository, use-case, client state, selector, and UI code must
use the canonical model for the current product.

Historical planning documents may mention removed modules, old routes, or
intermediate names. Treat those references as context, not current architecture.

### Invites

- Do **not** support `invite_code`.
- Use `invite_token` (and invite-links) only.

## Rationale

This prevents legacy compatibility from constraining product evolution and keeps the API surface minimal.
