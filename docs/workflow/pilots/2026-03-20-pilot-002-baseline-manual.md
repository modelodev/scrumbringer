# Pilot 002 — Baseline Manual

## Change request
Editar título + descripción de una task desde el modal de detalle, con guardar/cancelar, validación visible y teclado razonable.

## Outcome
- status: implemented_then_reverted_for_awo_rerun
- build: client green
- tests: `apps/client` green (`gleam build`, `gleam test`)
- UX issue found: la UI quedó funcional pero no comunicaba bien que la tarea se pudiera editar

## Key observations
- el cambio técnico era viable y la infraestructura existente bastaba
- el resultado necesitó revisión posterior de discoverability
- esto se considera fallo del workflow/checkpoints, no prueba de valor de AWO todavía

## Files touched during baseline
- apps/client/src/scrumbringer_client/api/tasks.gleam
- apps/client/src/scrumbringer_client/api/tasks/operations.gleam
- apps/client/src/scrumbringer_client/client_state/member/pool.gleam
- apps/client/src/scrumbringer_client/features/pool/dialogs.gleam
- apps/client/src/scrumbringer_client/features/pool/msg.gleam
- apps/client/src/scrumbringer_client/features/pool/update.gleam
- apps/client/src/scrumbringer_client/features/tasks/update.gleam
- apps/client/src/scrumbringer_client/i18n/en.gleam
- apps/client/src/scrumbringer_client/i18n/es.gleam
- apps/client/src/scrumbringer_client/i18n/text.gleam
- apps/client/test/task_detail_edit_test.gleam

## Decision
Revert baseline implementation and rerun the same change after modifying the workflow structurally.
