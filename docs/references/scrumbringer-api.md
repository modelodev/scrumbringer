# Scrumbringer Bearer API Reference For Agents

This reference covers the API surface usable with `SCRUMBRINGER_API_TOKEN`.
Bearer tokens do not use browser cookies or CSRF.

## Environment

Required for all calls:

- `SCRUMBRINGER_BASE_URL`
- `SCRUMBRINGER_API_TOKEN`

Recommended business variables:

- `SCRUMBRINGER_PROJECT_ID`
- `SCRUMBRINGER_TASK_ID`
- `SCRUMBRINGER_CARD_ID`
- `SCRUMBRINGER_MILESTONE_ID`

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
- `403`: token lacks scope, project access, or Bearer is not allowed for route.
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
- `milestones:read`
- `milestones:write`

## Supported Routes

### Projects

| Action | Method | Path | Scope |
| --- | --- | --- | --- |
| List projects | `GET` | `/api/v1/projects` | `projects:read` |

This lists projects visible to the token integration user. It does not list all
organization projects. A token without a `project_id` restriction still only sees
projects where its integration user is a member. If the response is empty, the
token probably has no project membership or lacks `projects:read`.

Project creation/editing/membership administration is not Bearer-supported.

### Tasks

| Action | Method | Path | Scope |
| --- | --- | --- | --- |
| List project tasks | `GET` | `/api/v1/projects/:project_id/tasks` | `tasks:read` |
| Get task | `GET` | `/api/v1/tasks/:task_id` | `tasks:read` |
| Create task | `POST` | `/api/v1/projects/:project_id/tasks` | `tasks:write` |
| Patch task | `PATCH` | `/api/v1/tasks/:task_id` | `tasks:write` |
| Claim task | `POST` | `/api/v1/tasks/:task_id/claim` | `tasks:write` |
| Release task | `POST` | `/api/v1/tasks/:task_id/release` | `tasks:write` |
| Complete task | `POST` | `/api/v1/tasks/:task_id/complete` | `tasks:write` |

Query filters for list tasks:

- `status`
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
  "card_id": 20,
  "milestone_id": 30
}
```

Only `title`, `priority`, and `type_id` are core creation fields. Include
`description`, `card_id`, and `milestone_id` when known.

Patch task body examples:

```json
{
  "version": 4,
  "title": "Clarify importer retry behavior",
  "description": "Document retry limits and failure states."
}
```

```json
{ "milestone_id": 30 }
```

Task transition body:

```json
{ "version": 4 }
```

Initial agent policy: do not call `claim`, even after confirmation. Keep it as
a documented API capability for a future skill policy update. Release/complete
only when the user explicitly confirms that the integration user should perform
that state transition.

### Task Notes

| Action | Method | Path | Scope |
| --- | --- | --- | --- |
| List task notes | `GET` | `/api/v1/tasks/:task_id/notes` | `notes:read` |
| Add task note | `POST` | `/api/v1/tasks/:task_id/notes` | `notes:write` |

Task notes are append-only.

```json
{ "content": "External system reported retry success." }
```

### Cards

| Action | Method | Path | Scope |
| --- | --- | --- | --- |
| List project cards | `GET` | `/api/v1/projects/:project_id/cards` | `cards:read` |
| Get card | `GET` | `/api/v1/cards/:card_id` | `cards:read` |
| Create card | `POST` | `/api/v1/projects/:project_id/cards` | `cards:write` |
| Patch card | `PATCH` | `/api/v1/cards/:card_id` | `cards:write` |
| Delete card | `DELETE` | `/api/v1/cards/:card_id` | `cards:write` |

Create/patch card body:

```json
{
  "title": "Importer stabilization",
  "description": "Work needed to make importer retries observable.",
  "color": "blue",
  "milestone_id": 30
}
```

`color` and `milestone_id` are optional. Delete only after explicit
confirmation; cards with tasks may be rejected.

### Card Notes

| Action | Method | Path | Scope |
| --- | --- | --- | --- |
| List card notes | `GET` | `/api/v1/cards/:card_id/notes` | `notes:read` |
| Add card note | `POST` | `/api/v1/cards/:card_id/notes` | `notes:write` |
| Delete card note | `DELETE` | `/api/v1/cards/:card_id/notes/:note_id` | `notes:write` |

```json
{ "content": "Scope clarified: retry logs are part of this card." }
```

Delete card notes only after explicit confirmation.

### Milestones

| Action | Method | Path | Scope |
| --- | --- | --- | --- |
| List project milestones | `GET` | `/api/v1/projects/:project_id/milestones` | `milestones:read` |
| Get milestone | `GET` | `/api/v1/milestones/:milestone_id` | `milestones:read` |
| Create milestone | `POST` | `/api/v1/projects/:project_id/milestones` | `milestones:write` |
| Patch milestone | `PATCH` | `/api/v1/milestones/:milestone_id` | `milestones:write` |
| Delete milestone | `DELETE` | `/api/v1/milestones/:milestone_id` | `milestones:write` |

Create/patch milestone body:

```json
{
  "name": "Importer stabilization",
  "description": "Reduce import failure rate and make retry behavior observable."
}
```

Delete milestones only after explicit confirmation.

## Not Bearer-Supported

Do not attempt these with `SCRUMBRINGER_API_TOKEN`:

- workflows;
- rules;
- task templates;
- API token administration;
- org users, invites, assignments, and membership administration;
- project creation/editing/deletion;
- capabilities and task types;
- operational metrics and rule metrics;
- work sessions / now-working;
- resource view tracking (`/api/v1/views/*`).

If the user asks for one of these, explain that the current Bearer API does not
support it and offer a safe alternative: inspect supported resources, add a
note, or propose a human-admin action.

## Work Design Guidance

Use this when the user asks the agent to shape work:

- Start with a milestone if the work has a delivery outcome.
- Use cards for coherent slices under that milestone.
- Use tasks for pullable units with clear completion criteria.
- Avoid putting a person's name in a task title as an assignment signal.
- Prefer "Available work" language over "assigned to".
- Add notes for external context instead of rewriting task history.
- Keep automation/workflow changes out of agent scope.
