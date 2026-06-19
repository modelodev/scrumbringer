# Interface Entity Mutability Audit

Fecha: 2026-06-13

Auditoria enfocada en detectar entidades que el usuario puede crear o configurar
desde la interfaz, pero que luego no puede editar, eliminar, revocar o corregir
de forma equivalente.

## Estado posterior

Los hallazgos de este informe reflejan el estado auditado el 2026-06-13. La
implementacion posterior queda detallada en
`docs/interface-entity-mutability-improvement-plan.md` y cubre los casos
principales detectados: edicion operativa completa de tareas, borrado controlado
de notas de tarea, invalidacion de invitaciones, renombrado de capacidades,
renombrado/revocacion de API tokens y desactivacion de identidades de
integracion sin tokens activos.

## Resumen

Estado global: **riesgo medio**.

La interfaz cubre bien la mayoria de entidades principales de administracion
operativa: proyectos, cards, card trees, task types, workflows, reglas,
templates, usuarios, membresias de proyecto y dependencias. El problema no esta
en un CRUD general incompleto, sino en varios objetos secundarios o campos
creados en formularios que quedan bloqueados despues de crear la entidad.

El caso de mayor impacto esta en tareas: se pueden definir `priority`,
`type_id`, `card_id` y `parent_card_id` al crear, pero la edicion principal de la
tarea solo permite cambiar titulo y descripcion. Esto contradice la expectativa
de una plataforma de trabajo pull-based donde el equipo debe poder mantener el
pool limpio sin pedir cambios fuera del producto.

## Hallazgos

### P1 - La tarea solo es parcialmente editable tras crearla

**Entidad:** Task.

**Evidencia:**

- El dialogo de creacion captura titulo, descripcion, prioridad, tipo,
  card tree y card: `apps/client/src/scrumbringer_client/features/pool/create_dialog.gleam:71`.
- El formulario de edicion del detalle solo renderiza titulo y descripcion:
  `apps/client/src/scrumbringer_client/features/tasks/detail_editor.gleam:67`.
- `is_dirty` solo compara titulo y descripcion:
  `apps/client/src/scrumbringer_client/features/tasks/detail_editor.gleam:61`.
- El cliente `update_task` solo envia `version`, `title` y `description`:
  `apps/client/src/scrumbringer_client/api/tasks/operations.gleam:281`.
- El backend acepta `priority`, `type_id` y `parent_card_id` en `PATCH /tasks`,
  pero no `card_id`: `apps/server/src/scrumbringer_server/http/tasks/payloads.gleam:73`.

**Impacto:**

Un usuario puede crear una tarea con tipo, prioridad, card o card tree
incorrectos y quedarse sin un camino claro para corregirla desde el detalle de
tarea. La filosofia del producto favorece la autoorganizacion del pool, por lo
que estos metadatos deberian ser corregibles por quien tenga permiso para editar
la tarea.

**Recomendacion:**

Ampliar la edicion de tarea para cubrir todos los campos de creacion que sigan
siendo parte del modelo operativo:

- `priority`
- `type_id`
- `parent_card_id`
- `card_id`, si el producto considera que la relacion card-task no es
  historica/inmutable

Si alguno debe ser deliberadamente inmutable, la UI debe hacerlo explicito en el
detalle, no esconderlo como una omision.

### P1 - Las notas de tarea son create-only y son inconsistentes con notas de card

**Entidad:** Task note.

**Evidencia:**

- La API cliente de task notes solo lista y crea notas:
  `apps/client/src/scrumbringer_client/api/tasks/notes.gleam:33`.
- El handler HTTP solo permite `GET` y `POST`:
  `apps/server/src/scrumbringer_server/http/task_notes.gleam:36`.
- La vista de notas de tarea pasa `on_delete`, pero cada `NoteView` queda con
  `can_delete: False`: `apps/client/src/scrumbringer_client/features/pool/task_notes.gleam:119`.
- En cambio, las notas de card si pueden borrarse por autor o admin:
  `apps/client/src/scrumbringer_client/components/card_detail_modal.gleam:715`.

**Impacto:**

Una nota de tarea con error, informacion sensible o texto accidental no se puede
retirar. Ademas, el producto presenta dos modelos mentales diferentes para una
misma accion: las notas de card tienen borrado; las notas de tarea no.

**Recomendacion:**

Decidir un unico modelo para notas:

- Si las notas son conversacion operativa, permitir borrar notas propias y
  permitir borrado admin, igual que en cards.
- Si las notas son historicas/audit log, hacerlas append-only en cards y tasks,
  y nombrarlas de forma que el usuario entienda esa irreversibilidad.

### P2 - Las capabilities no se pueden renombrar

**Entidad:** Capability.

**Evidencia:**

- La API cliente tiene crear y eliminar capability, pero no update:
  `apps/client/src/scrumbringer_client/api/org.gleam:231`.
- La tabla de capabilities ofrece gestionar miembros y borrar, pero no editar:
  `apps/client/src/scrumbringer_client/features/admin/capabilities_view.gleam:213`.

**Impacto:**

Una capability con typo o cambio de terminologia obliga a borrar y recrear. Como
las capabilities estan asociadas a miembros y tipos de tarea, ese workaround
puede romper configuracion o inducir perdida de contexto.

**Recomendacion:**

Anadir accion de renombrado con validacion de unicidad dentro del proyecto. No
hace falta ampliar el modelo mas alla de `name` si el objetivo es cubrir la
correccion basica.

### P2 - Los invite links no se pueden revocar ni invalidar desde la interfaz

**Entidad:** Invite link.

**Evidencia:**

- La UI lista enlaces, permite copiar y regenerar, pero no revocar:
  `apps/client/src/scrumbringer_client/features/invites/view.gleam:120`.
- El estado `Invalidated` existe en el dominio de la vista:
  `apps/client/src/scrumbringer_client/features/invites/view.gleam:25`.
- La API cliente solo lista, crea y regenera:
  `apps/client/src/scrumbringer_client/api/org.gleam:298`.
- El handler HTTP solo permite `GET` y `POST` para invite links:
  `apps/server/src/scrumbringer_server/http/org_invite_links.gleam:27`.

**Impacto:**

Un admin puede generar un enlace para un email equivocado o comprometido, pero
no puede invalidarlo explicitamente. Regenerar no es equivalente a revocar si el
problema es que el invite ya no debe existir.

**Recomendacion:**

Anadir accion `Revoke`/`Invalidate` para enlaces activos. La UI ya contempla el
estado invalidado, por lo que el modelo visual esta preparado para representarlo.

### P2 - Los usuarios de integracion no tienen ciclo de vida de gestion

**Entidad:** Integration user.

**Evidencia:**

- El backend permite listar y crear integration users, pero no editar ni borrar:
  `apps/server/src/scrumbringer_server/http/integration_users.gleam:16`.
- La persistencia define `create`, `find_or_create` y `list_for_org`, pero no
  update/delete: `apps/server/src/scrumbringer_server/services/integration_users.gleam:29`.
- La UI de API tokens crea o reutiliza integraciones a partir del campo
  `integration`: `apps/client/src/scrumbringer_client/features/admin/api_tokens_view.gleam:176`.
- La API cliente de API tokens solo lista integration users, crea tokens y
  revoca tokens: `apps/client/src/scrumbringer_client/api/api_tokens.gleam:17`.

**Impacto:**

Si se introduce una integracion con email/nombre incorrecto, queda visible como
identidad de integracion pero sin una pantalla para corregirla, desactivarla o
eliminarla. Revocar tokens no elimina necesariamente la identidad.

**Recomendacion:**

Separar claramente `Integration users` de `API tokens` en la interfaz o
declararlos identidades internas no editables. Si son visibles como entidades,
deben poder desactivarse o eliminarse cuando no tengan tokens activos.

### P3 - Los API tokens son inmutables salvo revocacion

**Entidad:** API token.

**Evidencia:**

- El formulario de creacion define nombre, integracion, proyecto, expiracion y
  scopes: `apps/client/src/scrumbringer_client/features/admin/api_tokens_view.gleam:154`.
- La tabla solo ofrece revocar:
  `apps/client/src/scrumbringer_client/features/admin/api_tokens_view.gleam:138`.
- La API cliente solo crea y revoca, sin update:
  `apps/client/src/scrumbringer_client/api/api_tokens.gleam:41`.

**Impacto:**

La inmutabilidad de tokens puede ser correcta por seguridad. El riesgo esta en
que no queda expresada como decision de producto: cambiar nombre, scopes,
proyecto o expiracion exige revocar y recrear.

**Recomendacion:**

Mantenerlos inmutables si esa es la politica de seguridad, pero explicitarlo en
la UI y documentacion de API tokens. Como mejora menor, permitir editar solo el
nombre descriptivo si no se quiere tocar scopes ni grants.

### P3 - La organizacion se crea con nombre, pero no tiene edicion de perfil

**Entidad:** Organization.

**Evidencia:**

- El primer registro crea la organizacion con `org_name`:
  `apps/server/src/scrumbringer_server/persistence/auth/registration.gleam:73`.
- La pantalla de org settings gestiona usuarios, roles y eliminacion de usuarios,
  no el perfil/nombre de la organizacion:
  `apps/client/src/scrumbringer_client/features/admin/org_settings_view.gleam:40`.
- No aparece una API de update/delete de organizacion en el cliente ni en el
  servidor en el barrido por `update_organization`, `delete_organization` u
  operaciones sobre `organizations`.

**Impacto:**

Si el nombre de organizacion se usa como identidad visible, un error de
onboarding queda sin correccion. Es riesgo bajo si el nombre no se muestra o si
la organizacion se considera tenant tecnico.

**Recomendacion:**

Si el nombre aparece en navegacion, invitaciones o reporting, anadir edicion de
nombre para admins. No recomiendo exponer eliminacion de organizacion sin una
politica explicita de borrado de tenant.

## Entidades con cobertura suficiente

| Entidad | Cobertura observada | Notas |
| --- | --- | --- |
| Projects | Crear, editar, eliminar | CRUD principal cubierto. |
| Cards | Crear, editar, eliminar | El borrado puede bloquearse si hay tareas, pero se comunica como restriccion. |
| Card Trees | Crear, editar, eliminar | El borrado esta restringido por estado/contenido. |
| Task types | Crear, editar, eliminar | Cobertura correcta para administracion. |
| Workflows | Crear, editar, eliminar | Cobertura correcta. |
| Workflow rules | Crear, editar, eliminar | Tambien hay attach/detach de templates. |
| Task templates | Crear, editar, eliminar | Cobertura correcta. |
| Org users | Cambiar rol, eliminar | No hay edicion de email, razonable si viene de identidad. |
| Project memberships | Anadir, cambiar rol, quitar | El termino de producto deberia consolidarse como "equipo". |
| Dependencies | Anadir, quitar | Editar una dependencia equivale a quitar y anadir otra. |

## Recomendacion de producto

La regla mas alineada con la filosofia de ScrumBringer es:

> Si una entidad o campo se crea para mantener el pool operativo, debe poder
> corregirse desde el producto por el usuario con permiso natural. Si algo es
> inmutable por seguridad, auditoria o integridad historica, la interfaz debe
> decirlo y ofrecer una salida equivalente: revocar, archivar, invalidar o
> recrear sin perdida de configuracion.

Prioridad sugerida:

1. Completar edicion de tarea para todos los campos operativos.
2. Unificar el modelo de notas entre tasks y cards.
3. Anadir revocacion de invite links.
4. Anadir renombrado de capabilities.
5. Clarificar o gestionar usuarios de integracion.
6. Documentar la inmutabilidad de API tokens y decidir si el nombre es editable.
7. Decidir si la organizacion necesita perfil editable.

## Propuesta de garantia

Para cada correccion, exigir:

- Test unitario de update para el flujo de estado Lustre afectado.
- Test de API o servicio cuando se anada endpoint nuevo.
- Test e2e minimo para comprobar que la accion aparece en la interfaz y que el
  objeto deja de quedar atrapado tras crearse.
- Mensajes de error especificos para restricciones intencionales, por ejemplo
  "no se puede borrar porque tiene tareas" o "los tokens son inmutables; revoca
  y crea uno nuevo".
