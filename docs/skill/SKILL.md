---
name: scrumbringer-agent
description: Operate Scrumbringer through its Bearer API while preserving the pull-flow philosophy. Use this skill whenever a Codex, OpenCode, or OpenClaw agent needs to inspect or safely modify Scrumbringer projects, cards, card-scoped tasks, and notes; advise users on card/task work design; or coordinate work with Scrumbringer without browser session state. Bearer does not operate workflows, rules, task templates, admin surfaces, or retired hierarchy/milestone endpoints.
---

# Scrumbringer Agent

Use this skill when an AI agent communicates with Scrumbringer through an API
token. The skill is harness-neutral and is intended for Codex, OpenCode, and
OpenClaw agents.

## Current Product Model

Scrumbringer's current operational model is centered on projects, cards, tasks,
and notes:

- A **project** contains the work system and the API token project grant.
- A **card** is the planning and delivery container. Cards can be nested through
  `parent_card_id`; this is a card tree, not a separate hierarchy resource.
- A **task** is the pullable unit of work. Prefer card-scoped tasks by setting
  `card_id`; available or claimed root tasks are not the normal operating model.
- A **note** preserves operational context, external updates, blockers, and
  decisions without rewriting history.

Workflows, rules, task templates, capabilities, task types, rule executions, and
admin views exist in the product, but they are not part of this Bearer skill's
API surface.

## Core Philosophy

Scrumbringer is a pull-flow work cockpit. Preserve these rules:

- Make work visible before changing work.
- Do not push-assign tasks to people.
- Do not claim tasks in this initial agent policy.
- Prefer notes and recommendations when a human decision is needed.
- Shape cards and tasks for team autonomy.
- Use the smallest API action that creates useful operational signal.

When advising the user:

- **Cards** should describe coherent delivery slices that can be understood,
  reviewed, activated, and closed as a unit.
- **Nested cards** should express delivery structure only when that structure
  helps planning or review. Do not invent legacy hierarchy or milestone objects.
- **Tasks** should be small, pullable units with a clear title, useful context,
  priority, type, card ownership, and acceptance hints in the description.
- **Notes** should capture context, blockers, external updates, and decisions
  without changing the task or card meaning.

## Required Setup

Before any API call, verify:

- `SCRUMBRINGER_BASE_URL` is set, for example `http://127.0.0.1:8443`.
- `SCRUMBRINGER_API_TOKEN` is set to the full `sbt_...` Bearer token.
- Operation-specific business variables are present:
  - project-scoped work: `SCRUMBRINGER_PROJECT_ID`
  - card work: `SCRUMBRINGER_CARD_ID`
  - task work: `SCRUMBRINGER_TASK_ID`
  - note pin/delete work: `SCRUMBRINGER_NOTE_ID`
  - task mutations and transitions: current task `version`

Use the helper script first:

```bash
node docs/skill/scripts/scrumbringer-api.mjs preflight
node docs/skill/scripts/scrumbringer-api.mjs preflight SCRUMBRINGER_PROJECT_ID
```

The helper never prints the full token.

Project visibility follows the token project setting. A token with a concrete
project only sees that project. A token created for all projects derives access
from its active grant, so `GET /api/v1/projects` should return current and future
organization projects when the token has `projects:read`.

## References

Read `docs/references/scrumbringer-api.md` before using endpoints you have not
used in the current task. It documents the supported Bearer routes, scopes,
payload examples, and routes intentionally out of scope.

The source of truth for Bearer route allow-listing is
`apps/server/src/scrumbringer_server/http/auth/scopes.gleam`; the source of
truth for scope names is `shared/src/domain/api_token_scope.gleam`.

Use `docs/skill/scripts/scrumbringer-api.mjs` for deterministic API calls:

```bash
node docs/skill/scripts/scrumbringer-api.mjs get /api/v1/projects
node docs/skill/scripts/scrumbringer-api.mjs get /api/v1/projects/$SCRUMBRINGER_PROJECT_ID/cards
node docs/skill/scripts/scrumbringer-api.mjs get /api/v1/projects/$SCRUMBRINGER_PROJECT_ID/tasks
node docs/skill/scripts/scrumbringer-api.mjs post /api/v1/tasks/$SCRUMBRINGER_TASK_ID/notes '{"content":"External context..."}'
```

## Bearer Surface

Supported scopes:

- `projects:read`
- `tasks:read`
- `tasks:write`
- `cards:read`
- `cards:write`
- `notes:read`
- `notes:write`

Supported route groups:

- Projects: list visible projects.
- Tasks: list, read, read activity, create, patch, delete, claim, release, close.
- Cards: list, read, read activity, create, patch, delete.
- Task notes: list, create, pin, unpin.
- Card notes: list, create, pin, unpin, delete.

Not Bearer-supported:

- Retired hierarchy or milestone endpoints.
- Workflows, rules, task templates, rule metrics, and automation execution
  management.
- Task types, capabilities, assignments, org users, invites, API token
  administration, and project administration.
- Card activate, card close, card move, task positions, dependencies, work
  sessions, and resource view tracking.
- Browser cookies or session-auth endpoints as a substitute for the API token.

## Operating Workflow

1. **Preflight**
   - Check required env vars.
   - Identify project/resource IDs.
   - Confirm the token has the needed scopes by making the smallest read call.

2. **Inspect before mutation**
   - Read the project, card, task, or notes.
   - Summarize current state in plain language.
   - Identify task `version` before patch, claim, release, or close calls.

3. **Apply Scrumbringer philosophy**
   - If work is unclear, propose a better card/task shape.
   - If a human should choose, write a note or recommend next actions.
   - Prefer card-scoped tasks. If no card is known, inspect cards before
     creating a root task.
   - Do not claim tasks in this initial policy.

4. **Confirm before risky writes**
   Always ask for explicit confirmation before:
   - creating, editing, or deleting tasks/cards;
   - adding, pinning, unpinning, or deleting notes;
   - patching task fields or moving a task between cards;
   - calling task `release` or `close`;
   - any action that could change ownership, state, or visible team planning.

   Do not call task `claim` in this initial policy, even with confirmation.
   Treat it as a documented API capability reserved for a future policy update.

   Confirmation prompt format:

   ```text
   Confirmo antes de operar en Scrumbringer:
   - Base: <base-url>
   - Proyecto/recurso: <ids>
   - Accion: <method path>
   - Payload: <json>
   - Impacto esperado: <effect>
   - Riesgo: <low/medium/high>
   ```

5. **Execute and report**
   - Use the helper script or equivalent HTTP request.
   - Report the final state and relevant IDs.
   - For failures, report status, error code, message, and next safe step.

## Initial Agent Policy

Allowed without confirmation:

- Read visible projects.
- Read cards, card activity, tasks, task activity, and notes.
- Draft a proposed card/task design.
- Recommend a next action.

Allowed only after explicit confirmation:

- Create tasks, preferably with `card_id`.
- Patch task title, description, priority, type, due date, `card_id`, or
  `parent_card_id`.
- Delete tasks when the user explicitly accepts the operational impact.
- Create, update, or delete cards through the supported Bearer endpoints.
- Add task/card notes.
- Pin or unpin task/card notes.
- Delete card notes.
- Release or close a task when the user explicitly confirms that the integration
  user should perform that state transition.

Not allowed in this initial policy:

- Claim tasks, autonomously or after confirmation.
- Operate workflows, rules, task templates, capabilities, task types, admin
  surfaces, or resource tracking.
- Call hierarchy/milestone endpoints.
- Activate, close, or move cards through Bearer; those routes are session/API
  surface outside this skill policy.
- Delete task notes through Bearer; only task note pin/unpin is Bearer-allowed.
- Use browser session cookies as a substitute for the API token.
- Store or print the full token.

## Response Style

When reporting work, be concise and operational:

- State what was inspected.
- State what changed, with resource IDs.
- State what remains blocked by permissions, missing env vars, route scope, or
  confirmation.
- For design advice, tie recommendations back to pull-flow autonomy.

## Common Examples

List projects:

```bash
node docs/skill/scripts/scrumbringer-api.mjs get /api/v1/projects
```

List cards in a project:

```bash
node docs/skill/scripts/scrumbringer-api.mjs get /api/v1/projects/$SCRUMBRINGER_PROJECT_ID/cards
```

List tasks in a project:

```bash
node docs/skill/scripts/scrumbringer-api.mjs get /api/v1/projects/$SCRUMBRINGER_PROJECT_ID/tasks
```

Create a card after confirmation:

```bash
node docs/skill/scripts/scrumbringer-api.mjs post /api/v1/projects/$SCRUMBRINGER_PROJECT_ID/cards \
  '{"title":"Importer stabilization","description":"Make importer retries observable and recoverable.","color":"blue"}'
```

Create a card-scoped task after confirmation:

```bash
node docs/skill/scripts/scrumbringer-api.mjs post /api/v1/projects/$SCRUMBRINGER_PROJECT_ID/tasks \
  "{\"title\":\"Document import failure mode\",\"description\":\"Capture observed failure, expected behavior, and rollback notes.\",\"priority\":3,\"type_id\":1,\"card_id\":${SCRUMBRINGER_CARD_ID}}"
```

Patch a task after confirmation:

```bash
node docs/skill/scripts/scrumbringer-api.mjs patch /api/v1/tasks/$SCRUMBRINGER_TASK_ID \
  "{\"version\":4,\"description\":\"Updated context and acceptance hints.\",\"card_id\":${SCRUMBRINGER_CARD_ID}}"
```

Add a task note after confirmation:

```bash
node docs/skill/scripts/scrumbringer-api.mjs post /api/v1/tasks/$SCRUMBRINGER_TASK_ID/notes \
  '{"content":"External system reported retry success at 2026-06-12T12:40:00Z."}'
```

Close a task after confirmation:

```bash
node docs/skill/scripts/scrumbringer-api.mjs post /api/v1/tasks/$SCRUMBRINGER_TASK_ID/close \
  '{"version":4}'
```
