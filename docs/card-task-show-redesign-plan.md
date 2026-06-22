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

### Tipos De Tabs Recomendados

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
│ [Plan] [Capacidades] [Personas] [Kanban]
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

### Tabs recomendadas

```text
Resumen | Trabajo | Notas | Actividad
```

- **Resumen:** salud, progreso, contexto fijado, due date, bloqueos, pool
  impact y accesos a vistas.
- **Trabajo:** lista de subcards o tasks, nunca ambas a la vez. La UI debe
  explicar claramente el tipo de contenido de la card.
- **Notas:** notas completas, enlaces, discusiones breves y gestion de fijados.
- **Actividad:** eventos relevantes de activacion, cierre, movimiento, cambios
  de estructura y notas.

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

### Tabs recomendadas

```text
Detalles | Dependencias | Notas | Actividad
```

- **Detalles:** descripcion, capability, prioridad, due date, tipo, estado y
  campos editables segun permisos.
- **Dependencias:** bloqueos entrantes y salientes, con estados claros y accion
  para abrir la task relacionada.
- **Notas:** notas completas, enlaces, discusiones breves y gestion de fijados.
- **Actividad:** claim, release, start, pause, complete, close, cambios y notas.

### Acciones

La accion primaria depende del estado:

- Disponible: Claim.
- Claimed: Start, Release o Close segun permisos.
- Ongoing: Complete, Pause/Release si aplica.
- Blocked: inspeccionar bloqueo; no reclamar si la politica lo impide.
- Closed: acciones de lectura y auditoria.

Task Show no debe convertirse en un dashboard. Debe ser una superficie de
ejecucion compacta.

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

### Modelo minimo recomendado

El modelo debe mantenerse simple, pero debe evitar duplicar dos conceptos de
nota incompatibles.

Opcion preferida si se toca SQL en esta iteracion:

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

Dominio:

```gleam
pub type NoteTarget {
  CardNoteTarget(card_id: Int)
  TaskNoteTarget(task_id: Int)
}

pub type Note {
  Note(
    id: Int,
    project_id: Int,
    target: NoteTarget,
    user_id: Int,
    content: String,
    url: Option(String),
    pinned: Bool,
    created_at: String,
    author_email: String,
    author_project_role: Option(ProjectRole),
    author_org_role: OrgRole,
  )
}
```

Opcion aceptable si se quiere una migracion menor:

```text
CardNote / TaskNote
- content
- url: Option(String)
- pinned: Bool
- created_by
- created_at
```

Pero en ese caso debe existir un `PinnedNoteView`/`NoteView` comun que oculte
las diferencias de shape entre card notes y task notes en la UI.

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
- `ui/detail_action_bar.gleam`: distribuye accion primaria, secundarias y menu.
- `ui/entity_path.gleam`: muestra path de card/task con wrapping seguro.
- `ui/detail_tabs.gleam`: API generica; no debe codificar `tasks/notes/metrics`.

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

### Slice 2: notas y contexto fijado bottom-up

- Anadir `pinned` y `url` al modelo elegido.
- Actualizar SQL, queries, presenters, codecs y API cliente.
- Crear accion de fijar/desfijar nota.
- Crear `note_content` y `pinned_context`.
- Reutilizar deteccion de links existente.
- Tests de codec, API, permisos, render seguro y limite de 3 fijadas.

### Slice 3: Card Show nuevo

- Implementar Card Show como vista Lustre normal.
- Cabecera: titulo, path, estado, due date, progreso y chips de salud.
- Navegacion contextual a Plan, Capacidades, Personas y Kanban con scope card.
- Tabs: Resumen, Trabajo, Notas, Actividad.
- Mover acciones peligrosas a menu secundario.
- Retirar emojis y representaciones legacy.
- Tests de navegacion scoped, acciones por permisos, contenido task/subcard y
  contexto fijado.

### Slice 4: Task Show nuevo

- Implementar Task Show como superficie de ejecucion.
- Cabecera: titulo, path/card padre, capability, prioridad, due date, estado,
  owner y bloqueo.
- Tabs: Detalles, Dependencias, Notas, Actividad.
- Accion primaria por estado.
- Navegacion contextual minima: abrir card padre y ver en Plan.
- Tests de estado, claimability, bloqueos, due date, notas fijadas y lectura en
  closed.

### Slice 5: retirada de legacy y refactor

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

### Limpieza

- No quedan imports a modulos eliminados.
- No quedan clases CSS legacy sin consumidor.
- No quedan tests que validen contratos visuales retirados.
- No queda serializacion JSON innecesaria entre Card Show y el estado Lustre si
  se elimina el custom element.

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
- El show principal muestra solo contexto fijado limitado.
- No se introduce una abstraccion generica de detalle de entidad.
- No se preserva legacy si contradice la nueva estructura.
- `MetricsTab` no forma parte del nuevo show; las senales utiles se integran en
  resumen.
