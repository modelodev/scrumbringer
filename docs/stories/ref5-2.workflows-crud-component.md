# Story ref5-2: Workflows CRUD Component

## Status

**Ready**

---

## Story

**As a** maintainer of the Scrumbringer codebase,
**I want** to extract the Admin Workflows CRUD dialogs (create, edit, delete) into a self-contained Lustre Component,
**so that** the dialog state is encapsulated, reducing root Model complexity and improving maintainability.

---

## Acceptance Criteria

1. **Component Registration**: A new Lustre Component `<workflow-crud-dialog>` is registered on app init and renders correctly when invoked.

2. **State Encapsulation**: All 15 Workflows CRUD state fields are moved from root Model to the component's internal state:
   - Create: `workflows_create_dialog_open`, `workflows_create_name`, `workflows_create_description`, `workflows_create_active`, `workflows_create_in_flight`, `workflows_create_error`
   - Edit: `workflows_edit_id`, `workflows_edit_name`, `workflows_edit_description`, `workflows_edit_active`, `workflows_edit_in_flight`, `workflows_edit_error`
   - Delete: `workflows_delete_confirm`, `workflows_delete_in_flight`, `workflows_delete_error`

3. **Message Encapsulation**: All 18 Workflows CRUD Msg variants are removed from root Msg and handled internally:
   - Create: `WorkflowCreateDialogOpened`, `WorkflowCreateDialogClosed`, `WorkflowCreateNameChanged`, `WorkflowCreateDescriptionChanged`, `WorkflowCreateActiveChanged`, `WorkflowCreateSubmitted`, `WorkflowCreated`
   - Edit: `WorkflowEditClicked`, `WorkflowEditNameChanged`, `WorkflowEditDescriptionChanged`, `WorkflowEditActiveChanged`, `WorkflowEditSubmitted`, `WorkflowUpdated`, `WorkflowEditCancelled`
   - Delete: `WorkflowDeleteClicked`, `WorkflowDeleteCancelled`, `WorkflowDeleteConfirmed`, `WorkflowDeleted`

4. **Handler Cleanup**: All workflow CRUD handlers in `features/admin/workflows.gleam` are moved to the component.

5. **Parent Communication**: The component communicates with the parent via:
   - **Attributes**: `locale` (String), `project-id` (Int as String), `mode` (create|edit|delete), `workflow-id` (Int as String)
   - **Properties**: `workflow` (Workflow as JSON) for edit prefill
   - **Custom Events**:
     - `workflow-created` with `{ workflow: Workflow }` payload
     - `workflow-updated` with `{ workflow: Workflow }` payload
     - `workflow-deleted` with `{ id: Int }` payload
     - `close-requested` when dialog closes

6. **Dialog Mode**: The component handles three modes internally:
   - Create mode: triggered by `mode="create"` attribute
   - Edit mode: triggered by `mode="edit"` attribute + `workflow-id` attribute
   - Delete confirm: triggered by `mode="delete"` attribute + `workflow-id` attribute

7. **Style Inheritance**: The component uses `adopt_styles(True)` to inherit CSS custom properties from parent.

8. **Active Toggle**: The "Active" checkbox field works correctly in both create and edit modes.

9. **Functional Parity**: All existing functionality works identically:
   - Open create dialog via "New Workflow" button
   - Fill name, description, active checkbox
   - Submit and see new workflow in list
   - Open edit dialog by clicking edit on a workflow row
   - Modify fields and save
   - Open delete confirmation by clicking delete
   - Confirm deletion

10. **Tests Pass**: All existing tests pass; new component has unit tests for Model and Msg types.

11. **No Dead Code**: All removed fields, messages, and handlers are completely deleted.

12. **Parent Minimal State**: The parent retains only:
    - `workflows_dialog_mode: Option(WorkflowDialogMode)` where `WorkflowDialogMode = Create | Edit(Int) | Delete(Int)`

13. **Playwright Validation**: A Playwright test script validates all CRUD operations end-to-end:
    - Login as admin, navigate to Admin > Workflows
    - Create a new workflow with name, description, active=true
    - Verify workflow appears in list
    - Edit the workflow, toggle active checkbox, save
    - Verify changes persist
    - Delete the workflow with confirmation
    - Verify workflow removed from list
    - Fix any defects found during validation before marking story complete

---

## Tasks / Subtasks

- [ ] **Task 1: Create component module** (AC: 1)
  - [ ] Create `apps/client/src/scrumbringer_client/components/workflow_crud_dialog.gleam`
  - [ ] Define internal `Model` type with 15 encapsulated fields
  - [ ] Define internal `Msg` type with all dialog messages
  - [ ] Define `DialogMode` type: `Create | Edit(Workflow) | Delete(Workflow)`
  - [ ] Implement `register()` function

- [ ] **Task 2: Implement component lifecycle** (AC: 5, 6, 7)
  - [ ] Use `on_attribute_change("mode", ...)` to receive dialog mode
  - [ ] Use `on_attribute_change("workflow-id", ...)` for edit/delete
  - [ ] Use `on_attribute_change("locale", ...)` for i18n
  - [ ] Use `on_attribute_change("project-id", ...)` for API calls
  - [ ] Use `on_property_change("workflow", ...)` to receive Workflow data
  - [ ] Configure `adopt_styles(True)`

- [ ] **Task 3: Implement i18n inside component** (AC: 9)
  - [ ] Create internal `t(locale, key)` helper
  - [ ] Import i18n text keys from shared module

- [ ] **Task 4: Migrate view code** (AC: 8, 9)
  - [ ] Move `view_workflow_create_dialog` from `features/admin/view.gleam`
  - [ ] Move edit dialog view
  - [ ] Move delete confirmation dialog
  - [ ] Update to use internal Model/Msg types

- [ ] **Task 5: Migrate update logic** (AC: 3, 4)
  - [ ] Move all handlers from `features/admin/workflows.gleam`
  - [ ] Implement internal API calls (create, update, delete)
  - [ ] Emit custom events on success
  - [ ] Emit `close-requested` on cancel/close

- [ ] **Task 6: Integrate component in parent** (AC: 5, 12)
  - [ ] Register component in `scrumbringer_client.gleam`
  - [ ] Replace dialog views in `features/admin/view.gleam` with `<workflow-crud-dialog>` element
  - [ ] Add `WorkflowDialogMode` type to parent Model
  - [ ] Listen for custom events
  - [ ] Update FFI `knownComponents` array

- [ ] **Task 7: Clean up root Model** (AC: 2, 11, 12)
  - [ ] Remove 15 fields from `client_state.gleam`
  - [ ] Add `workflows_dialog_mode: Option(WorkflowDialogMode)`
  - [ ] Update `default_model()` initialization

- [ ] **Task 8: Clean up root Msg** (AC: 3, 11)
  - [ ] Remove 18 Msg variants from `client_state.gleam`
  - [ ] Add minimal parent messages

- [ ] **Task 9: Clean up handlers** (AC: 4, 11)
  - [ ] Remove/simplify `features/admin/workflows.gleam`
  - [ ] Remove workflow dialog handlers from `features/admin/update.gleam`

- [ ] **Task 10: Write component tests** (AC: 10)
  - [ ] Create `apps/client/test/workflow_crud_dialog_test.gleam`
  - [ ] Test Model construction and defaults
  - [ ] Test Msg type constructors

- [ ] **Task 11: Verify existing tests** (AC: 10)
  - [ ] Run full test suite
  - [ ] Fix any broken tests

- [ ] **Task 12: Playwright E2E Validation** (AC: 13)
  - [ ] Write Playwright script to `/tmp/playwright-ref5-2-workflows.js`
  - [ ] Automate: login, navigate to Admin > Workflows
  - [ ] Automate: create workflow with name, description, active
  - [ ] Automate: verify workflow in list
  - [ ] Automate: edit workflow, toggle active checkbox
  - [ ] Automate: delete workflow with confirmation
  - [ ] Run script, fix any defects found
  - [ ] Re-run until all validations pass

---

## Dev Notes

### Relevant Source Tree

```
apps/client/src/scrumbringer_client/
├── components/
│   ├── card_detail_modal.gleam      # Reference implementation
│   ├── card_crud_dialog.gleam       # Similar pattern (ref5-1)
│   └── workflow_crud_dialog.gleam   # NEW - this story
├── component.ffi.mjs                # Update knownComponents array
├── features/admin/
│   ├── workflows.gleam              # Handlers to migrate
│   ├── update.gleam                 # Remove workflow dialog dispatching
│   └── view.gleam                   # Replace dialogs with component
├── client_state.gleam               # Remove 15 fields, 18 Msg variants
```

### Architecture Reference

See [Lustre Components Architecture](../architecture/lustre-components.md) for patterns.

### Workflow Fields

The Workflow entity has these fields:
- `id: Int`
- `name: String`
- `description: String`
- `active: Bool`
- `project_id: Int`

### Form Fields

| Field | Type | Validation | Default |
|-------|------|------------|---------|
| name | String (required) | Not empty | "" |
| description | String (optional) | None | "" |
| active | Bool | None | True |

### Differences from Cards CRUD

- No color picker (simpler)
- Has `active` checkbox instead
- Same dialog size (Md)

---

## Testing

### Test Location

`apps/client/test/workflow_crud_dialog_test.gleam`

### Test Standards

- Use `gleeunit` framework
- Test Model construction with `should.equal`
- Test Msg type constructors
- Test DialogMode type variants

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-20 | 0.1 | Initial draft | Sarah (PO) |
| 2026-01-20 | 0.2 | Added AC 13: Playwright E2E Validation | Sarah (PO) |
| 2026-01-20 | 1.0 | Status: Ready (PO approval) | Sarah (PO) |
