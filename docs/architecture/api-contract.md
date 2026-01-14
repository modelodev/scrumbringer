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

- `sb_session` (JWT): `HttpOnly; Secure; SameSite=Strict; Path=/`
- `sb_csrf`: not HttpOnly (readable by JS), `Secure; SameSite=Strict; Path=/`

### CSRF (Double-submit)

For **mutating** requests (`POST`, `PUT`, `PATCH`, `DELETE`) the client MUST send:

- Header: `X-CSRF: <value>`
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
- `CONFLICT_VERSION` (409)
- `CONFLICT_CLAIMED` (409)
- `CONFLICT_LAST_ORG_ADMIN` (409)
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
  "title": "Fix login",
  "description": "...",
  "priority": 4,
  "status": "available",
  "created_by": 123,
  "claimed_by": null,
  "claimed_at": null,
  "completed_at": null,
  "created_at": "2026-01-12T17:00:00Z",
  "version": 1
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
| `/api/v1/org/users` | GET | OA/PA | Lists org users (email search) |
| `/api/v1/org/users/:user_id` | PATCH | OA | Update org role (admin/member); cannot demote last org admin |
| `/api/v1/org/invites` | POST | OA | Creates invite token |
| `/api/v1/org/invite-links` | POST | OA | Creates invite link for email |
| `/api/v1/org/invite-links` | GET | OA | Lists invite links |
| `/api/v1/org/invite-links/regenerate` | POST | OA | Regenerates invite link token |
| `/api/v1/auth/invite-links/:token` | GET | Public | Validates invite-link token |
| `/api/v1/auth/password-resets` | POST | Public | Creates password reset token |
| `/api/v1/auth/password-resets/:token` | GET | Public | Validates reset token |
| `/api/v1/auth/password-resets/consume` | POST | Public | Consumes reset token (set new password) |
| `/api/v1/projects` | GET | OA/PA/M | Returns only projects user belongs to; includes `my_role` |
| `/api/v1/projects` | POST | OA | Creates project |
| `/api/v1/projects/:project_id/members` | GET | PA | Membership list |
| `/api/v1/projects/:project_id/members` | POST | PA | Add member (`role` member/admin) |
| `/api/v1/projects/:project_id/members/:user_id` | DELETE | PA | Remove member (cannot remove last admin) |
| `/api/v1/capabilities` | GET | OA/PA/M | Org-scoped |
| `/api/v1/capabilities` | POST | OA | Create capability |
| `/api/v1/me/capabilities` | GET | OA/PA/M | User-scoped |
| `/api/v1/me/capabilities` | PUT | OA/PA/M | User-scoped |
| `/api/v1/projects/:project_id/task-types` | GET | M | Project-scoped |
| `/api/v1/projects/:project_id/task-types` | POST | PA | Create task type |
| `/api/v1/projects/:project_id/tasks` | GET | M | List tasks (filters + q) |
| `/api/v1/projects/:project_id/tasks` | POST | M | Create task |
| `/api/v1/tasks/:task_id` | GET | M | Task must belong to a project user is in |
| `/api/v1/tasks/:task_id` | PATCH | M | Must be claimed by caller |
| `/api/v1/tasks/:task_id/claim` | POST | M | Transition available→claimed |
| `/api/v1/tasks/:task_id/release` | POST | M | Must be claimed by caller |
| `/api/v1/tasks/:task_id/complete` | POST | M | Must be claimed by caller |
| `/api/v1/tasks/:task_id/notes` | GET | M | Notes are append-only |
| `/api/v1/tasks/:task_id/notes` | POST | M | Append-only |
| `/api/v1/me/task-positions` | GET | M | Per-user positions |
| `/api/v1/me/task-positions/:task_id` | PUT | M | Per-user positions |

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

#### Invites (invite-only registration)

- `POST /api/v1/org/invites`
  - auth: org admin
  - body: `{ expires_in_hours? }`
  - default: `expires_in_hours = 168`
  - 200: `{ data: { invite } }`

Invite resource:

```json
{
  "token": "inv_2cQ8m9bCk0m1m9q0cPZ5vFh1lZ8pUe8o",
  "url_path": "/accept-invite?token=inv_2cQ8m9bCk0m1m9q0cPZ5vFh1lZ8pUe8o",
  "created_at": "...",
  "expires_at": "..."
}
```

Notes (de facto):
- Treat `token` as an **opaque, URL-safe random token**.
- `url_path` is a **relative path** (no scheme/host) intended for client-side composition.
- Token shape recommendation: **base64url/URL-safe alphabet**, ~**128 bits**+ of entropy (e.g. 16+ random bytes), optionally prefixed (`inv_`).
- Token is **single-use** in MVP.
- Default expiration when omitted: **168h (7 days)**.

#### Invite Links (email-bound)

- `POST /api/v1/org/invite-links`
  - auth: org admin
  - csrf: required (double-submit)
  - body: `{ email }`
  - 200: `{ data: { invite_link } }`

- `GET /api/v1/org/invite-links`
  - auth: org admin
  - sort: `email ASC`
  - 200: `{ data: { invite_links: InviteLink[] } }`

- `POST /api/v1/org/invite-links/regenerate`
  - auth: org admin
  - csrf: required (double-submit)
  - body: `{ email }`
  - 200: `{ data: { invite_link } }`

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
---

### Projects

- `GET /api/v1/projects`
  - sort: `name ASC`
  - 200: `{ data: { projects: Project[] } }` (each project includes `my_role`)

- `POST /api/v1/projects`
  - auth: **org admin only** (MVP)
  - body: `{ name }`
  - 200: `{ data: { project } }`

### Project Members (admin-managed)

- `GET /api/v1/projects/:project_id/members`
  - 200: `{ data: { members: ProjectMember[] } }`

- `POST /api/v1/projects/:project_id/members`
  - auth: project admin
  - body: `{ user_id, role }`
  - 200: `{ data: { member } }`

- `DELETE /api/v1/projects/:project_id/members/:user_id`
  - auth: project admin
  - 204

### Capabilities

- `GET /api/v1/capabilities`
  - scope: org
  - sort: `name ASC`
  - 200: `{ data: { capabilities: Capability[] } }`

- `POST /api/v1/capabilities`
  - auth: org admin
  - body: `{ name }`
  - 200: `{ data: { capability } }`

### User Capabilities

- `GET /api/v1/me/capabilities`
  - 200: `{ data: { capability_ids: number[] } }`

- `PUT /api/v1/me/capabilities`
  - body: `{ capability_ids: number[] }`
  - 200: `{ data: { capability_ids: number[] } }`

### Task Types

- `GET /api/v1/projects/:project_id/task-types`
  - sort: `name ASC`
  - 200: `{ data: { task_types: TaskType[] } }`

- `POST /api/v1/projects/:project_id/task-types`
  - auth: project admin
  - body: `{ name, icon, capability_id? }`
  - 200: `{ data: { task_type } }`

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
  - 200: `{ data: { tasks: Task[] } }`
  - vNext: allow multiple capabilities (e.g. `capability_id=1,2,3`)

- `POST /api/v1/projects/:project_id/tasks`
  - auth: project member
  - body: `{ title, description?, priority, type_id }`
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

### Task Notes (append-only)

- `GET /api/v1/tasks/:task_id/notes`
  - 200: `{ data: { notes: TaskNote[] } }`

- `POST /api/v1/tasks/:task_id/notes`
  - auth: project member
  - body: `{ content }`
  - 200: `{ data: { note } }`

### Task Positions (per-user)

- `GET /api/v1/me/task-positions`
  - query: `project_id` (optional)
  - 200: `{ data: { positions: TaskPosition[] } }`

- `PUT /api/v1/me/task-positions/:task_id`
  - auth: project member (task must belong to a project the user is in)
  - body: `{ x, y }`
  - 200: `{ data: { position } }`

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
