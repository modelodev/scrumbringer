# HT-12 UI Validation

Validated on `new_hierarchy` after commit `6ca616c` using
`scripts/dev-hot.sh` with:

- App: `http://127.0.0.1:19191`
- API: `http://127.0.0.1:18191/api/v1`
- Client dev server: `http://127.0.0.1:1234`

Browser checks used `agent-browser` against the running dev stack.

## Desktop

- Viewport: `1440x1000`
- Flow: opened the app, expanded navigation, switched into the work-card
  hierarchy view, and captured `/tmp/scrumbringer-ht12-desktop.png`.
- Result: authenticated shell rendered without blank states or runtime errors.
  Navigation showed Pool, Tarjetas, Cards, Initiatives, Task groups,
  Capacidades, Personas, and admin sections. Kanban content rendered with card
  columns, due-date markers, card actions, task rows, and claim actions.

## Tablet

- Viewport: `900x1100`
- Flow: kept the hierarchy/Kanban view active and captured
  `/tmp/scrumbringer-ht12-tablet.png`.
- Result: navigation, filters, Kanban heading, Draft/En curso/Closed columns,
  card actions, task rows, and claim actions remained visible and usable.

## Mobile

- Viewport: `390x844`
- Flow: captured `/tmp/scrumbringer-ht12-mobile.png`, opened an overdue task
  detail, and captured `/tmp/scrumbringer-ht12-mobile-task.png`.
- Result: filters, cards, due date, and task row were readable. The task detail
  modal opened with Detalles/Notas/Métricas tabs, readable summary content, and
  fixed bottom actions for Cerrar and Reclamar tarea.

## Legacy Copy Check

The final browser snapshots and accessibility snapshots did not expose removed
hierarchy terminology. Repository scans also returned no matches for removed
hierarchy, legacy delivery/state, or old task-event terms outside the historical
goal spec.
