# Ref-frontend: Reutilizacion y refactor Lustre

## Overview

Este epic consolida reutilizacion de vistas, eventos y efectos en el frontend Lustre, reduciendo duplicacion y mejorando el mantenimiento sin cambiar comportamiento visible.

**Fuente principal**: `informe_frontend.md` (auditoria de `apps/client/src`).

## Objectives

- Reducir "div soup" y duplicacion de vistas con fragments y helpers.
- Estandarizar decoders de eventos y helpers de efectos.
- Separar Msg y Model por feature/pagina para reducir complejidad del MVU central.

## Status

| Story | Title | Phase | Status |
|------|-------|-------|--------|
| ref-frontend-01 | [Fragments y composicion de vistas](./ref-frontend-01.fragments-view.md) | 1 | **Review** |
| ref-frontend-02 | [Helpers de attrs y clases](./ref-frontend-02.attrs-helpers.md) | 1 | **Review** |
| ref-frontend-03 | [Consolidar UI reusable](./ref-frontend-03.ui-reuse.md) | 1 | **Review** |
| ref-frontend-04 | [Msg wrappers por feature](./ref-frontend-04.msg-wrappers.md) | 2 | **Review** |
| ref-frontend-05 | [Sub-modelos por pagina](./ref-frontend-05.submodels.md) | 2 | **Ready** |
| ref-frontend-06 | [Decoders centralizados de eventos](./ref-frontend-06.event-decoders.md) | 3 | **Ready** |
| ref-frontend-07 | [Helpers de efectos comunes](./ref-frontend-07.effects-helpers.md) | 3 | **Ready** |
| ref-frontend-08 | [DOM measurements con after_paint](./ref-frontend-08.after-paint.md) | 3 | **Ready** |

## Dependency Graph

```
Phase 1 (view reuse)
  ref-frontend-01 (fragments)
  ref-frontend-02 (attrs helpers)  ──┐  (parallel)
  ref-frontend-03 (ui reuse)      ───┘

Phase 2 (mvu structure)
  ref-frontend-04 (msg wrappers) -> ref-frontend-05 (sub-models)

Phase 3 (events + effects)
  ref-frontend-06 (event decoders)
  ref-frontend-07 (effects helpers) ──┐ (parallel)
  ref-frontend-08 (after_paint)    ───┘ (after ref-frontend-06)
```

## Preconditions

- Confirmar flows criticos de UI (login, pool, admin, tasks).
- Tener baseline de tests cliente: `cd apps/client && gleam test`.

## Changelog

| Date | Description |
|------|-------------|
| 2026-01-25 | Created ref-frontend epic and 8 ready stories |
