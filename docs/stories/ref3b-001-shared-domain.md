# Story ref3b-001: Consolidar dominio compartido (shared)

## Status: Done

## Story
**As a** maintainer,
**I want** to consolidate domain types into a single `shared/` package,
**so that** there is one canonical source of truth and no duplicate domain definitions.

## Acceptance Criteria
1. All domain types live under `shared/src/domain/*`.
2. No code imports from `packages/domain` or `scrumbringer_domain`.
3. Client and server depend only on `shared` for domain types.
4. Tests pass (`gleam test`, `make test`).

## Tasks / Subtasks

### Inventory & Unification
- [x] List modules in `packages/domain/src/scrumbringer_domain/*` — `org_role.gleam`, `user.gleam`
- [x] List modules in `shared/src/domain/*` — 8 modules (task_status, task_type, etc.)
- [x] For each overlap, consolidate into `shared` and remove duplicates — No overlap, just migration

### Migration
- [x] Move any domain modules that exist only in `packages/domain` into `shared/src/domain` — Moved `org_role.gleam`, `user.gleam`
- [x] Update all imports from `scrumbringer_domain/*` to `domain/*` — Updated 24 files

### Dependencies
- [x] Update `apps/client/gleam.toml` to remove `scrumbringer_domain`, keep `shared`
- [x] Update `apps/server/gleam.toml` similarly
- [x] Remove `packages/domain` if empty — Removed entirely

### Verification
- [x] Run `gleam test` (client, server, shared) — All pass
- [x] Run `make test` — Server: 69, Client: 82

## Dev Notes
- Canonical domain source: `shared/src/domain`.
- No behavior changes, refactor only.

## Testing
- `gleam test`
- `make test`

## Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-18 | 0.1 | Created ref3b-001 story | assistant |

## Dev Agent Record

**Agent**: James (Dev)
**Date**: 2026-01-18
**Model**: claude-opus-4-5-20251101

### Implementation Summary

Consolidated domain types from `packages/domain` into `shared/src/domain`:

**Modules Migrated:**
- `org_role.gleam` — OrgRole ADT (Admin, Member) with parse/to_string
- `user.gleam` — User type with OrgRole field

**Files Modified (24 total):**

Client:
- `features/auth/update.gleam`, `features/my_bar/view.gleam`
- `api/auth.gleam`, `permissions.gleam`, `accept_invite.gleam`
- `client_update.gleam`, `client_view.gleam`, `hydration.gleam`, `client_state.gleam`
- Tests: `accept_invite_test.gleam`, `permissions_test.gleam`, `hydration_test.gleam`

Server:
- `http/auth.gleam`, `http/org_invites.gleam`, `http/projects.gleam`
- `http/capabilities.gleam`, `http/org_users.gleam`, `http/org_invite_links.gleam`
- `http/org_metrics.gleam`
- `services/auth_logic.gleam`, `services/jwt.gleam`, `services/store_state.gleam`
- `persistence/auth/queries.gleam`, `persistence/auth/registration.gleam`

Config:
- `apps/client/gleam.toml` — Removed `scrumbringer_domain` dependency
- `apps/server/gleam.toml` — Removed `scrumbringer_domain` dependency
- `Makefile` — Updated to use `shared` instead of `packages/domain`

**Deleted:**
- `packages/domain/` — Entire directory removed

**Created:**
- `shared/src/domain/org_role.gleam`
- `shared/src/domain/user.gleam`
- `shared/test/shared_test.gleam` — Test entry point

**AC Verification:**
1. ✓ All domain types now in `shared/src/domain/` (10 modules)
2. ✓ No code imports from `packages/domain` or `scrumbringer_domain`
3. ✓ Client and server depend only on `shared` for domain types
4. ✓ Tests pass: Server 69, Client 82

### File List

**Created:**
- `shared/src/domain/org_role.gleam`
- `shared/src/domain/user.gleam`
- `shared/test/shared_test.gleam`

**Modified:**
- `apps/client/gleam.toml`
- `apps/server/gleam.toml`
- `Makefile`
- 24 source files (import updates)

**Deleted:**
- `packages/domain/` (entire directory)

### Verification

- Build: ✓ 0 warnings
- Tests: ✓ Server 69, Client 82

## QA Results
