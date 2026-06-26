# Task Claim Active Card Invariant Plan

Fecha: 2026-06-26
Baseline operativo: `HEAD` anterior al inicio de este plan (`2d3c6b9b` en el
momento de registrar el documento).

## Objetivo

Propagar de abajo arriba esta regla de producto:

> Una task solo puede estar reclamada si pertenece a una card activa y ninguna
> card ancestro esta cerrada.

El plan no se considera completo si solo se bloquea un boton o se corrige un
endpoint. La regla debe quedar garantizada en PostgreSQL, expresada en tipos y
casos de uso del backend, distinguida en HTTP, reflejada en contratos
compartidos y limpiada en UI, seeds, fixtures y tests.

## Decisiones De Modelo

- `blocked` sigue siendo derivado, no estado persistido.
- Una task bloqueada no puede reclamarse.
- Una task ya reclamada puede volverse bloqueada si una dependencia se anade
  despues; sigue reclamada por la misma persona.
- Mientras una task reclamada este bloqueada, no se puede cerrar/completar.
- Una task reclamada y bloqueada si se puede liberar.
- Al cerrar o eliminar dependencias, la task queda desbloqueada de forma
  derivada y continua su flujo normal.
- Una task reclamada fuera de una card activa no es un estado que la UI deba
  explicar: es un estado invalido que se previene o se limpia.
- No se conserva compatibilidad legacy para root-pool claimed tasks ni para
  trabajo reclamado bajo cards draft/closed.

## Alcance Por Capa

### 1. Base De Datos

- Anadir una migracion posterior al modelo final.
- Normalizar datos invalidos antes de activar restricciones.
- Introducir una funcion SQL canonica, por ejemplo
  `task_card_claimable(card_id)`, que valide:
  - card existente;
  - card activa;
  - ningun ancestro cerrado.
- Rechazar por trigger cualquier `tasks.execution_state = 'claimed'`:
  - sin `card_id`;
  - sin campos de claim completos;
  - con `claimed_mode` invalido;
  - bajo card no claimable.
- Rechazar por trigger cambios de `cards.execution_state` o
  `cards.parent_card_id` que dejen claimed tasks bajo una linea no claimable.
- Mantener la query atomica de claim como camino normal; el trigger es defensa
  de integridad, no sustituto del comando.

### 2. SQL Y Repositorio

- Eliminar ramas de claim que permitan `tasks.card_id is null`.
- Exigir `card_id` valido en creacion operativa de tasks.
- Eliminar ramas de Pool activo para tasks sin card.
- Regenerar bindings SQL despues de tocar `.sql`.
- Cambiar el repositorio para que `claim_task` acepte un valor tipado
  `ClaimableTask`, no un `task_id` crudo.
- Mantener update de task, work session y audit event en la misma transaccion.
- Garantizar que un claim fallido no escribe audit event ni abre work session.

### 3. Use Cases Y Tipos

- Introducir una frontera opaca `ClaimableTask`.
- Construir `ClaimableTask` solo tras validar estado, dependencias y card
  lineage.
- Anadir un error especifico, por ejemplo `TaskCardNotActive`.
- No colapsar estos casos en un unico error:
  - ya reclamada;
  - bloqueada por dependencias;
  - card/ancestro no activo;
  - version stale;
  - task sin card.
- Evitar helpers que vuelvan a aceptar ids crudos en el flujo normal de claim.

### 4. HTTP

- Exponer un codigo claro para card-lineage invalida, por ejemplo
  `TASK_CARD_NOT_ACTIVE`.
- Preservar los codigos existentes para:
  - `CONFLICT_CLAIMED`;
  - `CONFLICT_BLOCKED`;
  - `CONFLICT_VERSION`.
- Si la actualizacion atomica no modifica filas, re-chequear el motivo para no
  devolver version conflict cuando el problema real es la card.
- Los rechazos no deben modificar version, claim fields, work sessions ni audit
  events.

### 5. Shared Contracts

- Eliminar `outside_active_work_scope` de `PersonWorkloadTask`.
- Eliminar su encoder, decoder y payload JSON.
- Eliminar cualquier contrato que trate claimed work fuera de active cards como
  estado esperado.
- Mantener tests de `TaskExecutionState` para combinaciones invalidas de campos
  `claimed_*` y `closed_*`.
- No intentar modelar claimability de card dentro del read model compartido; la
  regla vive en comandos de backend y BBDD.

### 6. Frontend

- Eliminar copy, badges, CSS y ramas de vista para "fuera del trabajo activo".
- Eliminar la key i18n `PeopleOutsideActiveWorkScope`.
- Mostrar contexto util de card en People sin explicar estados imposibles.
- Mantener CTAs diferenciados cuando existan ids validos:
  - `Abrir tarea`;
  - `Abrir tarjeta`.
- Mapear `TASK_CARD_NOT_ACTIVE` a feedback de usuario claro y refrescar datos si
  aplica.
- Evitar crear tareas desde UI sin card seleccionada; si el dialogo no tiene
  card, debe bloquear submit y pedir elegir una card.

### 7. Rules, Automations Y Eventos

- Una automatizacion no debe crear tasks en una card que acaba cerrada o que ya
  no acepta trabajo.
- Si una regla se dispara sobre un objetivo no apto para crear tasks, registrar
  una supresion explicita, no una task invalida.
- El motivo de supresion debe ser estable en dominio y persistencia, por
  ejemplo `target_no_longer_accepts_tasks`.
- El motor no debe reintroducir caminos de creacion root-pool o closed-card.

### 8. Seeds Y Fixtures

- Eliminar helpers que creen claimed tasks sin card.
- Reescribir seeds para que todo trabajo operativo viva bajo cards activas.
- Mantener cards draft/closed solo si no contienen claimed tasks invalidas.
- Ajustar fixtures publicos para crear card, activarla y crear la task debajo.
- No conservar helpers de compatibilidad para root-pool claimed tasks.

### 9. Limpieza

- Borrar tests cuyo unico proposito sea preservar payloads, copy o datos legacy.
- Borrar ramas SQL y Gleam de claim con `card_id is null`.
- Borrar copy/i18n/CSS de estados imposibles.
- Borrar helpers de seed/fixture que generen no-card operational work.
- Borrar o actualizar documentos que propongan `outside_active_work_scope` como
  solucion vigente.
- Revisar actividad, People, Pool y create dialogs para que no expliquen ni
  permitan root-pool tasks como flujo operativo.

## Matriz De Tests Obligatoria

### BBDD

- Direct SQL permite claim solo en task con card activa.
- Direct SQL rechaza claim sin card.
- Direct SQL rechaza claim bajo card draft.
- Direct SQL rechaza claim bajo card closed.
- Direct SQL rechaza claim si un ancestro esta closed.
- Direct SQL rechaza campos de claim incompletos.
- Cerrar una card con descendants reclamadas falla.
- Mover una card con descendants reclamadas bajo ancestro closed falla.
- La migracion limpia o normaliza claimed tasks invalidas antes de activar
  triggers.

### Repositorio

- Claim exitoso cambia estado, abre/actualiza work session y escribe
  exactamente un audit event.
- Claim fallido por card no activa no escribe audit event.
- Claim fallido por dependencias no escribe audit event.
- Claim fallido por version stale no escribe audit event.
- El repositorio no expone un camino normal `claim_task(task_id, ...)` sin
  `ClaimableTask`.

### Use Case / Tipos

- `ClaimableTask` se construye para task disponible, no bloqueada, con card
  activa y ancestros no cerrados.
- Falla para task sin card.
- Falla para card draft.
- Falla para card closed.
- Falla para ancestro closed.
- Falla para task bloqueada.
- Falla para task ya reclamada.

### HTTP

- `POST /api/v1/tasks/:id/claim` funciona con card activa.
- Rechaza no-card task con `TASK_CARD_NOT_ACTIVE` o error equivalente final.
- Rechaza draft card con `TASK_CARD_NOT_ACTIVE`.
- Rechaza closed card con `TASK_CARD_NOT_ACTIVE`.
- Rechaza ancestro closed con `TASK_CARD_NOT_ACTIVE`.
- Rechaza dependencias abiertas como blocked/conflict, no como card error.
- Rechaza version stale como version conflict, no como card error.
- Ningun rechazo modifica version, claim fields, sessions ni audit events.

### Shared

- Encoder de People workload no emite `outside_active_work_scope`.
- Decoder de People workload no requiere `outside_active_work_scope`.
- El tipo publico no expone el campo obsolete.
- `TaskExecutionState` sigue rechazando combinaciones invalidas de campos
  claimed/closed.
- El nuevo motivo de supresion de automatizaciones parsea y serializa de forma
  estable si se introduce.

### Frontend

- People no renderiza "fuera del trabajo activo".
- Personas con trabajo reclamado valido aparecen en la seccion correcta.
- Trabajo actual y trabajo reservado mantienen `Abrir tarea`.
- Cuando hay `card_id` valido, la UI mantiene `Abrir tarjeta`.
- El mapper de errores muestra feedback para `TASK_CARD_NOT_ACTIVE`.
- El dialogo de crear task no permite submit sin card operativa.
- No queda key i18n `TaskCreateRootPoolHint` si el modelo final exige card.

### Seeds, Fixtures Y Guards

- Seeds no generan claimed tasks sin card.
- Seeds no generan claimed tasks bajo cards draft/closed.
- Fixtures publicos crean tasks operativas bajo card activa.
- Tests no dependen de root-pool claimed tasks.
- Guardas con `rg` no encuentran copy/campos obsolete fuera de docs
  historicos marcados como superados.

## Comandos De Validacion

Ejecutar durante el cierre:

```sh
pg_isready -p 5433
make migrate
make squirrel
```

```sh
cd shared && gleam format --check src test && gleam build && gleam test
cd apps/server && gleam format --check src test && gleam build && gleam test
cd apps/client && gleam format --check src test && gleam build && gleam test
cd apps/client && gleam test --target javascript
git diff --check
```

Guardas de limpieza:

```sh
rg "outside_active_work_scope|PeopleOutsideActiveWorkScope" apps shared --glob '!build/**'
rg "TaskCreateRootPoolHint|Root Pool task|Pool raiz|root-pool|root pool" apps shared --glob '!build/**'
rg "tasks\\.card_id is null|task\\.card_id is null|t\\.card_id is null" apps db --glob '!build/**'
```

Los resultados positivos deben clasificarse:

- `parent_card_id is null` es valido para root cards.
- `card_id is null` en migraciones de limpieza puede ser valido si normaliza
  datos legacy antes de bloquearlos.
- `card_id is null` en caminos operativos de claim/create/list no es valido.

## Orden De Ejecucion

1. Registrar baseline y estado de diff.
2. Implementar migracion y tests de BBDD.
3. Cambiar SQL de claim/create/list y regenerar bindings.
4. Introducir `ClaimableTask` y errores especificos.
5. Ajustar repositorio, use cases y HTTP.
6. Ajustar shared contracts.
7. Ajustar frontend People, task mutation errors y create dialog.
8. Ajustar rules/automations para no crear tasks en objetivos cerrados.
9. Reescribir seeds y fixtures.
10. Borrar tests legacy y helpers obsolete.
11. Ejecutar matriz completa.
12. Ejecutar guardas `rg`.
13. Registrar resultado final y cualquier desviacion tecnica.

## Criterios De Cierre

- PostgreSQL impide el estado invalido aunque se salte el backend.
- El backend no tiene camino normal de claim con ids crudos sin validar.
- HTTP distingue card no activa, bloqueos, ya reclamada y version stale.
- People workload ya no transporta ni renderiza `outside_active_work_scope`.
- Seeds y fixtures no crean claimed work legacy.
- La UI no permite crear o reclamar trabajo operativo fuera de card activa.
- Rules/automations no crean tasks en targets que ya no aceptan trabajo.
- Tests cubren BBDD, repositorio, use case, HTTP, shared, frontend y seeds.
- No queda codigo de compatibilidad para claimed tasks fuera de cards activas.
- Cualquier incremento de lineas queda justificado por tests o restricciones de
  integridad; la limpieza posterior debe compensarlo eliminando legacy real.
