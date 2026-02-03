# API Contract (MVP)

> **Version:** 1.0
> **Parent:** [Architecture](../architecture.md)

---

## Overview

This document defines the HTTP API contract for the MVP.

- **Base URL:** `/api/v1`
- **Auth:** JWT stored in `HttpOnly` cookie
- **CSRF:** Double-submit token (cookie + header)
- **Realtime:** Not required for MVP (request/response + refresh). SSE/WebSocket can be added later.

---

## Conventions

### Sorting

MVP defines **server-side default sorting** per resource:

- Projects, Capabilities, Task Types: `name ASC`
- Tasks: `created_at DESC` (newest first)

### Pagination

MVP responses return full lists (no pagination). Pagination can be added later.

### Content Types

- Requests with bodies: `Content-Type: application/json`
- Responses: `application/json`

### Invalid JSON

- Malformed JSON payloads return `VALIDATION_ERROR` (400/422) or `INVALID_BODY` (400), depending on handler.

### IDs

All IDs are integer (`BIGSERIAL` in PostgreSQL).

### Timestamps

ISO-8601 strings (UTC), e.g. `2026-01-12T17:00:00Z`.

### Versioning / Concurrency

Mutable resources include a `version` integer.

- Client sends `version` on mutations.
- Server uses optimistic concurrency; on mismatch returns `409`.

### Response Envelope

All successful responses use:

```json
{ "data": <payload> }
```

Errors use:

```json
{
  "error": {
    "code": "SOME_CODE",
    "message": "Human readable message",
    "details": { }
  }
}
```

---

## Auth & Security

### Cookies

- `sb_session` (JWT): `HttpOnly; Secure; SameSite=Lax; Path=/`
- `sb_csrf`: not HttpOnly (readable by JS), `Secure; SameSite=Lax; Path=/`
- Secure flag is controlled by `SB_COOKIE_SECURE` (default True; set `false` for HTTP dev).

### CSRF (Double-submit)

For **mutating** requests (`POST`, `PUT`, `PATCH`, `DELETE`) the client MUST send:

- Header: `x-csrf: <value>` (case-insensitive)
- Cookie: `sb_csrf=<value>`

Server validates header equals cookie.

### Roles

- **Org admin**: can create projects, manage org invites, and is implicitly a project admin where assigned.
- **Project admin**: can manage project membership and project configuration.
- **Member**: can work with tasks inside projects they belong to.

### Authorization Rules (MVP)

General:
- No direct assignment (no endpoint to assign tasks to others).
- Project membership is admin-managed (no self-join).

Task rules:
- Creating tasks: any **project member**.
- Editing tasks (fields other than notes): requires the task to be **claimed by the caller**.
- Claim/Release/Complete: only valid when the caller is a **project member**; Release/Complete require the caller to be the **claimer**.
- Notes are **append-only** and can be added by any **project member**.
- Positions are per-user and can only be written by the **current user**.

---

## Error Codes (Minimum Set)

- `AUTH_REQUIRED` (401)
- `FORBIDDEN` (403)
- `NOT_FOUND` (404)
- `VALIDATION_ERROR` (422)
- `RATE_LIMITED` (429)
- `INTERNAL` (500)
- `INVALID_BODY` (400)
- `CONFLICT_VERSION` (409)
- `CONFLICT_CLAIMED` (409)
- `CONFLICT_LAST_ORG_ADMIN` (409)
- `CONFLICT` (409)
- `CONFLICT_HAS_TASKS` (409)
- `CONFLICT_INVALID_STATE` (409)
- `CONFLICT_SELF_DELETE` (409)
- `CONFLICT_SESSION_EXISTS` (409)
- `SELF_RELEASE` (400)
- `INVALID_DATE_RANGE` (400/422)
- `INVITE_REQUIRED` (403)
- `INVITE_INVALID` (403)
- `INVITE_EXPIRED` (403)
- `INVITE_USED` (403)
- `RESET_TOKEN_INVALID` (403)
- `RESET_TOKEN_USED` (403)

---

## Resources

### User

```json
{
  "id": 123,
  "email": "dev@team.com",
  "org_id": 1,
  "org_role": "admin",
  "created_at": "2026-01-12T17:00:00Z"
}
```

### Project

```json
{
  "id": 10,
  "org_id": 1,
  "name": "Core",
  "created_at": "2026-01-12T17:00:00Z",
  "my_role": "admin"
}
```

`my_role` is the caller's effective role in the project (useful to drive UI permissions).

### ProjectMember

```json
{
  "project_id": 10,
  "user_id": 123,
  "role": "member",
  "created_at": "2026-01-12T17:00:00Z"
}
```

### TaskType

```json
{
  "id": 5,
  "project_id": 10,
  "name": "Bug",
  "icon": "bug-ant",
  "capability_id": 2
}
```

### Task

```json
{
  "id": 999,
  "project_id": 10,
  "type_id": 5,
  "task_type": {
    "id": 5,
    "name": "Bug",
    "icon": "bug-ant"
  },
  "ongoing_by": { "user_id": 123 },
  "title": "Fix login",
  "description": "...",
  "priority": 4,
  "status": "available",
  "work_state": "available",
  "created_by": 123,
  "claimed_by": null,
  "claimed_at": null,
  "completed_at": null,
  "created_at": "2026-01-12T17:00:00Z",
  "version": 1,
  "card_id": 55,
  "card_title": "Sprint 6",
  "card_color": "blue",
  "has_new_notes": false,
  "blocked_count": 0,
  "dependencies": [
    { "task_id": 123, "title": "Prep", "status": "completed", "claimed_by": null }
  ]
}
```

### TaskNote (append-only)

```json
{
  "id": 1,
  "task_id": 999,
  "user_id": 123,
  "content": "Investigating...",
  "created_at": "2026-01-12T17:05:00Z"
}
```

### TaskPosition (per-user)

```json
{
  "task_id": 999,
  "user_id": 123,
  "x": 120,
  "y": 80,
  "updated_at": "2026-01-12T17:06:00Z"
}
```

### Card

```json
{
  "id": 55,
  "project_id": 10,
  "title": "Sprint 6",
  "description": "...",
  "color": "blue",
  "state": "active",
  "task_count": 12,
  "completed_count": 4,
  "created_by": 123,
  "created_at": "2026-01-12T17:00:00Z",
  "has_new_notes": false
}
```

### CardNote

```json
{
  "id": 1,
  "card_id": 55,
  "user_id": 123,
  "content": "Investigating...",
  "created_at": "2026-01-12T17:05:00Z",
  "author_email": "dev@team.com",
  "author_project_role": "admin",
  "author_org_role": "admin"
}
```

### TaskDependency

```json
{
  "task_id": 123,
  "title": "Prep",
  "status": "completed",
  "claimed_by": null
}
```

### TaskTemplate

```json
{
  "id": 77,
  "org_id": 1,
  "project_id": 10,
  "name": "Bugfix",
  "description": "Standard bug template",
  "type_id": 5,
  "type_name": "Bug",
  "priority": 3,
  "created_by": 123,
  "created_at": "2026-01-12T17:00:00Z",
  "rules_count": 2
}
```

### Workflow

```json
{
  "id": 3,
  "org_id": 1,
  "project_id": 10,
  "name": "Default",
  "description": "Main workflow",
  "active": true,
  "rule_count": 2,
  "created_by": 123,
  "created_at": "2026-01-12T17:00:00Z"
}
```

### Rule

```json
{
  "id": 9,
  "workflow_id": 3,
  "name": "Auto-close",
  "goal": "Close after complete",
  "resource_type": "task",
  "task_type_id": 5,
  "to_state": "completed",
  "active": true,
  "created_at": "2026-01-12T17:00:00Z",
  "templates": [
    {
      "id": 77,
      "org_id": 1,
      "project_id": 10,
      "name": "Bugfix",
      "description": "Standard bug template",
      "type_id": 5,
      "type_name": "Bug",
      "priority": 3,
      "created_by": 123,
      "created_at": "2026-01-12T17:00:00Z",
      "execution_order": 0
    }
  ]
}
```

### RuleTemplate

```json
{
  "id": 77,
  "org_id": 1,
  "project_id": 10,
  "name": "Bugfix",
  "description": "Standard bug template",
  "type_id": 5,
  "type_name": "Bug",
  "priority": 3,
  "created_by": 123,
  "created_at": "2026-01-12T17:00:00Z",
  "execution_order": 0
}
```

### WorkSessionState

```json
{
  "active_sessions": [
    {
      "task_id": 999,
      "started_at": "2026-01-12T17:00:00Z",
      "accumulated_s": 120
    }
  ],
  "as_of": "2026-01-12T17:02:00Z"
}
```

### OrgMetricsOverview

```json
{
  "overview": {
    "window_days": 30,
    "totals": {
      "claimed_count": 12,
      "released_count": 3,
      "completed_count": 8
    },
    "release_rate_percent": 25,
    "pool_flow_ratio_percent": 60,
    "time_to_first_claim_p50_ms": 7200000,
    "time_to_first_claim_sample_size": 10,
    "time_to_first_claim_buckets": [
      { "bucket": "0-1h", "count": 2 },
      { "bucket": "1-4h", "count": 5 }
    ],
    "release_rate_buckets": [
      { "bucket": "0-10%", "count": 3 },
      { "bucket": "10-25%", "count": 2 }
    ],
    "by_project": [
      {
        "project_id": 10,
        "project_name": "Core",
        "claimed_count": 6,
        "released_count": 1,
        "completed_count": 4,
        "release_rate_percent": 16,
        "pool_flow_ratio_percent": 70
      }
    ]
  }
}
```

### OrgProjectTaskMetrics

```json
{
  "window_days": 30,
  "project_id": 10,
  "tasks": [
    {
      "id": 999,
      "project_id": 10,
      "type_id": 5,
      "task_type": { "id": 5, "name": "Bug", "icon": "bug-ant" },
      "ongoing_by": { "user_id": 123 },
      "title": "Fix login",
      "description": "...",
      "priority": 4,
      "status": "available",
      "work_state": "available",
      "created_by": 123,
      "claimed_by": null,
      "claimed_at": null,
      "completed_at": null,
      "created_at": "2026-01-12T17:00:00Z",
      "version": 1,
      "claim_count": 2,
      "release_count": 1,
      "complete_count": 0,
      "first_claim_at": null
    }
  ]
}
```

### RuleMetricsWorkflowSummary

```json
{
  "workflow_id": 3,
  "workflow_name": "Default",
  "project_id": 10,
  "rule_count": 2,
  "evaluated_count": 30,
  "applied_count": 10,
  "suppressed_count": 20
}
```

### RuleMetricsRuleSummary

```json
{
  "rule_id": 9,
  "rule_name": "Auto-close",
  "active": true,
  "evaluated_count": 12,
  "applied_count": 4,
  "suppressed_count": 8
}
```

### RuleMetricsRule

```json
{
  "rule_id": 9,
  "rule_name": "Auto-close",
  "from": "2026-01-01T00:00:00Z",
  "to": "2026-01-31T23:59:59Z",
  "evaluated_count": 12,
  "applied_count": 4,
  "suppressed_count": 8,
  "suppression_breakdown": {
    "idempotent": 3,
    "not_user_triggered": 1,
    "not_matching": 2,
    "inactive": 2
  }
}
```

### RuleExecution

```json
{
  "id": 42,
  "origin_type": "task",
  "origin_id": 999,
  "outcome": "applied",
  "created_at": "2026-01-12T17:00:00Z",
  "suppression_reason": "inactive",
  "user_id": 123,
  "user_email": "dev@team.com"
}
```

---

## Endpoints

## Authorization Matrix (MVP)

Legend:
- OA = Org Admin
- PA = Project Admin
- M = Project Member
- Public = no auth

| Endpoint | Method | Roles | Notes |
|---|---|---|---|
| `/api/v1/health` | GET | Public | Health check |
| `/api/v1/auth/register` | POST | Public | Bootstrap creates org+Default project; after bootstrap requires invite |
| `/api/v1/auth/login` | POST | Public | |
| `/api/v1/auth/logout` | POST | OA/PA/M | Clears session |
| `/api/v1/auth/me` | GET | OA/PA/M | |
| `/api/v1/auth/invite-links/:token` | GET | Public | Validates invite-link token |
| `/api/v1/auth/password-resets` | POST | Public | Creates password reset token |
| `/api/v1/auth/password-resets/:token` | GET | Public | Validates reset token |
| `/api/v1/auth/password-resets/consume` | POST | Public | Consumes reset token (set new password) |
| `/api/v1/org/users` | GET | OA/PA | Lists org users (email search) |
| `/api/v1/org/users/:user_id` | PATCH | OA | Update org role (admin/member); cannot demote last org admin |
| `/api/v1/org/users/:user_id` | DELETE | OA | Delete user (cannot delete last org admin or self) |
| `/api/v1/org/users/:user_id/projects` | GET | OA | List projects for user |
| `/api/v1/org/users/:user_id/projects` | POST | OA | Add user to project |
| `/api/v1/org/users/:user_id/projects/:project_id` | PATCH | OA | Update user project role |
| `/api/v1/org/users/:user_id/projects/:project_id` | DELETE | OA | Remove user from project |
| `/api/v1/org/invites` | POST | OA | Creates invite token |
| `/api/v1/org/invite-links` | POST | OA | Creates invite link for email |
| `/api/v1/org/invite-links` | GET | OA | Lists invite links |
| `/api/v1/org/invite-links/regenerate` | POST | OA | Regenerates invite link token |
| `/api/v1/org/metrics/overview` | GET | OA | Admin metrics overview |
| `/api/v1/org/metrics/projects/:project_id/tasks` | GET | OA | Admin project task metrics |
| `/api/v1/projects` | GET | OA/PA/M | Returns only projects user belongs to; includes `my_role` |
| `/api/v1/projects` | POST | OA | Creates project |
| `/api/v1/projects/:project_id` | PATCH | OA | Update project name |
| `/api/v1/projects/:project_id` | DELETE | OA | Delete project |
| `/api/v1/projects/:project_id/members` | GET | PA | Membership list |
| `/api/v1/projects/:project_id/members` | POST | PA | Add member (`role` member/admin) |
| `/api/v1/projects/:project_id/members/:user_id` | PATCH | OA | Update member role |
| `/api/v1/projects/:project_id/members/:user_id` | DELETE | PA | Remove member (cannot remove last admin) |
| `/api/v1/projects/:project_id/members/:user_id/release-all-tasks` | POST | PA | Release all tasks for member |
| `/api/v1/projects/:project_id/capabilities` | GET | M | Project-scoped |
| `/api/v1/projects/:project_id/capabilities` | POST | PA | Create capability |
| `/api/v1/projects/:project_id/capabilities/:capability_id` | DELETE | PA | Delete capability |
| `/api/v1/projects/:project_id/members/:user_id/capabilities` | GET | M | Member capability ids |
| `/api/v1/projects/:project_id/members/:user_id/capabilities` | PUT | M/PA | Update member capabilities |
| `/api/v1/projects/:project_id/capabilities/:capability_id/members` | GET | M | Capability member ids |
| `/api/v1/projects/:project_id/capabilities/:capability_id/members` | PUT | PA | Update capability members |
| `/api/v1/projects/:project_id/task-types` | GET | M | Project-scoped |
| `/api/v1/projects/:project_id/task-types` | POST | PA | Create task type |
| `/api/v1/task-types/:type_id` | PATCH | PA | Update task type |
| `/api/v1/task-types/:type_id` | DELETE | PA | Delete task type |
| `/api/v1/projects/:project_id/task-templates` | GET | PA | List task templates |
| `/api/v1/projects/:project_id/task-templates` | POST | PA | Create task template |
| `/api/v1/task-templates/:template_id` | PATCH | PA | Update task template |
| `/api/v1/task-templates/:template_id` | DELETE | PA | Delete task template |
| `/api/v1/projects/:project_id/workflows` | GET | PA | List workflows |
| `/api/v1/projects/:project_id/workflows` | POST | PA | Create workflow |
| `/api/v1/workflows/:workflow_id` | PATCH | PA | Update workflow |
| `/api/v1/workflows/:workflow_id` | DELETE | PA | Delete workflow |
| `/api/v1/workflows/:workflow_id/rules` | GET | PA | List rules |
| `/api/v1/workflows/:workflow_id/rules` | POST | PA | Create rule |
| `/api/v1/rules/:rule_id` | PATCH | PA | Update rule |
| `/api/v1/rules/:rule_id` | DELETE | PA | Delete rule |
| `/api/v1/rules/:rule_id/templates/:template_id` | POST | PA | Attach template |
| `/api/v1/rules/:rule_id/templates/:template_id` | DELETE | PA | Detach template |
| `/api/v1/workflows/:workflow_id/metrics` | GET | PA/OA | Workflow metrics |
| `/api/v1/rules/:rule_id/metrics` | GET | PA/OA | Rule metrics |
| `/api/v1/rules/:rule_id/executions` | GET | PA/OA | Rule executions |
| `/api/v1/org/rule-metrics` | GET | OA | Org rule metrics |
| `/api/v1/projects/:project_id/rule-metrics` | GET | PA/OA | Project rule metrics |
| `/api/v1/projects/:project_id/cards` | GET | M | List cards |
| `/api/v1/projects/:project_id/cards` | POST | PA | Create card |
| `/api/v1/cards/:card_id` | GET | M | Get card |
| `/api/v1/cards/:card_id` | PATCH | PA | Update card |
| `/api/v1/cards/:card_id` | DELETE | PA | Delete card |
| `/api/v1/cards/:card_id/notes` | GET | M | List card notes |
| `/api/v1/cards/:card_id/notes` | POST | M | Add card note |
| `/api/v1/cards/:card_id/notes/:note_id` | DELETE | M/PA/OA | Delete card note (author or manager) |
| `/api/v1/projects/:project_id/tasks` | GET | M | List tasks (filters + q) |
| `/api/v1/projects/:project_id/tasks` | POST | M | Create task |
| `/api/v1/tasks/:task_id` | GET | M | Task must belong to a project user is in |
| `/api/v1/tasks/:task_id` | PATCH | M | Must be claimed by caller |
| `/api/v1/tasks/:task_id/claim` | POST | M | Transition available→claimed |
| `/api/v1/tasks/:task_id/release` | POST | M | Must be claimed by caller |
| `/api/v1/tasks/:task_id/complete` | POST | M | Must be claimed by caller |
| `/api/v1/tasks/:task_id/dependencies` | GET | M | List dependencies |
| `/api/v1/tasks/:task_id/dependencies` | POST | PA/OA | Add dependency |
| `/api/v1/tasks/:task_id/dependencies/:depends_on_task_id` | DELETE | PA/OA | Remove dependency |
| `/api/v1/tasks/:task_id/notes` | GET | M | Notes are append-only |
| `/api/v1/tasks/:task_id/notes` | POST | M | Append-only |
| `/api/v1/views/tasks/:task_id` | PUT | M | Mark task notes as read (per-user) |
| `/api/v1/me/task-positions` | GET | M | Per-user positions |
| `/api/v1/me/task-positions/:task_id` | PUT | M | Per-user positions |
| `/api/v1/views/cards/:card_id` | PUT | M | Mark card notes as read (per-user) |
| `/api/v1/me/work-sessions/active` | GET | M | Active work sessions |
| `/api/v1/me/work-sessions/start` | POST | M | Start work session |
| `/api/v1/me/work-sessions/pause` | POST | M | Pause work session |
| `/api/v1/me/work-sessions/heartbeat` | POST | M | Heartbeat work session |
| `/api/v1/me/active-task` | GET | M | Alias of work-sessions/active |
| `/api/v1/me/active-task/start` | POST | M | Alias of work-sessions/start |
| `/api/v1/me/active-task/pause` | POST | M | Alias of work-sessions/pause |
| `/api/v1/me/active-task/heartbeat` | POST | M | Alias of work-sessions/heartbeat |
| `/api/v1/me/metrics` | GET | M | User activity metrics |

### Health

- `GET /api/v1/health`
  - 200: `{ data: { ok: true } }`

### Auth

#### Bootstrap rules (MVP)

- System has a **single organization**.
- **Invite-only registration** once the org exists.
- The **first registered user** bootstraps the org and becomes **org admin**.
- On bootstrap, the system creates a default project named `Default` and adds the user as project admin.

- `POST /api/v1/auth/register`
  - body (bootstrap when no org exists yet): `{ email, password, org_name }`
  - body (normal registration): `{ password, invite_token }` (email is derived from the invite token)
  - errors: `INVITE_REQUIRED` | `INVITE_INVALID` | `INVITE_EXPIRED` | `INVITE_USED`
  - 200: `{ data: { user } }` + sets cookies (`sb_session`, `sb_csrf`)

- `GET /api/v1/auth/invite-links/:token`
  - 200: `{ data: { email } }`
  - 403: `INVITE_INVALID` | `INVITE_USED`

- `POST /api/v1/auth/password-resets`
  - body: `{ email }`
  - 200: `{ data: { reset: { token, url_path } } }`
  - `url_path` is a relative path (no scheme/host) intended for client-side composition
  - notes:
    - token TTL: 24h
    - single active token per email (creating a new token invalidates the previous active token)
    - unknown emails do not leak (still returns 200; token is not persisted and will validate/consume as `RESET_TOKEN_INVALID`)

- `GET /api/v1/auth/password-resets/:token`
  - 200: `{ data: { email } }`
  - 403: `RESET_TOKEN_INVALID` | `RESET_TOKEN_USED`

- `POST /api/v1/auth/password-resets/consume`
  - body: `{ token, password }`
  - 204
  - 403: `RESET_TOKEN_INVALID` | `RESET_TOKEN_USED`

- `POST /api/v1/auth/login`
  - body: `{ email, password }`
  - 200: `{ data: { user } }` + sets cookies

- `POST /api/v1/auth/logout`
  - csrf: required (double-submit)
  - 204, clears cookies

- `GET /api/v1/auth/me`
  - 200: `{ data: { user } }`

### Organization

#### Users (directory)

- `GET /api/v1/org/users`
  - auth: org admin or project admin
  - sort: `email ASC`
  - query: `q` (optional; searches email only)
  - 200: `{ data: { users: User[] } }`

- `PATCH /api/v1/org/users/:user_id`
  - auth: org admin only
  - csrf: required (double-submit)
  - body: `{ org_role }` where `org_role` is `admin|member`
  - 200: `{ data: { user } }`
  - 409: `CONFLICT_LAST_ORG_ADMIN` when attempting to demote the last remaining org admin

- `DELETE /api/v1/org/users/:user_id`
  - auth: org admin only
  - csrf: required (double-submit)
  - 204
  - 409: `CONFLICT_SELF_DELETE` when attempting to delete own user
  - 409: `CONFLICT_LAST_ORG_ADMIN` when attempting to delete last org admin

#### User Projects (org admin managed)

- `GET /api/v1/org/users/:user_id/projects`
  - auth: org admin only
  - 200: `{ data: { projects: Project[] } }`

- `POST /api/v1/org/users/:user_id/projects`
  - auth: org admin only
  - csrf: required (double-submit)
  - body: `{ project_id, role? }` (role defaults to `member`)
  - 200: `{ data: { project: { id, name, role } } }`

- `PATCH /api/v1/org/users/:user_id/projects/:project_id`
  - auth: org admin only
  - csrf: required (double-submit)
  - body: `{ role }`
  - 200: `{ data: { project: { id, name, role, previous_role } } }`

- `DELETE /api/v1/org/users/:user_id/projects/:project_id`
  - auth: org admin only
  - csrf: required (double-submit)
  - 200: `{ data: {} }`

#### Invites (invite-only registration)

- `POST /api/v1/org/invites`
  - auth: org admin
  - csrf: required (double-submit)
  - body: `{ expires_in_hours? }`
  - default: `expires_in_hours = 168`
  - 200: `{ data: { invite } }`
  - 422: `VALIDATION_ERROR` when `expires_in_hours` is invalid

Invite resource:

```json
{
  "code": "inv_2cQ8m9bCk0m1m9q0cPZ5vFh1lZ8pUe8o",
  "created_at": "...",
  "expires_at": "..."
}
```

Notes (de facto):
- Treat `code` as an **opaque, URL-safe random token**.
- Token shape recommendation: **base64url/URL-safe alphabet**, ~**128 bits**+ of entropy (e.g. 16+ random bytes), prefixed (`inv_`).
- Token is **single-use** in MVP.
- Default expiration when omitted: **168h (7 days)**.

#### Invite Links (email-bound)

- `POST /api/v1/org/invite-links`
  - auth: org admin
  - csrf: required (double-submit)
  - body: `{ email }`
  - 200: `{ data: { invite_link } }`
  - 422: `VALIDATION_ERROR` when email is invalid

- `GET /api/v1/org/invite-links`
  - auth: org admin
  - sort: `email ASC`
  - 200: `{ data: { invite_links: InviteLink[] } }`

- `POST /api/v1/org/invite-links/regenerate`
  - auth: org admin
  - csrf: required (double-submit)
  - body: `{ email }`
  - 200: `{ data: { invite_link } }`
  - 422: `VALIDATION_ERROR` when email is invalid

InviteLink resource:

```json
{
  "email": "user@team.com",
  "token": "il_2cQ8m9bCk0m1m9q0cPZ5vFh1lZ8pUe8o",
  "url_path": "/accept-invite?token=il_2cQ8m9bCk0m1m9q0cPZ5vFh1lZ8pUe8o",
  "state": "active",
  "created_at": "...",
  "used_at": null,
  "invalidated_at": null
}
```

Notes:
- Single active token per email (create/regenerate invalidates the previous active token).
- No time expiry (token lifecycle is `active | used | invalidated`).
- API returns `token` and `url_path` (no absolute URL); server does not send emails.

#### Metrics (org admin)

- `GET /api/v1/org/metrics/overview`
  - auth: org admin only
  - query: `window_days` (optional, 1-365, default 30)
  - 200: `{ data: OrgMetricsOverview }`

- `GET /api/v1/org/metrics/projects/:project_id/tasks`
  - auth: org admin only
  - query: `window_days` (optional, 1-365, default 30)
  - 200: `{ data: OrgProjectTaskMetrics }`
---

### Projects

- `GET /api/v1/projects`
  - sort: `name ASC`
  - 200: `{ data: { projects: Project[] } }` (each project includes `my_role`)

- `POST /api/v1/projects`
  - auth: **org admin only** (MVP)
  - csrf: required (double-submit)
  - body: `{ name }`
  - 200: `{ data: { project } }`
  - 400: `INVALID_BODY` when payload is malformed

- `PATCH /api/v1/projects/:project_id`
  - auth: **org admin only**
  - csrf: required (double-submit)
  - body: `{ name }`
  - 200: `{ data: { project } }`
  - 400: `INVALID_BODY` when payload is malformed

- `DELETE /api/v1/projects/:project_id`
  - auth: **org admin only**
  - csrf: required (double-submit)
  - 204

### Project Members (admin-managed)

- `GET /api/v1/projects/:project_id/members`
  - 200: `{ data: { members: ProjectMember[] } }`

- `POST /api/v1/projects/:project_id/members`
  - auth: project admin
  - csrf: required (double-submit)
  - body: `{ user_id, role }`
  - 200: `{ data: { member } }`

- `DELETE /api/v1/projects/:project_id/members/:user_id`
  - auth: project admin
  - csrf: required (double-submit)
  - 204

- `PATCH /api/v1/projects/:project_id/members/:user_id`
  - auth: org admin
  - csrf: required (double-submit)
  - body: `{ role }`
  - 200: `{ data: { member } }`

- `POST /api/v1/projects/:project_id/members/:user_id/release-all-tasks`
  - auth: project admin
  - csrf: required (double-submit)
  - 200: `{ data: { released_count, task_ids } }`
  - 400: `SELF_RELEASE` when attempting to release own tasks

### Capabilities

- `GET /api/v1/projects/:project_id/capabilities`
  - scope: project
  - 200: `{ data: { capabilities: Capability[] } }`

- `POST /api/v1/projects/:project_id/capabilities`
  - auth: project admin
  - csrf: required (double-submit)
  - body: `{ name }`
  - 200: `{ data: { capability } }`

- `DELETE /api/v1/projects/:project_id/capabilities/:capability_id`
  - auth: project admin
  - csrf: required (double-submit)
  - 200: `{ data: { id } }`

### Member Capabilities

- `GET /api/v1/projects/:project_id/members/:user_id/capabilities`
  - auth: project member
  - 200: `{ data: { capability_ids: number[] } }`

- `PUT /api/v1/projects/:project_id/members/:user_id/capabilities`
  - auth: self or project admin
  - csrf: required (double-submit)
  - body: `{ capability_ids: number[] }`
  - 200: `{ data: { capability_ids: number[] } }`

### Capability Members

- `GET /api/v1/projects/:project_id/capabilities/:capability_id/members`
  - auth: project member
  - 200: `{ data: { user_ids: number[] } }`

- `PUT /api/v1/projects/:project_id/capabilities/:capability_id/members`
  - auth: project admin
  - csrf: required (double-submit)
  - body: `{ user_ids: number[] }`
  - 200: `{ data: { user_ids: number[] } }`

### Task Types

- `GET /api/v1/projects/:project_id/task-types`
  - sort: `name ASC`
  - 200: `{ data: { task_types: TaskType[] } }`

- `POST /api/v1/projects/:project_id/task-types`
  - auth: project admin
  - body: `{ name, icon, capability_id? }`
  - 200: `{ data: { task_type } }`

- `PATCH /api/v1/task-types/:type_id`
  - auth: project admin
  - csrf: required (double-submit)
  - body: `{ name?, icon?, capability_id? }`
  - 200: `{ data: { task_type } }`

- `DELETE /api/v1/task-types/:type_id`
  - auth: project admin
  - csrf: required (double-submit)
  - 204

### Task Templates

- `GET /api/v1/projects/:project_id/task-templates`
  - auth: project admin
  - 200: `{ data: { templates: TaskTemplate[] } }`

- `POST /api/v1/projects/:project_id/task-templates`
  - auth: project admin
  - csrf: required (double-submit)
  - body: `{ name, description?, type_id, priority? }` (priority defaults to 3)
  - 200: `{ data: { template } }`

- `PATCH /api/v1/task-templates/:template_id`
  - auth: project admin
  - csrf: required (double-submit)
  - body: `{ name?, description?, type_id?, priority? }`
  - 200: `{ data: { template } }`

- `DELETE /api/v1/task-templates/:template_id`
  - auth: project admin
  - csrf: required (double-submit)
  - 204

### Workflows

- `GET /api/v1/projects/:project_id/workflows`
  - auth: project admin
  - 200: `{ data: { workflows: Workflow[] } }`

- `POST /api/v1/projects/:project_id/workflows`
  - auth: project admin
  - csrf: required (double-submit)
  - body: `{ name, description?, active? }` (active defaults to false)
  - 200: `{ data: { workflow } }`

- `PATCH /api/v1/workflows/:workflow_id`
  - auth: project admin
  - csrf: required (double-submit)
  - body: `{ name?, description?, active? }` (active is 0/1)
  - 200: `{ data: { workflow } }`

- `DELETE /api/v1/workflows/:workflow_id`
  - auth: project admin
  - csrf: required (double-submit)
  - 204

Workflow example responses:

List workflows:

```json
{
  "data": {
    "workflows": [
      {
        "id": 3,
        "org_id": 1,
        "project_id": 10,
        "name": "Default",
        "description": "Main workflow",
        "active": true,
        "rule_count": 2,
        "created_by": 123,
        "created_at": "2026-01-12T17:00:00Z"
      }
    ]
  }
}
```

Create/update workflow:

```json
{
  "data": {
    "workflow": {
      "id": 3,
      "org_id": 1,
      "project_id": 10,
      "name": "Default",
      "description": "Main workflow",
      "active": true,
      "rule_count": 2,
      "created_by": 123,
      "created_at": "2026-01-12T17:00:00Z"
    }
  }
}
```

### Rules

- `GET /api/v1/workflows/:workflow_id/rules`
  - auth: project admin
  - 200: `{ data: { rules: Rule[] } }`

- `POST /api/v1/workflows/:workflow_id/rules`
  - auth: project admin
  - csrf: required (double-submit)
  - body: `{ name, goal?, resource_type, task_type_id?, to_state, active? }`
  - 200: `{ data: { rule } }`

- `PATCH /api/v1/rules/:rule_id`
  - auth: project admin
  - csrf: required (double-submit)
  - body: `{ name?, goal?, resource_type?, task_type_id?, to_state?, active? }` (active is 0/1)
  - 200: `{ data: { rule } }`

- `DELETE /api/v1/rules/:rule_id`
  - auth: project admin
  - csrf: required (double-submit)
  - 204

- `POST /api/v1/rules/:rule_id/templates/:template_id`
  - auth: project admin
  - csrf: required (double-submit)
  - body: `{ execution_order? }` (defaults to 0)
  - 200: `{ data: { templates: RuleTemplate[] } }`

- `DELETE /api/v1/rules/:rule_id/templates/:template_id`
  - auth: project admin
  - csrf: required (double-submit)
  - 204

Rule example responses:

List rules:

```json
{
  "data": {
    "rules": [
      {
        "id": 9,
        "workflow_id": 3,
        "name": "Auto-close",
        "goal": "Close after complete",
        "resource_type": "task",
        "task_type_id": 5,
        "to_state": "completed",
        "active": true,
        "created_at": "2026-01-12T17:00:00Z",
        "templates": []
      }
    ]
  }
}
```

Create/update rule:

```json
{
  "data": {
    "rule": {
      "id": 9,
      "workflow_id": 3,
      "name": "Auto-close",
      "goal": "Close after complete",
      "resource_type": "task",
      "task_type_id": 5,
      "to_state": "completed",
      "active": true,
      "created_at": "2026-01-12T17:00:00Z",
      "templates": []
    }
  }
}
```

Attach template:

```json
{
  "data": {
    "templates": [
      {
        "id": 77,
        "org_id": 1,
        "project_id": 10,
        "name": "Bugfix",
        "description": "Standard bug template",
        "type_id": 5,
        "type_name": "Bug",
        "priority": 3,
        "created_by": 123,
        "created_at": "2026-01-12T17:00:00Z",
        "execution_order": 0
      }
    ]
  }
}
```

### Rule Metrics (read-only)

- `GET /api/v1/workflows/:workflow_id/metrics`
  - auth: project admin
  - query: `from`/`to` (RFC3339, optional, default last 30 days)
  - constraints: max range 90 days; `from <= to`
  - errors: `INVALID_DATE_RANGE` (400/422)
  - 200: `{ data: { workflow_id, workflow_name, from, to, rules: RuleMetricsRuleSummary[], totals } }`

- `GET /api/v1/rules/:rule_id/metrics`
  - auth: project admin
  - query: `from`/`to` (RFC3339, optional, default last 30 days)
  - constraints: max range 90 days; `from <= to`
  - errors: `INVALID_DATE_RANGE` (400/422)
  - 200: `{ data: RuleMetricsRule }`

- `GET /api/v1/rules/:rule_id/executions`
  - auth: project admin
  - query: `from`/`to` (RFC3339, optional, default last 30 days)
  - query: `limit`/`offset` (optional)
  - constraints: max range 90 days; `from <= to`
  - errors: `INVALID_DATE_RANGE` (400/422)
  - 200: `{ data: { rule_id, executions: RuleExecution[], pagination } }`

- `GET /api/v1/org/rule-metrics`
  - auth: org admin
  - query: `from`/`to` (RFC3339, optional, default last 30 days)
  - constraints: max range 90 days; `from <= to`
  - errors: `INVALID_DATE_RANGE` (400/422)
  - 200: `{ data: { from, to, workflows: RuleMetricsWorkflowSummary[], totals } }`

- `GET /api/v1/projects/:project_id/rule-metrics`
  - auth: project admin
  - query: `from`/`to` (RFC3339, optional, default last 30 days)
  - constraints: max range 90 days; `from <= to`
  - errors: `INVALID_DATE_RANGE` (400/422)
  - 200: `{ data: { project_id, from, to, workflows: RuleMetricsWorkflowSummary[], totals } }`

#### Rule metrics example responses

Workflow metrics:

```json
{
  "data": {
    "workflow_id": 3,
    "workflow_name": "Default",
    "from": "2026-01-01T00:00:00Z",
    "to": "2026-01-31T23:59:59Z",
    "rules": [
      {
        "rule_id": 9,
        "rule_name": "Auto-close",
        "active": true,
        "evaluated_count": 12,
        "applied_count": 4,
        "suppressed_count": 8
      }
    ],
    "totals": {
      "evaluated_count": 12,
      "applied_count": 4,
      "suppressed_count": 8
    }
  }
}
```

Rule metrics:

```json
{
  "data": {
    "rule_id": 9,
    "rule_name": "Auto-close",
    "from": "2026-01-01T00:00:00Z",
    "to": "2026-01-31T23:59:59Z",
    "evaluated_count": 12,
    "applied_count": 4,
    "suppressed_count": 8,
    "suppression_breakdown": {
      "idempotent": 3,
      "not_user_triggered": 1,
      "not_matching": 2,
      "inactive": 2
    }
  }
}
```

Rule executions:

```json
{
  "data": {
    "rule_id": 9,
    "executions": [
      {
        "id": 42,
        "origin_type": "task",
        "origin_id": 999,
        "outcome": "applied",
        "created_at": "2026-01-12T17:00:00Z",
        "user_id": 123,
        "user_email": "dev@team.com"
      }
    ],
    "pagination": {
      "limit": 50,
      "offset": 0,
      "total": 1
    }
  }
}
```

Org rule metrics:

```json
{
  "data": {
    "from": "2026-01-01T00:00:00Z",
    "to": "2026-01-31T23:59:59Z",
    "workflows": [
      {
        "workflow_id": 3,
        "workflow_name": "Default",
        "project_id": 10,
        "rule_count": 2,
        "evaluated_count": 30,
        "applied_count": 10,
        "suppressed_count": 20
      }
    ],
    "totals": {
      "evaluated_count": 30,
      "applied_count": 10,
      "suppressed_count": 20
    }
  }
}
```

Project rule metrics:

```json
{
  "data": {
    "project_id": 10,
    "from": "2026-01-01T00:00:00Z",
    "to": "2026-01-31T23:59:59Z",
    "workflows": [
      {
        "workflow_id": 3,
        "workflow_name": "Default",
        "project_id": 10,
        "rule_count": 2,
        "evaluated_count": 30,
        "applied_count": 10,
        "suppressed_count": 20
      }
    ],
    "totals": {
      "evaluated_count": 30,
      "applied_count": 10,
      "suppressed_count": 20
    }
  }
}
```

### Tasks

#### State machine

A task has a `status` field with these allowed values:

- `available`
- `claimed`
- `completed`

Allowed transitions:

- `available` → `claimed` via `POST /tasks/:task_id/claim`
- `claimed` → `available` via `POST /tasks/:task_id/release`
- `claimed` → `completed` via `POST /tasks/:task_id/complete`

Invalid transitions return `422 VALIDATION_ERROR`.

---

- `GET /api/v1/projects/:project_id/tasks`
  - sort: `created_at DESC`
  - query: `status=available|claimed|completed` (optional)
  - query: `type_id` (optional)
  - query: `capability_id` (optional, via task_type; **single value in MVP**)
  - query: `q` (optional; searches title/description only)
  - query: `blocked=true|false` (optional)
  - 200: `{ data: { tasks: Task[] } }`
  - vNext: allow multiple capabilities (e.g. `capability_id=1,2,3`)

- `POST /api/v1/projects/:project_id/tasks`
  - auth: project member
  - body: `{ title, description?, priority, type_id, card_id? }`
  - 200: `{ data: { task } }`

- `GET /api/v1/tasks/:task_id`
  - 200: `{ data: { task } }`

- `PATCH /api/v1/tasks/:task_id`
  - auth: **task must be claimed by caller**
  - body: `{ title?, description?, priority?, type_id?, version }`
  - 200: `{ data: { task } }`

- `POST /api/v1/tasks/:task_id/claim`
  - auth: project member
  - body: `{ version }`
  - 200: `{ data: { task } }`
  - 409 `CONFLICT_CLAIMED` if already claimed

- `POST /api/v1/tasks/:task_id/release`
  - auth: **task must be claimed by caller**
  - body: `{ version }`
  - 200: `{ data: { task } }`

- `POST /api/v1/tasks/:task_id/complete`
  - auth: **task must be claimed by caller**
  - body: `{ version }`
  - 200: `{ data: { task } }`

### Task Dependencies

- `GET /api/v1/tasks/:task_id/dependencies`
  - 200: `{ data: { dependencies: TaskDependency[] } }`

- `POST /api/v1/tasks/:task_id/dependencies`
  - auth: project admin (org admin bypass)
  - csrf: required (double-submit)
  - body: `{ depends_on_task_id }`
  - 200: `{ data: { dependency } }`

- `DELETE /api/v1/tasks/:task_id/dependencies/:depends_on_task_id`
  - auth: project admin (org admin bypass)
  - csrf: required (double-submit)
  - 204

### Task Notes (append-only)

- `GET /api/v1/tasks/:task_id/notes`
  - 200: `{ data: { notes: TaskNote[] } }`

- `POST /api/v1/tasks/:task_id/notes`
  - auth: project member
  - csrf: required (double-submit)
  - body: `{ content }`
  - 200: `{ data: { note } }`

### Task Views (per-user)

- `PUT /api/v1/views/tasks/:task_id`
  - auth: project member (task must belong to a project the user is in)
  - csrf: required (double-submit)
  - body: `{}`
  - 204

### Task Positions (per-user)

- `GET /api/v1/me/task-positions`
  - query: `project_id` (optional)
  - 200: `{ data: { positions: TaskPosition[] } }`

- `PUT /api/v1/me/task-positions/:task_id`
  - auth: project member (task must belong to a project the user is in)
  - csrf: required (double-submit)
  - body: `{ x, y }`
  - 200: `{ data: { position } }`

### Cards

- `GET /api/v1/projects/:project_id/cards`
  - auth: project member
  - 200: `{ data: { cards: Card[] } }`

- `POST /api/v1/projects/:project_id/cards`
  - auth: project admin
  - csrf: required (double-submit)
  - body: `{ title, description?, color? }`
  - 200: `{ data: { card } }`

- `GET /api/v1/cards/:card_id`
  - auth: project member
  - 200: `{ data: { card } }`

- `PATCH /api/v1/cards/:card_id`
  - auth: project admin
  - csrf: required (double-submit)
  - body: `{ title, description?, color? }`
  - 200: `{ data: { card } }`

- `DELETE /api/v1/cards/:card_id`
  - auth: project admin
  - csrf: required (double-submit)
  - 204
  - 409: `CONFLICT_HAS_TASKS` when the card has tasks

### Card Notes

- `GET /api/v1/cards/:card_id/notes`
  - auth: project member
  - 200: `{ data: { notes: CardNote[] } }`

- `POST /api/v1/cards/:card_id/notes`
  - auth: project member
  - csrf: required (double-submit)
  - body: `{ content }`
  - 200: `{ data: { note } }`

- `DELETE /api/v1/cards/:card_id/notes/:note_id`
  - auth: note author, project admin, or org admin
  - csrf: required (double-submit)
  - 204

### Card Views (per-user)

- `PUT /api/v1/views/cards/:card_id`
  - auth: project member (card must belong to a project the user is in)
  - csrf: required (double-submit)
  - body: `{}`
  - 204

### Work Sessions (per-user)

- `GET /api/v1/me/work-sessions/active`
  - 200: `{ data: WorkSessionState }`

- `POST /api/v1/me/work-sessions/start`
  - csrf: required (double-submit)
  - body: `{ task_id }`
  - 200: `{ data: WorkSessionState }`
  - 409: `CONFLICT_CLAIMED` if task is not claimed by caller
  - 409: `CONFLICT_INVALID_STATE` if task is completed
  - 409: `CONFLICT_SESSION_EXISTS` if an active session exists

- `POST /api/v1/me/work-sessions/pause`
  - csrf: required (double-submit)
  - body: `{ task_id }`
  - 200: `{ data: WorkSessionState }`

- `POST /api/v1/me/work-sessions/heartbeat`
  - csrf: required (double-submit)
  - body: `{ task_id }`
  - 200: `{ data: WorkSessionState }`

Aliases (same behavior and payloads):
- `GET /api/v1/me/active-task`
- `POST /api/v1/me/active-task/start`
- `POST /api/v1/me/active-task/pause`
- `POST /api/v1/me/active-task/heartbeat`

### Me Metrics

- `GET /api/v1/me/metrics`
  - query: `window_days` (optional, 1-365, default 30)
  - 200: `{ data: { metrics: { window_days, claimed_count, released_count, completed_count } } }`

---

## Conflict Examples

### Version conflict

- Client sends `version=3` but server has `version=4`.

Response:

```json
{
  "error": {
    "code": "CONFLICT_VERSION",
    "message": "Version conflict",
    "details": { "expected": 3, "actual": 4 }
  }
}
```
