# Card And Task Show Redesign Plan

## Objetivo

Rediseñar las vistas de detalle de card y task para que compartan el
lenguaje visual de las nuevas superficies de ScrumBringer sin confundir sus
misiones.

La card es un nodo de contexto, planificacion, seguimiento y navegacion. La
task es una unidad ejecutable, reclamable y operativa. Ambas deben usar el
mismo vocabulario visual, pero no deben parecer la misma pantalla con otro
nombre.

## Principios

1. **Misma gramatica visual, distinta mision.** Card y task comparten cabecera,
   chips, secciones, empty states, tabs, botones, menus secundarios y densidad,
   pero cada una prioriza informacion distinta.
2. **La card no ejecuta trabajo.** La card explica el trabajo, resume su salud,
   permite crear estructura y enlaza a las vistas principales con esa card como
   scope.
3. **La task es la hoja accionable.** La task concentra estado de ejecucion,
   claim, start, complete, release, bloqueos, due date y contexto minimo.
4. **Las notas no son una wiki ni un chat.** Las notas sirven para enlazar
   documentos, conversaciones y decisiones breves. El show debe mostrar solo el
   contexto fijado imprescindible.
5. **No duplicar vistas completas dentro del show.** Plan, Capacidades,
   Personas y Kanban siguen siendo superficies principales. Card Show solo debe
   mostrar previews y enlaces directos.
6. **Sin compatibilidad legacy.** El redisenio no debe adaptar indefinidamente
   el modal antiguo. Si una pieza existe solo para sostener la interfaz anterior,
   debe sustituirse y retirarse.
7. **Rehacer antes que parchear cuando simplifique.** En esta iteracion se
   acepta tirar codigo existente si permite un modelo mas simple, tipado y
   homogeneo.

## Dependencias Y Decisiones Compartidas

Este plan es anterior a la unificacion final de Pool y a `fin_refactor`, pero
debe mantenerse consistente con ellos:

- `Blocked` no es un estado persistido de task. Es una condicion derivada de
  dependencias incompletas.
- Una task bloqueada puede mostrarse en Task Show y en Pool, pero no debe
  ofrecer claim si la politica de claimability lo impide.
- Due date es una senal visual y operativa, no un trigger de automatizacion.
- No reabrir decisiones ya cerradas de Pool, Plan, Capacidades, Personas o
  automatizaciones salvo contradiccion real documentada.

## Estrategia De Sustitucion Limpia

La implementacion debe tratar Card Show y Task Show como una nueva superficie,
no como una evolucion cosmetica del modal actual.

Decisiones:

- Rehacer **Card Show** como vista Lustre normal. Evitar el custom element
  `card-detail-modal` salvo que se demuestre una razon tecnica fuerte para
  conservarlo.
- Retirar el puente `ui/card_detail_host.gleam` si deja de ser necesario. El
  puente actual obliga a serializar cards/tasks a JSON y dificulta pasar datos
  como `due_date` o eventos de navegacion scoped.
- Sustituir tabs especificas antiguas por tabs tipadas por show.
- No mantener `MetricsTab` como tab visible en Card Show ni Task Show. Las
  metricas utiles pasan a senales compactas dentro del resumen; el analisis
  completo vive en las vistas principales.
- Al finalizar, eliminar codigo, CSS y tests que solo validen el contrato viejo.

### Tipos De Tabs Cerrados

```gleam
pub type CardShowTab {
  CardSummaryTab
  CardWorkTab
  CardNotesTab
  CardActivityTab
}

pub type TaskShowTab {
  TaskDetailsTab
  TaskDependenciesTab
  TaskNotesTab
  TaskActivityTab
}
```

`ui/detail_tabs.gleam` debe evolucionar hacia una API generica basada en lista
de tabs:

```gleam
TabItem(id, label, count, has_indicator)
```

Despues de esto, `ui/card_tabs.gleam` y `ui/task_tabs.gleam` deben retirarse si
solo existen para el modal anterior.

La tab `Actividad` entra en la primera iteracion. No debe ser una tab vacia ni
decorativa: debe mostrar eventos operativos reales.

Regla UX: si una tab no tiene datos todavia, debe tener un empty state con una
accion o explicacion operativa breve. No debe existir contenido de relleno.

## Card Show

### Mision

Responder rapidamente:

- Que representa esta card.
- En que estado esta su arbol de trabajo.
- Que trabajo contiene o agrupa.
- Que contexto importante hay fijado.
- A que vistas principales puedo ir con esta card cargada.
- Que acciones estructurales puedo ejecutar segun permisos.

### Estructura

```text
┌ Card: API Cleanup                                      [Active] [x]
│ Hito > Entrega > Historia
│ 12 tasks · 7 done · 2 blocked · due 24 Jun
│
│ Abrir en: [Plan] [Capacidades] [Personas] [Kanban]
├───────────────────────────────────────────────────────────────
│ Resumen
│ Progreso        7 / 12 tasks cerradas
│ Estado          En curso por trabajo descendiente
│ Pool impact     4 tasks disponibles
│ Bloqueos        2 tasks bloqueadas
│
│ Contexto fijado
│ [Doc] Requisitos API Cleanup                         Abrir
│ [Chat] Decision sobre OAuth callback                 Abrir
│ [Nota] QA validara solo flujos criticos              Ver
│
│ Trabajo
│ ┌ Task A ─ Disponible ─ Dev ─ due today ┐
│ ┌ Task B ─ En curso ─ QA ─ bloqueada    ┐
│
│ [ + Task ] / [ + Subcard ]
└───────────────────────────────────────────────────────────────
```

### Navegacion contextual

Card Show debe incluir enlaces visibles a:

- **Plan** con scope card.
- **Capacidades** con scope card.
- **Personas** con scope card.
- **Kanban** con scope card, si la vista existe en la navegacion actual.

Estos enlaces deben ser botones secundarios o chips de navegacion, no acciones
primarias. Su funcion es permitir saltar desde el nodo al analisis completo.

Tratamiento visual recomendado:

- Mostrar como bloque compacto `Abrir en:` bajo el path/resumen, no como CTA
  dominante.
- Usar el mismo vocabulario de botones secundarios de las superficies
  principales.
- Si una vista no esta disponible por permisos, mostrar el enlace deshabilitado
  con razon estable o no mostrarlo si no aporta aprendizaje.
- No duplicar filtros de esas vistas dentro del show.

### Tabs

```text
Resumen | Trabajo | Notas | Actividad
```

- **Resumen:** salud, progreso, contexto fijado, due date, bloqueos, pool
  impact y accesos a vistas.
- **Trabajo:** lista de subcards o tasks, nunca ambas a la vez. La UI debe
  explicar claramente el tipo de contenido de la card.
- **Notas:** notas completas, enlaces, discusiones breves y gestion de fijados.
- **Actividad:** feed operativo con eventos relevantes de activacion, cierre,
  movimiento, cambios de estructura, cambios de due date, dependencias, notas y
  lifecycle de tasks descendientes cuando aporte contexto.

### Acciones

Acciones visibles:

- Crear task, si la card contiene tasks o aun esta vacia.
- Crear subcard, si la card contiene subcards o aun esta vacia.
- Entrar a vistas principales con scope card.

Acciones secundarias en menu:

- Activar.
- Mover.
- Cerrar.
- Eliminar, solo si no tiene historial operativo y la politica lo permite.

Las acciones peligrosas o poco frecuentes no deben estar a mano. Cerrar una
card debe sentirse mas cercano a borrar logicamente que a completar trabajo
ordinario.

Orden recomendado:

- Accion contextual principal: `+ Task` o `+ Subcard`.
- Navegacion contextual: `Abrir en ...`.
- Menu secundario `...`: activar, mover, cerrar, eliminar.

No mezclar acciones de estructura con navegacion ni con resumen de salud.

## Task Show

### Mision

Responder rapidamente:

- Que hay que hacer.
- Si puedo reclamarla o actuar sobre ella.
- Quien la tiene o en que estado de ejecucion esta.
- Si esta bloqueada y por que.
- Cuando vence.
- De que card viene.
- Que contexto fijado necesito para ejecutarla.

### Estructura

```text
┌ Task: Fix OAuth callback                              [Available] [x]
│ API Cleanup > Backend · Dev · P2 · due today
│
│ [Claim] [Bloquear] [...]
├───────────────────────────────────────────────────────────────
│ Detalles
│ Descripcion...
│
│ Estado operativo
│ Disponible para reclamar
│ Sin dependencias abiertas
│
│ Contexto fijado
│ [PR] Implementacion anterior                         Abrir
│ [Chat] Decision OAuth                                Abrir
│ [Nota] Validar callback con usuario sin sesion       Ver
│
│ Contexto
│ Card padre: API Cleanup                 [Abrir card] [Ver en Plan]
└───────────────────────────────────────────────────────────────
```

### Tabs

```text
Detalles | Dependencias | Notas | Actividad
```

- **Detalles:** descripcion, capability, prioridad, due date, tipo, estado y
  campos editables segun permisos.
- **Dependencias:** bloqueos entrantes y salientes, con estados claros y accion
  para abrir la task relacionada.
- **Notas:** notas completas, enlaces, discusiones breves y gestion de fijados.
- **Actividad:** claim, release, start, pause, complete, close, cambios de due
  date, dependencias, notas fijadas/desfijadas y cambios relevantes.

### Acciones

La accion primaria depende del estado:

- Disponible: Claim.
- Claimed: Start, Release o Close segun permisos.
- Ongoing: Complete, Pause/Release si aplica.
- Blocked: inspeccionar bloqueo; no reclamar si la politica lo impide.
- Closed: acciones de lectura y auditoria.

Task Show no debe convertirse en un dashboard. Debe ser una superficie de
ejecucion compacta.

La action bar de Task Show debe ser sticky en la parte inferior del drawer en
desktop y en la parte inferior de la pantalla completa en mobile. En modo
edicion, las acciones visibles cambian a `Cancelar` y `Guardar`; no deben
convivir con acciones de lifecycle.

## Notas Y Contexto Fijado

### Mision de las notas

Las notas sirven para:

- enlazar documentos;
- enlazar conversaciones externas;
- dejar decisiones breves;
- registrar comentarios cortos;
- facilitar traspasos de contexto.

No deben reemplazar:

- documentacion extensa;
- chat operativo;
- checklist de trabajo;
- estados;
- subtareas.

### Contexto fijado

Tanto Card Show como Task Show deben mostrar una seccion principal llamada
**Contexto fijado**.

Reglas:

1. Mostrar como maximo 3 notas fijadas en el show principal.
2. Si hay mas, mostrar un enlace `+N en notas`.
3. Las notas fijadas pueden ser enlaces o texto breve.
4. El contenido se renderiza siempre como texto seguro; no HTML de usuario.
5. Fijar una nota no cambia el estado de la card ni de la task.
6. El usuario debe poder fijar y desfijar desde la tab Notas.
7. Si no hay notas fijadas, la seccion `Contexto fijado` puede ocultarse en el
   resumen para no meter ruido visual. La tab Notas sigue mostrando el empty
   state correspondiente.
8. Fijar/desfijar es una accion compartida visible para el equipo; debe tener
   feedback inmediato y quedar registrada en Actividad.

Permisos:

- Cualquier miembro puede fijar/desfijar sus propias notas.
- Managers pueden fijar/desfijar cualquier nota del proyecto.
- La UI debe explicar cuando una nota no puede fijarse/desfijarse por permisos.

### Diferencia de intencion

En **Card Show**, el contexto fijado representa contexto estable:

- documento de producto;
- enlace a diseno;
- conversacion de decision;
- acuerdo de alcance;
- criterio general.

En **Task Show**, el contexto fijado representa contexto de ejecucion:

- PR;
- bug externo;
- conversacion tecnica;
- log;
- decision puntual;
- nota de traspaso.

### Modelo De Notas Cerrado

Se adopta la opcion de tabla comun `notes` con tablas de relacion especificas
por entidad. Es la opcion preferida porque mantiene FKs reales, evita duplicar
logica de notas y conserva un modelo formalmente claro.

```text
notes
- id
- project_id
- user_id
- content
- url: Option(String)
- pinned: Bool
- created_at
- updated_at

card_notes
- note_id
- card_id

task_notes
- note_id
- task_id
```

Reglas:

- Una nota vive en `notes`.
- La pertenencia a card o task vive en la tabla de relacion correspondiente.
- La primera iteracion permite una nota vinculada a una sola entidad.
- Si en el futuro se permite compartir una nota entre varias entidades, el
  modelo soporta multiples filas de relacion sin cambiar `notes`.
- `pinned` vive en `notes`; fijar una nota no cambia el estado de la card ni de
  la task.

Dominio:

```gleam
pub type NoteSubject {
  CardNoteSubject(card_id: card_id.CardId)
  TaskNoteSubject(task_id: task_id.TaskId)
}

pub type Note {
  Note(
    id: note_id.NoteId,
    project_id: project_id.ProjectId,
    subject: NoteSubject,
    user_id: user_id.UserId,
    content: String,
    url: Option(String),
    pinned: Bool,
    created_at: String,
    updated_at: String,
    author_email: String,
    author_project_role: Option(ProjectRole),
    author_org_role: OrgRole,
  )
}
```

Codigo recomendado:

- `shared/src/domain/note/entity.gleam`
- `shared/src/domain/note/id.gleam`
- `shared/src/domain/note/subject.gleam`
- `shared/src/domain/note/note_codec.gleam`

Evitar `Option(card_id)` + `Option(task_id)` en el dominio. El sujeto debe ser
un ADT para que una nota no pueda no tener destino ni tener dos destinos a la
vez dentro del codigo.

No introducir `NoteKind` al inicio salvo que ya exista una necesidad clara. La
UI debe inferir el tratamiento visual:

- con URL: enlace contextual;
- sin URL: nota breve;
- pinned: aparece en Contexto fijado.

## Reutilizacion

Evitar una abstraccion grande de `EntityDetail`. Incluso rehaciendo ambos shows,
la reutilizacion debe estar en componentes pequenos y contratos tipados.

Preferir componentes pequenos:

- `modal_header` / cabecera consistente.
- chips de estado, due date, prioridad, capability, bloqueos y ownership.
- seccion reutilizable para `Contexto fijado`.
- tabs genericas con ids tipados por cada show.
- menu secundario con razones disabled.
- empty states compactos.
- action bar primaria/secundaria.
- enlaces de navegacion contextual para scope card.
- `note_content` para render seguro de texto y enlaces.
- `entity_path` para rutas de card reutilizando `card_queries.card_path`.

El objetivo es reutilizar vocabulario visual y piezas atomicas, no forzar una
pantalla generica.

### Componentes Nuevos O A Consolidar

- `ui/note_content.gleam`: render seguro de contenido, deteccion de URLs y
  enlaces externos. Debe reutilizar la logica existente de `domain/link_detection`.
- `ui/pinned_context.gleam`: muestra hasta 3 notas fijadas y `+N en notas`.
- `ui/activity_list.gleam`: feed compacto, agrupado por fecha, con actor,
  timestamp, copy operativo y enlace opcional a entidad relacionada.
- `ui/detail_action_bar.gleam`: distribuye accion primaria, secundarias y menu.
- `ui/entity_path.gleam`: muestra path de card/task con wrapping seguro.
- `ui/detail_tabs.gleam`: API generica; no debe codificar `tasks/notes/metrics`.

Reglas de componentes:

- Preferir funciones de vista puras con `Config(msg)` antes que componentes
  Lustre con estado interno.
- Solo usar componente registrable/custom element cuando haya aislamiento real
  de estado o integracion externa que lo justifique.
- Los componentes compartidos no deben importar `features/cards/show` ni
  `features/tasks/show`; la direccion de dependencia debe ser features -> ui.

## Presentacion Del Show

Card Show y Task Show no deben quedar atados al modal antiguo.

Decision:

- Desktop: drawer/panel ancho de detalle.
- Mobile: pantalla completa.
- Modal bloqueante solo para confirmaciones o dialogs secundarios.

Razon:

- Card Show funciona como hub contextual y puerta a otras vistas; un drawer
  mantiene mejor continuidad con Plan/Capacidades/Personas.
- Task Show es operativo; un panel ancho permite mantener accion primaria,
  dependencias y notas sin encerrar al usuario en una pantalla pesada.
- Mobile necesita foco completo y targets tactiles claros.

## Navegacion Scoped

Card Show debe navegar a las vistas principales con card cargada como scope
mediante contrato tipado y URL/query params.

Contrato recomendado:

```gleam
pub type ScopedView {
  ScopedPlan
  ScopedCapabilities
  ScopedPeople
  ScopedKanban
}

pub type ShowNavigation {
  NavigateToScopedView(
    view: ScopedView,
    project_id: Int,
    card_id: Int,
  )
}
```

Formato de URL orientativo:

```text
/app?project=6&view=cards&work_scope=card&card=42
/app?project=6&view=cards&plan_mode=kanban&work_scope=card&card=42
/app?project=6&view=capabilities&work_scope=card&card=42
/app?project=6&view=people&work_scope=card&card=42
```

La navegacion debe poder recargarse y compartirse sin perder contexto.

No reutilizar `scope=card` si `scope` ya existe para otro filtro en `url_state`.
Debe haber un contrato canonico en `url_state.gleam` y tests de round-trip.

## Actividad

La tab Actividad entra en esta iteracion como feed operativo.

Principio UX:

- Actividad muestra cambios que ayudan a entender que paso y quien debe hablar
  con quien.
- No es una auditoria exhaustiva en bruto.
- Por defecto muestra eventos relevantes; si se necesita auditoria completa,
  debe existir un filtro o expansion explicita.
- El feed debe agrupar por fecha, paginar o limitar resultados, y ofrecer `Ver
  mas` para no empujar el contenido principal.

### Card Activity

Eventos incluidos:

- card creada;
- card activada;
- card cerrada;
- card movida;
- subcard creada;
- task creada;
- due date modificada;
- nota creada;
- nota fijada/desfijada;
- dependencia relevante creada/resuelta en task descendiente cuando afecte al
  estado global;
- task descendiente claim/release/start/complete cuando aporte contexto de flujo.

Ejemplo:

```text
Actividad
Hoy
10:42  Ana activo la card
10:18  Luis creo 3 tasks dentro de esta card

Ayer
17:20  Marta movio la card desde Entrega API
16:05  Ana fijo una nota: Requisitos API Cleanup
```

### Task Activity

Eventos incluidos:

- task creada;
- claim;
- release;
- start;
- pause, si existe en el modelo;
- complete;
- close;
- due date modificada;
- dependencia anadida/eliminada/resuelta;
- nota creada;
- nota fijada/desfijada;
- cambios relevantes de titulo, descripcion, capability, prioridad o card padre.

Ejemplo:

```text
Actividad
Hoy
11:03  Luis reclamo la task
11:30  Luis empezo trabajo
12:10  Se anadio bloqueo: Configure secrets

Ayer
18:22  Ana cambio due date a 24 Jun
17:05  Marta fijo una nota: Conversacion OAuth
```

Eventos excluidos:

- hover;
- apertura/cierre de show;
- cambios internos sin valor operativo;
- ruido tecnico de workflows que no ayude al usuario final.

Si algun evento aun no existe en audit log, el slice debe ampliarlo de abajo
arriba en vez de inventar actividad solo en frontend.

### Modelo De Actividad

El dominio debe usar un ADT compartido, no strings sueltos.

```gleam
pub type ActivitySubject {
  ActivityCard(card_id: card_id.CardId)
  ActivityTask(task_id: task_id.TaskId)
}

pub type ActivityKind {
  CardCreated
  CardActivated
  CardClosed
  CardMoved
  TaskCreated
  TaskClaimed
  TaskReleased
  TaskStarted
  TaskClosed
  TaskDependencyAdded
  TaskDependencyRemoved
  NoteCreated
  NotePinned
  NoteUnpinned
  DueDateChanged
}

pub type ActivityEvent {
  ActivityEvent(
    id: activity_id.ActivityId,
    project_id: project_id.ProjectId,
    subject: ActivitySubject,
    kind: ActivityKind,
    actor_user_id: user_id.UserId,
    actor_label: String,
    summary: String,
    created_at: String,
  )
}
```

`shared/src/domain/audit_event/kind_codec.gleam` debe ampliarse o sustituirse
para cubrir la taxonomia real de `audit_events`. No debe quedar una lista
parcial que compile pero pierda eventos.

Permisos:

- Leer Actividad requiere `ReadHistory`.
- Si el usuario no tiene permiso, la tab no se muestra o aparece deshabilitada
  con razon clara, segun el patron usado por el resto del producto.

## Impacto De Codigo Esperado

Areas actuales relevantes:

- `apps/client/src/scrumbringer_client/components/card_detail_modal.gleam`
- `apps/client/src/scrumbringer_client/ui/card_detail_host.gleam`
- `apps/client/src/scrumbringer_client/features/pool/task_detail_header.gleam`
- `apps/client/src/scrumbringer_client/features/pool/task_detail_details.gleam`
- `apps/client/src/scrumbringer_client/features/tasks/detail_editor.gleam`
- `apps/client/src/scrumbringer_client/ui/notes_list.gleam`
- `apps/client/src/scrumbringer_client/ui/modal_header.gleam`
- `apps/client/src/scrumbringer_client/features/layout/work_surface.gleam`
- `apps/client/src/scrumbringer_client/url_state.gleam`
- `shared/src/domain/audit_event/kind_codec.gleam`
- `apps/server/src/scrumbringer_server/use_case/audit_events_db.gleam`

La implementacion debe revisar si `ui/notes_list` puede soportar pinned notes
sin duplicar logica entre card notes y task notes.

### Codigo A Retirar Si La Sustitucion Limpia Se Completa

- `apps/client/src/scrumbringer_client/components/card_detail_modal.gleam`
- `apps/client/src/scrumbringer_client/ui/card_detail_host.gleam`
- `apps/client/src/scrumbringer_client/ui/card_tabs.gleam`
- `apps/client/src/scrumbringer_client/ui/task_tabs.gleam`, si deja de ser el
  contrato de tabs de Task Show.
- `apps/client/src/scrumbringer_client/ui/detail_metrics.gleam`, si no queda
  ningun consumidor real tras mover metricas utiles al resumen.
- CSS asociado solo al modal antiguo:
  - `.card-metrics-*`
  - `.card-task-status`
  - tabs antiguas acopladas a `TasksTab`/`MetricsTab`
  - clases de `card-detail-modal` que no use el nuevo show.
- Tests que solo prueben constructores o etiquetas legacy:
  - expectativas de `MetricsTab` como tab visible;
  - expectativas de `TasksTab` cuando la tab visible sea `Resumen` o
    `Detalles`;
  - tests del custom element si se elimina el custom element.

La limpieza debe verificarse con:

```bash
rg "MetricsTab|TabMetrics|card-metrics|card_detail_host|card-detail-modal|card_tabs|task_tabs" apps/client/src apps/client/test
```

Los matches restantes deben estar justificados o eliminarse.

## Plan De Implementacion Recomendado

### Slice 1: contrato nuevo y limpieza de tabs

- Crear tabs tipadas para Card Show y Task Show.
- Evolucionar `ui/detail_tabs.gleam` hacia API generica.
- Retirar `card_tabs.gleam` y `task_tabs.gleam` si ya no aportan contrato propio.
- Cambiar estado cliente para usar los nuevos tabs.
- Tests de render, aria, indicadores de notas y cambio de tab.
- Asegurar que las tabs se ocultan/deshabilitan por permiso cuando aplique
  (`Actividad` requiere `ReadHistory`).

### Slice 2: notas y contexto fijado bottom-up

- Migrar a `notes` + `card_notes`/`task_notes` como tablas de relacion.
- Anadir `pinned` y `url`.
- Actualizar SQL, queries, presenters, codecs y API cliente.
- Crear accion de fijar/desfijar nota.
- Crear `note_content` y `pinned_context`.
- Reutilizar deteccion de links existente.
- Tests de codec, API, permisos, render seguro y limite de 3 fijadas.
- Crear migracion que preserve notas existentes sin mantener tipos legacy.
- Actualizar seeds con notas fijadas y no fijadas para Card Show y Task Show.

### Slice 3: actividad bottom-up

- Revisar audit log actual.
- Definir `ActivityKind` y mapper de eventos a activity feed.
- Anadir eventos faltantes necesarios para Card Show y Task Show.
- Crear componentes de activity list.
- Tests de eventos incluidos/excluidos, orden y copy visible.
- Anadir endpoints paginados/limitados para card activity y task activity.
- Card activity debe poder consultar eventos del subarbol de forma acotada.

### Slice 4: Card Show nuevo

- Implementar Card Show como vista Lustre normal.
- Cabecera: titulo, path, estado, due date, progreso y chips de salud.
- Navegacion contextual a Plan, Capacidades, Personas y Kanban con scope card.
- Tabs: Resumen, Trabajo, Notas, Actividad.
- Mover acciones peligrosas a menu secundario.
- Retirar emojis y representaciones legacy.
- Tests de navegacion scoped, acciones por permisos, contenido task/subcard y
  contexto fijado.
- Validar que el drawer no tapa permanentemente el contexto ni duplica el panel
  derecho.

### Slice 5: Task Show nuevo

- Implementar Task Show como superficie de ejecucion.
- Cabecera: titulo, path/card padre, capability, prioridad, due date, estado,
  owner y bloqueo.
- Tabs: Detalles, Dependencias, Notas, Actividad.
- Accion primaria por estado.
- Navegacion contextual minima: abrir card padre y ver en Plan.
- Tests de estado, claimability, bloqueos, due date, notas fijadas y lectura en
  closed.
- En mobile, action bar sticky y contenido con un unico eje de scroll.

### Slice 6: retirada de legacy y refactor

- Eliminar modulos, CSS y tests obsoletos.
- Ejecutar busquedas `rg` de simbolos legacy.
- Pasar `gleam-refactor`.
- Ejecutar tests completos.
- Validar visualmente con agent-browser desktop/mobile.

## Tests

### Card Show

- Renderiza cabecera con estado, path, resumen y due date.
- Renderiza enlaces a Plan, Capacidades, Personas y Kanban con scope card.
- No renderiza botones de claim/start/complete.
- Si contiene tasks, muestra accion `+ Task`.
- Si contiene subcards, muestra accion `+ Subcard`.
- Si esta vacia, muestra una accion contextual sin permitir mezclar tasks y
  subcards despues.
- Muestra hasta 3 notas fijadas y `+N en notas` cuando corresponde.
- Acciones secundarias muestran razon disabled cuando no estan permitidas.
- No renderiza `MetricsTab`.
- No usa iconos unicode/emoji para estados de task.
- El evento de navegacion scoped conserva project id, view y card id.

### Task Show

- Renderiza estado operativo, capability, prioridad, due date y card padre.
- Muestra la accion primaria correcta segun estado.
- No muestra enlaces globales innecesarios como accion principal.
- Muestra contexto fijado limitado a 3 elementos.
- Muestra dependencias y bloqueos con etiquetas no basadas solo en color.
- Task bloqueada no ofrece claim si la politica lo impide.
- Task closed queda en modo lectura salvo acciones permitidas.
- No renderiza `MetricsTab`.
- Dependencias tiene tab propia o seccion primaria, no queda mezclada de forma
  ambigua con detalles.

### Notas

- Fijar una nota la hace aparecer en Contexto fijado.
- Desfijar una nota la elimina del resumen principal.
- Notas con URL se renderizan como enlaces seguros.
- Notas sin URL se renderizan como texto breve.
- No se renderiza HTML de usuario.
- Permisos de borrar/editar/fijar se respetan en card y task.
- El mismo renderizador de contenido se usa en lista completa y contexto fijado.
- Los codecs de nota aceptan y emiten `pinned` y `url`.
- El orden de notas fijadas es estable y predecible.
- Fijar/desfijar respeta permisos: autor o manager.
- Crear/fijar/desfijar nota genera actividad visible.
- La migracion conserva notas existentes en la nueva tabla `notes`.

### Actividad

- Card Activity muestra eventos reales de card, estructura, due date, notas y
  flujo descendiente relevante.
- Task Activity muestra eventos reales de lifecycle, due date, dependencias,
  notas y cambios relevantes.
- No aparecen eventos de hover, apertura de show o ruido tecnico.
- El orden es cronologico descendente y agrupable por fecha.
- Si falta audit log, se anade en backend antes de pintar el evento.
- Leer actividad respeta `ReadHistory`.
- Los endpoints limitan/paginan resultados.
- Los eventos usan `ActivityKind`/`AuditEventKind` tipado, no strings filtrados
  ad hoc en frontend.

### Navegacion

- La navegacion scoped usa `work_scope=card` para evitar conflicto con otros
  parametros `scope`.
- `url_state.gleam` tiene parse/serialize round-trip para Plan, Kanban,
  Capacidades y Personas con card scope.
- Recargar la URL mantiene la card seleccionada.

### Limpieza

- No quedan imports a modulos eliminados.
- No quedan clases CSS legacy sin consumidor.
- No quedan tests que validen contratos visuales retirados.
- No queda serializacion JSON innecesaria entre Card Show y el estado Lustre si
  se elimina el custom element.
- No quedan modelos duplicados `CardNote`/`TaskNote` si la migracion a `Note`
  comun se completa.

## Validacion Visual Con Agent Browser

Recorrer al menos:

1. Abrir una card activa con tasks, revisar resumen, trabajo y contexto fijado.
2. Abrir una card activa con subcards, comprobar que no se mezclan acciones de
   task y subcard.
3. Desde Card Show navegar a Plan, Capacidades y Personas con la card cargada.
4. Abrir una task disponible y reclamarla.
5. Abrir una task claimed/ongoing y comprobar acciones primarias.
6. Abrir una task bloqueada y revisar tratamiento visual y dependencias.
7. Fijar y desfijar notas en card y task.
8. Validar desktop y mobile: sin overflow, sin acciones duplicadas, sin modales
   ilegibles.

## Decisiones Cerradas

- Card y task comparten lenguaje visual, no layout identico.
- Card Show enlaza a las vistas principales con scope card.
- Task Show se centra en ejecucion, no en analisis global.
- Las notas son contexto ligero y enlaces, no documentacion extensa.
- Las notas se modelan con `notes` comun y relaciones especificas
  `card_notes`/`task_notes`.
- El show principal muestra solo contexto fijado limitado.
- No se introduce una abstraccion generica de detalle de entidad.
- No se preserva legacy si contradice la nueva estructura.
- `MetricsTab` no forma parte del nuevo show; las senales utiles se integran en
  resumen.
- `Actividad` forma parte de la primera iteracion y debe alimentarse de eventos
  reales.
- Desktop usa drawer/panel ancho; mobile usa pantalla completa.
- La navegacion scoped se refleja en URL/query params.
