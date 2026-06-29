# Scrumbringer Bearer API Reference For Agents

This reference covers the API surface usable with `SCRUMBRINGER_API_TOKEN`.
Bearer tokens do not use browser cookies or CSRF. The route allow-list is
implemented in `apps/server/src/scrumbringer_server/http/auth/scopes.gleam`.

## Environment

Required for all calls:

- `SCRUMBRINGER_BASE_URL`
- `SCRUMBRINGER_API_TOKEN`

Recommended business variables:

- `SCRUMBRINGER_PROJECT_ID`
- `SCRUMBRINGER_CARD_ID`
- `SCRUMBRINGER_TASK_ID`
- `SCRUMBRINGER_NOTE_ID`

Authorization header:

```http
Authorization: Bearer sbt_<public_id>_<secret>
```

## Response Shape

Successful responses:

```json
{ "data": { "...": "..." } }
```

Errors:

```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "Bearer token is not allowed for this route"
  }
}
```

Important statuses:

- `401`: token missing/invalid/expired/revoked.
- `403`: token lacks scope, project access, role permission, or Bearer is not
  allowed for the route.
- `404`: resource not found.
- `409`: optimistic concurrency or state conflict.
- `422`: validation error.

## Scopes

Supported Bearer scopes:

- `projects:read`
- `tasks:read`
- `tasks:write`
- `cards:read`
- `cards:write`
- `notes:read`
- `notes:write`

There are no Bearer scopes for hierarchies, milestones, workflows, rules, task
templates, task types, capabilities, users, projects administration, or API token
administration.

## Supported Routes

### Projects

| Action | Method | Path | Scope |
| --- | --- | --- | --- |
| List projects | `GET` | `/api/v1/projects` | `projects:read` |

This lists projects visible to the token. A token limited to a concrete
`project_id` only returns that project. A token created for all projects derives
access from its active grant and returns current and future organization projects
when it has `projects:read`.

Project creation/editing/membership administration is not Bearer-supported.

### Cards

| Action | Method | Path | Scope |
| --- | --- | --- | --- |
| List project cards | `GET` | `/api/v1/projects/:project_id/cards` | `cards:read` |
| Get card | `GET` | `/api/v1/cards/:card_id` | `cards:read` |
| Get card activity | `GET` | `/api/v1/cards/:card_id/activity` | `cards:read` |
| Create card | `POST` | `/api/v1/projects/:project_id/cards` | `cards:write` |
| Patch card | `PATCH` | `/api/v1/cards/:card_id` | `cards:write` |
| Delete card | `DELETE` | `/api/v1/cards/:card_id` | `cards:write` |

Create/patch card body:

```json
{
  "title": "Importer stabilization",
  "description": "Work needed to make importer retries observable.",
  "color": "blue",
  "parent_card_id": 30,
  "due_date": "2026-07-10"
}
```

`description`, `color`, `parent_card_id`, and `due_date` are optional.
`parent_card_id` nests a card under another card; it is not a hierarchy or
milestone ID. Delete only after explicit confirmation; cards with operational
history, children, or tasks may be rejected.

Bearer does not allow card activate, card close, or card move endpoints.

### Tasks

| Action | Method | Path | Scope |
| --- | --- | --- | --- |
| List project tasks | `GET` | `/api/v1/projects/:project_id/tasks` | `tasks:read` |
| Get task | `GET` | `/api/v1/tasks/:task_id` | `tasks:read` |
| Get task activity | `GET` | `/api/v1/tasks/:task_id/activity` | `tasks:read` |
| Create task | `POST` | `/api/v1/projects/:project_id/tasks` | `tasks:write` |
| Patch task | `PATCH` | `/api/v1/tasks/:task_id` | `tasks:write` |
| Delete task | `DELETE` | `/api/v1/tasks/:task_id` | `tasks:write` |
| Claim task | `POST` | `/api/v1/tasks/:task_id/claim` | `tasks:write` |
| Release task | `POST` | `/api/v1/tasks/:task_id/release` | `tasks:write` |
| Close task | `POST` | `/api/v1/tasks/:task_id/close` | `tasks:write` |

Query filters for list tasks:

- `status`: `available`, `claimed`, or `closed`
- `type_id`
- `capability_id`
- `q`
- `blocked=true|false`

Create task body:

```json
{
  "title": "Document import failure mode",
  "description": "Capture observed failure and expected behavior.",
  "priority": 3,
  "type_id": 1,
  "card_id": 20
}
```

Only `title`, `priority`, and `type_id` are required by the payload decoder, but
agents should prefer including `card_id` so the task belongs to a delivery card.
`parent_card_id` is also accepted for pool-to-card movement semantics, but a
task creation request must not include both `card_id` and `parent_card_id`.

Patch task body examples:

```json
{
  "version": 4,
  "title": "Clarify importer retry behavior",
  "description": "Document retry limits and failure states."
}
```

```json
{
  "version": 4,
  "card_id": 20,
  "due_date": "2026-07-10"
}
```

Task transition body:

```json
{ "version": 4 }
```

Initial agent policy: do not call `claim`, even after confirmation. Keep it as
a documented API capability for a future skill policy update. Release/close only
when the user explicitly confirms that the integration user should perform that
state transition.

### Task Notes

| Action | Method | Path | Scope |
| --- | --- | --- | --- |
| List task notes | `GET` | `/api/v1/tasks/:task_id/notes` | `notes:read` |
| Add task note | `POST` | `/api/v1/tasks/:task_id/notes` | `notes:write` |
| Pin task note | `POST` | `/api/v1/tasks/:task_id/notes/:note_id/pin` | `notes:write` |
| Unpin task note | `DELETE` | `/api/v1/tasks/:task_id/notes/:note_id/pin` | `notes:write` |

```json
{ "content": "External system reported retry success." }
```

Deleting task notes is not Bearer-supported.

### Card Notes

| Action | Method | Path | Scope |
| --- | --- | --- | --- |
| List card notes | `GET` | `/api/v1/cards/:card_id/notes` | `notes:read` |
| Add card note | `POST` | `/api/v1/cards/:card_id/notes` | `notes:write` |
| Pin card note | `POST` | `/api/v1/cards/:card_id/notes/:note_id/pin` | `notes:write` |
| Unpin card note | `DELETE` | `/api/v1/cards/:card_id/notes/:note_id/pin` | `notes:write` |
| Delete card note | `DELETE` | `/api/v1/cards/:card_id/notes/:note_id` | `notes:write` |

```json
{ "content": "Scope clarified: retry logs are part of this card." }
```

Delete card notes only after explicit confirmation.

## Not Bearer-Supported

Do not attempt these with `SCRUMBRINGER_API_TOKEN`:

- hierarchy or milestone endpoints;
- workflows;
- rules;
- rule metrics and automation executions;
- task templates;
- API token and integration identity administration;
- org users, invites, assignments, and membership administration;
- project creation/editing/deletion;
- capabilities and task types;
- card activate/close/move routes;
- task dependencies and task positions;
- operational metrics;
- work sessions / now-working;
- resource view tracking (`/api/v1/views/*`).

If the user asks for one of these, explain that the current Bearer API does not
support it and offer a safe alternative: inspect supported resources, add a
note, or propose a human-admin action.

## Work Design Guidance

Use this when the user asks the agent to shape work:

- Start with a card that represents a coherent delivery or discovery slice.
- Use nested cards only when the parent/child structure improves planning,
  review, or activation context.
- Use tasks for pullable units with clear completion criteria.
- Prefer card-scoped tasks over root tasks.
- Avoid putting a person's name in a task title as an assignment signal.
- Prefer "available work" language over "assigned to".
- Add notes for external context instead of rewriting task history.
- Keep automation/workflow changes out of Bearer-agent scope.
