# Story ref-frontend-06: Decoders centralizados de eventos

## Status

**Ready**

---

## Story

**As a** maintainer,
**I want** to centralize custom event decoders,
**so that** event handling is reusable and consistent across features.

---

## Acceptance Criteria

1. A shared module exists for event decoders (e.g. `utils/event_decoders.gleam`).
2. Drag/drop and custom component events use the shared decoders.
3. No event payload behavior changes are introduced.

---

## Tasks / Subtasks

- [ ] **Task 1: Create decoder catalog** (AC: 1)
  - [ ] Add `apps/client/src/scrumbringer_client/utils/event_decoders.gleam`
  - [ ] Add decoders for drag events and custom component payloads

- [ ] **Task 2: Migrate usage** (AC: 2, 3)
  - [ ] Update pool drag/drop event handlers to use shared decoders
  - [ ] Update component custom event handlers to use shared decoders

- [ ] **Task 3: Regression check** (AC: 3)
  - [ ] Run `cd apps/client && gleam test`
  - [ ] Smoke check drag/drop behavior

---

## Dev Notes

### Relevant Source Tree

```
apps/client/src/scrumbringer_client/
├── utils/
├── features/pool/
└── components/
```

### Standards and Constraints

- Keep decoders pure and reusable.
- Avoid feature-specific logic in shared decoder module.

Reference: `docs/architecture/coding-standards.md` (view purity and shared helpers).

---

## Testing

- `cd apps/client && gleam test`

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-25 | 1.0 | Ready story created | Sarah (PO) |

---

## QA Results
