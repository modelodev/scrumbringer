# Pull Flow Model Hardening Plan

## Context

ScrumBringer is a pull-flow project management product. The core product
contract is that work is visible in a shared pool, selected by the person doing
it, and then owned by that person until it is released or completed. Team
communication should stay outside the product; ScrumBringer keeps operational
context through notes, dependencies, cards, milestones, and flow signals.

This plan documents the intended model fit for three product decisions:

1. Who can edit tasks.
2. What `blocked` means.
3. How to replace "Assignments" language with "Equipo".

## Current Model Review

### Database

The `tasks` table stores lifecycle state with:

- `status`: `available`, `claimed`, `completed`.
- `claimed_by` and `claimed_at`: only meaningful for `claimed`.
- `completed_at`: only meaningful for `completed`.
- `version`: optimistic concurrency token for mutations.

The `task_dependencies` table stores dependency edges:

- `task_id`: task being blocked.
- `depends_on_task_id`: task that must be completed first.

There is no persisted `blocked` task state. This is correct. Blocked is a
derived readiness signal: a task is blocked when it has at least one dependency
whose status is not `completed`.

### Shared Types

`shared/src/domain/task_state.gleam` already has the right lifecycle shape:

```gleam
pub type TaskState {
  Available
  Claimed(claimed_by: Int, claimed_at: String, mode: status.ClaimedState)
  Completed(completed_at: String)
}
```

This makes invalid combinations unrepresentable after mapping from the database:

- completed with `claimed_by`
- claimed without `claimed_by`
- claimed without `claimed_at`
- available with `claimed_by`

`shared/src/domain/task_status.gleam` provides the public status vocabulary:

- `Available`
- `Claimed(Taken)`
- `Claimed(Ongoing)`
- `Completed`

`shared/src/domain/task.gleam` carries `blocked_count` and `dependencies` on
`Task`. That is enough for UI rendering and client-side affordances, while the
server must remain the source of truth for claim enforcement.

### Server Workflow

The current workflow already implements the desired edit semantics in behavior:

- `available` tasks can be updated by any project member who can fetch the task.
- `claimed` tasks can be updated only by the claiming user.
- `completed` tasks return `NotAuthorized`.

The naming is misleading:

- `UpdateTask` says "owner only".
- `update_task_claimed_by_user` says claimed-only.
- The SQL query name says `update_task_claimed_by_user`, while the SQL predicate
  also allows `status = 'available'`.

The original claim flow did not enforce blocked server-side. The UI opened a
blocked-claim confirmation in some paths, and drag/drop could still submit a
claim. That made `blocked` a warning rather than a hard readiness rule. The
implemented cleanup now makes blocked tasks non-claimable and keeps these
details as historical context for the hardening work.

### Client UI

The client already hides or disables claim actions in several blocked surfaces.
The earlier blocked claim override has been retired:

- `member_blocked_claim_task`
- `MemberBlockedClaimCancelled`
- `MemberBlockedClaimConfirmed`
- `blocked_claim_modal`

These names are kept here as historical audit markers only. They should not
reappear if blocked means non-claimable.

The org section currently uses the `Assignments` section, route, messages, and
labels for project/team membership management. The visible product term should
be `Equipo`; internal module names can be migrated separately.

## Target Rules

### Task Editing

The target edit rule is:

- Available task: any project member may edit task fields.
- Claimed task: only the claiming user may edit task fields.
- Completed task: no normal task-field edits.
- Notes: any project member may add notes; task notes can be deleted by their
  author or by a manager/admin when a correction is needed.
- Dependencies: manager/admin controlled, unchanged by this plan.

This keeps pool tasks collectively shapeable before ownership, and protects
ownership after claim.

### Blocked Claiming

The target blocked rule is:

- A blocked task is visible, searchable, readable, annotatable, and editable
  under the edit rules above.
- A blocked task is not claimable.
- A task becomes claimable when all dependencies are completed or the blocking
  dependency edges are removed.

This makes the pool trustworthy: if the UI or API allows claim, the task is
ready to be worked.

### Team Language

The target product language is:

- Navigation label: `Equipo`.
- Page title: `Equipo`.
- Toggle labels: `Por proyecto`, `Por persona`.
- Search placeholder: `Buscar proyectos o personas`.
- Empty state copy should use `personas`, `equipo`, and `proyectos`, not
  `asignaciones`.

The canonical route should be `/org/team`. `/org/assignments` should remain as
a compatibility route during transition.

## Type Design

### Task Edit Authorization

Add a small pure authorization decision near workflow task logic, for example in
`services/workflows/handlers.gleam` or a focused sibling module if it keeps the
handler smaller. The preferred shape is a direct gate returning `Result(Nil,
Error)` because no later branch needs extra data:

```gleam
fn authorize_task_edit(task: task_mappers.Task, user_id: Int) ->
  Result(Nil, Error) {
  case task.state {
    task_state.Available -> Ok(Nil)
    task_state.Claimed(claimed_by: owner_id, ..) if owner_id == user_id ->
      Ok(Nil)
    task_state.Claimed(..) | task_state.Completed(..) ->
      Error(NotAuthorized)
  }
}
```

If a later implementation genuinely needs different behavior for available and
own-claimed edits, introduce a private `TaskEditGrant` type then. Until that
point, `Result(Nil, Error)` is more idiomatic: the domain rule is still enforced
with exhaustive pattern matching, but the code does not invent an unused value.

Rename persistence boundaries to match behavior:

- SQL query name: `update_editable_task`.
- Query function: `update_editable_task`.
- Comments: "available or claimed by caller", not "claimed by user".

No database migration is needed for this rule.

### Claimability

Add a domain error variant to workflow errors:

```gleam
TaskBlockedByDependencies(blocked_count: Int)
```

Claim handling should reject blocked tasks before calling the transition query:

```gleam
fn claim_task_for_current(...) {
  case current.status, current.blocked_count {
    Claimed(_), _ -> Error(AlreadyClaimed)
    Completed, _ -> Error(InvalidTransition)
    Available, count if count > 0 -> Error(TaskBlockedByDependencies(count))
    Available, _ -> claim_available_task(...)
  }
}
```

The SQL update should also enforce the invariant atomically:

```sql
and not exists (
  select 1
  from task_dependencies d
  join tasks blocker on blocker.id = d.depends_on_task_id
  where d.task_id = tasks.id
    and blocker.status != 'completed'
)
```

The service-level check provides a clear domain error when the fetched task is
already known to be blocked. The SQL predicate protects against races where a
dependency is added or reopened between fetch and update. If the atomic update
returns no row, conflict detection should re-fetch the task and map
`blocked_count > 0` to `TaskBlockedByDependencies`.

HTTP mapping:

- Status: `409`
- Code: `CONFLICT_BLOCKED`
- Message: `Task has incomplete dependencies`
- Details, if convenient: `{ "blocked_count": count }`

### Team Section Naming

Prefer renaming the type-level section from `Assignments` to `Team`:

```gleam
pub type AdminSection {
  Invites
  OrgSettings
  Projects
  Team
  ApiTokens
  Metrics
  ...
}
```

This is better than changing only strings because future code will pattern
match on `Team`, not on the old assignment mental model.

Keep file/module names under `features/assignments` for the first pass if that
keeps the implementation small. A later mechanical rename can move files to
`features/team` after behavior and route compatibility are stable.

Router behavior:

- `format(Org(Team))` should emit `/org/team`.
- `parse("/org/team")` should parse as `Org(Team)`.
- `parse("/org/assignments")` should redirect to `Org(Team)` or parse as
  `Org(Team)` and be replaced by canonical URL.
- Assignment-view query parameters should still be supported on the team route.

## Idiomatic Gleam And Quality Bar

The implementation should keep the existing model and make invalid behavior
unrepresentable at the closest practical boundary:

- Keep lifecycle as `TaskState`/`TaskStatus`; do not add `Blocked` as a status.
- Keep blocked as derived data from dependencies and enforce claimability in the
  workflow plus the atomic SQL update.
- Use small pure helpers for rules that are currently spread across handlers,
  such as edit authorization and client claimability.
- Prefer explicit custom error variants over stringly typed blocked failures.
- Pattern match on task state and workflow errors exhaustively; avoid catch-all
  branches that would hide a future status or error.
- Keep helper types private unless they are part of a real module contract.

Tests are part of the design, not a cleanup pass:

- Server behavior tests must cover edit authorization, blocked claim rejection,
  unblock-by-completion, unblock-by-edge-removal, and the SQL race guard.
- Client tests must cover every claim entry point: card, row, detail footer,
  click/touch, and drag/drop.
- Router/i18n tests must prove `/org/team` is canonical while
  `/org/assignments` remains compatible.
- Gleam tests should use `let assert`, not the deprecated `should` style.
- Fixtures should reuse existing domain constructors so test data stays aligned
  with `Task`, `TaskState`, and `TaskStatus`.

Run the narrow package tests while developing and the repository gate before
completion:

- `gleam test` in touched Gleam packages.
- `gleam check` where the package supports it.
- `gleam format --check src test` or the repository's equivalent format gate.
- `make test` or the project release gate before merging this behavioral change.

## DRY And Obsolescence Cleanup

This change should remove the old warning/override model instead of adding a
second blocked interpretation beside it.

Required cleanup:

- Done: remove `member_blocked_claim_task` from pool state.
- Done: remove `MemberBlockedClaimCancelled` and `MemberBlockedClaimConfirmed`.
- Done: delete `blocked_claim_modal` and its tests after replacing expectations
  with "blocked tasks do not submit claim".
- Done: remove modal i18n keys and feedback strings that only support blocked
  override.
- Done: centralize client claimability in `features/tasks/claimability.gleam`
  and use it from card, row, detail footer, click, and drag/drop handling.
- Rename `update_task_claimed_by_user` and generated query bindings to
  `update_editable_task` so comments, function names, and SQL predicates all
  describe the same rule.
- Rename route helpers such as `format_assignments`, `replace_assignments_view`,
  and `push_assignments_view` to team-oriented names. Keep compatibility wrappers
  only when existing call sites need a staged migration.
- Rename visible i18n variants from `Assignments...` to `Team...` when practical.
  If the diff becomes too broad, update visible strings first and leave an
  explicit follow-up for type-level i18n cleanup.

Do not introduce a broad SQL abstraction only to deduplicate dependency summary
selects in this pass. The necessary DRY boundary is claimability and naming.
If dependency summary SQL continues to diverge, handle it separately with a view
or a focused query refactor.

## Implementation Plan

### 1. Align Documentation

Update the API contract to say:

- Available tasks can be edited by project members.
- Claimed tasks can be edited only by the claimer.
- Completed tasks are not editable through normal task PATCH.
- Blocked tasks cannot be claimed until incomplete dependencies are completed or
  removed.

### 2. Harden Server Task Editing

1. Add `authorize_task_edit`.
2. Use it from `handle_update_task`.
3. Rename `update_task_claimed_by_user` to `update_editable_task`.
4. Rename SQL query `update_task_claimed_by_user` to `update_editable_task`.
5. Keep the SQL predicate:
   `status = 'available' or (status = 'claimed' and claimed_by = $2)`.
6. Update comments and tests that currently describe this behavior with old
   owner-only or claimed-only language.

### 3. Harden Server Blocked Claiming

1. Add `TaskBlockedByDependencies(blocked_count: Int)` to workflow errors.
2. Reject blocked available tasks in `claim_task_for_current`.
3. Add the `not exists incomplete dependency` predicate to `tasks_claim.sql`.
4. Extend claim conflict detection to return blocked when a failed claim sees
   `blocked_count > 0`.
5. Map the error to `409 CONFLICT_BLOCKED`.
6. Ensure Bearer task claim receives the same behavior through the same workflow.

### 4. Simplify Client Blocked Claim UX

1. Done: remove `member_blocked_claim_task` from pool state.
2. Done: remove blocked claim messages and handlers.
3. Done: delete `blocked_claim_modal`.
4. Done: make direct click, detail footer, list row, canvas card, and drag/drop
   share one helper rule: blocked tasks do not submit claim.
5. Keep dependency visibility through blocked badge, task details, and blocker
   highlighting.
6. Add a non-modal feedback path for blocked drag/drop attempts if needed.

### 5. Rename Visible Assignments To Equipo

1. Rename `permissions.Assignments` to `permissions.Team`.
2. Update router slug to `team`.
3. Keep `assignments` as compatibility input.
4. Update i18n visible strings:
   - `Assignments`: `Equipo`
   - `AssignmentsSearchPlaceholder`: `Buscar proyectos o personas`
   - empty states to use `personas` and `equipo`
5. Rename route helper functions to team-oriented names.
6. Keep internal module paths initially unless the implementation is already
   touching most assignment files.

### 6. Clean Up Tests

Add or update tests at the public behavior boundaries.

Server:

- Available task can be patched by another project member.
- Claimed task can be patched by claimer.
- Claimed task cannot be patched by another member.
- Completed task cannot be patched.
- Blocked available task cannot be claimed.
- Previously blocked task can be claimed after dependency completion.
- Previously blocked task can be claimed after dependency removal.
- Race guard: claim SQL does not claim when an incomplete dependency exists.

Client:

- Blocked canvas card has no claim action.
- Blocked list row has no claim action.
- Blocked detail footer disables/hides claim.
- Blocked drag/drop does not call claim API.
- No blocked claim modal is rendered.

Router/i18n:

- `/org/team` is canonical.
- `/org/assignments` remains compatible.
- Visible nav/page label is `Equipo`.

Use `let assert` in Gleam tests and reuse existing domain constructors for task
fixtures.

## Non-Goals

- Do not add a persisted `blocked` column.
- Do not introduce a fourth task status such as `blocked`.
- Do not change note semantics.
- Do not create task assignment endpoints.
- Do not rename every `assignments` file in the first pass unless the diff is
  already mostly mechanical and low-risk.

## Acceptance Criteria

- The backend rejects blocked claims regardless of client behavior.
- The UI no longer offers a blocked-claim override.
- Editing behavior matches the product rule and the naming no longer suggests
  claimed-only editing.
- The org membership area is visibly called `Equipo`.
- `/org/team` is canonical and `/org/assignments` remains compatible.
- Tests cover server contracts, UI affordances, and route compatibility.
