# change_brief_contract

## Change Overview

**What**: Edit task title and description from the task detail modal in the pool view.

**Why**: Users currently cannot modify a task's title or description after creation without navigating away. Inline editing from the detail modal improves workflow continuity and discoverability.

**Scope**: Minimal: title field (text input), description field (textarea), save/cancel buttons, visible validation, reasonable keyboard support.

---

## Change Scope

- Add editable fields (title + description) inside the existing DETALLES tab of the task detail modal
- Inline editing within the existing modal (no separate dialog)
- Show save/cancel buttons only when changes are pending
- Client-side validation: title required, non-empty after trim; description optional
- Visible error messages near invalid fields
- Keyboard: Enter in title field → blur/save; Escape → cancel; Tab → natural flow; focus trap within edit controls
- No new API endpoints needed (PATCH /api/v1/tasks/:id already exists and supports title/description)

---

## Constraints

- Must work within existing modal structure (`dialogs.gleam`)
- Must use existing `FieldUpdate` pattern from `field_update.gleam` for PATCH payload
- Must include task version for optimistic locking
- Must handle network errors gracefully (retry / show error)
- Must not break existing task detail tabs (Notas, Métricas)
- Gleam/Lustre client: follow existing patterns (no external dependencies)

---

## Acceptance Criteria

1. Opening the DETALLES tab shows task title and description as read-only text
2. An "Editar" button is visible in the DETALLES tab header (discoverability)
3. Clicking "Editar" switches title/description to editable inputs
4. "Guardar" button is disabled when form is invalid or unchanged
5. "Cancelar" button reverts changes and exits edit mode
6. Title validation: shows error "El título es obligatorio" when empty
7. On save: PATCH request sent, on success fields return to read-only with new values
8. On save failure: show error message, keep edit mode, allow retry
9. Keyboard: Enter on title → save (if valid); Escape → cancel; Tab → navigate inputs
10. Focus returns to "Editar" button after cancel/save

---

## Success Signal

The feature is done when all 10 AC are demonstrable via Playwright E2E test and all existing tests pass.
