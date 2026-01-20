# Story ref5-4: Rules CRUD Component

## Status

**Ready**

---

## Story

**As a** maintainer of the Scrumbringer codebase,
**I want** to extract the Admin Rules CRUD dialogs (create, edit, delete) into a self-contained Lustre Component,
**so that** the dialog state is encapsulated, reducing root Model complexity and improving maintainability.

---

## Acceptance Criteria

1. **Component Registration**: A new Lustre Component `<rule-crud-dialog>` is registered on app init and renders correctly when invoked.

2. **State Encapsulation**: All 21 Rules CRUD state fields are moved from root Model to the component's internal state:
   - Create: `rules_create_dialog_open`, `rules_create_name`, `rules_create_goal`, `rules_create_resource_type`, `rules_create_task_type_id`, `rules_create_to_state`, `rules_create_active`, `rules_create_in_flight`, `rules_create_error`
   - Edit: `rules_edit_id`, `rules_edit_name`, `rules_edit_goal`, `rules_edit_resource_type`, `rules_edit_task_type_id`, `rules_edit_to_state`, `rules_edit_active`, `rules_edit_in_flight`, `rules_edit_error`
   - Delete: `rules_delete_confirm`, `rules_delete_in_flight`, `rules_delete_error`

3. **Message Encapsulation**: All 24 Rules CRUD Msg variants are removed from root Msg and handled internally:
   - Create: `RuleCreateDialogOpened`, `RuleCreateDialogClosed`, `RuleCreateNameChanged`, `RuleCreateGoalChanged`, `RuleCreateResourceTypeChanged`, `RuleCreateTaskTypeIdChanged`, `RuleCreateToStateChanged`, `RuleCreateActiveChanged`, `RuleCreateSubmitted`, `RuleCreated`
   - Edit: `RuleEditClicked`, `RuleEditNameChanged`, `RuleEditGoalChanged`, `RuleEditResourceTypeChanged`, `RuleEditTaskTypeIdChanged`, `RuleEditToStateChanged`, `RuleEditActiveChanged`, `RuleEditSubmitted`, `RuleUpdated`, `RuleEditCancelled`
   - Delete: `RuleDeleteClicked`, `RuleDeleteCancelled`, `RuleDeleteConfirmed`, `RuleDeleted`

4. **Handler Cleanup**: All rule CRUD handlers in `features/admin/rules.gleam` are moved to the component.

5. **Parent Communication**: The component communicates with the parent via:
   - **Attributes**: `locale` (String), `workflow-id` (Int as String), `mode` (create|edit|delete), `rule-id` (Int as String)
   - **Properties**:
     - `rule` (Rule as JSON) for edit prefill
     - `task-types` (List(TaskType) as JSON) for task type selector
   - **Custom Events**:
     - `rule-created` with `{ rule: Rule }` payload
     - `rule-updated` with `{ rule: Rule }` payload
     - `rule-deleted` with `{ id: Int }` payload
     - `close-requested` when dialog closes

6. **Dialog Mode**: The component handles three modes internally:
   - Create mode: triggered by `mode="create"` attribute
   - Edit mode: triggered by `mode="edit"` attribute + `rule-id` attribute
   - Delete confirm: triggered by `mode="delete"` attribute + `rule-id` attribute

7. **Style Inheritance**: The component uses `adopt_styles(True)` to inherit CSS custom properties from parent.

8. **Conditional Fields**: The `task_type_id` field is only visible when `resource_type == "task"`. This logic must be handled internally in the component.

9. **Dynamic State Options**: The `to_state` select options depend on `resource_type`:
   - When `resource_type == "task"`: available, claimed, completed
   - When `resource_type == "card"`: pendiente, en_curso, cerrada

10. **Dialog Size**: This component uses `DialogLg` size (larger than other CRUD dialogs).

11. **Functional Parity**: All existing functionality works identically:
    - Open create dialog via "New Rule" button
    - Fill name, goal, resource type, task type (conditional), to_state, active
    - State options update when resource type changes
    - Task type field appears/disappears based on resource type
    - Submit and see new rule in list
    - Open edit dialog by clicking edit on a rule row
    - Modify fields and save
    - Open delete confirmation by clicking delete
    - Confirm deletion

12. **Tests Pass**: All existing tests pass; new component has unit tests for Model and Msg types.

13. **No Dead Code**: All removed fields, messages, and handlers are completely deleted.

14. **Parent Minimal State**: The parent retains only:
    - `rules_dialog_mode: Option(RuleDialogMode)` where `RuleDialogMode = Create | Edit(Int) | Delete(Int)`

15. **Playwright Validation**: A Playwright test script validates all CRUD operations end-to-end:
    - Login as admin, navigate to Admin > Workflows > (select workflow) > Rules
    - Create a new rule with resource_type="task", verify task_type field appears
    - Change resource_type to "card", verify task_type field hides and state options change
    - Submit and verify rule appears in list
    - Edit the rule, change fields, save
    - Verify changes persist
    - Delete the rule with confirmation
    - Verify rule removed from list
    - **Critical**: Validate conditional field behavior (task_type visibility) and dynamic state options
    - Fix any defects found during validation before marking story complete

---

## Tasks / Subtasks

- [ ] **Task 1: Create component module** (AC: 1)
  - [ ] Create `apps/client/src/scrumbringer_client/components/rule_crud_dialog.gleam`
  - [ ] Define internal `Model` type with 21 encapsulated fields
  - [ ] Define internal `Msg` type with all dialog messages
  - [ ] Define `DialogMode` type: `Create | Edit(Rule) | Delete(Rule)`
  - [ ] Implement `register()` function

- [ ] **Task 2: Implement component lifecycle** (AC: 5, 6, 7)
  - [ ] Use `on_attribute_change("mode", ...)` to receive dialog mode
  - [ ] Use `on_attribute_change("rule-id", ...)` for edit/delete
  - [ ] Use `on_attribute_change("locale", ...)` for i18n
  - [ ] Use `on_attribute_change("workflow-id", ...)` for API calls
  - [ ] Use `on_property_change("rule", ...)` to receive Rule data
  - [ ] Use `on_property_change("task-types", ...)` to receive task type options
  - [ ] Configure `adopt_styles(True)`

- [ ] **Task 3: Implement i18n inside component** (AC: 11)
  - [ ] Create internal `t(locale, key)` helper
  - [ ] Import i18n text keys from shared module
  - [ ] Include all state labels for both resource types

- [ ] **Task 4: Implement conditional field logic** (AC: 8, 9)
  - [ ] Create internal `view_state_options(resource_type)` helper
  - [ ] Return task states when resource_type == "task"
  - [ ] Return card states when resource_type == "card"
  - [ ] Show/hide task_type_id field based on resource_type

- [ ] **Task 5: Migrate view code** (AC: 10, 11)
  - [ ] Move `view_rule_create_dialog` from `features/admin/view.gleam`
  - [ ] Move `view_edit_rule_dialog`
  - [ ] Move delete confirmation dialog
  - [ ] Use `DialogLg` size
  - [ ] Update to use internal Model/Msg types

- [ ] **Task 6: Migrate update logic** (AC: 3, 4)
  - [ ] Move all handlers from `features/admin/rules.gleam`
  - [ ] Handle resource_type change to reset task_type_id and to_state
  - [ ] Implement internal API calls (create, update, delete)
  - [ ] Emit custom events on success
  - [ ] Emit `close-requested` on cancel/close

- [ ] **Task 7: Integrate component in parent** (AC: 5, 14)
  - [ ] Register component in `scrumbringer_client.gleam`
  - [ ] Replace dialog views in `features/admin/view.gleam` with `<rule-crud-dialog>` element
  - [ ] Pass task_types list as property
  - [ ] Add `RuleDialogMode` type to parent Model
  - [ ] Listen for custom events
  - [ ] Update FFI `knownComponents` array

- [ ] **Task 8: Clean up root Model** (AC: 2, 13, 14)
  - [ ] Remove 21 fields from `client_state.gleam`
  - [ ] Add `rules_dialog_mode: Option(RuleDialogMode)`
  - [ ] Update `default_model()` initialization

- [ ] **Task 9: Clean up root Msg** (AC: 3, 13)
  - [ ] Remove 24 Msg variants from `client_state.gleam`
  - [ ] Add minimal parent messages

- [ ] **Task 10: Clean up handlers** (AC: 4, 13)
  - [ ] Remove/simplify `features/admin/rules.gleam`
  - [ ] Remove rule dialog handlers from `features/admin/update.gleam`

- [ ] **Task 11: Write component tests** (AC: 12)
  - [ ] Create `apps/client/test/rule_crud_dialog_test.gleam`
  - [ ] Test Model construction and defaults
  - [ ] Test Msg type constructors
  - [ ] Test state_options_for_resource_type helper

- [ ] **Task 12: Verify existing tests** (AC: 12)
  - [ ] Run full test suite
  - [ ] Fix any broken tests

- [ ] **Task 13: Playwright E2E Validation** (AC: 15)
  - [ ] Write Playwright script to `/tmp/playwright-ref5-4-rules.js`
  - [ ] Automate: login, navigate to Admin > Workflows > (select workflow) > Rules
  - [ ] Automate: create rule with resource_type="task", verify task_type visible
  - [ ] Automate: change resource_type to "card", verify task_type hidden
  - [ ] Automate: verify state options change (task states vs card states)
  - [ ] Automate: submit, verify rule in list
  - [ ] Automate: edit rule, change fields
  - [ ] Automate: delete rule with confirmation
  - [ ] **Critical validations**:
    - [ ] Conditional task_type field visibility
    - [ ] Dynamic state options based on resource_type
    - [ ] Field reset on resource_type change
  - [ ] Run script, fix any defects found
  - [ ] Re-run until all validations pass

---

## Dev Notes

### Relevant Source Tree

```
apps/client/src/scrumbringer_client/
├── components/
│   ├── card_detail_modal.gleam        # Reference implementation
│   ├── card_crud_dialog.gleam         # ref5-1
│   ├── workflow_crud_dialog.gleam     # ref5-2
│   ├── task_template_crud_dialog.gleam # ref5-3
│   └── rule_crud_dialog.gleam         # NEW - this story
├── component.ffi.mjs                  # Update knownComponents array
├── features/admin/
│   ├── rules.gleam                    # Handlers to migrate
│   ├── update.gleam                   # Remove rule dialog dispatching
│   └── view.gleam                     # Replace dialogs with component
├── client_state.gleam                 # Remove 21 fields, 24 Msg variants
```

### Architecture Reference

See [Lustre Components Architecture](../architecture/lustre-components.md) for patterns.

### Rule Fields

The Rule entity has these fields:
- `id: Int`
- `name: String`
- `goal: String`
- `resource_type: String` ("task" | "card")
- `task_type_id: Option(Int)` (only when resource_type == "task")
- `to_state: String`
- `active: Bool`
- `workflow_id: Int`

### Form Fields

| Field | Type | Validation | Default | Notes |
|-------|------|------------|---------|-------|
| name | String (required) | Not empty | "" | |
| goal | String (optional) | None | "" | |
| resource_type | String (select) | "task" or "card" | "task" | |
| task_type_id | Option(Int) | None | None | **Conditional**: only when resource_type == "task" |
| to_state | String (select) | Dynamic options | "completed" | Options depend on resource_type |
| active | Bool | None | True | |

### State Options Logic

**CRITICAL**: This is the key complexity of this component.

```gleam
fn state_options_for_resource_type(locale: Locale, resource_type: String) -> List(#(String, String)) {
  case resource_type {
    "task" -> [
      #("available", t(locale, TaskStateAvailable)),
      #("claimed", t(locale, TaskStateClaimed)),
      #("completed", t(locale, TaskStateCompleted)),
    ]
    "card" | _ -> [
      #("pendiente", t(locale, CardStatePendiente)),
      #("en_curso", t(locale, CardStateEnCurso)),
      #("cerrada", t(locale, CardStateCerrada)),
    ]
  }
}
```

### Resource Type Change Handling

When `resource_type` changes:
1. Reset `task_type_id` to `None`
2. Reset `to_state` to first valid state for new resource type
3. Re-render state options

```gleam
fn handle_resource_type_changed(model: Model, resource_type: String) -> #(Model, Effect(Msg)) {
  let new_to_state = case resource_type {
    "task" -> "completed"
    _ -> "cerrada"
  }
  #(
    Model(
      ..model,
      resource_type: resource_type,
      task_type_id: option.None,
      to_state: new_to_state,
    ),
    effect.none(),
  )
}
```

### Complexity Warning

This is the most complex component in ref5 due to:
1. Conditional field visibility
2. Dynamic select options
3. Field interdependencies
4. Larger dialog size

Take extra care with testing the field interactions.

---

## Testing

### Test Location

`apps/client/test/rule_crud_dialog_test.gleam`

### Test Standards

- Use `gleeunit` framework
- Test Model construction with `should.equal`
- Test Msg type constructors
- Test `state_options_for_resource_type` returns correct options
- Test resource_type change resets dependent fields

### Playwright Validation

After implementation, validate these scenarios:
1. Create rule with resource_type = task, verify task_type field appears
2. Change resource_type to card, verify task_type field disappears
3. Verify state options change when resource_type changes
4. Edit existing rule, verify all fields prefill correctly
5. Delete rule and verify it's removed from list

---

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-20 | 0.1 | Initial draft | Sarah (PO) |
| 2026-01-20 | 0.2 | Added AC 15: Playwright E2E Validation with conditional field checks | Sarah (PO) |
| 2026-01-20 | 1.0 | Status: Ready (PO approval) | Sarah (PO) |
