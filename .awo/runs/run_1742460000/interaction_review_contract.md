# interaction_review_contract

## User-Facing Interaction Analysis

### Discoverability

**Problem**: The "Editar" button must be obvious to users who don't know the feature exists.

**Solution**: Place the "Editar" button in the DETALLES tab header, right-aligned, using a consistent secondary button style matching the existing UI pattern. The button label is localized "Editar". It is positioned inside the tab panel, visible only when DETALLES is active.

**Risk**: Users who never switch to the DETALLES tab will not see the edit button.
- **Mitigation**: Consider adding an edit icon in the task header title area, or a tooltip on the title. For MVP, the button in DETALLES is sufficient given the existing tab structure.

---

### Interaction Pattern: Inline Edit Toggle

**Pattern selected**: Toggle edit mode within the existing DETALLES tab.

**States**:
1. **Read mode** (default): Title and description shown as plain text with an "Editar" button
2. **Edit mode**: Title → `<input type="text">`, description → `<textarea>`, with "Guardar" and "Cancelar" buttons
3. **Saving**: Guardar disabled, spinner on button
4. **Error**: Error message shown below form, fields remain editable, Guardar re-enabled

**Transitions**:
- Read → Edit: Click "Editar"
- Edit → Save: Click "Guardar" (if valid)
- Edit → Cancel: Click "Cancelar" or press Escape
- Edit → Save (invalid): Guardar stays disabled; error shown inline
- Saving → Success: Switch to read mode with updated values
- Saving → Error: Show error message, remain in edit mode

---

### Feedback & Error Handling

| Scenario | User Feedback |
|----------|--------------|
| Empty title on submit | "El título es obligatorio" shown below title input |
| Network error on save | Error banner inside modal body, above the form fields |
| Version conflict (409) | "Esta tarea fue modificada por otro usuario. Recarga para ver los cambios." |
| Save success | Fields update to new values, switch to read mode, no toast needed |

---

### Keyboard Accessibility

| Key | Context | Action |
|-----|---------|--------|
| Enter | In title input | Blur title input (no submit, to prevent accidental save) |
| Escape | In any edit field | Cancel edit, revert to read mode |
| Tab | Navigate between inputs | Standard focus order: title → description → Guardar → Cancelar |
| Shift+Tab | Navigate back | Standard reverse focus order |
| Enter | On Guardar button (focused) | Submit form |
| Escape | On Guardar button (focused) | Cancel edit |

**Focus management**:
- On enter edit mode: focus moves to title input
- On cancel: focus returns to "Editar" button
- On save success: focus returns to "Editar" button
- On save error: focus stays on the title input

---

### Minimum Interaction Tests (Playwright E2E)

1. **Test: Edit button visible** — Open task detail, switch to DETALLES tab, assert "Editar" button is visible
2. **Test: Enter edit mode** — Click "Editar", assert title/description are now inputs
3. **Test: Validation blocks save** — Enter edit mode, clear title, assert Guardar is disabled
4. **Test: Cancel reverts** — Enter edit mode, modify fields, click Cancelar, assert read mode with original values
5. **Test: Save updates fields** — Enter edit mode, modify title, click Guardar, assert read mode shows new title
6. **Test: Escape cancels** — Enter edit mode, press Escape, assert read mode restored
7. **Test: Keyboard navigation** — Tab order is: title → description → Guardar → Cancelar
