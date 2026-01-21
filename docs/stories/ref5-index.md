# Refactoring 5: Admin CRUD Componentization

## Overview

Este epic implementa la componentización de los diálogos CRUD del Admin Panel como Lustre Components, siguiendo el patrón establecido en Story 3.6 (Card Detail Modal).

**Arquitectura de referencia**: [Lustre Components Architecture](../architecture/lustre-components.md)

## Objective

Reducir el bloat en el Model/Msg raíz extrayendo el estado de los diálogos CRUD a componentes Lustre encapsulados con Shadow DOM.

**Impacto logrado**: **70 campos Model**, **82 variantes Msg** extraídos.

## Status

| Story | Title | Complexity | Model Fields | Msg Variants | Status |
|-------|-------|------------|--------------|--------------|--------|
| ref5-1 | [Cards CRUD Component](./ref5-1.cards-crud-component.md) | Low | 17 | 20 | **Done** |
| ref5-2 | [Workflows CRUD Component](./ref5-2.workflows-crud-component.md) | Low | 15 | 18 | **Done** |
| ref5-3 | [Task Templates CRUD Component](./ref5-3.task-templates-crud-component.md) | Medium | 17 | 20 | **Done** |
| ref5-4 | [Rules CRUD Component](./ref5-4.rules-crud-component.md) | High | 21 | 24 | **Done** |
| ref5-5 | [Hygiene and Warnings Cleanup](./ref5-5.hygiene-and-warnings.md) | Low | — | — | **Done** |

## Dependency Graph

```
ref5-1 (Cards CRUD) ──────┐
                          │
ref5-2 (Workflows CRUD) ──┼── Can run in parallel (independent entities)
                          │
ref5-3 (Task Templates) ──┤
                          │
ref5-4 (Rules CRUD) ──────┘ (last due to complexity)
                          │
ref5-5 (Hygiene) ─────────┘ (after all components complete)
```

**Note**: Stories are independent and can be implemented in any order. Priority is based on complexity (simplest first).

## Design Principles

Per UX analysis documented in [Lustre Components Architecture](../architecture/lustre-components.md#design-philosophy):

1. **Encapsulation over Generalization** - Each component is self-contained, not a generic dialog
2. **No config-based forms** - View functions are more readable than configuration objects
3. **Accept structural differences** - Components with different patterns remain separate

## Milestone: ref5 Complete

- [x] Cards CRUD Component extracted and working
- [x] Workflows CRUD Component extracted and working
- [x] Task Templates CRUD Component extracted and working
- [x] Rules CRUD Component extracted and working
- [x] 70 Model fields removed from root
- [x] 82 Msg variants removed from root
- [x] All tests pass (261 tests)
- [x] FFI `knownComponents` array updated with all new components
- [x] Build warnings cleaned (ref5-5)
- [x] Documentation updated (ref5-5)

## Gate

Each component story can be merged independently once QA passes.

| Story | QA Gate | Date |
|-------|---------|------|
| ref5-1 | PASS | 2026-01-20 |
| ref5-2 | PASS | 2026-01-20 |
| ref5-3 | PASS | 2026-01-21 |
| ref5-4 | PASS | 2026-01-21 |
| ref5-5 | PASS | 2026-01-21 |

## Technical Notes

### FFI Registration

When adding new components, update `component.ffi.mjs`:

```javascript
const knownComponents = ['card-detail-modal', 'card-crud-dialog', 'workflow-crud-dialog', 'task-template-crud-dialog', 'rule-crud-dialog']
```

### Component Registration

All components must be registered in `scrumbringer_client.gleam`:

```gleam
pub fn main() {
  case card_crud_dialog.register() {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
  // ... other components
}
```

## Future Work: Additional Componentization Candidates

The following dialog fields follow the legacy pattern and are candidates for a future **ref6** sprint:

| Entity | Fields | Location |
|--------|--------|----------|
| Projects | 3 fields (`projects_create_*`) | `features/projects/` |
| Capabilities | 4 fields (`capabilities_create_*`) | `features/capabilities/` |
| Task Types | 6 fields (`task_types_create_*`) | `features/task_types/` |
| Member Task Creation | 7 fields (`member_create_*`) | `features/pool/` |
| Member Position Edit | 5 fields (`member_position_edit_*`) | `features/pool/` |

**Total: 25 additional fields** that could benefit from the same componentization pattern.

## Changelog

| Date | Description |
|------|-------------|
| 2026-01-20 | Created epic index and 4 component stories |
| 2026-01-20 | Updated counts after Architect validation (70 fields, 82 variants) |
| 2026-01-20 | All 4 stories moved to Ready status (PO approval) |
| 2026-01-21 | ref5-1 through ref5-4 completed and QA approved |
| 2026-01-21 | Added ref5-5 for hygiene cleanup and documented future work |
| 2026-01-21 | ref5-5 completed: 0 warnings, 261 tests pass, sprint complete |
