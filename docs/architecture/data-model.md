# Data Model

> **Version:** 1.0
> **Parent:** [Architecture](../architecture.md)

---

## Entity Relationship Diagram

```
┌──────────────┐       ┌──────────────┐
│ Organization │       │  Capability  │
│──────────────│       │──────────────│
│ id           │       │ id           │
│ name         │◄──────│ name         │
│ created_at   │       │ org_id (FK)  │
└──────────────┘       └──────────────┘
       │                      │
       │                      │
       ▼                      ▼
┌──────────────┐       ┌────────────────┐
│     User     │       │ UserCapability │
│──────────────│       │────────────────│
│ id           │◄──────│ user_id (FK)   │
│ email        │       │ cap_id (FK)    │
│ password_hash│       └────────────────┘
│ org_id (FK)  │
│ created_at   │
└──────────────┘
       │
       ▼
┌──────────────┐       ┌──────────────┐
│   Project    │       │   TaskType   │
│──────────────│       │──────────────│
│ id           │       │ id           │
│ name         │◄──────│ name         │
│ org_id (FK)  │       │ icon         │
│ created_at   │       │ cap_id (FK)? │
└──────────────┘       │ project_id   │
       ▲               └──────────────┘
       │
       │  ┌────────────────┐
       │  │ ProjectMember  │
       │  │────────────────│
       └──│ project_id (FK)│
          │ user_id (FK)   │
          │ role           │
          └────────────────┘

┌─────────────────────────────┴────────────────────────────┐
│                          Task                             │
│───────────────────────────────────────────────────────────│
│ id            │ title         │ description               │
│ priority      │ status        │ type_id (FK)              │
│ project_id    │ created_by    │ claimed_by (FK)?          │
│ claimed_at?   │ completed_at? │ created_at                │
│ version       │               │                           │
└───────────────────────────────────────────────────────────┘
       │                              │
       ▼                              ▼
┌──────────────┐              ┌──────────────┐          ┌────────────────┐
│   TaskNote   │              │ TaskPosition │          │  UserTaskView  │
│──────────────│              │──────────────│          │────────────────│
│ id           │              │ task_id (FK) │          │ user_id (FK)   │
│ task_id (FK) │              │ user_id (FK) │          │ task_id (FK)   │
│ user_id (FK) │              │ x            │          │ last_viewed_at │
│ content      │              │ y            │          └────────────────┘
│ created_at   │              │ updated_at   │
└──────────────┘              └──────────────┘

┌──────────────┐
│  CardNote    │
│──────────────│
│ id           │
│ card_id (FK) │
│ user_id (FK) │
│ content      │
│ created_at   │
└──────────────┘
┌────────────────┐
│  UserCardView  │
│────────────────│
│ user_id (FK)   │
│ card_id (FK)   │
│ last_viewed_at │
└────────────────┘
```

---

## Entities

### Organization
```sql
CREATE TABLE organizations (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### OrgInvite (invite-only registration)

`code` is an opaque, URL-safe random token (single-use in MVP).

```sql
CREATE TABLE org_invites (
    code TEXT PRIMARY KEY,
    org_id BIGINT NOT NULL REFERENCES organizations(id),
    created_by BIGINT NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    used_at TIMESTAMPTZ,
    used_by BIGINT REFERENCES users(id)
);

CREATE INDEX idx_org_invites_org ON org_invites(org_id);
CREATE INDEX idx_org_invites_used_at ON org_invites(used_at);
```

### User
```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    org_id BIGINT NOT NULL REFERENCES organizations(id),
    org_role TEXT NOT NULL DEFAULT 'member' CHECK (org_role IN ('member', 'admin')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Capability
```sql
CREATE TABLE capabilities (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    org_id BIGINT NOT NULL REFERENCES organizations(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(name, org_id)
);
```

### UserCapability
```sql
CREATE TABLE user_capabilities (
    user_id BIGINT NOT NULL REFERENCES users(id),
    capability_id BIGINT NOT NULL REFERENCES capabilities(id),
    PRIMARY KEY (user_id, capability_id)
);
```

### Project
```sql
CREATE TABLE projects (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    org_id BIGINT NOT NULL REFERENCES organizations(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### ProjectMember
Users can participate in multiple projects within their organization.

In the MVP, **project membership is managed by admins** (no self-join).

```sql
CREATE TABLE project_members (
    project_id BIGINT NOT NULL REFERENCES projects(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'admin')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (project_id, user_id)
);

CREATE INDEX idx_project_members_user ON project_members(user_id);
```

### TaskType
```sql
CREATE TABLE task_types (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    icon TEXT NOT NULL,  -- heroicon name
    capability_id BIGINT REFERENCES capabilities(id),
    project_id BIGINT NOT NULL REFERENCES projects(id),
    UNIQUE(name, project_id)
);
```

### Task
```sql
CREATE TABLE tasks (
    id BIGSERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    priority INT NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    status TEXT NOT NULL DEFAULT 'available'
        CHECK (status IN ('available', 'claimed', 'completed')),
    type_id BIGINT NOT NULL REFERENCES task_types(id),
    project_id BIGINT NOT NULL REFERENCES projects(id),
    created_by BIGINT NOT NULL REFERENCES users(id),
    claimed_by BIGINT REFERENCES users(id),
    claimed_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1
);

CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_project ON tasks(project_id);
CREATE INDEX idx_tasks_claimed_by ON tasks(claimed_by);
```

### TaskNote
```sql
CREATE TABLE task_notes (
    id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL REFERENCES tasks(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_task_notes_task ON task_notes(task_id);
```

### TaskPosition
```sql
CREATE TABLE task_positions (
    task_id BIGINT NOT NULL REFERENCES tasks(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    x INT NOT NULL DEFAULT 0,
    y INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (task_id, user_id)
);

### CardNote
```sql
CREATE TABLE card_notes (
    id BIGSERIAL PRIMARY KEY,
    card_id BIGINT NOT NULL REFERENCES cards(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_card_notes_card ON card_notes(card_id);
```

### UserCardView
```sql
CREATE TABLE user_card_views (
    user_id BIGINT NOT NULL REFERENCES users(id),
    card_id BIGINT NOT NULL REFERENCES cards(id),
    last_viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, card_id)
);

CREATE INDEX idx_user_card_views_card ON user_card_views(card_id);
```

### UserTaskView
```sql
CREATE TABLE user_task_views (
    user_id BIGINT NOT NULL REFERENCES users(id),
    task_id BIGINT NOT NULL REFERENCES tasks(id),
    last_viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, task_id)
);

CREATE INDEX idx_user_task_views_task ON user_task_views(task_id);
```
```

---

## Commands

Commands represent user intentions. Validated on server before execution.

**Bootstrap / Invites (MVP):**
- When no organization exists yet, the first registration bootstraps it and creates the first org admin.
- After that, registrations must present a valid, unexpired invite code.

| Command | Fields | Validation |
|---------|--------|------------|
| `CreateTask` | title, description?, priority, type_id | User is project member |
| `ClaimTask` | task_id, version | User is project member, status=available, version match |
| `ReleaseTask` | task_id, version | Claimed by user, version match |
| `CompleteTask` | task_id, version | Claimed by user, version match |
| `UpdateTask` | task_id, fields, version | Claimed by user, version match |
| `AddTaskNote` | task_id, content | User is project member |
| `MoveTask` | task_id, x, y | User is project member |
| `DeleteTask` | task_id, version | Claimed by user OR creator, version match |
| `AddProjectMember` | project_id, user_id, role | Caller is project admin, target user in same org |
| `RemoveProjectMember` | project_id, user_id | Caller is project admin, cannot remove last admin |

---

## Events

Events represent state changes. Used for UI updates and audit.

| Event | Fields | Triggered By |
|-------|--------|--------------|
| `TaskCreated` | task | CreateTask |
| `TaskClaimed` | task_id, user_id, claimed_at | ClaimTask |
| `TaskReleased` | task_id, user_id | ReleaseTask |
| `TaskCompleted` | task_id, user_id, completed_at | CompleteTask |
| `TaskUpdated` | task_id, changed_fields | UpdateTask |
| `TaskNoteAdded` | note | AddTaskNote |
| `TaskPositionChanged` | task_id, user_id, x, y | MoveTask |
| `TaskDeleted` | task_id | DeleteTask |

---

## Concurrency Strategy

### Optimistic Concurrency Control

1. Each task has a `version` field (starts at 1)
2. Client sends `version` with every mutating command
3. Server checks `WHERE id = $1 AND version = $2`
4. On success: increment version, apply change
5. On failure: return conflict error with current state

### Claim Conflicts

**Scenario:** Two users click "Claim" simultaneously

**Resolution:** First-Write-Wins
```sql
UPDATE tasks
SET claimed_by = $1,
    claimed_at = NOW(),
    status = 'claimed',
    version = version + 1
WHERE id = $2
  AND status = 'available'
  AND version = $3
RETURNING *;
```

- First UPDATE succeeds (1 row affected)
- Second UPDATE fails (0 rows affected)
- Loser gets conflict response, UI refreshes

### Optimistic UI

1. User clicks "Claim"
2. UI immediately shows task as claimed (optimistic)
3. Server processes command
4. Success: UI state confirmed
5. Conflict: UI reverts, shows notification

---

## Status State Machine

```
┌───────────┐    Claim     ┌─────────┐   Complete   ┌───────────┐
│ available │─────────────►│ claimed │─────────────►│ completed │
└───────────┘              └─────────┘              └───────────┘
       ▲                        │
       │       Release          │
       └────────────────────────┘
```

**Transitions:**
- `available` → `claimed`: ClaimTask (any user)
- `claimed` → `available`: ReleaseTask (claimed user only)
- `claimed` → `completed`: CompleteTask (claimed user only)
- `completed` → (terminal state)

---

## Decay Calculation

Age-based visual decay is calculated client-side:

```gleam
pub fn calculate_decay(created_at: Time) -> Float {
  let age_days = time.diff_days(time.now(), created_at)
  let decay = int.min(age_days, 30) |> int.to_float
  decay /. 30.0  // 0.0 to 1.0
}
```

Visual effects based on decay:
- 0.0-0.3: Fresh (full color)
- 0.3-0.6: Aging (slight desaturation)
- 0.6-0.9: Old (more desaturation, slight opacity)
- 0.9-1.0: Critical (red tint, pulsing)

---

## Priority Visual Mapping

```gleam
pub fn priority_to_size(priority: Int) -> String {
  case priority {
    1 -> "w-16 h-16"   // Lowest - smallest
    2 -> "w-20 h-20"
    3 -> "w-24 h-24"   // Default
    4 -> "w-28 h-28"
    5 -> "w-32 h-32"   // Highest - largest
  }
}
```
