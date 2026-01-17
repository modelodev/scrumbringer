# Sprint 3 Refactor — File-by-File Backlog

**Generated:** 2026-01-17
**Updated:** 2026-01-17 (v2 — enhanced with target mapping + duplications)
**Branch:** `refactor-sprint3`

---

## Hygiene Rules (Sprint 3)

| Rule | Description |
|------|-------------|
| **Size** | Files ≤100 lines (unless justified in `////` docs) |
| **Module docs** | `////` required at top of every module |
| **Function docs** | `///` with examples for all public functions |
| **TEA purity** | `view` functions must be pure (no effects) |
| **ADT source** | Types must come from `shared/domain` — no duplication |

---

## Summary

| Category | Count | Description |
|----------|-------|-------------|
| 🔴 Critical | 12 | >500 lines — Must split |
| 🟠 Large | 32 | 101-500 lines — Review/split |
| 🟢 Compliant | 41 | ≤100 lines — Docs check only |
| ❌ Missing Docs | 44 | No `////` module docs |
| ✅ Has Docs | 41 | Has `////` module docs |

### Action Types

| Action | Description |
|--------|-------------|
| **Split** | Break into multiple smaller modules |
| **Extract** | Extract helpers/utilities to separate module |
| **Migrate** | Move to new location in architecture |
| **Doc-only** | Just add `////` module docs |
| **Exempt** | No changes needed (generated/external) |

---

## 🔴 CRITICAL (>500 lines) — Priority 1

| Lines | Docs | File | Action | Target Module | Rule Violated |
|------:|:----:|------|--------|---------------|---------------|
| 3667 | ✅ | `client/client_view.gleam` | Split | `client/features/*/view.gleam` | Size, TEA isolation |
| 2896 | ✅ | `server/sql.gleam` | Exempt | — | (Squirrel-generated) |
| 2276 | ✅ | `client/client_update.gleam` | Split | `client/features/*/update.gleam` | Size |
| 1646 | ✅ | `client/api.gleam` | Migrate | `client/api/*` (delete after) | Size, ADT dup |
| 733 | ✅ | `client/client_state.gleam` | Split | `client/features/*/model.gleam` | Size |
| 725 | ✅ | `client/api/tasks.gleam` | Split | `client/api/tasks/*.gleam` | Size, ADT dup |
| 711 | ✅ | `server/http/tasks.gleam` | Split | `server/http/tasks/*.gleam` | Size |
| 597 | ✅ | `server/services/task_workflow_actor.gleam` | Split | `server/services/workflows/*.gleam` | Size |
| 589 | ✅ | `client/client_workflows/admin.gleam` | Split | `client/features/admin/*.gleam` | Size |
| 554 | ✅ | `client/update_helpers.gleam` | Extract | `client/app/effects.gleam` + feature updates | Size |
| 513 | ✅ | `server/services/tasks_db.gleam` | Split | `server/persistence/tasks/*.gleam` | Size |
| 438 | ❌ | `server/services/auth_db.gleam` | Split+Doc | `server/persistence/auth/*.gleam` | Size, Docs |

---

## 🔁 Duplications Detected

### ADT Type Duplications (Must consolidate to `shared/domain`)

| Type | Defined In | Action |
|------|------------|--------|
| `TaskStatus` | `api.gleam`, `api/tasks.gleam`, `server/domain/task_status.gleam` | → `shared/domain/task_status.gleam` |
| `ClaimedState` | `api.gleam`, `api/tasks.gleam`, `server/domain/task_status.gleam` | → `shared/domain/task_status.gleam` |
| `WorkState` | `api.gleam`, `api/tasks.gleam` | → `shared/domain/task_status.gleam` |
| `OngoingBy` | `api.gleam`, `api/tasks.gleam` | → `shared/domain/task_status.gleam` |
| `Task` | `api.gleam`, `api/tasks.gleam` | → `shared/domain/task.gleam` |
| `TaskNote` | `api.gleam`, `api/tasks.gleam` | → `shared/domain/task.gleam` |
| `TaskPosition` | `api.gleam`, `api/tasks.gleam` | → `shared/domain/task.gleam` |
| `ActiveTask` | `api.gleam`, `api/tasks.gleam` | → `shared/domain/task.gleam` |
| `Project` | `api.gleam`, `api/projects.gleam` | → `shared/domain/project.gleam` |
| `ProjectMember` | `api.gleam`, `api/projects.gleam` | → `shared/domain/project.gleam` |
| `OrgUser` | `api.gleam`, `api/org.gleam` | → `shared/domain/org.gleam` |
| `Capability` | `api.gleam`, `api/org.gleam` | → `shared/domain/capability.gleam` |
| `OrgInvite` | `api.gleam`, `api/org.gleam` | → `shared/domain/org.gleam` |
| `InviteLink` | `api.gleam`, `api/org.gleam` | → `shared/domain/org.gleam` |
| `ApiError` | `api.gleam`, `api/core.gleam` | → `shared/domain/api_error.gleam` |
| `MyMetrics` | `api.gleam`, `api/metrics.gleam` | → `shared/domain/metrics.gleam` |
| `OrgMetrics*` | `api.gleam`, `api/metrics.gleam` | → `shared/domain/metrics.gleam` |

### Pattern Duplications (Consolidate to shared utilities)

| Pattern | Found In (11 files) | Target |
|---------|---------------------|--------|
| 401/403 auth error handling | `client_workflows/*`, `update_helpers`, `client_update`, `client_view` | `client/app/effects.gleam` |
| Loading/Error/NotLoaded views | 25 files | `client/ui/loading.gleam`, `client/ui/error.gleam` |

---

## 📦 Legacy `api.gleam` Migration

### Importers (25 source files)

These files import `scrumbringer_client/api` and must be migrated to use `api/*` modules:

| File | Import Used For |
|------|-----------------|
| `scrumbringer_client.gleam` | Types + decoders |
| `client_state.gleam` | All types |
| `client_update.gleam` | Types + API calls |
| `client_view.gleam` | Types for rendering |
| `update_helpers.gleam` | Error handling |
| `client_workflows/admin.gleam` | Admin types |
| `client_workflows/auth.gleam` | Auth types |
| `client_workflows/capabilities.gleam` | Capability types |
| `client_workflows/invite_links.gleam` | InviteLink types |
| `client_workflows/now_working.gleam` | ActiveTask types |
| `client_workflows/projects.gleam` | Project types |
| `client_workflows/task_types.gleam` | TaskType types |
| `client_workflows/tasks.gleam` | Task types |
| `accept_invite.gleam` | OrgInvite types |
| `reset_password.gleam` | PasswordReset types |
| `permissions.gleam` | Project type |
| `router.gleam` | Route params |
| `hydration.gleam` | State types |

### Migration Strategy

1. **Phase A**: Ensure all types exist in `api/*` modules (✅ done)
2. **Phase B**: Update importers to use `api/*` instead of `api`
3. **Phase C**: Delete `api.gleam` once no importers remain

---

## 🟠 LARGE (101-500 lines) — Priority 2

### Server

| Lines | Docs | File | Action | Target | Rule |
|------:|:----:|------|--------|--------|------|
| 376 | ✅ | `http/metrics_service.gleam` | Review | — | Size (justify) |
| 341 | ❌ | `http/projects.gleam` | Doc+Review | — | Docs, Size |
| 322 | ❌ | `http/password_resets.gleam` | Doc+Review | — | Docs, Size |
| 305 | ❌ | `http/auth.gleam` | Doc+Review | — | Docs, Size |
| 257 | ❌ | `services/projects_db.gleam` | Doc | `persistence/projects.gleam` | Docs |
| 241 | ❌ | `services/auth_logic.gleam` | Doc | `services/auth/logic.gleam` | Docs |
| 229 | ❌ | `http/task_positions.gleam` | Doc | — | Docs |
| 223 | ✅ | `http/tasks/validators.gleam` | — | — | (OK) |
| 221 | ❌ | `services/org_invite_links_db.gleam` | Doc | `persistence/invites.gleam` | Docs |
| 220 | ✅ | `http/tasks/filters.gleam` | — | — | (OK) |
| 220 | ✅ | `domain/task_status.gleam` | — | `shared/domain/task_status.gleam` | ADT dup |
| 213 | ❌ | `http/org_users.gleam` | Doc | — | Docs |
| 204 | ✅ | `http/me_active_task.gleam` | — | — | (OK) |
| 199 | ✅ | `http/tasks/presenters.gleam` | — | — | (OK) |
| 196 | ❌ | `http/capabilities.gleam` | Doc | — | Docs |
| 195 | ❌ | `services/org_users_db.gleam` | Doc | `persistence/org_users.gleam` | Docs |
| 194 | ❌ | `services/now_working_db.gleam` | Doc | `persistence/now_working.gleam` | Docs |
| 188 | ❌ | `services/password_resets_db.gleam` | Doc | `persistence/password_resets.gleam` | Docs |
| 185 | ✅ | `http/org_metrics.gleam` | — | — | (OK) |
| 182 | ❌ | `scrumbringer_server.gleam` | Doc | — | Docs |
| 177 | ❌ | `http/org_invite_links.gleam` | Doc | — | Docs |
| 173 | ✅ | `http/metrics_presenters.gleam` | — | — | (OK) |
| 151 | ❌ | `services/store.gleam` | Doc | — | Docs |
| 148 | ✅ | `services/now_working_actor.gleam` | — | — | (OK) |
| 146 | ❌ | `http/task_notes.gleam` | Doc | — | Docs |
| 145 | ❌ | `services/jwt.gleam` | Doc | `services/auth/jwt.gleam` | Docs |
| 121 | ❌ | `services/user_capabilities_db.gleam` | Doc | `persistence/capabilities.gleam` | Docs |
| 107 | ❌ | `services/task_types_db.gleam` | Doc | `persistence/task_types.gleam` | Docs |
| 101 | ❌ | `http/me_metrics.gleam` | Doc | — | Docs |

### Client

| Lines | Docs | File | Action | Target | Rule |
|------:|:----:|------|--------|--------|------|
| 422 | ✅ | `client_workflows/tasks.gleam` | Review | `features/tasks/update.gleam` | Size |
| 395 | ✅ | `api/metrics.gleam` | Review | — | Size, ADT dup |
| 366 | ✅ | `client_workflows/auth.gleam` | Review | `features/auth/update.gleam` | Size |
| 326 | ✅ | `client_ffi.gleam` | Review | `ffi/*.gleam` | Size |
| 320 | ✅ | `router.gleam` | Review | `app/router.gleam` | Size |
| 318 | ✅ | `scrumbringer_client.gleam` | Review | `app/main.gleam` | Size |
| 303 | ❌ | `i18n/es.gleam` | Doc | — | Docs |
| 298 | ❌ | `i18n/en.gleam` | Doc | — | Docs |
| 287 | ✅ | `client_workflows/invite_links.gleam` | Review | `features/invites/update.gleam` | Size |
| 280 | ✅ | `client_workflows/now_working.gleam` | Review | `features/now_working/update.gleam` | Size |
| 278 | ✅ | `api/org.gleam` | Review | — | ADT dup |
| 275 | ❌ | `i18n/text.gleam` | Doc | — | Docs |
| 267 | ✅ | `api/auth.gleam` | Review | — | ADT dup |
| 256 | ✅ | `api/core.gleam` | Review | — | ADT dup |
| 247 | ✅ | `client_workflows/projects.gleam` | Review | `features/projects/update.gleam` | Size |
| 245 | ✅ | `client_workflows/task_types.gleam` | Review | `features/task_types/update.gleam` | Size |
| 240 | ✅ | `hydration.gleam` | Review | `app/hydration.gleam` | Size |
| 155 | ❌ | `accept_invite.gleam` | Doc | `features/invites/accept.gleam` | Docs |
| 150 | ❌ | `reset_password.gleam` | Doc | `features/auth/reset_password.gleam` | Docs |
| 149 | ✅ | `client_workflows/capabilities.gleam` | — | `features/capabilities/update.gleam` | (OK) |
| 137 | ✅ | `api/projects.gleam` | — | — | ADT dup |
| 124 | ❌ | `styles.gleam` | Doc | `ui/styles.gleam` | Docs |
| 105 | ❌ | `theme.gleam` | Doc | `ui/theme.gleam` | Docs |

---

## 🟢 COMPLIANT (≤100 lines) — Priority 3

### Server

| Lines | Docs | File | Action | Target |
|------:|:----:|------|--------|--------|
| 89 | ✅ | `http/tasks/conflict_handlers.gleam` | — | — |
| 89 | ❌ | `http/org_invites.gleam` | Doc-only | — |
| 88 | ❌ | `http/api.gleam` | Doc-only | — |
| 76 | ❌ | `main.gleam` | Doc-only | — |
| 75 | ❌ | `services/store_state.gleam` | Doc-only | — |
| 74 | ❌ | `services/org_invites_db.gleam` | Doc-only | `persistence/invites.gleam` |
| 63 | ❌ | `services/task_positions_db.gleam` | Doc-only | `persistence/task_positions.gleam` |
| 63 | ❌ | `services/task_notes_db.gleam` | Doc-only | `persistence/task_notes.gleam` |
| 62 | ❌ | `services/capabilities_db.gleam` | Doc-only | `persistence/capabilities.gleam` |
| 34 | ❌ | `services/password.gleam` | Doc-only | `services/auth/password.gleam` |
| 26 | ❌ | `http/csrf.gleam` | Doc-only | — |
| 22 | ❌ | `services/task_events_db.gleam` | Doc-only | `persistence/task_events.gleam` |
| 22 | ❌ | `services/rate_limit.gleam` | Doc-only | — |
| 14 | ❌ | `services/time.gleam` | Doc-only | — |

### Client

| Lines | Docs | File | Action | Target |
|------:|:----:|------|--------|--------|
| 84 | ❌ | `pool_prefs.gleam` | Doc-only | `features/pool/prefs.gleam` |
| 75 | ❌ | `permissions.gleam` | Doc-only | `features/auth/permissions.gleam` |
| 62 | ❌ | `i18n/locale.gleam` | Doc-only | — |
| 53 | ✅ | `client_workflows/i18n.gleam` | — | `features/i18n/update.gleam` |
| 22 | ❌ | `member_section.gleam` | Doc-only | `ui/member_section.gleam` |
| 17 | ❌ | `member_visuals.gleam` | Doc-only | `ui/member_visuals.gleam` |
| 11 | ❌ | `i18n/i18n.gleam` | Doc-only | — |

### Domain Package

| Lines | Docs | File | Action | Target |
|------:|:----:|------|--------|--------|
| 19 | ❌ | `org_role.gleam` | Doc-only | `shared/domain/org_role.gleam` |
| 11 | ❌ | `user.gleam` | Doc-only | `shared/domain/user.gleam` |

---

## Exemptions

| File | Reason |
|------|--------|
| `server/sql.gleam` (2896 lines) | Squirrel-generated — do not modify manually |
| `packages/birl/*` | External package — not in refactor scope |

---

## Execution Order (Recommended)

### Phase 1: Quick Wins — Documentation
1. Add `////` docs to all ≤100 line files (23 files)
2. Add `////` docs to 101-200 line files (12 files)

### Phase 2: ADT Consolidation
3. Create `shared/domain/*.gleam` with canonical types
4. Update `api/*` modules to re-export from `shared/domain`
5. Update `server/domain/*` to re-export from `shared/domain`

### Phase 3: Legacy Migration
6. Update all 18 importers to use `api/*` instead of `api`
7. Delete `client/api.gleam`

### Phase 4: Pattern Consolidation
8. Create `client/ui/loading.gleam` and `client/ui/error.gleam`
9. Extract auth error handling to `client/app/effects.gleam`

### Phase 5: Critical Splits
10. Split `client_view.gleam` → `features/*/view.gleam`
11. Split `client_state.gleam` → `features/*/model.gleam`
12. Split `client_update.gleam` → `features/*/update.gleam`
13. Split remaining >500 line files

### Phase 6: Large File Review
14. Review 101-500 line files for split opportunities
15. Add justification in `////` docs if keeping size

---

## Progress Tracking

```
[ ] Phase 1: Documentation (35 files)
    [ ] Server ≤100 lines (14 files)
    [ ] Client ≤100 lines (7 files)
    [ ] Domain (2 files)
    [ ] Server 101-200 lines (8 files)
    [ ] Client 101-200 lines (4 files)

[ ] Phase 2: ADT Consolidation
    [ ] Create shared/domain/task_status.gleam
    [ ] Create shared/domain/task.gleam
    [ ] Create shared/domain/project.gleam
    [ ] Create shared/domain/org.gleam
    [ ] Create shared/domain/metrics.gleam
    [ ] Update api/* re-exports
    [ ] Update server/domain/* re-exports

[ ] Phase 3: Legacy Migration
    [ ] Update 18 importers
    [ ] Delete client/api.gleam

[ ] Phase 4: Pattern Consolidation
    [ ] Create client/ui/loading.gleam
    [ ] Create client/ui/error.gleam
    [ ] Extract auth error handling

[ ] Phase 5: Critical Splits
    [ ] client_view.gleam (3667 lines)
    [ ] client_state.gleam (733 lines)
    [ ] client_update.gleam (2276 lines)
    [ ] server/http/tasks.gleam (711 lines)
    [ ] server/services/tasks_db.gleam (513 lines)
    [ ] Remaining 6 critical files

[ ] Phase 6: Large File Review
    [ ] Server 101-500 lines (29 files)
    [ ] Client 101-500 lines (23 files)
```
