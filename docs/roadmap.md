# Product Roadmap

This document captures the planned product backlog across sprints.

> Notes
> - Sprint 2 stories are executable and live in `docs/stories/2.*.md`.
> - Sprint 3+ entries below are *planning stubs* (examples) and must be refined before implementation.
> - Metrics for the rules engine are mandatory as part of the engine DoD.

---

## Epics

### Epic A — Multi-user onboarding (invite-only)
- Invite links (no SMTP)
- Accept invite → register → login
- Org settings (roles)
- Reset password (link)

### Epic B — Themes / skins
- Theme tokens
- CSS variables
- Theme selection + persistence

### Epic M — Metrics
- My panel: personal metrics only
- Admin metrics: org/project aggregates + distributions
- No leaderboards; drill-down limited to project/tasks in Sprint 2

### Epic W — Workflows / rules engine (v1.1+)
- Rules defined per org and per project
- Triggers on task + card (ficha) state changes and other task changes (type/capability/priority)
- Action: create tasks from templates into the pool
- Instrumentation is part of DoD (evaluated/applied/suppressed + counters)

### Epic F — Fichas (cards)
- Container for tasks
- States: `pendiente / en_curso / cerrada`
- State changes are automatic, derived from the state of tasks inside the card

---

## Sprint 2 (2 weeks) — v0.2

**Goal:** Multi-user onboarding + reset password + theming foundation + MVP metrics.

**Stories:**
- `docs/stories/2.1.invites-by-link.md`
- `docs/stories/2.2.accept-invite-register-login.md`
- `docs/stories/2.3.org-settings-roles.md`
- `docs/stories/2.4.reset-password-by-link.md`
- `docs/stories/2.5.theme-engine-v1.md`
- `docs/stories/2.6.metrics-v1.md`

---

## Sprint 3 (2 weeks) — v0.3 (Planning stubs / examples)

**Goal:** Introduce cards (fichas) + first cut workflows engine with mandatory rule metrics.

**Stories (stubs):**
- `docs/stories/3.1.fichas-v1.md`
- `docs/stories/3.2.workflows-engine-v1.md`
- `docs/stories/3.3.workflows-admin-metrics.md`

---

## Sprint 4 (2 weeks) — v0.4 (Planning stubs / examples)

**Goal:** Expand workflows + add advanced metrics (burndown/agenda/time) as optional follow-ups.

**Stories (stubs):**
- `docs/stories/4.1.workflows-templates-v1.md`
- `docs/stories/4.2.workflows-dashboard-v1.md`
- `docs/stories/4.3.burndown-v1.md`
- `docs/stories/4.4.agenda-v1.md`
- `docs/stories/4.5.time-tracking-v1.md`

---

## Change Log

| Date | Version | Description |
|------|---------|-------------|
| 2026-01-14 | 1.0 | Initial roadmap from Sprint 1 close + Sprint 2 planning |
