# impact_scan_contract

## Files to Modify

### Client Files

| File | Change Type | Rationale |
|------|-------------|-----------|
| `apps/client/src/scrumbringer_client/api/tasks/operations.gleam` | Add function | Missing `update_task_title_description` PATCH function |
| `apps/client/src/scrumbringer_client/features/pool/msg.gleam` | Add msgs | `MemberTaskEditClicked`, `MemberTaskEditCancelled`, `MemberTaskEditTitleChanged`, `MemberTaskEditDescriptionChanged`, `MemberTaskEditSubmitted`, `MemberTaskUpdated(ApiResult(Task))` |
| `apps/client/src/scrumbringer_client/client_state/member/pool.gleam` | Add fields | `member_task_edit_mode: Bool`, `member_task_edit_title: String`, `member_task_edit_description: String`, `member_task_edit_error: Option(String)`, `member_task_edit_in_flight: Bool` |
| `apps/client/src/scrumbringer_client/features/pool/update.gleam` | Add handlers | Handle all new messages; call API; update task in store on success |
| `apps/client/src/scrumbringer_client/features/pool/dialogs.gleam` | Add UI | Add "Editar" button in DETALLES tab; show inputs in edit mode; save/cancel buttons; validation error display |
| `apps/client/src/scrumbringer_client/i18n/text.gleam` | Add i18n | `Edit`, `Save`, `Cancel`, `TitleRequired` (Spanish strings) |
| `apps/client/assets/task_detail_edit.css` | New file | Styles for edit mode inputs and buttons |

### Test Files

| File | Change Type | Rationale |
|------|-------------|-----------|
| `apps/client/test/scrumbringer_client/features/pool/update_test.gleam` | Extend | Test update handlers for new messages |
| `apps/client/test/scrumbringer_client/api/tasks/operations_test.gleam` | New file | Test `update_task_title_description` function |

---

## Technical Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Task version conflicts (optimistic locking) | Medium | Always send current `task.version` in PATCH body; handle 409 Conflict server-side |
| Race condition: task mutated while editing | Low | On PATCH success, update store with server-returned task; if 409, show conflict error |
| Edit state leaking across task detail opens | Medium | Reset edit state on `MemberTaskDetailsOpened` and `MemberTaskDetailsClosed` |
| Client store not updated after PATCH | High | After successful PATCH, update task in `member_tasks` store; update `member_task_detail_metrics` if changed |
| Lustre state model immutability | Low | Copy current title/description into edit state fields; revert or commit on cancel/submit |

---

## Regression Surface

- **DETALLES tab read mode**: Currently shows task details as read-only text. Must remain unchanged when not in edit mode.
- **NOTAS tab**: Must remain fully functional.
- **METRICS tab**: Must remain fully functional.
- **Task header**: Title displayed in header must remain read-only; editing happens only in DETALLES tab.
- **Task creation dialog**: Must not be affected.
- **Task claim/release/complete**: Must not be affected.

---

## Test Surface

- Unit: Update handler for each new message variant
- Unit: Validation logic (title non-empty)
- Unit: API function constructs correct PATCH body
- Integration: Store update after successful PATCH
- E2E: Edit button visible, edit mode enters, validation shows, save/cancel work, keyboard navigation

---

## No Changes Required

- Server-side: PATCH `/api/v1/tasks/:id` already exists and handles `title`/`description` fields
- Shared domain: `domain/field_update.gleam` already supports partial updates
- Client routing: No new routes needed
