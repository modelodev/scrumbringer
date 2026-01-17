# Sprint 3 Refactor — File-by-File Backlog

**Generated:** 2026-01-17
**Branch:** `refactor-sprint3`
**Hygiene Rules:**
- Files ≤100 lines (unless justified)
- Module docs (`////`) required
- Public function docs (`///` with examples) required

---

## Summary

| Category | Count | Description |
|----------|-------|-------------|
| 🔴 Critical | 12 | >500 lines — Must split |
| 🟠 Large | 32 | 101-500 lines — Review/split |
| 🟢 Compliant | 41 | ≤100 lines — Docs check only |
| ❌ Missing Docs | 44 | No `////` module docs |
| ✅ Has Docs | 41 | Has `////` module docs |

---

## 🔴 CRITICAL (>500 lines) — Priority 1

These files **must be split** into smaller modules per Sprint 3 architecture.

| Lines | Docs | File | Action |
|------:|:----:|------|--------|
| 3667 | ✅ | `client/client_view.gleam` | Split into `views/*` feature modules |
| 2896 | ✅ | `server/sql.gleam` | **EXEMPT** (Squirrel-generated) |
| 2276 | ✅ | `client/client_update.gleam` | Further split into `client_workflows/*` |
| 1646 | ✅ | `client/api.gleam` | **LEGACY** — Migrate to `api/*` modules |
| 733 | ✅ | `client/client_state.gleam` | Split model into feature models |
| 725 | ✅ | `client/api/tasks.gleam` | Split into task operation modules |
| 711 | ✅ | `server/http/tasks.gleam` | Split into handler sub-modules |
| 597 | ✅ | `server/services/task_workflow_actor.gleam` | Split workflow phases |
| 589 | ✅ | `client/client_workflows/admin.gleam` | Split admin operations |
| 554 | ✅ | `client/update_helpers.gleam` | Split by concern |
| 513 | ✅ | `server/services/tasks_db.gleam` | Split query groups |
| 438 | ❌ | `server/services/auth_db.gleam` | Add docs + split |

---

## 🟠 LARGE (101-500 lines) — Priority 2

Review for potential splitting or justify size in module docs.

### Server (101-500 lines)

| Lines | Docs | File | Status |
|------:|:----:|------|--------|
| 376 | ✅ | `server/http/metrics_service.gleam` | Review |
| 341 | ❌ | `server/http/projects.gleam` | Add docs |
| 322 | ❌ | `server/http/password_resets.gleam` | Add docs |
| 305 | ❌ | `server/http/auth.gleam` | Add docs |
| 257 | ❌ | `server/services/projects_db.gleam` | Add docs |
| 241 | ❌ | `server/services/auth_logic.gleam` | Add docs |
| 229 | ❌ | `server/http/task_positions.gleam` | Add docs |
| 223 | ✅ | `server/http/tasks/validators.gleam` | OK |
| 221 | ❌ | `server/services/org_invite_links_db.gleam` | Add docs |
| 220 | ✅ | `server/http/tasks/filters.gleam` | OK |
| 220 | ✅ | `server/domain/task_status.gleam` | OK |
| 213 | ❌ | `server/http/org_users.gleam` | Add docs |
| 204 | ✅ | `server/http/me_active_task.gleam` | OK |
| 199 | ✅ | `server/http/tasks/presenters.gleam` | OK |
| 196 | ❌ | `server/http/capabilities.gleam` | Add docs |
| 195 | ❌ | `server/services/org_users_db.gleam` | Add docs |
| 194 | ❌ | `server/services/now_working_db.gleam` | Add docs |
| 188 | ❌ | `server/services/password_resets_db.gleam` | Add docs |
| 185 | ✅ | `server/http/org_metrics.gleam` | OK |
| 182 | ❌ | `server/scrumbringer_server.gleam` | Add docs |
| 177 | ❌ | `server/http/org_invite_links.gleam` | Add docs |
| 173 | ✅ | `server/http/metrics_presenters.gleam` | OK |
| 151 | ❌ | `server/services/store.gleam` | Add docs |
| 148 | ✅ | `server/services/now_working_actor.gleam` | OK |
| 146 | ❌ | `server/http/task_notes.gleam` | Add docs |
| 145 | ❌ | `server/services/jwt.gleam` | Add docs |
| 121 | ❌ | `server/services/user_capabilities_db.gleam` | Add docs |
| 107 | ❌ | `server/services/task_types_db.gleam` | Add docs |
| 101 | ❌ | `server/http/me_metrics.gleam` | Add docs |

### Client (101-500 lines)

| Lines | Docs | File | Status |
|------:|:----:|------|--------|
| 422 | ✅ | `client/client_workflows/tasks.gleam` | Review |
| 395 | ✅ | `client/api/metrics.gleam` | Review |
| 366 | ✅ | `client/client_workflows/auth.gleam` | Review |
| 326 | ✅ | `client/client_ffi.gleam` | Review |
| 320 | ✅ | `client/router.gleam` | Review |
| 318 | ✅ | `client/scrumbringer_client.gleam` | Review |
| 303 | ❌ | `client/i18n/es.gleam` | Add docs |
| 298 | ❌ | `client/i18n/en.gleam` | Add docs |
| 287 | ✅ | `client/client_workflows/invite_links.gleam` | Review |
| 280 | ✅ | `client/client_workflows/now_working.gleam` | Review |
| 278 | ✅ | `client/api/org.gleam` | Review |
| 275 | ❌ | `client/i18n/text.gleam` | Add docs |
| 267 | ✅ | `client/api/auth.gleam` | Review |
| 256 | ✅ | `client/api/core.gleam` | Review |
| 247 | ✅ | `client/client_workflows/projects.gleam` | Review |
| 245 | ✅ | `client/client_workflows/task_types.gleam` | Review |
| 240 | ✅ | `client/hydration.gleam` | Review |
| 155 | ❌ | `client/accept_invite.gleam` | Add docs |
| 150 | ❌ | `client/reset_password.gleam` | Add docs |
| 149 | ✅ | `client/client_workflows/capabilities.gleam` | OK |
| 137 | ✅ | `client/api/projects.gleam` | OK |
| 124 | ❌ | `client/styles.gleam` | Add docs |
| 105 | ❌ | `client/theme.gleam` | Add docs |

---

## 🟢 COMPLIANT (≤100 lines) — Priority 3

Only need docs verification. Files marked ❌ need `////` module docs added.

### Server (≤100 lines)

| Lines | Docs | File |
|------:|:----:|------|
| 89 | ✅ | `server/http/tasks/conflict_handlers.gleam` |
| 89 | ❌ | `server/http/org_invites.gleam` |
| 88 | ❌ | `server/http/api.gleam` |
| 76 | ❌ | `server/main.gleam` |
| 75 | ❌ | `server/services/store_state.gleam` |
| 74 | ❌ | `server/services/org_invites_db.gleam` |
| 63 | ❌ | `server/services/task_positions_db.gleam` |
| 63 | ❌ | `server/services/task_notes_db.gleam` |
| 62 | ❌ | `server/services/capabilities_db.gleam` |
| 34 | ❌ | `server/services/password.gleam` |
| 26 | ❌ | `server/http/csrf.gleam` |
| 22 | ❌ | `server/services/task_events_db.gleam` |
| 22 | ❌ | `server/services/rate_limit.gleam` |
| 14 | ❌ | `server/services/time.gleam` |

### Client (≤100 lines)

| Lines | Docs | File |
|------:|:----:|------|
| 84 | ❌ | `client/pool_prefs.gleam` |
| 75 | ❌ | `client/permissions.gleam` |
| 62 | ❌ | `client/i18n/locale.gleam` |
| 53 | ✅ | `client/client_workflows/i18n.gleam` |
| 22 | ❌ | `client/member_section.gleam` |
| 17 | ❌ | `client/member_visuals.gleam` |
| 11 | ❌ | `client/i18n/i18n.gleam` |

### Domain Package (≤100 lines)

| Lines | Docs | File |
|------:|:----:|------|
| 19 | ❌ | `domain/org_role.gleam` |
| 11 | ❌ | `domain/user.gleam` |

---

## Exemptions

| File | Reason |
|------|--------|
| `server/sql.gleam` (2896 lines) | Squirrel-generated — do not modify manually |
| `packages/birl/*` | External package — not in refactor scope |

---

## Sprint 3 Objectives Mapping

| Objective | Related Files |
|-----------|---------------|
| **1. Eliminate view/update duplication** | `client_view.gleam`, `client_update.gleam`, `update_helpers.gleam` |
| **2. Remove legacy api.gleam** | `client/api.gleam` → migrate to `client/api/*` |
| **3. Modular api/* handlers** | `server/http/tasks.gleam` → already has `tasks/*` sub-modules |
| **4. Module hygiene (≤100 lines)** | All 🔴 Critical files |
| **5. Module docs (`////`)** | 44 files missing docs |

---

## Execution Order (Recommended)

### Phase 1: Documentation (Quick Wins)
1. Add `////` docs to all ≤100 line files (21 files)
2. Add `////` docs to 101-200 line files (15 files)

### Phase 2: Legacy Migration
3. Migrate `client/api.gleam` → `client/api/*` modules
4. Remove or deprecate legacy entry point

### Phase 3: Critical Splits
5. Split `client_view.gleam` → feature views
6. Split `client_state.gleam` → feature models
7. Split `client_update.gleam` → further workflow modules
8. Split `server/http/tasks.gleam` → handler modules
9. Split `server/services/tasks_db.gleam` → query modules

### Phase 4: Large File Review
10. Review 101-500 line files for split opportunities
11. Add justification in `////` docs if keeping size

---

## Progress Tracking

Use this section to track completion:

```
[ ] Phase 1: Documentation
    [ ] Server ≤100 lines (14 files)
    [ ] Client ≤100 lines (7 files)
    [ ] Domain (2 files)
[ ] Phase 2: Legacy Migration
    [ ] client/api.gleam migration
[ ] Phase 3: Critical Splits
    [ ] client_view.gleam
    [ ] client_state.gleam
    [ ] client_update.gleam
    [ ] server/http/tasks.gleam
    [ ] server/services/tasks_db.gleam
[ ] Phase 4: Large File Review
    [ ] Server 101-500 lines
    [ ] Client 101-500 lines
```
