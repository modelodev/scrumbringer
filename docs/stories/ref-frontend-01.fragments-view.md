# Story ref-frontend-01: Fragments y composicion de vistas

## Status

**Ready**

---

## Story

**As a** maintainer,
**I want** to introduce `element.fragment` and extract repeated view blocks in large views,
**so that** the UI code is more reusable and easier to maintain without changing behavior.

---

## Acceptance Criteria

1. `client_view.gleam` uses `element.fragment` to group repeated or large sibling blocks.
2. `features/admin/view.gleam` uses fragments in large sections to reduce nested wrapper divs.
3. Extracted view blocks remain pure functions (no effects).
4. No visual or routing behavior changes are introduced.

---

## Tasks / Subtasks

- [ ] **Task 1: Identify fragment candidates** (AC: 1, 2)
  - [ ] Audit `client_view.gleam` for repeated wrapper patterns
  - [ ] Audit `features/admin/view.gleam` for large nested sections

- [ ] **Task 2: Introduce fragments in client_view** (AC: 1, 3, 4)
  - [ ] Replace repeated wrapper divs with `element.fragment`
  - [ ] Extract repeated blocks into pure `view_*` helpers

- [ ] **Task 3: Introduce fragments in admin view** (AC: 2, 3, 4)
  - [ ] Add fragments to large admin sections
  - [ ] Extract repeated blocks into pure helpers

- [ ] **Task 4: Regression check** (AC: 4)
  - [ ] Run `cd apps/client && gleam test`
  - [ ] Smoke check admin + main navigation

---

## Dev Notes

### Relevant Source Tree

```
apps/client/src/scrumbringer_client/
├── client_view.gleam
├── features/admin/view.gleam
└── ui/
```

### Standards and Constraints

- View functions must remain pure (no effects) and return `Element(Msg)` only.
- Prefer view functions over components unless internal state is required.
- Keep changes localized to view composition (no routing changes).

Reference: `docs/architecture/coding-standards.md` (Lustre patterns, view purity).

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
