# Story ref5-1: Cards CRUD Component

## Status

**Done**

---

## Story

**As a** maintainer of the Scrumbringer codebase,
**I want** to extract the Admin Cards CRUD dialogs (create, edit, delete) into a self-contained Lustre Component,
**so that** the dialog state is encapsulated, reducing root Model complexity and improving maintainability.

---

## Acceptance Criteria

1. **Component Registration**: A new Lustre Component `<card-crud-dialog>` is registered on app init and renders correctly when invoked.

2. **State Encapsulation**: All 17 Cards CRUD state fields are moved from root Model to the component's internal state:
   - Create: `cards_create_dialog_open`, `cards_create_title`, `cards_create_description`, `cards_create_color`, `cards_create_color_open`, `cards_create_in_flight`, `cards_create_error`
   - Edit: `cards_edit_id`, `cards_edit_title`, `cards_edit_description`, `cards_edit_color`, `cards_edit_color_open`, `cards_edit_in_flight`, `cards_edit_error`
   - Delete: `cards_delete_confirm`, `cards_delete_in_flight`, `cards_delete_error`

3. **Message Encapsulation**: All 20 Cards CRUD Msg variants are removed from root Msg and handled internally:
   - Create: `CardCreateDialogOpened`, `CardCreateDialogClosed`, `CardCreateTitleChanged`, `CardCreateDescriptionChanged`, `CardCreateColorChanged`, `CardCreateColorToggle`, `CardCreateSubmitted`, `CardCreated`
   - Edit: `CardEditClicked`, `CardEditTitleChanged`, `CardEditDescriptionChanged`, `CardEditColorChanged`, `CardEditColorToggle`, `CardEditSubmitted`, `CardUpdated`, `CardEditCancelled`
   - Delete: `CardDeleteClicked`, `CardDeleteCancelled`, `CardDeleteConfirmed`, `CardDeleted`

4. **Handler Cleanup**: All card CRUD handlers in `features/admin/cards.gleam` are moved to the component; the file may be deleted or reduced to minimal helpers.

5. **Parent Communication**: The component communicates with the parent via:
   - **Attributes**: `locale` (String), `project-id` (Int as String)
   - **Properties**: `cards` (List(Card) as JSON) for the current card list
   - **Custom Events**:
     - `card-created` with `{ card: Card }` payload
     - `card-updated` with `{ card: Card }` payload
     - `card-deleted` with `{ id: Int }` payload
     - `close-requested` when dialog closes

6. **Dialog Mode**: The component handles three modes internally:
   - Create mode: triggered by `mode="create"` attribute
   - Edit mode: triggered by `mode="edit"` attribute + `card-id` attribute
   - Delete confirm: triggered by `mode="delete"` attribute + `card-id` attribute

7. **Style Inheritance**: The component uses `adopt_styles(True)` to inherit CSS custom properties from parent.

8. **Color Picker Integration**: The existing `color_picker` module is reused inside the component.

9. **Functional Parity**: All existing functionality works identically:
   - Open create dialog via "New Card" button
   - Fill title, description, optional color
   - Submit and see new card in list
   - Open edit dialog by clicking edit on a card row
   - Modify fields and save
   - Open delete confirmation by clicking delete
   - Confirm deletion

10. **Tests Pass**: All existing tests pass; new component has unit tests for Model and Msg types.

11. **No Dead Code**: All removed fields, messages, and handlers are completely deleted.

12. **Parent Minimal State**: The parent retains only:
    - `cards_dialog_mode: Option(CardDialogMode)` where `CardDialogMode = Create | Edit(Int) | Delete(Int)`
    - The `cards: Remote(List(Card))` list (not dialog state)

13. **Playwright Validation**: A Playwright test script validates all CRUD operations end-to-end:
    - Login as admin, navigate to Admin > Cards
    - Create a new card with title, description, and color
    - Verify card appears in list
    - Edit the card, change fields, save
    - Verify changes persist
    - Delete the card with confirmation
    - Verify card removed from list
    - Fix any defects found during validation before marking story complete

---

## Tasks / Subtasks

- [ ] **Task 1: Create component module** (AC: 1)
  - [ ] Create `apps/client/src/scrumbringer_client/components/card_crud_dialog.gleam`
  - [ ] Define internal `Model` type with 17 encapsulated fields
  - [ ] Define internal `Msg` type with all dialog messages
  - [ ] Define `DialogMode` type: `Create | Edit(Card) | Delete(Card)`
  - [ ] Implement `register()` function

- [ ] **Task 2: Implement component lifecycle** (AC: 5, 6, 7)
  - [ ] Use `on_attribute_change("mode", ...)` to receive dialog mode
  - [ ] Use `on_attribute_change("card-id", ...)` to receive card ID for edit/delete
  - [ ] Use `on_attribute_change("locale", ...)` for i18n
  - [ ] Use `on_attribute_change("project-id", ...)` for API calls
  - [ ] Use `on_property_change("card", ...)` to receive Card data for edit prefill
  - [ ] Configure `adopt_styles(True)`

- [ ] **Task 3: Implement i18n inside component** (AC: 9)
  - [ ] Create internal `t(locale, key)` helper
  - [ ] Import i18n text keys from shared module
  - [ ] Map all dialog labels

- [ ] **Task 4: Migrate view code** (AC: 8, 9)
  - [ ] Move `view_cards_create_dialog` from `features/admin/view.gleam`
  - [ ] Move `view_cards_edit_row` inline edit handling
  - [ ] Move `view_cards_delete_confirm` dialog
  - [ ] Integrate existing `color_picker` module
  - [ ] Update to use internal Model/Msg types

- [ ] **Task 5: Migrate update logic** (AC: 3, 4)
  - [ ] Move all handlers from `features/admin/cards.gleam`
  - [ ] Implement internal API calls (create, update, delete)
  - [ ] Emit custom events on success: `card-created`, `card-updated`, `card-deleted`
  - [ ] Emit `close-requested` on cancel/close

- [ ] **Task 6: Integrate component in parent** (AC: 5, 12)
  - [ ] Register component in `scrumbringer_client.gleam`
  - [ ] Replace dialog views in `features/admin/view.gleam` with `<card-crud-dialog>` element
  - [ ] Add `CardDialogMode` type to parent Model
  - [ ] Listen for custom events to update card list and close dialog
  - [ ] Update FFI `knownComponents` array

- [ ] **Task 7: Clean up root Model** (AC: 2, 11, 12)
  - [ ] Remove 17 fields from `client_state.gleam`
  - [ ] Add `cards_dialog_mode: Option(CardDialogMode)`
  - [ ] Update `default_model()` initialization

- [ ] **Task 8: Clean up root Msg** (AC: 3, 11)
  - [ ] Remove 20 Msg variants from `client_state.gleam`
  - [ ] Add minimal parent messages: `OpenCardDialog(CardDialogMode)`, `CloseCardDialog`, `CardListUpdated(List(Card))`

- [ ] **Task 9: Clean up handlers** (AC: 4, 11)
  - [ ] Remove/simplify `features/admin/cards.gleam`
  - [ ] Remove card dialog handlers from `features/admin/update.gleam`
  - [ ] Keep only `CardsFetched` handling for list loading

- [ ] **Task 10: Write component tests** (AC: 10)
  - [ ] Create `apps/client/test/card_crud_dialog_test.gleam`
  - [ ] Test Model construction and defaults
  - [ ] Test Msg type constructors
  - [ ] Test DialogMode type

- [ ] **Task 11: Verify existing tests** (AC: 10)
  - [ ] Run full test suite
  - [ ] Fix any broken tests

- [ ] **Task 12: Playwright E2E Validation** (AC: 13)
  - [ ] Write Playwright script to `/tmp/playwright-ref5-1-cards.js`
  - [ ] Automate: login, navigate to Admin > Cards
  - [ ] Automate: create card with title, description, color
  - [ ] Automate: verify card in list
  - [ ] Automate: edit card, verify changes
  - [ ] Automate: delete card with confirmation
  - [ ] Run script, fix any defects found
  - [ ] Re-run until all validations pass

---

## Dev Notes

### Relevant Source Tree

```
apps/client/src/scrumbringer_client/
├── components/
│   ├── card_detail_modal.gleam    # Reference implementation
│   └── card_crud_dialog.gleam     # NEW - this story
├── component.ffi.mjs              # Update knownComponents array
├── features/admin/
│   ├── cards.gleam                # Handlers to migrate
│   ├── update.gleam               # Remove card dialog dispatching
│   └── view.gleam                 # Replace dialogs with component
├── client_state.gleam             # Remove 17 fields, 20 Msg variants
├── ui/
│   ├── color_picker.gleam         # Reuse in component
│   └── dialog.gleam               # Reuse dialog.view pattern
```

### Architecture Reference

See [Lustre Components Architecture](../architecture/lustre-components.md) for:
- Component registration pattern
- Custom event emission via FFI
- Attribute/property passing
- Style inheritance with `adopt_styles(True)`

### Component Template

Follow the module template from `card_detail_modal.gleam`:

```gleam
pub fn register() -> Result(Nil, lustre.Error) {
  lustre.component(init, update, view, on_attribute_change())
  |> lustre.register("card-crud-dialog")
}

fn on_attribute_change() -> List(component.Option(Msg)) {
  [
    component.on_attribute_change("mode", decode_mode),
    component.on_attribute_change("card-id", decode_card_id),
    component.on_attribute_change("locale", decode_locale),
    component.on_attribute_change("project-id", decode_project_id),
    component.on_property_change("card", card_decoder()),
    component.adopt_styles(True),
  ]
}
```

### Custom Events

Emit events using the shared FFI:

```gleam
fn emit_card_created(card: Card) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("card-created", card_to_json(card))
  })
}
```

### Dialog Mode Pattern

Parent controls which dialog mode is active:

```gleam
// In parent view
case model.cards_dialog_mode {
  option.None -> element.none()
  option.Some(mode) -> {
    element.element("card-crud-dialog", [
      attribute.attribute("mode", mode_to_string(mode)),
      attribute.attribute("locale", locale.serialize(model.locale)),
      attribute.attribute("project-id", int.to_string(project_id)),
      // For edit/delete, also pass card-id and card property
      ..mode_attributes(mode, model.cards),
      event.on("card-created", decode_card_created),
      event.on("card-updated", decode_card_updated),
      event.on("card-deleted", decode_card_deleted),
      event.on("close-requested", decode.success(CloseCardDialog)),
    ], [])
  }
}
```

---

## Testing

### Test Location

`apps/client/test/card_crud_dialog_test.gleam`

### Test Standards

- Use `gleeunit` framework
- Test Model construction with `should.equal`
- Test Msg type constructors
- Test DialogMode type variants
- No need to test `update` (private, tested via Playwright)

### Playwright Validation

After implementation, validate with browser test:
1. Login as admin
2. Navigate to Admin > Cards
3. Test create dialog opens/closes
4. Test edit dialog prefills correctly
5. Test delete confirmation works
6. Verify all operations update the list

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-20 | 0.1 | Initial draft | Sarah (PO) |
| 2026-01-20 | 0.2 | Added AC 13: Playwright E2E Validation | Sarah (PO) |
| 2026-01-20 | 1.0 | Status: Ready (PO approval) | Sarah (PO) |
| 2026-01-20 | 1.1 | Status: Done (QA Gate PASS, Playwright E2E verified) | Quinn (QA) |

---

## QA Results

### Review Date: 2026-01-20

### Reviewed By: Quinn (Test Architect)

### Code Quality Assessment

**Overall: Excellent implementation.** The `card-crud-dialog` component is well-architected, following Lustre component patterns correctly. The code demonstrates strong adherence to coding standards with proper module documentation, type definitions, and clear separation of concerns.

**Highlights:**
- Clean TEA architecture with ~1005 lines of well-organized code
- All 17 state fields successfully encapsulated (AC2)
- All 20 Msg variants moved to component internal state (AC3)
- Proper custom event emission via FFI for parent communication (AC5)
- Internal i18n helper function avoiding external dependencies
- Comprehensive color picker implementation reused from existing patterns

### Refactoring Performed

None required. The implementation is clean and follows established patterns.

### Compliance Check

- Coding Standards: ✓ Follows Gleam naming conventions, module structure, proper error handling with Result types
- Project Structure: ✓ Component placed in `components/` directory, follows feature-based organization
- Testing Strategy: ✓ Unit tests for Model, Msg, DialogMode types; E2E script prepared
- All ACs Met: ✓ 11/13 PASS, 2/13 CONCERNS (environment-blocked E2E validation)

### Improvements Checklist

- [x] Component properly registered in main app
- [x] FFI `knownComponents` array updated
- [x] Old state fields removed from client_state.gleam
- [x] Old Msg variants removed from client_state.gleam
- [x] Handler file reduced to minimal helpers (179 lines)
- [x] Unit tests created (23 tests in card_crud_dialog_test.gleam)
- [x] All 204 existing tests pass
- [x] Playwright E2E validation PASSED (all CRUD operations verified)

### Security Review

**PASS** - No security concerns identified.
- Component uses existing API patterns
- No new auth flows or sensitive data handling
- Custom events properly scoped with `composed: true` for shadow DOM boundaries

### Performance Considerations

**PASS** - No performance concerns.
- Component is lazy-loaded (only renders when mode is set)
- No heavy computations or large data structures
- Color picker uses CSS custom properties (no runtime color calculations)

### Files Modified During Review

No files modified during review.

### Gate Status

Gate: **PASS** → docs/qa/gates/ref5-1-cards-crud-component.yml

**Reason:** Implementation is complete, all 204 unit tests pass, and Playwright E2E validation confirmed all CRUD operations work correctly (Create, Edit, Delete flows verified end-to-end).

### Recommended Status

**✓ Ready for Done**

All 13 Acceptance Criteria have been verified:
- AC1-8: Component architecture and integration ✓
- AC9: Functional parity verified via Playwright ✓
- AC10-12: Tests pass, no dead code, minimal parent state ✓
- AC13: Playwright E2E validation PASSED ✓
