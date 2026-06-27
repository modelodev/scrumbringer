# Card And Task Inspectors Definitive Plan

## Estado Del Documento

Este documento es el plan definitivo para convertir Card Show y Task Show en
inspectors operativos coherentes.

Sustituye como guia de ejecucion a:

- `docs/card-task-show-redesign-plan.md`
- `docs/card-task-show-ui-correction-plan.md`

Esos documentos quedan como historial de decisiones. Si hay conflicto, manda
este plan.

## Objetivo

Redisenar Card Show y Task Show como dos inspectors hermanos:

- **Card Inspector:** entiende, organiza y decide sobre trabajo agregado.
- **Task Inspector:** ejecuta una unidad concreta de trabajo.

La unificacion debe mejorar:

1. lenguaje visual unificado;
2. base de codigo mas DRY;
3. testeabilidad mediante componentes compartidos;
4. claridad operativa del modelo pull;
5. limpieza de codigo obsoleto en frontend, backend, tests, seeds y docs.

No es un polish cosmetico. La meta es que el producto responda mejor:

- en una card: que contiene, como va, que necesita ahora;
- en una task: que puedo hacer ahora, por que, y que me bloquea.

## Principios De Producto

1. **Card no ejecuta.** Card resume, agrupa, estructura y navega.
2. **Task ejecuta.** Task reclama, empieza, cierra, libera o explica por que no.
3. **Misma gramatica visual, distinta mision.** Compartir componentes pequenos,
   no forzar un `EntityShow` generico.
4. **Accion primaria unica.** Una pantalla debe tener una siguiente accion
   obvia o explicar por que no la hay.
5. **Navegacion secundaria contenida.** `Abrir en Plan/Kanban/...` no debe
   competir con la accion primaria.
6. **No contadores tecnicos.** No mostrar `0/0`, `1/10`, ni icono + numero
   sin contexto suficiente en inspectors.
7. **Mobile full-screen real.** En mobile, el inspector abierto es la superficie
   principal; el fondo no debe ser accesible ni competir visualmente.
8. **Sin compatibilidad legacy.** No conservar dos sistemas de show.

## Diagnostico Actual Basado En Codigo

### Frontend: Card Show

Modulo principal:

- `apps/client/src/scrumbringer_client/features/cards/show.gleam`

Hallazgos:

- Renderiza una superficie `card-show` con `role="complementary"`, no un
  contrato claro de inspector.
- Usa `modal_header` y clases `detail-header`, pero ya no es modal puro.
- El header mezcla estado, due date, tres chips de tarea y `card_progress.view`.
- `card_progress.view` sigue generando fracciones `closed/total`, que son
  tecnicas para Card Inspector.
- La navegacion contextual esta visible como cuatro links:
  `Ver en Plan`, `Ver en Kanban`, `Ver en Capacidades`, `Ver en Personas`.
- `Resumen` repite metricas y usa `progress_text` local.
- `Trabajo` lista tasks de forma plana con `task_item`, sin agrupar por estado
  operativo.
- La card vacia ya tiene una buena base:
  `card-empty-work-decision`, con `Anadir tarea` y `Anadir subtarjeta`.
- Notas y actividad reutilizan piezas compartidas, pero los empty states siguen
  siendo poco operativos.

Piezas ya aprovechables:

- `ui/task_metric.gleam`
- `ui/task_metric_chip.gleam`
- `ui/detail_tabs.gleam`
- `ui/action_menu.gleam`
- `ui/activity_feed.gleam`
- `ui/pinned_context.gleam`
- `ui/note_dialog.gleam`
- `ui/notes_list.gleam`
- `features/cards/show/hierarchy.gleam`
- `features/cards/policy.gleam`

Piezas a sustituir o reubicar:

- `ui/card_progress.gleam` para inspectors.
- `progress_text` local en Card Show.
- `card-scoped-navigation` como lista visible de links.
- `detail-summary-grid` como resumen principal de Card Inspector.
- `card-task-list` / `card-task-item` cuando se use como lista operativa plana.

### Frontend: Task Show

Modulos principales:

- `apps/client/src/scrumbringer_client/features/tasks/show/view.gleam`
- `apps/client/src/scrumbringer_client/features/tasks/show/header.gleam`
- `apps/client/src/scrumbringer_client/features/tasks/show/summary.gleam`
- `apps/client/src/scrumbringer_client/features/tasks/show/details.gleam`
- `apps/client/src/scrumbringer_client/features/tasks/show/footer.gleam`

Hallazgos:

- Task Show esta mejor modularizado que Card Show.
- La accion primaria ya se calcula por estado en `footer.gleam`:
  disponible -> reclamar, reclamada por mi -> empezar, en curso por mi ->
  cerrar.
- La accion primaria vive abajo en `task-action-bar`, no en el header. Eso
  reduce claridad en desktop y mobile.
- Header y summary duplican parte del contexto: estado, owner, card, prioridad,
  bloqueo.
- `task-context-navigation` muestra `Abrir card` y `Ver en Plan` como bloque
  visible, pero deberia estar en menu `Abrir en`.
- `TaskOperationalSummary` es util, pero hoy se comporta como tabla de facts,
  no como bloque de siguiente accion.
- `assigned/unassigned` usa lenguaje de asignacion. ScrumBringer debe preferir
  `Sin reclamar`, `Reclamada`, `En curso`, o copy equivalente de pull-flow.

Piezas aprovechables:

- `features/tasks/show/footer.gleam` como fuente inicial de politica de accion.
- `features/tasks/show/summary.gleam` para automation origin y facts.
- `features/pool/task_dependencies.gleam`.
- `features/pool/task_notes.gleam`.
- `features/tasks/show_editor.gleam`.

Piezas a sustituir o redisenar:

- `task-show-footer task-action-bar` como contenedor principal de accion.
- `task-context-navigation` visible.
- `task-show-summary-grid` como primer bloque de `Detalle`.
- tests que esperan `task-action-bar` como contrato visual principal.

### Frontend: Layout Y URL

Piezas relevantes:

- `apps/client/src/scrumbringer_client/url_state.gleam`
- `apps/client/src/scrumbringer_client/client_update.gleam`
- `apps/client/src/scrumbringer_client/client_view.gleam`
- `apps/client/src/scrumbringer_client/features/pool/card_show_update.gleam`
- `apps/client/src/scrumbringer_client/features/tasks/show_update.gleam`

Estado actual:

- El contrato `show=card&show_card=...` y `show=task&task=...` ya existe.
- Hay tests de URL separando `work_scope=card&card=...` de `show_card`.
- Card Show vive en `member.card_show_open` + `card_show_model`.
- Task Show vive en `member.task_show`.

Decision:

- Mantener ese contrato.
- No apilar Card Inspector y Task Inspector como overlays simultaneos.
- En desktop, usar un inspector a la vez en el panel derecho. Si una task se
  abre desde Card Inspector, Task Inspector reemplaza el cuerpo del inspector o
  navega a show=task manteniendo contexto, pero no crea modal encima de modal.
- En mobile, el show abierto es full-screen.

### Frontend: Estilos

Piezas actuales:

- `apps/client/src/scrumbringer_client/styles/ux.gleam`
- `apps/client/src/scrumbringer_client/styles/layout.gleam`
- `apps/client/src/scrumbringer_client/styles/dialogs.gleam`

Clases candidatas a retirar o cambiar de responsabilidad:

- `.card-scoped-navigation*`
- `.task-context-navigation*`
- `.detail-summary-grid`
- `.detail-summary-task-metric`
- `.detail-summary-item`
- `.card-progress-row`
- `.card-progress`
- `.card-progress-cell` en inspectors
- `.task-show-summary-grid` como resumen operativo principal
- `.task-action-bar` como lugar de accion primaria
- `.card-task-list` y `.card-task-item` si el nuevo `CardWorkList` los absorbe
- reglas mobile enormes que mezclan Card Show, Task Show y otros modales en una
  sola linea.

No retirar sin revisar consumidores:

- `modal_header.gleam`: sigue siendo usado por dialogos CRUD.
- `card_section_header.gleam`: lo usan task notes/dependencies; solo retirar de
  inspectors si queda redundante.
- `card_progress.gleam`: puede seguir siendo util en cards compactas fuera de
  inspectors, pero no debe producir copy crudo dentro de inspectors.

### Backend

El backend ya cubre la mayoria de datos necesarios:

- Cards:
  - `http/cards.gleam`
  - `http/cards/presenters.gleam`
  - `use_case/cards_db.gleam`
  - `repository/cards/*`
  - SQL `cards_get.sql`, `cards_list.sql`
- Tasks:
  - `http/tasks.gleam`
  - `http/tasks/tasks_get_patch.gleam`
  - `http/tasks/tasks_transitions.gleam`
  - `repository/tasks/queries.gleam`
  - SQL `tasks_get_for_user.sql`, `tasks_claim.sql`, `tasks_release.sql`,
    `tasks_close.sql`, `tasks_update.sql`
- Notes:
  - `http/card_notes.gleam`
  - `http/task_notes.gleam`
  - `use_case/card_notes_db.gleam`
  - `use_case/task_notes_db.gleam`
  - SQL `card_notes_*`, `task_notes_*`
- Activity:
  - `http/activity.gleam`
  - `use_case/activity_db.gleam`
  - `api/activity.gleam`
- Dependencies:
  - `http/tasks/task_dependencies.gleam`
  - `use_case/task_dependencies_db.gleam`
  - SQL `task_dependencies_*`
- Work sessions:
  - `http/work_sessions` route via `me/work-sessions/start`
  - active mode represented in task state as claimed mode.

Backend no debe reescribirse para este plan. Solo se debe tocar si falta algun
dato para los inspectors:

- owner label/email necesario en Task Inspector;
- counts de Card Inspector que no puedan derivarse del task list cargado;
- actividad de card que deba incluir subarbol acotado;
- seeds que no cubran card vacia, card con tareas, bloqueada, cerrada,
  task disponible, reclamada, en curso, bloqueada y cerrada.

### Tests Actuales Afectados

Tests frontend que se deben revisar:

- `apps/client/test/card_show_test.gleam`
- `apps/client/test/card_show_entry_test.gleam`
- `apps/client/test/card_show_actions_ht10_test.gleam`
- `apps/client/test/pool_card_show_state_test.gleam`
- `apps/client/test/pool_card_show_update_test.gleam`
- `apps/client/test/tasks_show_view_test.gleam`
- `apps/client/test/tasks_show_header_test.gleam`
- `apps/client/test/tasks_show_summary_test.gleam`
- `apps/client/test/tasks_show_details_test.gleam`
- `apps/client/test/tasks_show_footer_test.gleam`
- `apps/client/test/tasks_show_state_test.gleam`
- `apps/client/test/tasks_show_update_test.gleam`
- `apps/client/test/tasks_show_lifecycle_update_test.gleam`
- `apps/client/test/show_tabs_test.gleam`
- `apps/client/test/task_metric_chip_test.gleam`
- `apps/client/test/styles_accessibility_test.gleam`
- `apps/client/test/url_state_test.gleam`
- `apps/client/test/router_test.gleam`
- `apps/client/test/hydration_test.gleam`
- `apps/client/test/client_view_guard_test.gleam`

Tests backend que se deben revisar o ampliar:

- `apps/server/test/activity_http_test.gleam`
- `apps/server/test/notes_and_positions_http_test.gleam`
- `apps/server/test/cards_http_test.gleam`
- `apps/server/test/tasks_http_test.gleam`
- `apps/server/test/tasks_payloads_test.gleam`
- `apps/server/test/task_claim_active_card_invariant_test.gleam`
- `apps/server/test/integration/task_lifecycle_test.gleam`
- `apps/server/test/seed_operational_model_test.gleam`

## Disenio Final

### Card Inspector: Desktop

```text
App Shell
| Sidebar | Work Surface / Kanban / Cards | Card Inspector |

Card Inspector
P2 - Release Notes #4                                     [x]
En curso - Sin vencimiento - 1 de 10 cerradas
P2 - Sprint Planning #1 > P2 - Architecture #2

[ + Anadir tarea ] [ Abrir en v ] [ ... ]

Trabajo 10 | Resumen | Notas 0 | Actividad
----------------------------------------------------------
TRABAJO

Disponibles 6
  cacaca                       Disponible          [Tomar]
  release                      Disponible          [Tomar]

Reclamadas 3
  P2 - Task Extra #36          Luis                [Abrir]

Cerradas 1
  P2 - Task C #27              Cerrada
```

### Card Inspector: Empty Card

```text
P2 - API Cleanup #6                                      [x]
En curso - Sin vencimiento - Sin tareas
P2 - Sprint Planning #1

[ + Anadir tarea ] [ Anadir subtarjeta ] [ ... ]

Trabajo | Resumen | Notas 0 | Actividad
----------------------------------------------------------
Esta tarjeta todavia no tiene trabajo
Define si contiene tareas ejecutables o subtarjetas.

[ + Anadir tarea ] [ Anadir subtarjeta ]
```

Reglas:

- No mostrar `0/0`.
- No mostrar chips compactos de numero sin etiqueta si no hay contexto.
- `Trabajo` es la pestana inicial por defecto para Card Inspector.
- Si la card tiene tareas, `Trabajo` muestra trabajo agrupado por estado.
- Si la card no tiene tareas, `Trabajo` muestra el empty state de decision.
- `Resumen` no es la entrada inicial; queda como contexto, descripcion,
  estructura y senales.
- Deep-links con tab explicita y seleccion reciente del usuario deben respetarse
  cuando no contradigan permisos o estado de carga.

### Card Inspector: Resumen

```text
RESUMEN

Progreso
10 tareas - 1 cerrada - 0 bloqueadas - 10%
[barra semantica]

Descripcion
Seeded card

Estructura
Padre: P2 - Architecture #2
Subtarjetas: 0

Senales
Sin vencimiento - Sin bloqueos - Actividad baja
```

Reglas:

- `Resumen` no repite la lista de tareas.
- `Resumen` no sustituye al tab `Trabajo` como punto de entrada operativo.
- La distribucion de trabajo puede aparecer como lectura agregada, pero las
  acciones viven en `Trabajo`.

### Task Inspector: Desktop

```text
P2 - Task Extra #36                                     [x]
Disponible - Prioridad 3 - Sin vencimiento
Platform - Bug - P2 - Release Notes #4

[ Tomar tarea ] [ Abrir en v ] [ Editar ] [ ... ]

Detalle | Bloqueos 0 | Notas 2 | Actividad
----------------------------------------------------------
SIGUIENTE ACCION
Disponible para tomar
[ Tomar tarea ]

DESCRIPCION
Revisar release notes antes de publicar...

CONTEXTO
Card: P2 - Release Notes #4
Capacidad: Platform
Tipo: Bug
Prioridad: P3
Vencimiento: Sin vencimiento

NOTAS FIJADAS
  Criterio de aceptacion actualizado
```

### Task Inspector: Accion Por Estado

```text
Disponible
  Primaria: Tomar tarea

Reclamada por mi
  Primaria: Empezar
  Secundaria: Devolver al Pool

En curso por mi
  Primaria: Cerrar tarea
  Secundaria: Devolver al Pool

Reclamada por otra persona
  Sin primaria
  Texto: Reclamada por <persona>

Bloqueada
  Sin primaria de claim si la politica lo impide
  Texto: Bloqueada por N tareas
  Accion: Ver bloqueos

Cerrada
  Sin primaria
  Texto: Cerrada
```

### Task Inspector: Bloqueos

```text
BLOQUEOS 2                                      [+]

Esta tarea no puede avanzar hasta cerrar:

P2 - Task C #27             En curso - Luis       [Abrir]
P2 - Task D #28             Disponible            [Abrir]
```

Empty:

```text
Sin bloqueos
Esta tarea puede avanzar cuando alguien la tome.
[ Anadir bloqueo ]
```

### Mobile

Card y Task usan el mismo patron:

```text
P2 - Release Notes #4                              [x]
En curso - 1 de 10 cerradas
Sin vencimiento

[ + Anadir tarea ]                            [...]

Trabajo | Resumen | Notas
----------------------------------------------
contenido
```

Reglas mobile:

- No mostrar cuatro botones `Ver en ...`.
- `Abrir en` vive en overflow.
- Tabs sticky debajo del header.
- Header compacto.
- El fondo queda no interactivo.
- Un unico eje de scroll.

## Arquitectura Objetivo

### Barrido DRY De Componentes Existentes

La implementacion debe partir de un inventario de reutilizacion, no de una
lista de componentes nuevos. Regla: si una pieza nueva no reemplaza al menos
dos usos reales o no elimina un helper/local CSS duplicado, no entra en `ui/`.

| Pieza existente | Decision |
| --- | --- |
| `ui/tabs.gleam` | Mantener como motor canonico de tabs: roles, teclado, counts e indicadores ya existen. |
| `ui/detail_tabs.gleam` | Reutilizar para Card/Task Inspector. No crear `InspectorTabs` salvo wrapper minimo sin logica. |
| `ui/action_menu.gleam` | Reutilizar para acciones secundarias. Si `Abrir en` necesita enlaces reales, extender con items link antes de crear otro menu. |
| `ui/move_menu.gleam` | Usar como patron de wrapper fino sobre `action_menu`, no como dependencia directa. |
| `ui/button.gleam` | Fuente unica para acciones primarias/secundarias de inspectors. No crear markup local de botones. |
| `ui/action_buttons.gleam` y `ui/task_actions.gleam` | Reutilizar en filas compactas de tasks; no usarlos como accion primaria grande del Task Inspector. |
| `ui/task_item.gleam` | Base canonica de filas de trabajo en Card Inspector. Configurar leading, secondary y actions antes de crear una fila nueva. |
| `ui/task_status_indicator.gleam` | Indicador canonico de estado de task en filas y header. |
| `ui/task_metric.gleam` y `ui/task_metric_chip.gleam` | Mantener semantica de metricas. En inspectors usar version full o texto explicito cuando el chip compacto sea ambiguo. |
| `ui/activity_feed.gleam` | Reutilizar tal cual para Card y Task. No crear `inspector_activity_feed`. |
| `ui/note_content.gleam` | Reutilizar. Ya evita duplicar la URL explicita cuando aparece en el contenido; el plan solo debe exigir test. |
| `ui/notes_list.gleam` | Reutilizar para notas de Card/Task. No crear lista de notas especifica de inspector. |
| `ui/pinned_context.gleam` | Reutilizar para contexto fijado; ya limita visibles y soporta `more_label`. |
| `ui/note_dialog.gleam` | Reutilizar para crear/editar notas. No introducir modal nuevo. |
| `ui/empty_state.gleam` | Extender antes de crear empty states especificos: debe soportar dos acciones equilibradas para card vacia. |
| `ui/card_section_header.gleam` | Mantener para secciones con titulo + una accion. Generalizar solo si Card y Task duplican el mismo patron. |
| `ui/section_header.gleam` | No usar como base de inspectors si mantiene sesgo admin/iconografico. |
| `ui/modal_header.gleam` y `ui/modal_close_button.gleam` | Mantener para dialogos. Reutilizar close button si aplica, pero no forzar `modal_header` como header de inspector. |
| `ui/card_state_badge.gleam` y `ui/card_state.gleam` | Reutilizar para estado de card. |
| `ui/card_progress.gleam` | Mantener fuera de inspectors si tiene consumidores compactos. Sustituir dentro de inspectors. |
| `features/cards/show/hierarchy.gleam` | Reutilizar para contexto/ruta de card. Generalizar a `ui/context_path` solo si Task Inspector necesita el mismo patron. |
| `features/cards/scoped_navigation.gleam` | Mantener como fuente de URLs. La nueva UI debe envolverlo en menu, no duplicar logica de rutas. |
| `features/tasks/show/footer.gleam` | Extraer politica pura de acciones a `features/tasks/show/actions.gleam`; luego renderizarla desde header/next action. |
| `features/tasks/show/summary.gleam` | Conservar automation origin y facts utiles; separar si la vista nueva necesita bloques mas pequenos. |

### Componentes Compartidos Permitidos

Crear solo estas piezas nuevas, y solo si el PR demuestra los call sites
reemplazados:

- `ui/inspector_shell.gleam`
  - raiz, clase, close, role, mobile full-screen, testid y eje de scroll.
  - debe servir a Card y Task.
- `ui/inspector_header.gleam`
  - titulo, linea de estado, linea de contexto, accion primaria, menu
    `Abrir en` y menu secundario.
  - debe usar `ui/button`, `ui/action_menu` y `ui/modal_close_button` si aplica.

Piezas condicionadas:

- `ui/inspector_open_in_menu.gleam`
  - solo si extender `action_menu` con items link ensucia demasiado su API.
  - si se crea, debe ser un wrapper fino y sin logica propia de URLs.
- `ui/operational_summary.gleam`
  - solo si Card y Task terminan duplicando el mismo patron label/value.
  - si los bloques divergen, mantener `features/cards/show/summary.gleam` y
    `features/tasks/show/facts.gleam`.

No crear:

- `EntityShow`
- `GenericInspector(Entity)`
- `ui/inspector_tabs.gleam` con logica propia
- `ui/inspector_activity_feed.gleam`
- `ui/inspector_notes_list.gleam`
- `ui/card_work_task_row.gleam` si `task_item` puede configurarse
- `ui/task_metric_summary_chip.gleam`
- menus locales duplicados para Card y Task
- builders con muchos slots opcionales.

Mantener especificos:

- `features/cards/show/work_list.gleam`
- `features/cards/show/summary.gleam`
- `features/cards/show/header.gleam` si queda como adaptador fino
- `features/tasks/show/next_action.gleam`
- `features/tasks/show/blockers.gleam`
- `features/tasks/show/facts.gleam`

### Tipos Recomendados

Card:

```gleam
pub type CardOperationalProgress {
  NoTasks
  TaskProgress(total: Int, closed: Int, blocked: Int)
}

pub type CardPrimaryAction {
  AddTask
  AddSubcard
  ChooseWorkKind
  ActivateCard
  NoCardPrimaryAction(reason: String)
}
```

Task:

```gleam
pub type TaskPrimaryAction {
  ClaimTask
  StartWork
  CloseTask
  NoTaskPrimaryAction(reason: String)
}
```

`ReleaseClaim` no es primaria en este plan. Es salida secundaria.

## Limpieza Obligatoria

### Frontend

Retirar o transformar:

- `card_progress.view` en Card Inspector y Task/Card summaries.
- `progress_text` local en `features/cards/show.gleam`.
- `card-scoped-navigation` visible como grupo de botones.
- `task-context-navigation` visible como grupo de botones.
- `detail-summary-grid` como layout de Card Inspector.
- `task-show-summary-grid` como primer bloque de Task Inspector.
- `task-action-bar` como unica ubicacion de acciones primarias.
- tests que afirmen `task-action-bar` como contrato visual principal.
- `Assigned` / `Unassigned` en Task Inspector si se muestran al usuario como
  copy principal. Sustituir por copy pull-flow.
- CSS mobile concentrado en una sola regla gigante para Card/Task Show. Separar
  por bloque o por componentes nuevos.

Mantener si siguen teniendo consumidores:

- `modal_header.gleam` para dialogos.
- `card_progress.gleam` fuera de inspectors, hasta que exista reemplazo global.
- `card_section_header.gleam` para notas/dependencias si aporta consistencia.
- `detail_tabs.gleam` si queda como motor de tabs.

Busquedas de cierre:

```bash
rg "card_progress.view" apps/client/src/scrumbringer_client/features/cards apps/client/src/scrumbringer_client/features/tasks
rg "progress_text\\(" apps/client/src apps/client/test
rg "card-scoped-navigation|task-context-navigation" apps/client/src apps/client/test
rg "detail-summary-grid|task-show-summary-grid|task-action-bar" apps/client/src apps/client/test
rg "0/0|1/10" apps/client/src apps/client/test
```

Los matches restantes deben estar justificados en el PR.

### Backend

No eliminar backend existente salvo evidencia de no uso. Revisar:

- endpoints de actividad siguen necesarios;
- endpoints de notas siguen necesarios;
- dependencies siguen necesarios;
- task transitions siguen necesarios;
- `cards_task_count.sql` y counts de cards siguen necesarios fuera del inspector.

Ampliar solo si el frontend no puede derivar datos con coste razonable:

- card work breakdown por estado;
- owner label en dependencies;
- card subtree activity;
- seeds especificas para inspectors.

Busquedas de cierre:

```bash
rg "card_notes|task_notes|activity|task_dependencies" apps/server/src apps/server/test
rg "task_claimed|task_released|task_closed" apps/server/src apps/server/test
```

No deben desaparecer por cleanup. Deben quedar cubiertas por tests.

### Tests

Actualizar o retirar expectativas obsoletas:

- tests que esperen `0/0`, `1/10`, o fracciones visibles;
- tests que esperen cuatro links visibles `Ver en ...`;
- tests que esperen `task-action-bar` como lugar principal de accion;
- tests que esperen `Assigned` / `Unassigned` como copy principal de Task Show;
- tests de summary basados en grid generico en lugar de semantica operacional;
- tests CSS que busquen reglas antiguas si el nuevo componente las reemplaza.

Mantener o adaptar:

- tests de URL/deep-link;
- tests de apertura/cierre;
- tests de notes/activity/dependencies;
- tests de permisos;
- tests de transiciones de task.

## Tests Nuevos

### Frontend: Card Inspector

Crear o ampliar:

- `card_inspector_header_test.gleam`
  - no renderiza `0/0`;
  - empty card muestra `Sin tareas`;
  - card con tasks muestra `1 de 10 cerradas` o copy equivalente;
  - `Abrir en` renderiza menu, no cuatro botones visibles en mobile.
- `card_inspector_work_test.gleam`
  - `Trabajo` es la tab inicial al abrir Card Inspector sin tab explicita;
  - agrupa tasks por `Disponibles`, `Reclamadas`, `En curso`, `Bloqueadas`,
    `Cerradas`;
  - task disponible muestra accion `Tomar` si aplica;
  - task reclamada por otro muestra owner y accion `Abrir`;
  - empty card muestra decision task/subcard.
- `card_inspector_summary_test.gleam`
  - `Resumen` no es la tab inicial por defecto;
  - progreso semantico;
  - descripcion con label;
  - senales sin duplicar Trabajo;
  - pinned notes limitadas.
- `card_inspector_navigation_test.gleam`
  - `Abrir en` contiene Plan/Kanban/Capacidades/Personas;
  - URLs scoped conservan `project`, `view` y `work_scope=card`.

### Frontend: Task Inspector

Crear o ampliar:

- `task_inspector_header_test.gleam`
  - muestra estado pull-flow, prioridad, vencimiento y card;
  - no usa `Assigned`/`Unassigned` como copy principal;
  - `Abrir en` es menu.
- `task_inspector_next_action_test.gleam`
  - disponible -> `Tomar tarea`;
  - reclamada por mi -> `Empezar`;
  - en curso por mi -> `Cerrar tarea`;
  - reclamada por otro -> sin primaria;
  - bloqueada -> razon y acceso a bloqueos;
  - cerrada -> sin primaria.
- `task_inspector_blockers_test.gleam`
  - lista bloqueos abiertos;
  - empty state claro;
  - add/remove mantiene permisos.
- `task_inspector_details_test.gleam`
  - facts operativos sin duplicacion;
  - automation origin sigue visible cuando exista;
  - pinned notes siguen limitadas.

### Frontend: Shell, A11y Y URL

Crear o ampliar:

- `inspector_shell_test.gleam`
  - raiz con testid estable;
  - close button comun;
  - mobile full-screen class;
  - no apila Card y Task inspectors.
- `detail_tabs_inspector_test.gleam`
  - tabs con count en Trabajo/Notas/Bloqueos cuando aporte valor;
  - labels i18n;
  - tab activa estable.
- `action_menu_link_item_test.gleam`
  - `Abrir en` puede renderizar enlaces con href real;
  - items button y link mantienen roles/nombres accesibles;
  - no se duplican menus locales en Card/Task.
- `empty_state_multi_action_test.gleam`
  - empty state soporta accion primaria y secundaria;
  - mantiene single-action existente;
  - card vacia no necesita `card-empty-work-decision` bespoke a largo plazo.
- `task_item_card_work_row_test.gleam`
  - `task_item` cubre fila de trabajo con estado, owner, meta y acciones;
  - no se requiere fila nueva si la configuracion alcanza el layout objetivo.
- `note_content_test.gleam`
  - no duplica la URL visible cuando ya aparece en el contenido;
  - mantiene enlaces explicitos cuando el contenido no los incluye.
- `url_state_test.gleam`
  - mantener roundtrip show card/task;
  - scope card + show card conserva ids separados;
  - cerrar show limpia solo show.
- `hydration_test.gleam`
  - deep-link de Card Inspector carga cards/tasks/notas/activity;
  - deep-link de Task Inspector carga task/dependencies/notas/activity.

### Backend

Crear o ampliar:

- `activity_http_test.gleam`
  - task activity incluye claim, release, close y note events;
  - card activity incluye eventos propios y, si se decide, descendientes
    acotados;
  - paginacion estable.
- `notes_and_positions_http_test.gleam`
  - pinned notes de card/task con author, url y permisos.
- `tasks_http_test.gleam`
  - blocked task no claimable si la politica lo impide;
  - claimed mode `taken` vs `ongoing` disponible para Task Inspector.
- `seed_operational_model_test.gleam`
  - seed contiene card vacia, card con tasks, card bloqueada, card cerrada;
  - seed contiene task disponible, reclamada, en curso, bloqueada y cerrada;
  - seed contiene notas fijadas y actividad para Card/Task Inspector.

### Browser Validation

Registrar validacion manual o automatizada con `agent-browser`:

1. Desktop Card Inspector empty card.
2. Desktop Card Inspector con 10 tasks.
3. Desktop Task Inspector disponible.
4. Desktop Task Inspector reclamada/en curso.
5. Desktop Task Inspector bloqueada.
6. Mobile Card Inspector.
7. Mobile Task Inspector.
8. Navegacion `Abrir en` desde ambos inspectors.

Gates visuales:

- no `0/0`;
- no cuatro `Ver en` visibles en mobile;
- accion primaria visible arriba;
- destructive actions solo en menu;
- tabs no se rompen;
- un solo eje de scroll en mobile;
- fondo no interactivo en mobile.

## Criterios Medibles De Calidad

Al cerrar la implementacion se debe reportar:

- lineas eliminadas vs anadidas en frontend inspector-related;
- numero de clases CSS retiradas o fusionadas;
- numero de funciones locales sustituidas por componentes compartidos;
- numero de componentes `ui/` nuevos y justificacion por call sites;
- numero de componentes existentes extendidos en lugar de duplicados;
- numero de tests nuevos;
- numero de tests legacy eliminados o actualizados;
- resultado de `rg` para patrones legacy;
- resultado de tests completos.

Metas orientativas:

- maximo 2 componentes compartidos nuevos obligatorios:
  `ui/inspector_shell.gleam` y `ui/inspector_header.gleam`;
- un tercer componente compartido solo si reemplaza al menos 2 call sites o evita
  duplicar logica de rutas/menus;
- cada componente nuevo en `ui/` debe listar en el PR los helpers, clases o
  bloques de markup que elimina;
- reutilizar o extender al menos 6 piezas existentes del barrido:
  `detail_tabs`, `action_menu`, `button`, `empty_state`, `task_item`,
  `activity_feed`, `notes_list`, `pinned_context`, `task_status_indicator` o
  `task_metric`;
- eliminar o absorber al menos 4 helpers/bloques locales de inspectors
  relacionados con header, navegacion contextual, progress text, action bar,
  task rows o summary grids;
- eliminar al menos un sistema visible de progreso crudo en inspectors;
- eliminar los cuatro links visibles `Ver en ...` de Card Show/Task Show;
- reducir duplicacion entre Card Show y Task Show en header, tabs, open-in menu
  y empty states;
- no aumentar dependencias backend salvo necesidad demostrada;
- cubrir al menos 6 estados operativos: card empty, card with work, card
  blocked, task available, task claimed/ongoing, task blocked/closed.

Metas de limpieza comprobables:

- `rg "ui/inspector_tabs|inspector_activity_feed|inspector_notes_list" apps/client/src`
  no debe devolver matches salvo docs/tests negativos.
- `rg "card-empty-work-decision" apps/client/src apps/client/test` debe quedar
  eliminado o documentado como adaptador temporal hacia `empty_state`.
- `rg "card-scoped-navigation|task-context-navigation" apps/client/src apps/client/test`
  no debe encontrar navegacion contextual visible.
- `rg "detail-summary-grid|task-show-summary-grid|task-action-bar" apps/client/src apps/client/test`
  no debe encontrar contratos visuales principales.
- `rg "0/0|1/10" apps/client/src apps/client/test` no debe encontrar copy visible
  de inspectors.

## Orden De Implementacion

### Fase 1: Congelar Contratos

- Confirmar URL/deep-link actual.
- Confirmar seeds disponibles.
- Escribir tests esperados de Card/Task Inspector sin cambiar UI grande.
- Definir copy i18n nuevo.

Gate:

- tests nuevos fallan por UI actual, no por setup.

### Fase 2: DRY Primero, Componentes Nuevos Despues

- Ajustar `detail_tabs`/`show_tabs` para counts y labels de inspectors.
- Extender `action_menu` con item link si `Abrir en` requiere href real.
- Extender `empty_state` para dos acciones sin romper single-action.
- Confirmar que `task_item` cubre filas de trabajo de Card Inspector.
- Extraer politica pura de acciones desde `features/tasks/show/footer.gleam`.
- Crear `InspectorShell`.
- Crear `InspectorHeader`.
- Crear `InspectorOpenInMenu` solo si `action_menu` no puede cubrirlo limpiamente.
- Crear `OperationalSummary` solo si Card y Task duplican el mismo patron.

Gate:

- las extensiones a componentes existentes tienen tests propios;
- Card y Task pueden usar componentes compartidos sin flags excesivos;
- se elimina codigo duplicado o estilos equivalentes;
- no aparecen componentes nuevos prohibidos por el barrido DRY.

### Fase 3: Card Inspector

- Header semantico.
- Open-in menu.
- Trabajo agrupado.
- Resumen operativo.
- Empty card definitivo.
- Notes/activity con empty states mejores.
- Mobile full-screen.

Gate:

- no `0/0`/`1/10`;
- `Trabajo` es default al abrir Card Inspector;
- card vacia abre en `Trabajo` con decision task/subcard;
- `Resumen` no duplica la lista accionable de `Trabajo`;
- `Abrir en` en menu;
- tests Card Inspector verdes.

### Fase 4: Task Inspector

- Header orientado a ejecucion.
- Next action arriba.
- Footer degradado a acciones secundarias o eliminado si ya no aporta.
- Bloqueos como tab fuerte.
- Details/facts sin duplicacion.
- Notes/activity alineadas con Card Inspector.
- Mobile full-screen.

Gate:

- acciones por estado correctas;
- release/delete no son primarias;
- tests Task Inspector verdes.

### Fase 5: Backend/Seeds Solo Si Hace Falta

- Ajustar endpoints si falta dato real.
- Ampliar activity si el feed no cuenta historia suficiente.
- Ampliar seeds para validacion visual.

Gate:

- no hay mocks de UI compensando datos ausentes.

### Fase 6: Limpieza Final

- Retirar CSS legacy.
- Retirar tests legacy.
- Retirar helpers locales sustituidos.
- Actualizar docs de validacion.
- Ejecutar busquedas `rg`.
- Ejecutar test suite y browser validation.

Gate:

- no queda compatibilidad temporal de dos inspectors.

## Riesgos

- Abstraer demasiado pronto y crear un `EntityShow` rigido.
- Cambiar backend sin necesidad.
- Perder casos de automation origin en Task Show.
- Romper deep-links existentes.
- Hacer mobile visualmente full-screen pero no accesiblemente full-screen.
- Mantener `card_progress` en inspectors por conveniencia.
- Optimizar solo card vacia y dejar floja la card con trabajo real.

## Decision Final

Construir Card Inspector y Task Inspector como sistema de producto, no como
modales retocados.

Compartir shell y header, reutilizar tabs, menus, empty states, notes, activity,
task rows, status indicators y botones existentes siempre que la API siga
pequena. Mantener especificos el trabajo de card y la accion de task.

El trabajo no esta cerrado hasta que desaparezcan los signos de UI tecnica
(`0/0`, fracciones crudas, links contextuales dominantes, footers de accion
ambigua) y los tests prueben estados operativos reales del modelo pull.
