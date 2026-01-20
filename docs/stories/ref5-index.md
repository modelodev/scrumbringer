# Refactoring 5: Admin CRUD Componentization

## Overview

Este epic implementa la componentización de los diálogos CRUD del Admin Panel como Lustre Components, siguiendo el patrón establecido en Story 3.6 (Card Detail Modal).

**Arquitectura de referencia**: [Lustre Components Architecture](../architecture/lustre-components.md)

## Objective

Reducir el bloat en el Model/Msg raíz extrayendo el estado de los diálogos CRUD a componentes Lustre encapsulados con Shadow DOM.

**Impacto estimado**: **70 campos Model**, **82 variantes Msg** extraídos.

## Status

| Story | Title | Complexity | Model Fields | Msg Variants | Status |
|-------|-------|------------|--------------|--------------|--------|
| ref5-1 | [Cards CRUD Component](./ref5-1.cards-crud-component.md) | Low | 17 | 20 | **Ready** |
| ref5-2 | [Workflows CRUD Component](./ref5-2.workflows-crud-component.md) | Low | 15 | 18 | **Ready** |
| ref5-3 | [Task Templates CRUD Component](./ref5-3.task-templates-crud-component.md) | Medium | 17 | 20 | **Ready** |
| ref5-4 | [Rules CRUD Component](./ref5-4.rules-crud-component.md) | High | 21 | 24 | **Ready** |

## Dependency Graph

```
ref5-1 (Cards CRUD) ──────┐
                          │
ref5-2 (Workflows CRUD) ──┼── Can run in parallel (independent entities)
                          │
ref5-3 (Task Templates) ──┤
                          │
ref5-4 (Rules CRUD) ──────┘ (last due to complexity)
```

**Note**: Stories are independent and can be implemented in any order. Priority is based on complexity (simplest first).

## Design Principles

Per UX analysis documented in [Lustre Components Architecture](../architecture/lustre-components.md#design-philosophy):

1. **Encapsulation over Generalization** - Each component is self-contained, not a generic dialog
2. **No config-based forms** - View functions are more readable than configuration objects
3. **Accept structural differences** - Components with different patterns remain separate

## Milestone: ref5 Complete

- [ ] Cards CRUD Component extracted and working
- [ ] Workflows CRUD Component extracted and working
- [ ] Task Templates CRUD Component extracted and working
- [ ] Rules CRUD Component extracted and working
- [ ] 70 Model fields removed from root
- [ ] 82 Msg variants removed from root
- [ ] All tests pass
- [ ] FFI `knownComponents` array updated with all new components

## Gate

Each component story can be merged independently once QA passes.

## Technical Notes

### FFI Registration

When adding new components, update `component.ffi.mjs`:

```javascript
const knownComponents = ['card-detail-modal', 'card-crud-dialog', ...]
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

## Changelog

| Date | Description |
|------|-------------|
| 2026-01-20 | Created epic index and 4 component stories |
| 2026-01-20 | Updated counts after Architect validation (70 fields, 82 variants) |
| 2026-01-20 | All 4 stories moved to Ready status (PO approval) |
