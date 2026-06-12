# Analisis inverso de flujos y modulos

Fecha: 2026-06-12
Rama: `improvements-codebase`

## Metodo

El analisis combina dos fuentes:

- Recorrido con `agent-browser` sobre la app local en `https://127.0.0.1:8443`, autenticado como `admin@example.com`.
- Lectura estatica de rutas, clientes API, modulos backend/frontend y referencias con `rg`.

Nota operativa: el trazado HAR de `agent-browser` fallo por permisos del socket local, asi que la evidencia de navegador se basa en snapshots de accesibilidad y rutas visitadas. Los endpoints se completan por `apps/server/src/scrumbringer_server/web/router.gleam` y los modulos `apps/client/src/scrumbringer_client/api/*`.

## Estado tras refactor en `last_refactor`

Esta auditoria conserva la foto original de hallazgos. En la rama
`last_refactor` ya se ejecutaron las limpiezas priorizadas de bajo riesgo:

- Eliminados los aliases backend `/api/v1/me/active-task*`; el contrato activo
  queda en `/api/v1/me/work-sessions/*`.
- Eliminados los modulos frontend sin referencias señalados en la auditoria,
  incluido `features/skills/view.gleam`.
- Simplificada la ruta member a `/app/pool` sin `member_section.gleam`.
- Renombrado `features/fichas/*` a `features/cards/*`.
- Extraidos helpers backend para `resource_views` y presenters comunes de notas.
- Separado `api/workflows.gleam` en workflows, rules, task templates y rule
  metrics.
- Renombrado el cliente de metricas operativas a
  `api/operational_metrics.gleam`.
- Declarados `seed*.gleam` como dev/test y `persistence/auth` como frontera SQL
  intencional.

## Flujos observados

| ID | Flujo | Evidencia de navegador | Modulos principales |
| --- | --- | --- | --- |
| F0 | Login, sesion, reset e invitaciones | `/` con formulario de email/password y entrada a `/app/pool?project=14&view=pool` | auth backend/frontend |
| F1 | Shell autenticado, navegacion y panel derecho | Navegacion con Trabajo, Configuracion, Organizacion, selector de proyecto y panel "Mis tareas/Mis tarjetas" | router, layout, hydration, permisos |
| F2 | Pool de tareas | `/app/pool?project=14&view=pool`, filtros, busqueda, reclamar, arrastrar | tasks, pool, work filters |
| F3 | Detalle de tarea | Modal con tabs Tareas, Notas, Metricas, editar, dependencias, liberar/completar | task detail, notes, dependencies, views |
| F4 | Creacion de tarea y tarjeta | Modales "Nueva tarea" y "Crear tarjeta" | task/card create forms y CRUD |
| F5 | Kanban y tarjetas | `/app/pool?project=14&view=cards`, columnas Pendiente/En curso/Cerrada | cards, kanban, card detail |
| F6 | Vista por capacidades | `/app/pool?project=14&view=capabilities`, regiones y scopes de capacidades | capabilities board, work filters |
| F7 | Personas | `/app/pool?project=14&view=people`, busqueda y expansion de persona | people state/update/view |
| F8 | Hitos | `/app/pool?project=14&view=milestones`, crear hito, tarjetas/tareas por hito | milestones, cards, tasks |
| F9 | Configuracion de proyecto | `/config/members`, `/config/capabilities`, `/config/cards`, `/config/task-types` | members, capabilities, cards, task types |
| F10 | Automatizaciones | `/config/workflows`, vista de reglas, `/config/templates`, `/config/rule-metrics` | workflows, rules, templates, rule metrics |
| F11 | Organizacion | `/org/invites`, `/org/users`, `/org/projects`, `/org/assignments`, `/org/api-tokens` | org users/projects/invites/tokens |
| F12 | Metricas operativas | `/org/metrics` y paneles de detalle por proyecto | metrics db/service/presenters |
| F13 | API tokens externos | UI de tokens mas scopes backend para bearer tokens | api token services, auth scopes |
| F14 | Dev/test/seed | No es flujo de usuario; usado por entorno y datos de prueba | seed, SQL generado, migraciones |

## Backend

### Entrada, servidor y routing

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `apps/server/src/main.gleam` | F0-F13 | Arranque Erlang, env, pool DB y servidor Mist. No es flujo funcional propio, pero interviene en todos. |
| `apps/server/src/scrumbringer_server.gleam` | F0-F13 | Construye la app Wisp, cookies/sesion y contexto. Transversal. |
| `apps/server/src/scrumbringer_server/web/router.gleam` | F0-F13 | Mapa completo de endpoints. Aun mantiene aliases legacy `/api/v1/me/active-task*`. |
| `http/api.gleam`, `http/json_payload.gleam`, `http/query.gleam`, `http/service_error_response.gleam` | F0-F13 | Helpers transversales para payloads, query params y errores. No parecen muertos. |
| `http/client_ip.gleam`, `http/csrf.gleam` | F0, F13 | Soporte de seguridad para auth/rate-limit/sesion. |

Hallazgo: los aliases `/api/v1/me/active-task`, `/api/v1/me/active-task/start` y `/api/v1/me/active-task/pause` no aparecen en el cliente actual. Como no se quiere mantener legacy, son candidatos a eliminar si no hay integraciones externas documentadas.

### Auth, autorizacion y tokens

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `http/auth.gleam`, `http/auth/payloads.gleam`, `http/auth/presenters.gleam` | F0 | Login, logout, register, invite-link validation y `/me`. |
| `http/password_resets*.gleam`, `services/password_resets_db.gleam` | F0 | Solicitud, validacion y consumo de reset. No se observo desde navegador en la sesion, pero hay ruta publica y cliente API. |
| `persistence/auth/login.gleam`, `persistence/auth/registration.gleam`, `persistence/auth/queries.gleam` | F0 | Persistencia especifica de login/registro. Es una frontera distinta al patron `services/*_db.gleam`. |
| `services/auth_logic.gleam`, `services/jwt.gleam`, `services/password.gleam`, `services/rate_limit.gleam` | F0, F13 | Logica de credenciales, tokens y protecciones. |
| `http/authorization.gleam`, `http/auth/resource_access.gleam`, `http/auth/scopes.gleam`, `services/authorization.gleam` | F0-F13 | Permisos por usuario, proyecto y scopes bearer. |
| `http/api_tokens*.gleam`, `http/integration_users*.gleam`, `services/api_tokens.gleam`, `services/integration_users.gleam` | F11, F13 | UI de tokens API y usuarios de integracion; scopes backend para integraciones. |

Unificacion posible: mover `persistence/auth/*` a una convencion `services/auth_db.gleam` o declarar `persistence/*` como capa formal. Ahora auth es la excepcion frente al resto de persistencia.

### Proyectos, miembros y capacidades

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `http/projects*.gleam`, `services/projects_db.gleam` | F1, F9, F11 | CRUD proyectos, miembros, roles y release-all. |
| `http/capabilities*.gleam`, `services/capabilities_db.gleam` | F6, F9 | CRUD capacidades, miembros por capacidad y capacidades de usuario. |
| `http/org_users*.gleam`, `services/org_users_db.gleam` | F11 | Usuarios org, rol org, borrado, asignaciones a proyectos. |
| `http/org_invites*.gleam`, `http/org_invite_links*.gleam`, `services/org_invites_db.gleam`, `services/org_invite_links_db.gleam` | F0, F11 | Invitaciones y links. |

No hay codigo muerto aparente aqui. Hay duplicacion razonable entre gestion de miembros por proyecto y capacidades por miembro, pero con reglas de permisos diferentes.

### Tareas, notas, dependencias, posiciones y sesiones

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `http/tasks.gleam`, `http/tasks/*.gleam`, `services/task_events_db.gleam` | F2, F3, F4, F6, F8, F12 | Listado, creacion, detalle, patch, claim/release/complete, conflictos y filtros. |
| `persistence/tasks/queries.gleam`, `persistence/tasks/mappers.gleam` | F2, F3, F6, F8, F12 | Lectura rica de tareas, incluye `has_new_notes`. |
| `http/tasks/task_types_handlers.gleam`, `services/task_types_db.gleam` | F4, F9, F10 | CRUD tipos de tarea y validacion de creacion. |
| `http/task_positions*.gleam`, `services/task_positions_db.gleam` | F2, F5, F8 | Orden personal/posiciones y drag/drop. |
| `http/tasks/task_dependencies.gleam`, `services/task_dependencies_db.gleam` | F3 | Dependencias desde modal de detalle. |
| `http/task_notes.gleam`, `http/task_notes/presenters.gleam`, `services/task_notes_db.gleam` | F3 | Notas de tarea y badge de no leidas. |
| `http/task_views.gleam`, `services/user_task_views_db.gleam` | F3 | Marca de "visto" para calcular notas nuevas. |
| `http/work_sessions*.gleam`, `services/work_sessions_db.gleam` | F1, F2, F3 | Panel derecho: empezar, pausar/heartbeat, en curso. |

Unificacion posible: `task_notes` y `card_notes` son dos implementaciones paralelas con presentadores casi equivalentes. Mantener servicios DB separados es razonable por tablas distintas, pero payloads/presenters/mutaciones podrian vivir en una abstraccion comun de notas.

Unificacion posible: `task_views` y `card_views` son endpoints gemelos para tocar `last_viewed_at`. Podrian unificarse como `resource_views` con tipo `Task | Card`, reduciendo dos handlers y dos servicios DB casi identicos.

### Tarjetas e hitos

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `http/cards*.gleam`, `services/cards_db.gleam` | F4, F5, F8 | CRUD tarjetas, kanban, cards en hitos y modal de tarjeta. |
| `http/card_notes.gleam`, `http/card_notes/presenters.gleam`, `services/card_notes_db.gleam` | F5 | Notas de tarjeta, paralelo a notas de tarea. |
| `http/card_views.gleam`, `services/user_card_views_db.gleam` | F5 | Marca vista de tarjeta para notas nuevas. |
| `http/milestones*.gleam`, `services/milestones_db.gleam` | F8 | CRUD/activar hitos y asociacion con tareas/tarjetas. |

No hay modulo sin flujo aparente. La mayor oportunidad es la unificacion de notas/views descrita arriba.

### Automatizaciones, reglas, plantillas y metricas de reglas

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `http/workflows*.gleam`, `services/workflows_db.gleam`, `services/workflows/*.gleam` | F10 | CRUD workflows, validacion, autorizacion y handlers de reglas. |
| `http/rules*.gleam`, `services/rules_db.gleam`, `services/rules_engine.gleam`, `services/rules_templates.gleam` | F10 | CRUD reglas, ejecucion, plantillas aplicadas/suprimidas. |
| `http/task_templates*.gleam`, `services/task_templates_db.gleam` | F10 | Plantillas de tarea usadas por reglas. |
| `http/rule_metrics*.gleam`, `services/rule_metrics_db.gleam` | F10 | Agregados de reglas por org/proyecto/workflow/rule. |

No parece muerto: la vista de reglas muestra columnas `PLANTILLAS`, `APLICADAS` y `SUPRIMIDAS`, y `/config/rule-metrics` monta selectores de ventana. Si se simplifica, el candidato no es borrar sino separar mejor `api/workflows`/handlers por subdominio.

### Metricas operativas

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `http/me_metrics.gleam` | F1, F12 | Metricas personales. |
| `http/org_metrics.gleam`, `http/org_metrics_users.gleam` | F12 | Resumen org, detalle por proyecto y usuarios. |
| `http/metrics_query.gleam`, `http/metrics_service.gleam`, `http/metrics_presenters.gleam`, `services/metrics_db.gleam` | F12 | Query params, calculo y presentacion de metricas. |

Unificacion posible: conviven dos familias llamadas "metrics": operativas y de reglas. No estan muertas, pero el naming es facil de confundir. Recomendacion: namespace explicito `operational_metrics` vs `rule_metrics`.

### Persistencia transversal, SQL y seed

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `services/persisted_field.gleam`, `services/persisted_role.gleam` | F0-F13 | Decodificacion y normalizacion de valores persistidos. Usados ampliamente. |
| `services/service_error.gleam`, `services/time.gleam`, `services/store_state.gleam` | F0-F13 | Errores, tiempo y helpers de estado. |
| `sql.gleam`, `sql/*.sql` | F0-F13 | SQL generado y queries fuente. No se revisa como codigo de producto manual salvo queries concretas. |
| `seed.gleam`, `seed_builder.gleam`, `seed_db.gleam` | F14 | Datos de desarrollo/test. No intervienen en flujos de usuario de runtime. |

Codigo sin flujo de producto: `seed_builder.gleam`, `seed_db.gleam` y `seed.gleam` son necesarios para desarrollo/test, pero no son runtime. Si el artefacto de produccion los incluye, conviene aislarlos en paquete o modulo de dev.

## Frontend

### Entrada, router, estado raiz e hidratacion

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `scrumbringer_client.gleam`, `client_ffi.gleam`, `storage.gleam` | F0-F13 | Bootstrap Lustre, FFI y persistencia local. |
| `router.gleam`, `url_state.gleam`, `workspace_state.gleam`, `hydration.gleam` | F0-F13 | Parse/format de rutas, estado URL y cargas iniciales. |
| `client_state.gleam`, `client_update.gleam`, `client_view.gleam` | F0-F13 | Orquestadores raiz. Siguen siendo hotspots grandes. |
| `client_state/*` | F0-F13 | Estado por area: auth, admin, member, pool, notes, metrics, positions, now working. |
| `member_section.gleam` | F1-F8 | Ahora solo tiene variante `Pool`; no modela varias secciones. |

Codigo a simplificar: `member_section.gleam` ya no aporta extensibilidad real despues de eliminar rutas member legacy. Puede colapsarse a rutas `/app/pool` + `view` en `url_state`, o mantenerse solo si se planean nuevas secciones.

### Clientes API

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `api/core.gleam` | F0-F13 | Base HTTP y decodificacion comun. |
| `api/auth.gleam` | F0 | Login/logout/me/register/invites/password reset. |
| `api/projects.gleam`, `api/org.gleam`, `api/api_tokens.gleam` | F9, F11, F13 | Admin proyecto, org y tokens. |
| `api/tasks/*.gleam` | F2, F3, F4, F6, F8 | Operaciones de tareas, notas, dependencias, posiciones, active work, tipos y capacidades. |
| `api/cards.gleam` | F4, F5, F8 | CRUD/listado/cards view/notes. |
| `api/milestones.gleam` | F8 | CRUD y activacion de hitos. |
| `api/workflows.gleam` | F10 | Workflows, reglas, plantillas, metricas y ejecuciones. |
| `api/metrics.gleam` | F12 | Metricas personales/org/proyecto/usuarios. |

Unificacion posible: `api/workflows.gleam` concentra demasiadas responsabilidades F10. Separarlo en `api/workflows`, `api/rules`, `api/task_templates` y `api/rule_metrics` alinearia mejor frontend y backend.

### Layout, navegacion y panel derecho

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `features/layout/left_panel*.gleam` | F1-F12 | Navegacion lateral y datos de menu. |
| `features/layout/center_panel*.gleam`, `work_surface.gleam` | F2-F8 | Superficie central por vista y toolbar. |
| `features/layout/right_panel*.gleam` | F1-F12 | Panel "En curso", "Mis tareas", "Mis tarjetas", preferencias y salir. |
| `features/layout/member_mobile_shell.gleam`, `responsive_drawer.gleam`, `three_panel_layout.gleam` | F1-F12 | Shell responsive. |
| `features/my_bar/view.gleam` | F1-F3 | Render de filas de tareas propias usado por el panel/pool; el nombre es legacy, no el flujo. |
| `features/now_working/*.gleam` | F1-F3 | Estado y UI de trabajo activo. |

Codigo sin flujo aparente: `features/layout/view_mode_toggle.gleam` no tiene referencias activas. La navegacion de vistas ocurre ahora desde `left_panel`/rutas.

### Auth, invitaciones y password reset

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `features/auth/*.gleam` | F0 | Login y pantallas publicas. |
| `accept_invite.gleam`, `token_flow.gleam` | F0 | Registro por invitacion/token. |
| `reset_password.gleam` | F0 | Reset de password. |
| `features/invites/*.gleam` | F11 | Gestion de invitaciones org desde admin. |

No hay codigo muerto claro en este grupo, aunque no se ejercito reset completo en navegador.

### Pool, tareas y detalle

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `features/pool/root.gleam`, `view.gleam`, `view_config.gleam`, `view_context.gleam` | F2-F4 | Composicion de Pool y modales. |
| `features/pool/available_tasks.gleam`, `task_row.gleam`, `task_card.gleam`, `filters*.gleam`, `work_filters.gleam` | F2, F6 | Listado, filtros, scope de capacidades y rows. |
| `features/pool/drag*.gleam`, `position_*.gleam`, `touch.gleam` | F2, F5 | Drag/drop y posiciones. |
| `features/pool/task_detail_*.gleam`, `task_notes.gleam`, `task_dependencies.gleam`, `task_metrics.gleam`, `task_detail_tabs.gleam` | F3 | Modal de detalle, tabs, notas, dependencias y metricas. |
| `features/tasks/create_*.gleam`, `detail_*.gleam`, `dependency_*.gleam`, `mutation_*.gleam`, `note_*.gleam`, `task_list.gleam`, `update.gleam` | F3, F4 | Estado/formularios/mutaciones de tareas usados por Pool. |
| `features/pool/create_dialog*.gleam`, `dialogs.gleam`, `blocked_claim_modal.gleam`, `task_created_*` | F4 | Crear tarea/tarjeta y feedback. |
| `features/pool/preferences*.gleam`, `shortcut_update.gleam`, `project_refresh.gleam`, `refresh_update.gleam` | F1-F4 | Preferencias y refresco del area. |

Codigo sin flujo aparente: `features/tasks/view.gleam` solo aparece en comentarios. Las vistas reales de tareas estan en `features/pool/*`, `features/my_bar/view.gleam` y componentes UI.

### Tarjetas, kanban y fichas

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `features/views/kanban_board.gleam`, `features/views/grouped_list.gleam` | F5, F6 | Kanban y agrupaciones. |
| `features/cards/detail_modal_entry.gleam` | F5 | Entrada a detalle de tarjeta. |
| `features/fichas/list_view.gleam`, `features/fichas/view.gleam`, `features/fichas/view_config.gleam` | F5 | Detalle/listado de tarjetas. Usado desde `client_view`. |
| `components/card_detail_modal.gleam` | F5 | Modal concreto de tarjeta. |
| `components/card_crud_dialog.gleam` | F4, F5, F9 | Crear/editar tarjeta desde trabajo y admin. |

Unificacion/renombre: `features/fichas/*` no esta muerto, pero el nombre ya no ayuda. Recomendacion: renombrar a `features/cards/*` y dejar `fichas` solo si el lenguaje de producto lo requiere.

### Capacidades, personas e hitos

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `features/capability_board/view.gleam`, `features/capabilities/update.gleam`, `capability_scope.gleam` | F6, F9 | Vista por capacidades y administracion de capacidades. |
| `features/skills/update.gleam` | F6 | Actualiza capacidades propias desde mensajes de pool/capability scope. |
| `features/skills/view.gleam` | Sin flujo observado | Solo queda en tests; la UI de "My Skills" como seccion propia ya no aparece. |
| `features/people/*.gleam` | F7 | Busqueda y expansion de personas. |
| `features/milestones/*.gleam` | F8 | Vista completa de hitos, filtros, seleccion, dialogs y acciones sobre tarjetas/tareas. |

Codigo sin flujo aparente: `features/skills/view.gleam` parece remanente de la antigua seccion "My Skills"; `features/skills/update.gleam` aun interviene en preferencias/capacidades propias y no deberia borrarse junto con la vista sin revisar ese flujo.

### Administracion de proyecto y organizacion

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `features/admin/view.gleam`, `features/admin/update.gleam`, `features/admin/msg.gleam`, `client_state/admin*.gleam` | F9-F12 | Orquestacion admin. |
| `features/admin/member_*.gleam`, `features/admin/views/members.gleam` | F9 | Miembros, roles, liberar todas, capacidades por usuario. |
| `features/admin/capabilities_view.gleam`, `cards*.gleam`, `task_types_view.gleam` | F9 | CRUD de capacidades, tarjetas y tipos. |
| `features/admin/workflows*.gleam`, `workflow_rules_view*.gleam`, `task_templates*.gleam`, `rule_metrics*.gleam` | F10 | Automatizaciones, reglas, plantillas y metricas. |
| `features/admin/org_settings*.gleam`, `features/projects/*.gleam`, `features/assignments/*.gleam`, `features/admin/api_tokens*.gleam` | F11 | Usuarios/org, proyectos, asignaciones y tokens API. |
| `features/metrics/*.gleam` | F12 | Metricas org/personales. |

Unificacion posible: los subflujos admin repiten patron `RemoteData + dialog state + CRUD + toast/error`. Ya existe `components/crud_dialog_base.gleam`; se puede extender el patron para reducir duplicacion en `card_crud_dialog`, `task_type_crud_dialog`, `task_template_crud_dialog`, `workflow_crud_dialog` y `rule_crud_dialog`.

### Componentes UI, estilos, i18n y helpers

| Codigo | Flujos | Lectura |
| --- | --- | --- |
| `ui/button.gleam`, `ui/dialog.gleam`, `ui/data_table.gleam`, `ui/tabs.gleam`, `ui/remote.gleam`, `ui/toast.gleam`, `ui/error_*.gleam`, `ui/form_field.gleam` | F0-F13 | UI transversal usada por auth, pool y admin. |
| `ui/task_*.gleam`, `ui/card_*.gleam`, `ui/detail_*.gleam`, `ui/notes_*.gleam`, `ui/tooltips/*.gleam` | F2-F5, F8 | Componentes de tareas, tarjetas, tabs, notas y tooltips. |
| `components/*_crud_dialog.gleam`, `components/crud_dialog_base.gleam` | F4, F5, F9, F10, F11 | Dialogos CRUD. |
| `styles*.gleam`, `theme.gleam` | F0-F13 | CSS generado. |
| `i18n/*.gleam` | F0-F13 | Textos ES/EN. |
| `helpers/*.gleam`, `utils/*.gleam`, `domain/ids.gleam`, `permissions.gleam`, `pool_prefs.gleam`, `member_visuals.gleam` | F0-F13 | Helpers de dominio/UI. |

Codigo sin flujo aparente:

- `components/truncated_text.gleam`: no tiene referencias activas.
- `ui/action_row.gleam`: no tiene referencias activas.
- `ui/notes_tabs.gleam`: no tiene referencias activas; las tabs reales pasan por `task_detail_tabs`, `detail_tabs`, `task_tabs` o `card_tabs`.

## Lista priorizada de limpieza

1. Eliminar aliases legacy backend `/api/v1/me/active-task*` si no hay consumidores externos.
2. Eliminar frontend sin referencias: `components/truncated_text.gleam`, `features/layout/view_mode_toggle.gleam`, `features/tasks/view.gleam`, `ui/action_row.gleam`, `ui/notes_tabs.gleam`.
3. Eliminar o reubicar `features/skills/view.gleam`; conservar `features/skills/update.gleam` hasta revisar el flujo de capacidades propias.
4. Simplificar `member_section.gleam`, porque solo representa `Pool`.
5. Unificar `task_views`/`card_views` como recurso visto generico.
6. Unificar payloads/presenters de notas entre tareas y tarjetas.
7. Renombrar `features/fichas/*` a `features/cards/*` o documentar explicitamente que "fichas" es lenguaje de producto.
8. Separar `api/workflows.gleam` por responsabilidad: workflows, rules, templates, rule metrics.
9. Reducir duplicacion de dialogs CRUD admin extendiendo `crud_dialog_base`.
10. Separar claramente metricas operativas y metricas de reglas en nombres/modulos.
11. Aislar `seed*.gleam` como codigo de dev/test para que no parezca parte del runtime.

## Conclusiones

No encontre grandes bloques backend sin flujo: casi todo esta conectado por rutas API o por flujos visibles de admin/trabajo. Las excepciones backend son aliases legacy y codigo de seed/dev.

En frontend si hay restos claros tras la eliminacion de legacy: varias vistas/componentes no tienen referencias y `member_section` quedo como abstraccion de una sola variante. La mayor deuda activa no es codigo muerto sino responsabilidades grandes y paralelas: `client_update`, `client_view`, `api/workflows`, dialogs CRUD, notas y resource views.
