# Story ref5-3: Task Templates CRUD Component

## Status

**Ready**

---

## Story

**As a** maintainer of the Scrumbringer codebase,
**I want** to extract the Admin Task Templates CRUD dialogs (create, edit, delete) into a self-contained Lustre Component,
**so that** the dialog state is encapsulated, reducing root Model complexity and improving maintainability.

---

## Acceptance Criteria

1. **Component Registration**: A new Lustre Component `<task-template-crud-dialog>` is registered on app init and renders correctly when invoked.

2. **State Encapsulation**: All 17 Task Templates CRUD state fields are moved from root Model to the component's internal state:
   - Create: `task_templates_create_dialog_open`, `task_templates_create_name`, `task_templates_create_description`, `task_templates_create_type_id`, `task_templates_create_priority`, `task_templates_create_in_flight`, `task_templates_create_error`
   - Edit: `task_templates_edit_id`, `task_templates_edit_name`, `task_templates_edit_description`, `task_templates_edit_type_id`, `task_templates_edit_priority`, `task_templates_edit_in_flight`, `task_templates_edit_error`
   - Delete: `task_templates_delete_confirm`, `task_templates_delete_in_flight`, `task_templates_delete_error`

3. **Message Encapsulation**: All 20 Task Templates CRUD Msg variants are removed from root Msg and handled internally:
   - Create: `TaskTemplateCreateDialogOpened`, `TaskTemplateCreateDialogClosed`, `TaskTemplateCreateNameChanged`, `TaskTemplateCreateDescriptionChanged`, `TaskTemplateCreateTypeIdChanged`, `TaskTemplateCreatePriorityChanged`, `TaskTemplateCreateSubmitted`, `TaskTemplateCreated`
   - Edit: `TaskTemplateEditClicked`, `TaskTemplateEditNameChanged`, `TaskTemplateEditDescriptionChanged`, `TaskTemplateEditTypeIdChanged`, `TaskTemplateEditPriorityChanged`, `TaskTemplateEditSubmitted`, `TaskTemplateUpdated`, `TaskTemplateEditCancelled`
   - Delete: `TaskTemplateDeleteClicked`, `TaskTemplateDeleteCancelled`, `TaskTemplateDeleteConfirmed`, `TaskTemplateDeleted`

4. **Handler Cleanup**: All task template CRUD handlers in `features/admin/task_templates.gleam` are moved to the component.

5. **Parent Communication**: The component communicates with the parent via:
   - **Attributes**: `locale` (String), `project-id` (Int as String), `mode` (create|edit|delete), `template-id` (Int as String)
   - **Properties**:
     - `template` (TaskTemplate as JSON) for edit prefill
     - `task-types` (List(TaskType) as JSON) for type selector options
   - **Custom Events**:
     - `template-created` with `{ template: TaskTemplate }` payload
     - `template-updated` with `{ template: TaskTemplate }` payload
     - `template-deleted` with `{ id: Int }` payload
     - `close-requested` when dialog closes

6. **Dialog Mode**: The component handles three modes internally:
   - Create mode: triggered by `mode="create"` attribute
   - Edit mode: triggered by `mode="edit"` attribute + `template-id` attribute
   - Delete confirm: triggered by `mode="delete"` attribute + `template-id` attribute

7. **Style Inheritance**: The component uses `adopt_styles(True)` to inherit CSS custom properties from parent.

8. **Task Type Selector**: The component receives task types as a property and renders a select dropdown.

9. **Priority Selector**: The priority field is a select with predefined options (1-5).

10. **Functional Parity**: All existing functionality works identically:
    - Open create dialog via "New Template" button
    - Fill name, description, select task type, select priority
    - Submit and see new template in list
    - Open edit dialog by clicking edit on a template row
    - Modify fields and save
    - Open delete confirmation by clicking delete
    - Confirm deletion

11. **Tests Pass**: All existing tests pass; new component has unit tests for Model and Msg types.

12. **No Dead Code**: All removed fields, messages, and handlers are completely deleted.

13. **Parent Minimal State**: The parent retains only:
    - `task_templates_dialog_mode: Option(TaskTemplateDialogMode)` where `TaskTemplateDialogMode = Create | Edit(Int) | Delete(Int)`

14. **Playwright Validation**: A Playwright test script validates all CRUD operations end-to-end:
    - Login as admin, navigate to Admin > Task Templates (within a workflow)
    - Create a new template with name, description, task type, priority
    - Verify template appears in list
    - Edit the template, change task type and priority, save
    - Verify changes persist
    - Delete the template with confirmation
    - Verify template removed from list
    - Fix any defects found during validation before marking story complete

---

## Tasks / Subtasks

- [ ] **Task 1: Create component module** (AC: 1)
  - [ ] Create `apps/client/src/scrumbringer_client/components/task_template_crud_dialog.gleam`
  - [ ] Define internal `Model` type with 17 encapsulated fields
  - [ ] Define internal `Msg` type with all dialog messages
  - [ ] Define `DialogMode` type: `Create | Edit(TaskTemplate) | Delete(TaskTemplate)`
  - [ ] Implement `register()` function

- [ ] **Task 2: Implement component lifecycle** (AC: 5, 6, 7)
  - [ ] Use `on_attribute_change("mode", ...)` to receive dialog mode
  - [ ] Use `on_attribute_change("template-id", ...)` for edit/delete
  - [ ] Use `on_attribute_change("locale", ...)` for i18n
  - [ ] Use `on_attribute_change("project-id", ...)` for API calls
  - [ ] Use `on_property_change("template", ...)` to receive TaskTemplate data
  - [ ] Use `on_property_change("task-types", ...)` to receive task type options
  - [ ] Configure `adopt_styles(True)`

- [ ] **Task 3: Implement i18n inside component** (AC: 10)
  - [ ] Create internal `t(locale, key)` helper
  - [ ] Import i18n text keys from shared module

- [ ] **Task 4: Migrate view code** (AC: 8, 9, 10)
  - [ ] Move `view_task_template_create_dialog` from `features/admin/view.gleam`
  - [ ] Move edit dialog view
  - [ ] Move delete confirmation dialog
  - [ ] Implement task type selector from passed property
  - [ ] Implement priority selector (1-5)
  - [ ] Update to use internal Model/Msg types

- [ ] **Task 5: Migrate update logic** (AC: 3, 4)
  - [ ] Move all handlers from `features/admin/task_templates.gleam`
  - [ ] Implement internal API calls (create, update, delete)
  - [ ] Emit custom events on success
  - [ ] Emit `close-requested` on cancel/close

- [ ] **Task 6: Integrate component in parent** (AC: 5, 13)
  - [ ] Register component in `scrumbringer_client.gleam`
  - [ ] Replace dialog views in `features/admin/view.gleam` with `<task-template-crud-dialog>` element
  - [ ] Pass task_types list as property
  - [ ] Add `TaskTemplateDialogMode` type to parent Model
  - [ ] Listen for custom events
  - [ ] Update FFI `knownComponents` array

- [ ] **Task 7: Clean up root Model** (AC: 2, 12, 13)
  - [ ] Remove 17 fields from `client_state.gleam`
  - [ ] Add `task_templates_dialog_mode: Option(TaskTemplateDialogMode)`
  - [ ] Update `default_model()` initialization

- [ ] **Task 8: Clean up root Msg** (AC: 3, 12)
  - [ ] Remove 20 Msg variants from `client_state.gleam`
  - [ ] Add minimal parent messages

- [ ] **Task 9: Clean up handlers** (AC: 4, 12)
  - [ ] Remove/simplify `features/admin/task_templates.gleam`
  - [ ] Remove task template dialog handlers from `features/admin/update.gleam`

- [ ] **Task 10: Write component tests** (AC: 11)
  - [ ] Create `apps/client/test/task_template_crud_dialog_test.gleam`
  - [ ] Test Model construction and defaults
  - [ ] Test Msg type constructors

- [ ] **Task 11: Verify existing tests** (AC: 11)
  - [ ] Run full test suite
  - [ ] Fix any broken tests

- [ ] **Task 12: Playwright E2E Validation** (AC: 14)
  - [ ] Write Playwright script to `/tmp/playwright-ref5-3-templates.js`
  - [ ] Automate: login, navigate to Admin > Workflows > (select workflow) > Templates
  - [ ] Automate: create template with name, description, task type, priority
  - [ ] Automate: verify template in list
  - [ ] Automate: edit template, change task type and priority
  - [ ] Automate: delete template with confirmation
  - [ ] Verify task type and priority selectors work correctly
  - [ ] Run script, fix any defects found
  - [ ] Re-run until all validations pass

---

## Dev Notes

### Relevant Source Tree

```
apps/client/src/scrumbringer_client/
├── components/
│   ├── card_detail_modal.gleam          # Reference implementation
│   ├── card_crud_dialog.gleam           # Similar pattern (ref5-1)
│   ├── workflow_crud_dialog.gleam       # Similar pattern (ref5-2)
│   └── task_template_crud_dialog.gleam  # NEW - this story
├── component.ffi.mjs                    # Update knownComponents array
├── features/admin/
│   ├── task_templates.gleam             # Handlers to migrate
│   ├── update.gleam                     # Remove template dialog dispatching
│   └── view.gleam                       # Replace dialogs with component
├── client_state.gleam                   # Remove 17 fields, 20 Msg variants
```

### Architecture Reference

See [Lustre Components Architecture](../architecture/lustre-components.md) for patterns.

### TaskTemplate Fields

The TaskTemplate entity has these fields:
- `id: Int`
- `name: String`
- `description: String`
- `task_type_id: Option(Int)`
- `priority: Int` (1-5)
- `workflow_id: Int`

### Form Fields

| Field | Type | Validation | Default |
|-------|------|------------|---------|
| name | String (required) | Not empty | "" |
| description | String (optional) | None | "" |
| task_type_id | Option(Int) | None | None |
| priority | String (select) | 1-5 | "3" |

### Priority Options

```gleam
let priority_options = [
  #("1", "Highest"),
  #("2", "High"),
  #("3", "Medium"),
  #("4", "Low"),
  #("5", "Lowest"),
]
```

### Task Type Options

The component receives `task_types: List(TaskType)` as a JSON property from the parent, which already has this data loaded.

### Differences from Previous Components

- Has two select dropdowns (task type, priority)
- Task type options come from parent as property (not fetched internally)
- Medium complexity due to selector logic

---

## Testing

### Test Location

`apps/client/test/task_template_crud_dialog_test.gleam`

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
| 2026-01-20 | 0.2 | Added AC 14: Playwright E2E Validation | Sarah (PO) |
| 2026-01-20 | 1.0 | Status: Ready (PO approval) | Sarah (PO) |
