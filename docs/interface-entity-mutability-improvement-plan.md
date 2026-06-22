# Interface Entity Mutability Improvement Plan

Fecha: 2026-06-13

Plan de mejora derivado de `docs/interface-entity-mutability-audit.md`.

Objetivo: ninguna entidad creada o configurada por el usuario debe quedar
atrapada sin accion correctiva. Cuando una entidad sea inmutable por seguridad,
auditoria o integridad historica, la interfaz debe hacerlo explicito y ofrecer
una salida operativa equivalente: revocar, invalidar, archivar, desactivar o
recrear sin ambiguedad.

## Principios de decision

1. **Pool corregible.** Todo dato que afecte a la capacidad del equipo para
   elegir, entender o ejecutar trabajo en el pool debe poder corregirse desde el
   producto por el usuario con permiso natural.
2. **Seguridad sin falso CRUD.** Tokens e identidades tecnicas no necesitan CRUD
   completo si la alternativa correcta es revocar/desactivar. La UI debe
   nombrar esa decision.
3. **Historial claro.** Si una nota o evento se conserva por trazabilidad, no se
   debe presentar como comentario editable. Si se presenta como comentario
   operativo, debe tener borrado controlado.
4. **Permisos alineados con pull.** Las tareas disponibles son editables por
   miembros del proyecto; las reclamadas solo por quien las reclamo; las
   completadas son historicas y quedan bloqueadas salvo acciones
   administrativas futuras explicitas.
5. **Cambios pequenos, contratos tipados.** En Gleam, preferir ADTs y payloads
   explicitos sobre sentinelas nuevas. Reutilizar patrones existentes de
   `DialogMode`, `Remote`, `FieldUpdate`, `ApiResult`, `data_table` y
   `action_buttons`.

## Priorizacion

| Prioridad | Slice | Motivo |
| --- | --- | --- |
| 1 | Edicion completa de task operativa | Mayor impacto en el pool y en la filosofia pull-based. |
| 2 | Ciclo de vida de task notes | Inconsistencia visible con card notes y riesgo de errores no corregibles. |
| 3 | Invite links revocables | Seguridad y control administrativo. |
| 4 | Capabilities renombrables | Baja complejidad y alto valor para administracion diaria. |
| 5 | Integraciones y API tokens | Requiere separar seguridad de gestion de identidades tecnicas. |
| 6 | Perfil de organizacion | Menor impacto operativo; util si el nombre aparece en UI/reporting. |

## Slice 1: edicion completa de task operativa

### Producto

La task es la unidad central del pull flow. Si el equipo detecta que una task
tiene prioridad, tipo, card o hierarchy equivocados, corregirla debe ser parte
del trabajo normal, no una excepcion administrativa.

Decision:

- Mantener la regla ya acordada: una task disponible puede editarla cualquier
  miembro del proyecto; una task reclamada solo la edita quien la reclamo.
- No permitir editar tasks completadas desde el flujo normal.
- Tratar `title`, `description`, `priority`, `type_id`, `card_id` y
  `parent_card_id` como campos operativos editables.
- Si una task tiene `card_id`, su hierarchy efectivo se hereda de la card. En
  ese caso `parent_card_id` queda deshabilitado y explicado.

### UI/UX

Sustituir el editor actual de dos campos por un editor compacto por secciones en
el detalle de task:

- **Identity:** title y description.
- **Planning:** priority y type.
- **Placement:** card y hierarchy.

Comportamiento:

- Un solo boton `Edit` abre el modo edicion completo.
- `Save` se activa si cambia cualquier campo operativo.
- `Cancel` restaura todos los campos.
- La seccion Placement muestra:
  - selector de card con opcion `No card`;
  - selector de hierarchy solo si `No card`;
  - texto no intrusivo `Hierarchy inherited from card` si hay card.
- Si el backend rechaza una combinacion, el error se muestra junto a Placement,
  no como toast generico.
- En readonly, mostrar card, hierarchy efectivo, type y priority con el mismo
  vocabulario visual que la lista de tareas.

No usar un modal adicional: el detalle de task ya es el contexto de edicion.

### Codigo

Frontend:

- Extender el estado de detalle en
  `apps/client/src/scrumbringer_client/client_state/member/pool.gleam` con
  campos de edicion para `priority`, `type_id`, `card_id` y `parent_card_id`.
- Renombrar `detail_edit_form.Input` para que represente un formulario completo
  de task, no solo titulo/descripcion.
- Extender `features/tasks/detail_editor.gleam` para renderizar selects e inputs
  usando componentes existentes (`form_field`, `select`, `input`).
- Cargar opciones necesarias desde caches ya existentes:
  - `task_types` del proyecto;
  - `cards` del proyecto;
  - hierarchies ready del proyecto.
- Si alguna cache no esta cargada al entrar en edicion, mostrar skeleton/disabled
  en ese grupo y lanzar fetch puntual; no bloquear la edicion de titulo y
  descripcion.
- Extender `api/tasks/operations.update_task` para aceptar un payload tipado de
  actualizacion, no una lista plana de argumentos.

Backend:

- Extender `workflow_types.TaskUpdates` con
  `card_id: FieldUpdate(Option(Int))`.
- Extender `decode_update_task` para aceptar `card_id` como campo opcional.
- Decodificar `card_id` con el mismo enfoque que `parent_card_id`: mirar si el
  campo existe en el JSON y despues interpretar `null` como `Set(None)`. No usar
  `optional_field(..., None, optional(int))` si se necesita distinguir ausencia
  de clear explicito.
- Sustituir sentinelas ad hoc por helpers equivalentes a `parent_card_id` para
  poder distinguir `unchanged`, `set None` y `set Some(id)`.
- Extender `tasks_update.sql` y `tasks_queries.update_editable_task` para
  actualizar `card_id`.
- Validar que la card pertenece al mismo proyecto.
- Validar que no se mandan simultaneamente `card_id = Some(_)` y
  `parent_card_id = Set(Some(_))`.
- Cuando se asigna una card, limpiar `parent_card_id` de la task para que el
  hierarchy efectivo sea solo el de la card.
- Revisar scopes Bearer existentes: si `tasks:write` permite actualizar tasks,
  el contrato nuevo debe respetar las mismas validaciones y no abrir un bypass
  para mover tasks entre cards/hierarchies fuera de proyecto.

Tests:

- Unit tests de `detail_edit_form.evaluate` para cambios de cada campo.
- Tests de estado para start/cancel/save con todos los campos.
- Tests de payload server para `card_id` unchanged/set/clear.
- Tests de workflow para:
  - available task editable por miembro;
  - claimed task editable por owner;
  - claimed task por otro usuario rechazada;
  - card invalida rechazada;
  - card + hierarchy explicito rechazado.
- E2E minimo: crear task con metadata erronea, abrir detalle, corregir type,
  priority y card, guardar y comprobar lista/detalle.

## Slice 2: task notes con ciclo de vida consistente

### Producto

Las notas de tarea se usan para contexto operativo, decisiones y avances. Ese
uso se parece mas a comentario que a audit log. Por tanto, deben poder borrarse
con las mismas reglas que las notas de card.

Decision:

- Permitir borrar nota propia.
- Permitir borrar cualquier nota a project manager u org admin.
- No implementar edicion de notas en esta fase. Editar notas complica
  trazabilidad; borrar cubre el caso de error accidental o informacion sensible.

### UI/UX

- Activar el boton de borrar en task notes cuando `can_delete` sea true.
- Usar la misma affordance, tooltip y confirmacion que card notes.
- Mostrar empty state despues de borrar la ultima nota.
- Si el usuario no puede borrar, no mostrar accion disabled: evitar ruido y
  mantener la lista densa.
- No copiar sin mas el tooltip enriquecido de card notes si task notes no
  exponen email/roles del autor. Para esta fase basta con `Delete note` y
  `Delete note as admin` segun permiso.

### Codigo

- Anadir `DELETE /api/v1/tasks/:task_id/notes/:note_id`.
- Reutilizar el patron de `http/card_notes.gleam` para autorizacion:
  acceso a task, ownership de note, bypass manager/admin.
- Extender `task_notes_db` con `get_note` y `delete_note`.
- Anadir queries SQL `task_notes_get.sql` y `task_notes_delete.sql`.
- Extender `api/tasks/notes.gleam` con `delete_task_note`.
- Conectar `features/pool/task_notes.gleam` a `can_delete` real y a la mutation
  de estado ya prevista por el `on_delete` existente.
- Extender `task_notes.Config` con `can_manage_notes` o derivarlo del contexto
  del detalle para distinguir nota propia de borrado admin.
- Si los endpoints Bearer actuales permiten `notes:write`, decidir
  explicitamente si `DELETE task note` queda incluido en ese scope. Recomendado:
  si `notes:write` ya permite crear, tambien puede borrar notas creadas por la
  misma integracion; el borrado admin queda solo para sesion web con rol.

Tests:

- Unit tests de vista para mostrar/ocultar accion.
- Service/HTTP tests de borrado propio, borrado admin y rechazo a tercero.
- Test de estado cliente para quitar nota de la lista tras delete OK.

## Slice 3: invite links revocables

### Producto

Regenerar un invite link no resuelve el caso de "este invite ya no debe existir".
La accion correcta es invalidar. El dominio ya conoce `Invalidated`, por lo que
la solucion natural es exponer esa transicion.

Decision:

- Anadir accion `Invalidate` para invite links activos.
- No permitir invalidar links `Used` o ya `Invalidated`; mostrar estado final.
- Mantener `Regenerate` como accion separada para "necesito un link nuevo para
  el mismo email".

### UI/UX

- En la tabla de invites, acciones:
  - `Copy` para activos;
  - `Regenerate` para activos/invalidated segun politica actual;
  - `Invalidate` solo para activos.
- Confirmacion breve: `Invalidate invite for email? This link will stop working.`
- Tras invalidar, actualizar la fila a estado `Invalidated` sin sacar al usuario
  de la tabla.
- Usar icono de revoke/ban si existe en `icons`; si no, trash/delete con copy
  precisa, no como borrado fisico.

### Codigo

- Anadir funcion `invalidate_invite_link(db, org_id, email)` en
  `org_invite_links_db`.
- Implementar SQL que setee `invalidated_at = now()` solo si `used_at is null`
  e `invalidated_at is null`.
- Anadir endpoint `POST /api/v1/org/invite-links/invalidate` con payload
  `{ "email": ... }`. Es mejor que email en path: evita encoding raro, mantiene
  simetria con `regenerate` y permite reutilizar el decoder de email.
- Extender `api/org.gleam` con `invalidate_invite_link`.
- Extender `features/invites/update.gleam` con estados de confirmacion e
  in-flight por email.

Tests:

- DB test de active -> invalidated.
- HTTP test de admin requerido + CSRF.
- UI state test para confirmar, cancelar y exito.

## Slice 4: capabilities renombrables

### Producto

Capability es configuracion viva del equipo. Borrar y recrear para corregir un
nombre rompe asociaciones y obliga a trabajo manual.

Decision:

- Anadir rename, no un editor amplio.
- Mantener delete para eliminacion real.
- La unicidad sigue siendo por proyecto.

### UI/UX

- En la columna Actions, anadir `Edit name` antes de manage members y delete.
- Dialogo pequeno con un unico campo `Name`.
- Reutilizar el patron de los dialogs CRUD ya existentes para task types/cards.
- Si hay conflicto de nombre, error inline en el dialogo.

### Codigo

- Anadir `PATCH /api/v1/projects/:project_id/capabilities/:capability_id`.
- Anadir `capabilities_update.sql`.
- Extender `capabilities_db` con `update_capability`.
- Extender `api/org.gleam` con `update_project_capability`.
- Extender `capabilities` client state con dialog mode edit, edit name,
  in-flight y error.
- Mantener actualizadas las caches de capability members despues del rename; los
  ids no cambian, solo el nombre mostrado.

Tests:

- DB/HTTP test para rename OK, duplicado y capability de otro proyecto.
- State test de dialogo edit.
- View test de accion y error.

## Slice 5: integraciones y API tokens

### Producto

Los API tokens no deberian ser plenamente editables: scopes, proyecto y
expiracion forman parte del grant de seguridad. Cambiarlos in-place puede ocultar
rotaciones necesarias. La mejor solucion es:

- API tokens: inmutables salvo `revoke`.
- Nombre descriptivo del token: editable, porque no cambia el grant de
  seguridad y corrige errores de administracion.
- Integration users: gestionables como identidades tecnicas, no como usuarios
  humanos.

Decision:

- Documentar en la UI que los grants de tokens son inmutables: para cambiar
  scope/proyecto/expiracion, revocar y crear otro.
- Permitir editar solo `name` en tokens activos y revocados. No permitir editar
  integracion, scopes, proyecto ni expiracion.
- Anadir vista secundaria `Integrations` dentro de Tokens API o una seccion en
  la misma pantalla.
- Permitir desactivar integraciones sin tokens activos.
- No permitir borrar/desactivar una integracion con tokens activos; primero hay
  que revocar sus tokens.

### UI/UX

- En create token, cambiar label `Integration` por `Integration identity` y
  microcopy: `Existing names are reused; new names create a technical identity.`
- En tabla de tokens, anadir nota compacta: `Grants are immutable. Revoke and
  create a new token to change access.`
- Anadir accion `Rename` para el token, con dialogo pequeno de un campo. No usar
  el dialogo de creacion como editor, porque podria sugerir que scopes/proyecto
  tambien son editables.
- En tabla de integrations:
  - email/name;
  - created_at;
  - active token count;
  - action `Deactivate` si count = 0.
- Evitar mezclar usuarios humanos con integraciones en `Org Settings`.

### Codigo

- Mantener `api_tokens` sin update de scopes/proyecto/expiry.
- Anadir solo `PATCH /api/v1/api-tokens/:id` con payload `{ "name": ... }`.
  Es mejor que un sub-path `/name` porque sigue el contrato PATCH del resto de
  recursos sin sugerir que los grants sean editables.
- Anadir `integration_users.deactivate` con `deleted_at = now()` para identidades
  sin tokens activos.
- Extender `GET /api/v1/integration-users` para incluir `active_token_count`.
- Anadir endpoint `DELETE /api/v1/integration-users/:id` como soft delete.
- Ajustar `find_or_create` para no reutilizar integraciones soft-deleted sin una
  decision explicita. Recomendado: devolver conflicto y pedir reactivacion futura
  si se intenta reutilizar el mismo nombre.

Tests:

- DB tests de deactivate sin tokens activos y bloqueo con tokens activos.
- HTTP tests admin + CSRF.
- UI tests de microcopy y acciones.

## Slice 6: perfil de organizacion

### Producto

La organizacion no necesita borrado desde UI en esta fase. Si el nombre aparece
en navegacion, reportes o invitaciones, necesita edicion por admins.

Decision:

- Anadir edicion de nombre de organizacion.
- No anadir delete organization.

### UI/UX

- En `Org Settings`, separar:
  - `Organization profile`: name editable.
  - `Users`: tabla actual.
- Guardado inline o dialogo simple; preferir inline porque es un unico campo.
- Error inline si el nombre esta vacio.

### Codigo

- Anadir `GET/PATCH /api/v1/org`.
- Crear `organizations_db` pequeno con `get_org` y `update_org_name`.
- Extender bootstrap/hydration si el cliente necesita mostrar el nombre.
- Mantener `org_settings_view` centrada en org, con subcomponentes para profile
  y users para evitar que crezca sin estructura.

Tests:

- HTTP test admin only.
- State/view test del campo name.

## Orden de implementacion recomendado

1. **Task edit contract.** Primero backend y payload, luego UI de detalle.
2. **Task notes delete.** Reutiliza patron card notes; bajo riesgo y visible.
3. **Invite invalidate.** Seguridad administrativa con dominio ya preparado.
4. **Capability rename.** CRUD simple, buena limpieza de admin.
5. **API tokens/integrations.** Primero microcopy/documentacion, despues
   deactivate integration.
6. **Organization profile.** Solo si el nombre se muestra o se va a mostrar.

## Limpiezas transversales

Estas limpiezas reducen duplicacion sin crear una abstraccion prematura:

- **Payloads de update con clear explicito.** Crear helpers locales para campos
  `FieldUpdate(Option(Int))` en tasks, usados por `parent_card_id` y `card_id`.
  Evita nuevos sentinelas y mantiene claro el contrato absent/null/value.
- **Notas task/card.** Extraer solo lo comun de autorizacion y estado visual si
  ambos modelos siguen convergiendo. No forzar un unico tipo de nota mientras
  `CardNote` tiene metadatos de autor y `TaskNote` no.
- **Dialogs CRUD.** Capabilities y token rename deben reutilizar patrones
  existentes de dialogos pequenos y estados `in_flight/error`; no crear un
  framework nuevo de CRUD.
- **Mensajes i18n.** Agrupar textos nuevos por entidad en `i18n/text.gleam`,
  `i18n/en.gleam` y `i18n/es.gleam`. Evitar strings inline en vistas, salvo
  atributos tecnicos.
- **Docs.** Actualizar `docs/api-tokens.md` cuando se implemente token rename,
  integraciones desactivables o cualquier matiz de scopes `notes:write`.

## Alternativas descartadas

| Alternativa | Motivo de descarte |
| --- | --- |
| Hacer CRUD completo para todo | Debilita decisiones de seguridad/auditoria. Tokens e integraciones necesitan revocacion/desactivacion, no edicion total. |
| Editar notas in-place | Complica trazabilidad y no es necesario para corregir errores sensibles; borrar propio/admin cubre el problema detectado. |
| Borrar invite links fisicamente | El dominio ya modela `Invalidated`; conservar estado ayuda a auditoria administrativa. |
| Permitir editar tasks completadas | Puede reescribir historia operacional. Mejor dejar completadas como historicas salvo una futura accion admin explicita. |
| Usar modales separados para cada campo de task | Fragmenta un flujo central. El detalle de task debe ser el lugar natural de correccion. |
| Reutilizar el dialogo de create token como edit token | Sugiere que grants son editables y aumenta riesgo de cambios de seguridad accidentales. |

## Iteraciones del plan

El plan se reviso en tres pasadas:

1. **Version base.** Cubria cada hallazgo con una accion correctiva directa.
2. **Mejora de dominio.** Se sustituyo el enfoque de "CRUD para todo" por
   ciclos de vida especificos: editar para datos operativos, borrar controlado
   para notas, invalidar para invites, revocar/desactivar para seguridad.
3. **Mejora tecnica.** Se fijaron decisiones que evitaban ambiguedad:
   `card_id` como `FieldUpdate(Option(Int))`, endpoint unico de invalidate,
   token grants inmutables con solo rename, y no copiar metadatos de card notes
   a task notes sin soporte real.

Tras la tercera pasada no queda una alternativa mejor sin cambiar decisiones de
producto mas amplias, como permitir edicion de tasks completadas o convertir los
tokens en grants mutables. Esas alternativas se descartan arriba por impacto en
historial y seguridad.

## Garantias de calidad

- `gleam check` debe pasar tras cada slice.
- `gleam test` debe pasar tras cada slice.
- Nuevos endpoints con tests HTTP o service.
- Nuevas transiciones de UI con tests de update puros.
- E2E al menos para Slice 1, porque cubre el flujo principal del producto.
- No introducir componentes visuales nuevos si ya existe equivalente en
  `ui/action_buttons`, `ui/dialog`, `ui/form_field`, `ui/data_table` o
  `ui/notes_list`.

## Criterio de terminado

La deficiencia queda cubierta cuando:

- el usuario ve una accion correctiva natural;
- la accion tiene permisos claros;
- el backend representa la transicion con tipos explicitos;
- el estado cliente no puede quedar desincronizado tras exito/error;
- hay test del caso feliz y del rechazo principal;
- si la entidad sigue siendo inmutable, la UI lo dice y ofrece la accion
  equivalente.
