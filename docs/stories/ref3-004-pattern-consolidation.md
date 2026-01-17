# Story ref3-004: Consolidación de patrones duplicados — Phase 4

## Status: Draft

## Story
**As a** maintainer,
**I want** to consolidate duplicated UI/update patterns,
**so that** logic is centralized, consistent, and easier to maintain.

## Acceptance Criteria
1. Shared loading/error/empty UI patterns are extracted into reusable components.
2. Auth error handling (401/403) is centralized in `client/app/effects.gleam`.
3. All previous duplicate call sites are updated to use the new shared utilities.
4. Tests pass and behavior remains unchanged.

## Tasks / Subtasks

- [ ] Create shared UI components for loading/error/empty states
  - [ ] `client/ui/loading.gleam`
  - [ ] `client/ui/error.gleam`
  - [ ] (Optional) `client/ui/empty_state.gleam`

- [ ] Centralize auth error handling
  - [ ] Extract 401/403 handling to `client/app/effects.gleam`
  - [ ] Ensure consistent redirect/toast behavior across workflows

- [ ] Update call sites to use shared utilities
  - [ ] Replace loading/error/empty blocks in views (all occurrences in `client_view.gleam` and feature views)
  - [ ] Replace auth error blocks in `client_workflows/*`, `update_helpers.gleam`, `client_update.gleam`

- [ ] Verification
  - [ ] Run `gleam test`
  - [ ] Run `make test`

## Dev Notes
- Source of truth: `docs/sprint-3-backlog.md` → Pattern Duplications section.
- Keep UI components pure; no effects in view.

## Testing
- `gleam test`
- `make test`

## Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-17 | 0.1 | Created ref3-004 story from Sprint 3 backlog | assistant |

## Dev Agent Record

## QA Results
