# Bottom-Up Data Model Refactor Plan

## Estado

Plan actualizado tras revisar el estado actual de la base de codigo y
`db/schema.sql`.

Fecha de revision: 2026-06-21.

Este documento sustituye el diagnostico inicial anterior. El modelo ya ha
avanzado: varias piezas que antes eran objetivo de refactor ya existen en el
schema final. El foco ahora debe moverse de "introducir jerarquia" a "cerrar el
modelo final, eliminar compatibilidad transitoria y reforzar integridad".

## Principio Rector

La refactorizacion debe hacerse de abajo arriba:

```text
DB schema
-> SQL queries
-> server use cases
-> shared domain/types/codecs
-> API contracts
-> client state/update
-> client views
-> seeds/tests/docs
```

No se debe mantener una capa legacy temporal si el producto ya decidio adoptar
el modelo nuevo. Cuando algo quede obsoleto, se elimina o se reescribe.

## Schema Objetivo Final

El schema canonico final queda definido asi antes de migrar:

- `tasks.execution_state` es el unico estado persistido de task, junto con
  `claimed_mode`, `closed_reason`, `claimed_*` y `closed_*` como detalles de
  ciclo de vida. No existe columna persistida `tasks.status`, ni
  `tasks_status_check`, ni indices basados en esa columna.
- La API puede seguir exponiendo un campo `status` solo como valor derivado para
  contratos externos, nunca como almacenamiento ni como fuente de verdad.
- Las FKs compuestas de pertenencia a proyecto (`cards(project_id,
  parent_card_id)` y `tasks(project_id, card_id)`) quedan validadas; `NOT VALID`
  no es un estado final aceptable.
- `cards` es un arbol aciclico. Una card no puede apuntarse a si misma ni moverse
  bajo un descendiente.
- `task_dependencies` es un grafo dirigido aciclico dentro de un mismo proyecto.
  No se permiten autociclos, ciclos transitivos ni dependencias entre proyectos.
- La integridad cross-project se defiende en DB para task type, capability,
  task template, rules, audit targets y API tokens. Los checks de aplicacion son
  UX/errores legibles, no la unica barrera de integridad.
- `audit_events` usa una taxonomia canonica:
  `task_created`, `task_claimed`, `task_released`, `task_closed`,
  `card_activated`, `card_closed`, `card_moved`,
  `task_dependency_added`, `task_dependency_removed`. Cada evento exige
  exactamente un target coherente (`task_id` o `card_id`) y el target debe
  pertenecer al `project_id`/`org_id` del evento.
- `rule_executions` deja de usar `origin_type`/`origin_id`; el origen se modela
  con `task_id` o `card_id` explicitos, exactamente uno no nulo y con FK real.
- `project_settings.version` es version de escritura real: se incrementa en DB
  en cada `UPDATE`.

## Estado Actual Confirmado

### Ya Esta Resuelto O Parcialmente Resuelto

El schema actual ya incluye:

- `cards.parent_card_id`.
- `cards.execution_state` con `draft | active | closed`.
- `cards.due_date`.
- `tasks.execution_state` con `available | claimed | closed`.
- `tasks.claimed_mode`.
- `tasks.closed_reason`.
- `tasks.due_date`.
- `tasks.capability_id`.
- `project_settings`.
- `project_settings.healthy_pool_limit`.
- `project_card_depth_names`.
- `project_card_depth_names.depth > 0`.
- `cards_project_id_id_unique`.
- FK compuesta `cards(project_id, parent_card_id) -> cards(project_id, id)`,
  aunque aun aparece `NOT VALID`.
- FK compuesta `tasks(project_id, card_id) -> cards(project_id, id)`, aunque
  aun aparece `NOT VALID`.
- trigger para impedir que una card contenga a la vez child cards y tasks.
- `audit_events` como tabla viva.
- La antigua entidad de hito ya no aparece en `db/schema.sql`.
- No se han encontrado referencias vivas a la antigua entidad de hito en `shared/src`,
  `apps/client/src` o `apps/server/src` excluyendo artefactos generados.

Por tanto, el plan ya no debe centrarse en crear estas piezas, sino en cerrar
las aristas que han quedado abiertas.

## Problemas Restantes

### 1. `tasks.status` Sigue En El Schema

`tasks.status` sigue existiendo junto a `tasks.execution_state`.

Esto contradice el modelo final:

- `execution_state` ya es el estado canonico.
- muchas queries ya devuelven `status` derivado desde `execution_state`;
- siguen existiendo indices `idx_tasks_status` y `idx_tasks_card_status`;
- hay una migracion de reparacion que re-sincroniza `status` desde
  `execution_state`.

Diagnostico:

`tasks.status` es compatibilidad transitoria. Debe desaparecer del schema final.

Trabajo:

- eliminar columna `tasks.status`;
- eliminar `tasks_status_check`;
- eliminar `idx_tasks_status`;
- eliminar `idx_tasks_card_status`;
- eliminar cualquier escritura sobre `tasks.status`;
- mantener, solo si la API lo necesita temporalmente, un campo de respuesta
  derivado desde `execution_state`, no persistido;
- revisar `shared/src/domain/task.gleam`, porque aun conserva `status` y
  `work_state` como campos materiales junto a `state`.

Resultado esperado:

```text
DB canonico: tasks.execution_state + claimed_mode + closed_reason
API/UI: labels o filtros derivados, no columna persistida
```

### 2. Hay Dos Modelos De Task En Shared

Existen dos familias de tipos:

```text
shared/src/domain/task.gleam
shared/src/domain/task_state.gleam
shared/src/domain/task_status.gleam
```

y:

```text
shared/src/domain/task/entity.gleam
shared/src/domain/task/state.gleam
shared/src/domain/task/state_codec.gleam
shared/src/domain/task/placement.gleam
```

El segundo grupo representa mejor el modelo nuevo de task leaf claimable.
El primero aun carga conceptos de UI/API antiguos (`status`, `work_state`,
`TaskPhase`).

Trabajo:

- decidir el tipo canonico compartido para task leaf;
- usar `domain/task/entity.gleam` y `domain/task/state.gleam` como centro del
  modelo;
- mover los conceptos de vista (`TaskPhase`, `WorkState`, labels derivados) a
  una capa de presentacion o compatibilidad de API si siguen siendo necesarios;
- evitar que un `Task` materialice simultaneamente `state`, `status` y
  `work_state`;
- hacer que codecs decodifiquen `execution_state` canonico y deriven labels
  solo donde se necesite.

### 3. FKs Compuestas `NOT VALID`

El schema final aun contiene:

```sql
cards_parent_card_fk ... NOT VALID
tasks_project_card_fk ... NOT VALID
```

Esto es razonable en una migracion de reparacion, pero no como estado final.

Trabajo:

- limpiar datos invalidos si existieran;
- validar constraints;
- dejar el schema final sin `NOT VALID`;
- anadir tests de integridad cross-project para card parent y task card.

### 4. Falta Proteccion Contra Ciclos

El schema impide mezclar child cards y tasks, pero no impide ciclos en:

- arbol de cards;
- dependencias entre tasks.

Trabajo:

- crear trigger/funcion para impedir que una card sea movida bajo si misma o
  bajo un descendiente;
- crear trigger/funcion para impedir ciclos en `task_dependencies`;
- cubrir ambos casos con tests SQL/integracion.

Ejemplos ilegales:

```text
card A -> card B -> card A
task A depends_on task B, task B depends_on task A
```

### 5. Integridad Cross-Project Incompleta

El schema tiene algunas FKs por `id` simple donde el dominio requiere pertenencia
al mismo proyecto.

Casos a revisar/endurecer:

- `tasks.type_id -> task_types(id)` debe asegurar mismo `project_id`.
- `tasks.capability_id -> capabilities(id)` debe asegurar mismo `project_id`.
- `task_types.capability_id -> capabilities(id)` debe asegurar mismo
  `project_id`.
- `task_templates.type_id -> task_types(id)` debe asegurar mismo `project_id`.
- `rules.task_type_id -> task_types(id)` debe asegurar compatibilidad con el
  workflow/project.
- `audit_events.task_id/card_id` deben pertenecer al `project_id` del evento.
- `api_tokens.project_id` debe pertenecer al `org_id` del token.
- `api_tokens.integration_user_id` y `created_by` deben pertenecer al `org_id`.

Preferencia:

- FKs compuestas cuando el schema lo permita con claves unicas auxiliares;
- triggers claros cuando la relacion dependa de varias tablas.

Evitar:

- checks en aplicacion como unica defensa.

### 6. `audit_events` Aun Tiene Taxonomia Ambigua

`audit_events.event_type` admite actualmente:

```text
task_created
task_claimed
task_released
task_completed
task_done
card_activated
card_closed
```

Problemas:

- `task_completed` y `task_done` duplican intencion.
- El modelo nuevo habla de `Closed(reason: Done | ManuallyClosed | ...)`.
- `task_id` y `card_id` son opcionales y no hay constraint fuerte que exija el
  target correcto por `event_type`.

Trabajo:

- definir taxonomia canonica de eventos;
- preferir `task_closed` con `closed_reason` en payload o columna derivada antes
  que duplicar `task_completed`/`task_done`;
- exigir exactamente el target correcto:
  - eventos de task requieren `task_id`;
  - eventos de card requieren `card_id`;
  - eventos mixtos solo si estan explicitamente modelados;
- validar que `project_id`/`org_id` coinciden con el target;
- actualizar metricas para leer `audit_events` canonicos.

Taxonomia inicial recomendada:

```text
task_created
task_claimed
task_released
task_closed
card_activated
card_closed
card_moved
task_dependency_added
task_dependency_removed
```

### 7. `rule_executions` Sigue Con Target Polimorfico Debil

`rule_executions` usa:

```text
origin_type
origin_id
```

Aunque hay check de `origin_type`, no hay FK real al recurso de origen.

Opciones:

1. Reemplazar por columnas explicitas:

```text
task_id nullable
card_id nullable
CHECK exactly one non-null
```

2. Asociar ejecuciones a `audit_events` si la ejecucion siempre nace de un
evento auditable.

Recomendacion:

Usar columnas explicitas `task_id`/`card_id` para simplicidad inmediata. Evaluar
`audit_event_id` solo si aporta una traza real de ejecucion de workflows.

### 8. `project_settings.version` No Esta Garantizado Como Version De Escritura

`project_settings.version` existe con default `1`, pero el schema no muestra
autoincremento automatico en update.

Trabajo:

- decidir si `version` protege concurrencia optimista;
- si si, crear trigger `version = version + 1` en updates reales;
- si no, eliminar `version` para no sugerir una garantia falsa.

Recomendacion:

Mantenerlo y hacerlo automatico, porque ya se eligio una direccion de settings
versionadas.

### 9. Documentacion De Modelo Desactualizada

`docs/architecture/data-model.md` no refleja el modelo actual:

- sigue presentando `Task.status` como columna base;
- no describe correctamente cards jerarquicas;
- no incorpora `project_settings`;
- no incorpora `project_card_depth_names`;
- no incorpora due dates actuales;
- no describe `audit_events` como modelo vivo.

Trabajo:

- actualizar `docs/architecture/data-model.md` al final de la refactorizacion;
- enlazar este plan desde el indice si se mantiene como plan activo;
- eliminar referencias conceptuales obsoletas a la antigua entidad de hito como
  entidad viva.

### 10. Artefactos Generados Pueden Confundir Auditorias

Se detectan referencias legacy a la antigua entidad de hito en
`apps/client/build/**`.

No son fuente, pero ensucian busquedas amplias y auditorias.

Trabajo:

- no usar `build/` como fuente de verdad;
- limpiar artefactos generados si el flujo del repo lo permite;
- ajustar scripts de auditoria para excluir `build/`;
- asegurar que `rg` de validacion final excluye build o lo regenera limpio.

## Orden De Refactorizacion

### Fase 1. Tests Rojos De Integridad

Antes de tocar schema:

- test que demuestre que `tasks.status` ya no debe existir;
- test de card cycle rechazado;
- test de task dependency cycle rechazado;
- test de card parent cross-project rechazado y constraint validada;
- test de task card cross-project rechazado y constraint validada;
- test de task type/capability cross-project rechazado;
- test de audit event sin target correcto rechazado;
- test de rule execution con origin inexistente rechazado;
- test de `project_settings.version` autoincrementado.

### Fase 2. Schema DB

Crear migraciones para:

- eliminar `tasks.status` e indices asociados;
- validar FKs `cards_parent_card_fk` y `tasks_project_card_fk`;
- introducir triggers anti-ciclo;
- endurecer integridad cross-project;
- redisenar `audit_events` target/taxonomia;
- redisenar `rule_executions` target;
- autoincrementar `project_settings.version`.

Regenerar `db/schema.sql`.

### Fase 3. SQL Queries

Actualizar `apps/server/src/scrumbringer_server/sql/*.sql`:

- ninguna query escribe `tasks.status`;
- ninguna query lee `tasks.status`;
- los campos de respuesta tipo `status` se derivan de `execution_state` solo si
  siguen formando parte del contrato externo;
- filtros de API usan `execution_state`/`claimed_mode` internamente;
- dependencies y blockers usan `execution_state != 'closed'`.

Regenerar `apps/server/src/scrumbringer_server/sql.gleam`.

### Fase 4. Shared Domain Y Codecs

Unificar modelos:

- `domain/task/entity.gleam` y `domain/task/state.gleam` como nucleo;
- eliminar duplicacion material entre `state`, `status` y `work_state`;
- mantener helpers de presentacion si la UI los necesita;
- revisar `task_codec.gleam` para decodificar estado canonico;
- revisar `api/tasks/contracts.gleam`.

### Fase 5. Server Use Cases

Actualizar:

- lifecycle de tasks;
- lifecycle de cards;
- workflows/rules;
- metrics;
- dependencies;
- project settings;
- audit logging.

Todo cambio de estado debe persistir estado canonico y audit event canonico en
una transaccion coherente.

### Fase 6. Client

Actualizar:

- filtros de Pool;
- cards detail;
- Plan/Kanban;
- Capacidades;
- Personas, si ya esta implementada;
- task item/status labels.

La UI puede mostrar "Disponible", "Reclamada", "En curso" o "Cerrada", pero
esas etiquetas deben derivarse del ADT canonico, no de una segunda columna.

### Fase 7. Seeds

Actualizar seeds para cubrir:

- cards sin padre;
- cards con subcards;
- cards con tasks;
- tasks sin card que van siempre al pool;
- due dates futuras y vencidas;
- bloqueos por dependencia;
- closed por `done`, `manually_closed`, `closed_by_ancestor`;
- pool saludable y pool saturado respecto a `healthy_pool_limit`;
- audit events representativos;
- workflow executions con targets validos.

### Fase 8. Documentacion Y Limpieza

- actualizar `docs/architecture/data-model.md`;
- actualizar diagramas o tablas afectadas;
- borrar helpers legacy;
- borrar tests que validen compatibilidad antigua;
- limpiar generated build si procede;
- revisar busquedas de la antigua entidad de hito, `tasks.status` y
  `task_events`, excluyendo migraciones
  historicas y docs de archivo.

## Criterios De Aceptacion

- `db/schema.sql` no contiene columna `tasks.status`.
- `db/schema.sql` no contiene indices `idx_tasks_status` ni
  `idx_tasks_card_status`.
- `db/schema.sql` no contiene FKs `NOT VALID` como estado final.
- No se puede crear ciclo de cards.
- No se puede crear ciclo de dependencias de tasks.
- No se puede asociar una task a card, task type o capability de otro proyecto.
- No se puede crear audit event con target incoherente.
- No se puede crear rule execution con origin inexistente.
- `project_settings.version` se actualiza automaticamente o se elimina.
- No quedan referencias vivas a la antigua entidad de hito fuera de
  migraciones historicas,
  documentacion de archivo o artefactos generados.
- La API y el cliente usan estado canonico y derivan labels de presentacion.
- `docs/architecture/data-model.md` describe el modelo actual.
- Tests de DB, shared, server y client pasan.

## Riesgos

- La eliminacion de `tasks.status` toca API, frontend y tests.
- La unificacion de tipos de task en `shared` puede provocar un cambio amplio.
- Los triggers anti-ciclo deben ser correctos y no degradar operaciones normales
  de move/dependency.
- La taxonomia de `audit_events` puede afectar metricas y workflows.

Mitigacion:

- avanzar con tests rojos por fase;
- mantener migraciones pequenas y verificables;
- regenerar schema y SQL bindings en cada paso;
- ejecutar validacion completa antes de tocar vistas;
- despues validar visualmente las vistas principales con agent-browser.
