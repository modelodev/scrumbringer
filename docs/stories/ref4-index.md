# Refactoring 4: Server Test Foundation & DRY

## Overview

Este epic implementa la **Fase 0** del [Refactoring Roadmap v2.0](../architecture/refactoring-roadmap.md): establecer una base de tests antes de cualquier refactoring del servidor.

## Status

| Story | Title | Status | Dependencies |
|-------|-------|--------|--------------|
| ref4-0.1 | [Test Infrastructure Setup](./ref4-0.1.test-infrastructure.md) | **Ready** | None |
| ref4-0.2 | [Critical Path Tests](./ref4-0.2.critical-path-tests.md) | **Ready** | ref4-0.1 |
| ref4-0.3 | [Authorization Tests](./ref4-0.3.authorization-tests.md) | **Ready** | ref4-0.1 |
| ref4-0.4 | [Workflow Tests](./ref4-0.4.workflow-tests.md) | **Ready** | ref4-0.1 |
| ref4-0.5 | [JSON Helpers Tests](./ref4-0.5.json-helpers-tests.md) | **Ready** | ref4-0.1 |

## Dependency Graph

```
ref4-0.1 (Infrastructure)
    │
    ├── ref4-0.2 (Critical Path)
    │
    ├── ref4-0.3 (Authorization)
    │
    ├── ref4-0.4 (Workflows)
    │
    └── ref4-0.5 (JSON Helpers)
```

## Milestone: Fase 0 Complete

- [ ] Test infrastructure created and documented
- [ ] **≥15 tests** covering critical path
- [ ] CI runs tests automatically
- [ ] Test coverage of:
  - [ ] Task lifecycle (claim/release/complete)
  - [ ] Authorization (project member/admin)
  - [ ] Workflows CRUD
  - [ ] JSON helpers

## Gate

**Fase 0 MUST be completed before starting Fase 1 (DRY refactoring).**

Refactoring without tests is an unacceptable regression risk.

## Future Phases (Not Yet Sharded)

| Phase | Focus | Status |
|-------|-------|--------|
| Fase 1 | Fundamentos DRY (json.gleam, option.gleam, authorization.gleam) | Pending |
| Fase 2 | Type Safety (FieldUpdate, CardState, ResourceType) | Pending |
| Fase 3 | Arquitectura HTTP (middleware, api.from_result) | Pending |
| Fase 4 | SQL y Documentación | Pending |

See [Refactoring Roadmap](../architecture/refactoring-roadmap.md) for full details.

## Changelog

| Date | Description |
|------|-------------|
| 2026-01-20 | Created index and 5 stories for Fase 0 |
| 2026-01-20 | All stories validated and moved to Ready status (PO review) |
