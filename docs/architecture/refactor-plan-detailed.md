# Plan detallado de refactorizacion (Gleam + Lustre)

Fecha: 2026-02-05
Repo: scrumbringer
Alcance principal: apps/client/src/scrumbringer_client

## Objetivos

- Modularizar MVU por feature.
- Reducir "god modules" (client_state/update/view/update_helpers).
- Unificar routing y URL state.
- Reutilizar flujos TEA de tokens.
- Modularizar CSS sin cambiar API publica.
- Normalizar decoders en domain/*/codec.

## Guardrails (Fase 0)

Baseline obligatorio por fase:
- `make test`
- `make format`

Smoke manual minimo (post-fase):
- Login con usuario valido.
- Ir a Pool.
- Ver sidebar derecho con info si hay tareas claimed.
- Hacer claim y confirmar actualizacion del sidebar derecho.

## Fase 1 - Modularizacion MVU por feature

Pre-fase (TDD):
- Identificar el comportamiento observable del feature a migrar.
- Crear/actualizar tests a nivel de update (pure) y, si aplica, view (smoke/DOM) antes de mover codigo.
- Definir tipos y firmas nuevas primero (type-driven).

Decision: Msg global como wrapper por feature (opcion A). Migracion por dependencias.

Orden logico por dependencias:
1) auth
2) i18n
3) layout
4) pool
5) tasks
6) now_working
7) projects
8) assignments
9) invites
10) capabilities / task_types / workflows / cards
11) metrics
12) skills / fichas / my_bar

Estrategia por feature:
- Crear modulos por feature:
  - features/<feature>/state.gleam
  - features/<feature>/msg.gleam
  - features/<feature>/update.gleam
  - features/<feature>/view.gleam
- client_state.gleam solo orquesta Model root y wrappers:
  - AuthMsg(auth.Msg), PoolMsg(pool.Msg), etc
- client_update.gleam solo rutea:
  - AuthMsg(inner) -> features/auth/update.update(...)
- client_view.gleam ensambla y delega views por feature.
- client_update_dispatch.gleam se elimina en Fase 4.

Done:
- Cada feature tiene sus 4 modulos.
- client_state/update/view quedan como routers/ensambladores.

## Fase 2 - Reducir update_helpers.gleam

Pre-fase (TDD):
- Crear tests unitarios por helper movido (funciones puras).
- Para helpers con effects (toast/auth), crear tests de wiring en update.
- Actualizar `docs/architecture/helpers-catalog.md` con los helpers movidos.

Decision: crear `scrumbringer_client/helpers/` y mantener update_helpers como facade temporal.
Inventario de helpers en `docs/architecture/helpers-catalog.md` (debe actualizarse en esta fase).

Modulos sugeridos:
- helpers/dicts.gleam
- helpers/options.gleam
- helpers/lookup.gleam
- helpers/time.gleam
- helpers/validation.gleam
- helpers/selection.gleam
- helpers/toast.gleam
- helpers/i18n.gleam
- helpers/auth.gleam

Estrategia:
- Mover funciones a helpers.
- Re-exports en update_helpers (temporal).
- Migrar imports por lotes (i18n -> time/validation -> lookup/selection).
- Al final eliminar update_helpers.

## Fase 3 - Refactor client_state.gleam

Pre-fase (TDD):
- Tests de invariantes del Model (ADT/opaque) para evitar estados invalidos.
- Tests de accessors (si se exponen) para asegurar compatibilidad.
- Definir tipos nuevos antes de mover campos.

Decision: submodelos nested por feature. Sin areas excluidas.

Acciones:
- Mover AuthModel/UiModel a client_state/auth.gleam y client_state/ui.gleam.
- Dividir AdminModel:
  - admin/{projects,invites,capabilities,members,metrics,workflows,rules,task_templates,task_types,cards,assignments}.gleam
- Dividir MemberModel:
  - member/{pool,now_working,skills,metrics,notes,dependencies,positions}.gleam
- Consolidar flags de dialogo en ADTs (DialogClosed | Create | Edit | Delete).
- Mantener accessors/re-exports temporales para minimizar churn.

## Fase 4 - client_update.gleam (dispatcher)

Pre-fase (TDD):
- Tests para cada Msg wrapper: delega al feature correcto.
- Tests para hydration (si se extrae) con snapshots y comandos esperados.
- Estabilizar firmas antes de mover handlers.

Decision: extraer hydration a features/hydration/update.gleam y eliminar client_update_dispatch.gleam.

Acciones:
- client_update.gleam queda con routing global + delegacion a features.
- Logica de admin/pool/assignments migra a features/*/update.
- client_update_dispatch.gleam se elimina.

## Fase 5 - Unificar routing + URL state

Pre-fase (TDD):
- Tests de parse/format para rutas criticas (Login, Member, Config/Org).
- Tests de round-trip: parse -> format -> parse.
- Tests para query invalidas (redirigir o normalizar).

Decision:
- router.Route.Member usa UrlState completo.
- url_state es la fuente unica de parse/format de query (incluye admin params).
- url_state se modulariza internamente.

Acciones:
- router.gleam solo parsea path y delega query a url_state.
- url_state agrega admin params (ej: assignments_view_mode).
- router.format usa url_state.to_query_string.
- Ajustar client_update.gleam y hydration.gleam.

## Fase 6 - Unificar flujo TEA de tokens

Pre-fase (TDD):
- Tests unitarios del flujo generico (token_flow) para estados y transiciones.
- Tests especificos de errores (INVITE_* / RESET_*).
- Validar que los wrappers mantienen la API previa.

Decision: Escenario 1 (re-export + Submitting generico).

Acciones:
- Crear token_flow.gleam con State/Model/Msg genericos.
- accept_invite.gleam y reset_password.gleam re-exportan tipos.
- Acciones especificas quedan en wrappers (Register vs Consume, Authed vs GoToLogin).

## Fase 7 - Modularizar CSS

Pre-fase (TDD):
- No hay tests automatizables directos para CSS.
- Ejecutar smoke manual tras el reordenamiento.
- Mantener el orden de precedencia y registrar cambios en el comentario de orden.

Decision:
- Agrupar CSS por funcionalidad (no por Story).
- Agregar comentario de orden en styles.gleam.

Acciones:
- Crear styles/* (base, layout, pool, forms, tables, modals, admin, etc).
- Mantener API base_css() en styles.gleam.
- Conservar orden de precedencia.

## Fase 8 - Normalizar decoders

Pre-fase (TDD):
- Tests de decoders con fixtures JSON reales (si existen).
- Tests de fallos para valores invalidos.
- Definir tipos y firmas en domain/*/codec antes de migrar.

Decision:
- Naming: domain/<entity>/codec.gleam
- Mover api/tasks/decoders.gleam a domain/task/codec.gleam

Acciones:
- Mover decoders locales de api/* a domain/*/codec.
- api/* importa codecs de domain.
- scrumbringer_client/decoders.gleam queda como facade temporal.

## Notas

- Cada fase debe pasar `make test` + `make format` y smoke manual.
- Se recomienda convertir fases en stories si se ejecuta incrementalmente.

## Notas Lustre (framework)

- Mantener `view` puro: no FFI ni side effects, solo render y eventos.
- Effects siempre en `update` con `Effect`, no en views.
- Hydration extraida debe permanecer determinista y sin APIs de navegador.
- Routing debe limitarse a parse/format y navegación, no lógica de modelo.
- `ui/event_decoders` separado de decoders JSON.
