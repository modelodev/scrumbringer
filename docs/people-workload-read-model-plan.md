# People Workload Read Model Plan

## Status

Superseded by `task-claim-active-card-invariant-plan.md` for any behavior that
allowed claimed work outside active card lineage.

This plan replaces the current accidental composition used by the `Personas`
view. `Personas` must not infer team workload from the generic Pool task list.
It needs a dedicated read model whose contract matches the product question:

> Who has work, who is working now, who is blocked, and who is available in the
> selected project context?

No legacy or compatibility layer should be kept while implementing this plan.
Internal code must move to the new workload model directly.

## Cleanup Policy

This proposal treats cleanup as a success condition. The implementation is not
complete while old internal composition paths, compatibility state, fallback
decoders, or tests for the previous behavior remain.

Every trace of the previous `Personas` model must be classified as one of:

- **delete**: obsolete code, fixtures, styles, copy, tests, and helpers with no
  owner after `PersonWorkload` exists;
- **migrate**: behavior that still matters but must move to the workload read
  model, workload codec, or `features/people`;
- **external boundary**: a persisted/API compatibility requirement with an
  explicit owner and comment.

For this feature, no internal compatibility is accepted as final state. In
particular, do not keep a dual path where `Personas` can render from the old
`/members` plus `/tasks` composition when the workload endpoint fails or has not
loaded. Loading, error, and empty states must be explicit workload states.

Production migration scope does not require preserving unfinished internal
transitions. If code exists only to support a model that is no longer deployed,
used, or intentionally exposed as an external contract, it should be removed
rather than wrapped.

## Final Proposal

`Personas` becomes a workload coordination surface, not a projection assembled
from Pool internals. The screen should answer three operational questions from a
single backend contract:

- who is working now;
- who has reserved work but has not started it;
- who needs attention or is available.

The final implementation must use `PersonWorkload` as the owned model for this
feature. Pool can still navigate to tasks and cards, but it must not be the
source of truth for classifying people.

The UI should keep the current dense operational style used by ScrumBringer and
make the two expanded person sections clearer:

- `Trabajando ahora`: tasks with an ongoing session, shown as the active focus
  for that person.
- `Reclamadas, no iniciadas`: claimed tasks without an ongoing session, shown as
  reserved work.
- `Requiere atencion`: derived signals such as blocked claimed tasks. `blocked`
  remains derived, not a persisted task state.
- `Disponibles`: people with no claimed or ongoing workload.

Rows can still open task detail, but copy and labels must make that explicit:
the action is about the task, while the row remains about the person. Context
should show task title, card title, card phase, capability when available, and a
clear flag when the card is outside active Pool scope.

Blocked semantics:

- `blocked` is derived from open dependencies.
- A blocked task cannot be claimed.
- An already claimed task can become blocked if a manager adds a dependency.
- If a claimed task becomes blocked, it remains assigned to the same person.
- While blocked, the task cannot be closed.
- It can be released.
- When dependencies close or disappear, the task unblocks automatically and
  continues its normal flow.

This plan intentionally avoids compatibility fallbacks. If a call site still
needs the old task/member composition after the workload endpoint exists, that
call site must be migrated or deleted.

## Problem

The current implementation mixes incompatible scopes:

- `/api/v1/projects/:id/members` counts claimed tasks from `tasks`.
- `/api/v1/projects/:id/tasks` filters out tasks whose card is not `active`.
- `Personas` derives person state from the frontend task list.

This creates contradictory behavior. A member can have a claimed task counted by
the roster endpoint, while the task is absent from the task endpoint consumed by
`Personas`. In that case the UI can classify the person as available, and the
`Con trabajo` filter can hide them.

The root issue is architectural: `Personas` consumes endpoints designed for
other screens and reconstructs a workload model in the client.

## Target Model

Add a dedicated endpoint:

```text
GET /api/v1/projects/:project_id/people/workload
```

The endpoint returns one row per project member, including:

- member identity and project role;
- primary operational state;
- working-now tasks;
- reserved claimed tasks;
- attention signals;
- available/free state;
- task summaries needed by the UI;
- card context for valid active-card work.

The earlier version of this plan proposed a scope flag for claimed tasks in
draft or closed cards. That proposal is obsolete: those states are invalid under
the final claim invariant and must be prevented or cleaned, not explained in
the People payload.

Suggested payload shape:

```json
{
  "data": {
    "people": [
      {
        "user_id": 4,
        "email": "beta@example.com",
        "role": "member",
        "state": "reserved",
        "working_now": [],
        "reserved": [
          {
            "task_id": 4,
            "title": "P1 - Session timeout #4",
            "card_id": 3,
            "card_title": "P1 - Retrospective #3",
            "card_state": "draft",
            "blocked": false
          }
        ],
        "attention": [],
        "summary": {
          "working_now_count": 0,
          "reserved_count": 1,
          "attention_count": 0
        }
      }
    ]
  }
}
```

Exact field names can change during implementation, but the contract must keep
these semantics:

- claimed work counts as person workload even when its card is `draft`;
- ongoing work is shown as working now;
- blocked is derived, not a stored task state;
- closed tasks do not count as active workload;
- non-members are excluded;
- hidden scope is explained with flags, not silently dropped.

## UI Contract

The initial `Personas` screen should not require opening every person to
understand workload distribution. The collapsed row should expose the same
summary language for every person:

```text
Persona                 Estado              Trabajo                         Contexto                  Accion
admin@example.com       Trabajando ahora     1 activa, 2 reservadas          Card A, Card B            Ver trabajo
beta@example.com        Requiere atencion    1 bloqueada                     Card C                    Revisar
gamma@example.com       Disponible           Capacidad disponible            Sin trabajo asignado       Asignar
```

Expanded sections:

```text
admin@example.com

  Trabajando ahora
  - Tarea activa                      Card / Capability              Abrir tarea

  Reclamadas, no iniciadas
  - Tarea reservada                   Card / Capability              Abrir tarea
  - Tarea fuera de trabajo activo     Draft card / fuera de scope    Abrir tarea

  Requiere atencion
  - Tarea bloqueada                   Espera dependencias            Revisar bloqueo
```

Column guidance should be shared with other operational views through a small
UI helper, not hard-coded per screen. Use the same visual language for compact
column help: icon, short label, tooltip/detail text, and no large explanatory
blocks inside the work surface.

## Backend Plan

1. Add a read-model module for people workload.
2. Add one SQL query or a small query set dedicated to workload rows.
3. Add `GET /api/v1/projects/:project_id/people/workload`.
4. Keep authorization aligned with the current people view: project members can
   read workload for their project, with existing capability visibility rules
   applied only where they are product requirements.
5. Reject or clean invalid claimed work outside active card lineage before it
   reaches the workload read model.
6. Preserve deterministic ordering: attention, working now, reserved,
   available, then email/name.

Do not extend `/projects/:id/tasks` to support people-specific behavior. That
endpoint belongs to task navigation and Pool work surfaces.

The backend read model owns all cross-entity workload decisions:

- membership inclusion;
- task execution state inclusion;
- ongoing session detection;
- blocked derivation;
- card context and card phase;
- outside-active-work-scope flag;
- summary counters.

The frontend may filter and render the model, but it must not recompute the
truth from unrelated endpoint payloads.

## Frontend Plan

1. Add an API client for `people/workload`.
2. Add shared/domain codecs for the workload payload.
3. Change `Personas` to consume `PersonWorkload` rows directly.
4. Remove workload derivation from generic `member_tasks`.
5. Keep rendering logic local to `features/people`.
6. Keep filters simple:
   - `Todos`;
   - `Con trabajo`;
   - `Atencion`;
   - `Disponibles`.
7. Show work outside active Pool scope explicitly, for example:

```text
Reservada · fuera del trabajo activo
```

The UI must not present someone as available when they have claimed or ongoing
work.

State ownership:

- `features/people` owns expansion state, filters, search, and view rendering.
- `PersonWorkload` owns person workload buckets and summary.
- Pool owns task navigation and refresh triggers only.
- Work-session updates may reconcile an already loaded workload row optimistically,
  but the canonical refresh remains the workload endpoint.

## Cleanup Plan

This cleanup is part of the implementation, not a later optional pass.

Remove or simplify:

- `claimed_count` from `ProjectMember` if it is only used by `Personas`;
- SQL joins in `project_members_list.sql` that mix membership with task state;
- frontend derivation helpers that classify people from generic task lists;
- `member_tasks` dependency in `features/people`;
- `task_is_claimed`, `tasks_for_member`, and similar reconstruction helpers once
  the new workload model is used;
- people-specific refresh logic that fetches `/tasks`, `/task-types`, `/cards`,
  `/members`, and `/org/users` only to rebuild a table;
- tests that validate the old reconstruction path instead of workload behavior;
- test fixtures whose only purpose is preserving the old `/members` plus
  `/tasks` composition.
- duplicated fixture builders that create Pool tasks only so `Personas` can
  derive people state;
- temporary route aliases, fallback decoders, and old message variants for
  people roster refresh;
- UI copy that still describes old Pool-derived states instead of the workload
  states;
- dead i18n keys introduced for the previous `Personas` design;
- CSS selectors specific to removed row shapes, badges, or legacy filters.

Layer-specific cleanup:

- **Backend**: keep `/members` focused on project membership; remove task-state
  joins and counters from that path unless another non-Personas owner is proven;
  remove SQL/query helpers created only to reproduce the old frontend
  reconstruction.
- **Shared domain**: keep one workload contract and one codec; remove
  transitional enum values, fallback decode branches, or duplicated task summary
  shapes created only to bridge old and new people models.
- **Frontend state/update**: remove old people roster messages, old state fields,
  old refresh fan-out, and any classification derived from `member_tasks`,
  `cards`, `task_types`, `capabilities`, or `org_users`.
- **Frontend view**: remove old labels, badges, row variants, CSS hooks, and
  i18n keys tied to `Capacidad disponible` or claimed-count heuristics when they
  no longer represent the workload contract.
- **Tests**: delete tests that pass while the original bug is still possible;
  rewrite only the cases that prove current product behavior through
  `PersonWorkload`.
- **Seeds/fixtures**: remove accidental people/task data and replace it with
  named cases for working-now, reserved, attention, available, outside active
  work scope, and high-volume reserved work.

Do not keep compatibility shims such as:

- fallback from new workload to old member/task composition;
- dual `claimed_count` and workload counters for internal UI use;
- alternate decoders accepting both old and new internal shapes;
- legacy frontend state fields kept only to avoid updating call sites.

The only acceptable compatibility is at an external persisted/API boundary with
explicit justification. This plan does not currently require one.

Explicit non-goals:

- Do not keep `/members` as a partial workload endpoint.
- Do not preserve old `Personas` test helpers if they encode the old model.
- Do not introduce a generic dashboard abstraction for one screen.
- Do not make the workload endpoint mirror Pool filters.
- Do not hide draft-card work to match the old task list behavior.

## Cleanup Verification

Before closing the plan, run targeted searches and remove all obsolete traces:

```sh
rg "people_roster|MemberPeopleRosterFetched|claimed_count" apps shared
rg "derive_status|PersonStatus|tasks_for_member|task_is_claimed" apps/client
rg "member_tasks|task_types|capabilities|org_users" apps/client/src/scrumbringer_client/features/people
```

Expected result:

- no production dependency from `features/people` to generic Pool task state;
- no internal fallback from workload to roster/tasks composition;
- no tests proving the old composition path;
- no retained compatibility code without a documented external boundary.

## Testing Plan

Use `let assert` style tests. Avoid broad snapshots unless the rendered output is
small and focused.

### Backend HTTP Contract

Add tests for `GET /api/v1/projects/:id/people/workload`:

- claimed task in an active card returns the person as `reserved`;
- claimed task without a card is rejected by lower-level invariants and is not
  represented as reserved work;
- claimed task in a draft card is rejected by lower-level invariants and is not
  represented as reserved work;
- ongoing task returns the person as `working_now`;
- claimed blocked task returns the person in `attention`;
- person with no claimed or ongoing tasks returns as `available`;
- non-member users are excluded;
- unauthorized users get `403`.

Regression test name to include:

```gleam
pub fn people_workload_includes_claimed_tasks_in_draft_cards_test() {
  // obsolete: draft-card claimed work is invalid under the final invariant
}
```

### Backend Read Model

Add pure or repository-level tests for the derivation rules:

- `draft` card does not remove workload;
- `closed` task does not count;
- `available` task does not count as assigned work;
- blocked is derived from open dependencies;
- ongoing takes precedence over reserved for primary state;
- summary counters match the returned buckets.

### Shared Domain / Codec

Add JSON contract tests:

- server payload encodes into the shared workload type;
- client decoder accepts the server payload;
- enum values round-trip for primary state and scope flags.

### Frontend

Add focused tests for `features/people`:

- `ShowEveryone` renders every workload row;
- `ShowWithWork` includes reserved, working-now, and attention rows;
- `ShowWithWork` includes a reserved row outside active work scope;
- `ShowFree` excludes people with any claimed or ongoing workload;
- search matches person email, task title, card title, and capability/context;
- rendering distinguishes "reserved" from "outside active work scope".

Remove or rewrite tests that construct `member_tasks` to prove `Personas`
derives workload from generic Pool data. That path is the defect.

Add update-level tests:

- loading `people/workload` replaces the visible people model;
- work-session start moves the current user's task from reserved to working now
  when workload is already loaded;
- work-session pause moves it back to reserved;
- failed work-session commands do not mutate workload;
- search and filters operate only on `PersonWorkload` rows.

Retire or rewrite:

- tests that assert `Personas` changes only because `/tasks` changed;
- tests whose fixtures fetch task types, capabilities, cards, members, and org
  users merely to reconstruct people rows;
- tests that accept an available person while the workload contract reports
  claimed work.

## Seed Plan

Make the seed explicit rather than accidental:

- admin working now;
- beta with a normal reserved task;
- one user with a reserved task in a draft card;
- one user with a blocked reserved task;
- one user available;
- one user with multiple reserved tasks to exercise load summary.

Seed comments or fixture names should state the intended UI case. Avoid
ambiguous data that only happens to reveal behavior.

## Acceptance Criteria

- `Personas` no longer depends on `/projects/:id/tasks` to decide whether a
  person has work.
- A claimed task in a draft card still makes the person appear under
  `Con trabajo`.
- The UI never labels a person as available while the workload endpoint reports
  claimed or ongoing work.
- `/members` is a roster endpoint again, or any retained counters have a
  documented non-Personas owner.
- Old compatibility paths and internal legacy fields are removed.
- Tests cover the draft-card regression at backend contract and frontend filter
  levels.
- `gleam test` passes for the touched apps.
- The cleanup verification searches above have been run and any remaining hit is
  either deleted or explicitly justified as a real owner outside this feature.
- The implementation is validated in browser against the local app with seeded
  people covering working-now, reserved, attention, and available states.
