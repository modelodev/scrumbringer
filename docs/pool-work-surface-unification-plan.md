# Pool Work Surface Unification Plan

## Estado

Plan registrado tras revisar la vista Pool actual, sus componentes frontend, su
cobertura de tests y la filosofia de ScrumBringer.

Fecha de revision: 2026-06-22.

## Objetivo

Unificar Pool con la anatomia visual de Plan, Capacidades y Personas sin
convertirlo en otra vista de estructura.

Pool debe seguir siendo la superficie de ejecucion:

```text
que trabajo abierto hay ahora en el pool,
que puedo reclamar,
que esta bloqueado,
y que accion inmediata puedo tomar.
```

Pool no debe competir con Plan, Kanban, Capacidades o Personas. Su mision no es
explorar el arbol, analizar capacidades o coordinar personas. Su mision es
facilitar pull-flow.

## Diagnostico Actual

### Lo Que Ya Esta Bien

- Pool ya usa `work_surface.header` a traves de
  `features/pool/chrome.gleam`.
- `features/pool/task_card.gleam` ya cubre bien el objeto operativo principal:
  claim, release, complete, bloqueo, hover, due date/urgency, drag, touch y
  preview.
- `features/pool/task_row.gleam` reutiliza `ui/task_item`.
- `features/pool/available_tasks.gleam` ya concentra parte importante de la
  derivacion de tareas visibles.
- El sidebar derecho ya separa correctamente:
  - tareas en curso;
  - mis tareas reclamadas;
  - contexto.
- Hay buena cobertura atomica:
  - `pool_available_tasks_test`;
  - `pool_filters_test`;
  - `pool_chrome_test`;
  - `pool_task_card_test`;
  - `pool_task_row_test`;
  - `pool_my_tasks_dropzone_test`;
  - tests de drag, touch, highlights, create dialog y preferencias.

### Problemas

- Los filtros de Pool siguen siendo propiedad de `features/layout/center_panel.gleam`.
  Esto rompe la direccion que ya seguimos en Plan, Capacidades y Personas:
  cada vista debe ser dueña de su header, controles y cuerpo.
- `center_panel` todavia conoce detalles de filtros de Pool:
  tipo, capacidad, busqueda y scope de capacidades.
- Existe `member_filters_status` y `MemberPoolStatusChanged`, pero la barra
  visible actual no expone claramente un selector de estado.
- Usar `TaskPhase` como filtro de Pool es ambiguo. Pool no deberia filtrar por
  `claimed` o `done` como si fuese una vista historica o de trabajo propio.
- `available_tasks.state` filtra siempre `Available`, por lo que un filtro de
  estado general sobre `TaskPhase` choca con la mision real de Pool.
- Falta un test de composicion de Pool como superficie completa:
  header + control bar propia + body.

## Decision De Producto

Pool debe mostrar trabajo abierto en el pool, separando claramente:

- tareas reclamables ahora;
- tareas abiertas pero bloqueadas;
- el total abierto visible.

No debe ocultar los bloqueos por defecto. ScrumBringer busca fomentar
comunicacion, y los bloqueos son una senal operativa importante.

Por tanto, el filtro principal no debe ser `TaskPhase`. Debe ser un filtro
propio de visibilidad de Pool.

## Tipo Recomendado

Crear un ADT especifico, con nombres de producto:

```gleam
pub type PoolVisibility {
  AllOpen
  ReadyToClaim
  Blocked
}
```

Semantica:

- `AllOpen`: muestra tareas abiertas del pool, reclamables y bloqueadas. Es el
  default recomendado.
- `ReadyToClaim`: muestra solo tareas que el usuario puede reclamar ahora.
- `Blocked`: muestra solo tareas abiertas bloqueadas.

No usar:

```gleam
TaskPhase
```

como filtro visual primario de Pool.

`TaskPhase` puede seguir existiendo como derivacion de estado de task donde sea
necesario, pero no debe modelar la intencion de visibilidad de Pool.

### Ubicacion Del Tipo

`PoolVisibility` debe vivir en frontend, dentro del feature de Pool:

```text
apps/client/src/scrumbringer_client/features/pool/visibility.gleam
```

No debe moverse a `shared`.

Razon:

- no es una entidad de dominio global;
- no forma parte del contrato de persistencia;
- no representa el ciclo de vida real de una task;
- expresa una intencion de vista: que subconjunto del trabajo abierto quiere ver
  el usuario en Pool.

Esto mantiene limpia la frontera:

```text
dominio task -> execution_state / TaskPhase derivado
vista Pool   -> PoolVisibility
```

## Default

El default debe ser:

```gleam
AllOpen
```

con orden inteligente:

1. reclamables primero;
2. bloqueadas despues;
3. dentro de cada grupo, mantener la logica actual de prioridad/posicion/edad
   que ya tenga Pool.

Razon:

- `ReadyToClaim` como default ayuda a elegir rapido, pero esconde friccion.
- `AllOpen` mantiene visibles los bloqueos sin confundirlos con acciones
  disponibles.
- La UI puede hacer que las bloqueadas tengan menor peso visual y una accion
  clara de inspeccion, no de claim.

## Tratamiento Visual De Tareas Bloqueadas

Las tareas bloqueadas deben verse en Pool por defecto cuando la visibilidad sea
`AllOpen`. No deben esconderse, porque ScrumBringer quiere hacer visible la
friccion operativa y fomentar conversacion.

Tampoco deben competir visualmente con las tareas reclamables ni parecer
reclamables por error.

Tratamiento recomendado:

- badge explicito `Bloqueada`;
- indicador de dependencias bloqueantes;
- tono de atencion basado en `danger` o `warning`, pero sutil;
- borde completo o fondo muy leve, nunca una franja lateral nueva;
- sin accion de claim;
- accion secundaria de inspeccion, por ejemplo abrir detalle o `Ver bloqueo`;
- hover/focus puede reutilizar el sistema actual de highlight de dependencias
  bloqueantes.

Evitar:

- fondo rojo fuerte en toda la card;
- patron de alarma permanente;
- ocultar la card bloqueada de `AllOpen`;
- mostrar un boton de claim deshabilitado como accion principal.

Wireframe:

```text
┌────────────────────────────┐
│ Task bloqueada             │
│ Backend · API Cleanup      │
│ [Bloqueada] 2 dependencias │
│ [Ver]                      │
└────────────────────────────┘
```

La intencion es que el usuario vea que existe trabajo bloqueado, entienda que no
puede reclamarlo todavia y tenga una entrada clara para investigar o hablar con
el equipo.

## Anatomia Visual Final

Pool debe tener la misma anatomia general que las demas vistas:

```text
Header
Control bar
Body
```

Wireframe:

```text
┌────────────────────────────────────────────────────────────┐
│ Pool                                                       │
│ Tareas activas disponibles para que el equipo las reclame. │
│                                                            │
│ 12 abiertas  9 reclamables  3 bloqueadas  limite sano 20   │
├────────────────────────────────────────────────────────────┤
│ Buscar...  Tipo [Todos]  Capacidad [Todas]  [Todas/Mias]  │
│ Ver [Abiertas ▼]                            Vista [▦ ≡]    │
├────────────────────────────────────────────────────────────┤
│ Canvas/List de tasks                                       │
└────────────────────────────────────────────────────────────┘
```

Labels recomendadas para `PoolVisibility`:

```text
AllOpen      -> Abiertas
ReadyToClaim -> Reclamables
Blocked      -> Bloqueadas
```

## Header

Titulo:

```text
Pool
```

Proposito:

```text
Tareas activas disponibles para que el equipo las reclame.
```

Summary chips:

- abiertas;
- reclamables;
- bloqueadas;
- limite saludable del pool.

Si el limite saludable se supera, el chip debe usar tono de atencion:

```text
Pool saturado 24/20
```

Ese limite es blando: advierte, no bloquea.

## Control Bar

Crear una control bar propiedad de Pool, por ejemplo:

```text
features/pool/control_bar.gleam
```

Controles:

- busqueda;
- tipo;
- capacidad;
- selector de capacidades:
  - todas;
  - mis capacidades;
- visibilidad de Pool:
  - abiertas;
  - reclamables;
  - bloqueadas;
- vista:
  - canvas;
  - lista.

No incluir scope estructural `Nivel/Card` como control principal.

Opcionalmente, en una iteracion posterior, podria existir un filtro contextual
secundario:

```text
Contexto: Todo el pool | Card activa... | Nivel...
```

Pero no forma parte de esta mejora. Meterlo ahora mezclaria Pool con Plan.

## Body

Mantener los dos modos existentes:

- `Canvas`;
- `List`.

La diferencia es legitima:

- Canvas: cockpit visual, prioridad, decay, due date, drag y lectura rapida.
- Lista: densidad, busqueda y escaneo operativo.

No redisenar `task_card`, `task_row`, `my_tasks_dropzone` ni `now_working`
salvo para adaptarlos a la nueva composicion.

## Reutilizacion

Reutilizar:

- `features/layout/work_surface.gleam`;
- `features/work_filters.gleam`;
- `features/pool/available_tasks.gleam`;
- `features/pool/task_card.gleam`;
- `features/pool/task_row.gleam`;
- `features/pool/my_tasks_dropzone.gleam`;
- `ui/task_item.gleam`;
- `ui/badge.gleam` / `ui/signal_chip.gleam`;
- `ui/empty_state.gleam`;
- estilos existentes de `center-filters-work` solo como vocabulario visual,
  migrandolos o renombrando lo necesario para que Pool sea dueña de su control
  bar.

Evitar:

- crear una abstraccion generica `work_surface_control_bar` antes de que todas
  las vistas tengan APIs estables;
- redisenar las task cards;
- duplicar logica de filtros ya existente en `work_filters`.
- mover `PoolVisibility` a `shared`;
- usar `TaskPhase` como proxy de visibilidad de Pool.

## Cambios De Codigo Esperados

### 1. Nuevo Modelo De Visibilidad

Crear un modulo estrecho, por ejemplo:

```text
apps/client/src/scrumbringer_client/features/pool/visibility.gleam
```

Debe contener:

- `PoolVisibility`;
- `default`;
- `parse`;
- `to_string`;
- `label`;
- predicados de filtrado si encajan.

### 2. Estado

Sustituir o retirar el uso de:

```gleam
member_filters_status: Option(task_status.TaskPhase)
MemberPoolStatusChanged
```

para la vista Pool, si ya no tiene consumidor legitimo.

Preferencia:

```gleam
member_pool_visibility: PoolVisibility
MemberPoolVisibilityChanged(String)
```

Si `member_filters_status` todavia se usa para otro flujo real, renombrar o
aislar su uso para que no modele la visibilidad de Pool.

Decision fuerte:

- `member_filters_status` no debe seguir siendo el estado principal de
  visibilidad de Pool.
- `MemberPoolStatusChanged` no debe ser el mensaje de UI para el selector `Ver`
  de Pool.
- Si tras el refactor no queda consumidor real de esos elementos, deben
  eliminarse junto con sus tests.
- Si algun contrato externo todavia habla de `status`, debe permanecer en la
  frontera correspondiente como valor derivado, no como estado de UI de Pool.

### 3. available_tasks

Extender `available_tasks.Config` con:

```gleam
visibility: PoolVisibility
```

Derivar:

- `AllOpen`: tareas `Available`, bloqueadas y no bloqueadas;
- `ReadyToClaim`: tareas `Available` y `blocked_count == 0`;
- `Blocked`: tareas `Available` y `blocked_count > 0`.

Mantener `work_filters.matches` para tipo, capacidad, mis capacidades y busqueda.

Separacion esperada:

```text
PoolVisibility decide estado operativo visible:
  AllOpen | ReadyToClaim | Blocked

work_filters decide refinamiento transversal:
  busqueda | tipo | capacidad | mis capacidades
```

No mezclar ambos conceptos en un unico tipo generico.

### 4. Control Bar

Mover la toolbar de Pool desde `center_panel` a Pool:

```text
features/pool/control_bar.gleam
```

`center_panel` debe dejar de renderizar filtros de Pool. Debe limitarse a:

- recibir contenido;
- enrutar por vista;
- conservar handlers de drag si siguen perteneciendo a la region central.

### 5. View Config

Actualizar:

```text
features/pool/view_config.gleam
features/pool/view.gleam
features/pool/chrome.gleam
client_view.gleam
```

para pasar:

- task types;
- capabilities;
- filtros;
- callbacks;
- visibility;
- view mode.

### 6. Limpieza

Eliminar:

- filtros Pool obsoletos de `center_panel`;
- mensajes no usados;
- estado no usado;
- estilos `.center-filters-work` si quedan sin consumidor, o renombrarlos a una
  clase propiedad de Pool;
- tests que congelen el ownership antiguo de `center_panel`.

No eliminar:

- `work_filters`, si sigue compartido por Pool y Capacidades;
- `task_card`, `task_row`, `my_tasks_dropzone`;
- `pool_prefs.ViewMode`.

## Tests Requeridos

### Unitarios

- `pool_visibility_default_is_all_open_test`.
- `pool_visibility_parse_roundtrip_test`.
- `pool_visibility_rejects_unknown_test`.
- `available_tasks_all_open_includes_blocked_and_unblocked_test`.
- `available_tasks_ready_to_claim_excludes_blocked_test`.
- `available_tasks_blocked_only_includes_only_blocked_test`.
- `available_tasks_never_includes_claimed_or_closed_test`.
- `available_tasks_filters_type_capability_search_and_my_capabilities_test`.

### Vista

- Pool renderiza `work-surface-header`.
- Pool renderiza su propia control bar.
- Pool renderiza selector `Ver` con `Abiertas`, `Reclamables`, `Bloqueadas`.
- Pool renderiza toggle `Canvas/List`.
- Pool muestra summary chips de abiertas, reclamables, bloqueadas y limite.
- Pool saturado usa tono de atencion y no bloquea.
- Empty state sin reclamables explica que puede haber bloqueadas.
- Empty state de `Blocked` sin bloqueadas no sugiere crear una task nueva.
- Pool no duplica `Mis tareas` en el body central.

### Center Panel

- `center_panel` no renderiza filtros de Pool.
- `center_panel` no renderiza `filter-type`, `filter-capability` ni
  `filter-capability-scope` por si mismo para Pool.
- Plan, Capacidades y Personas siguen sin recibir filtros globales.

### Regresion

- Canvas sigue renderizando task cards.
- Lista sigue renderizando task rows.
- Claim action aparece solo en tareas reclamables.
- Bloqueadas aparecen en `AllOpen` pero sin accion de claim.
- Bloqueadas en `AllOpen` tienen tratamiento visual de atencion sutil:
  badge/estado claro, indicador de dependencias y accion de inspeccion.
- Drag-to-claim sigue funcionando.
- Sidebar derecho sigue mostrando mis tareas reclamadas.
- Shortcuts existentes no se rompen:
  - crear task;
  - foco de busqueda;
  - cerrar dialogos;
  - cambio canvas/list si aplica.

## Validacion Con Agent Browser

Casos minimos:

1. Entrar en Pool.
2. Confirmar que la cabecera y control bar se ven integradas con Plan,
   Capacidades y Personas.
3. Cambiar `Ver`:
   - Abiertas;
   - Reclamables;
   - Bloqueadas.
4. Comprobar que bloqueadas son visibles en Abiertas pero no reclamables.
5. Buscar una task.
6. Filtrar por tipo.
7. Filtrar por capacidad.
8. Cambiar entre todas/mis capacidades.
9. Cambiar Canvas/List.
10. Reclamar una task y confirmar que sale del body central y aparece en el
    sidebar derecho.
11. Probar responsive/mobile:
    - control bar no se desborda;
    - botones tactiles mantienen tamano util;
    - no se duplican acciones.

Repetir la validacion tras corregir cualquier problema visual o funcional.

## Criterios De Aceptacion

- Pool es dueña de header, control bar y body.
- `center_panel` deja de renderizar filtros de Pool.
- La visibilidad de Pool se modela con `PoolVisibility`, no con `TaskPhase`.
- `AllOpen` es el default.
- Las tareas bloqueadas son visibles por defecto, pero no reclamables.
- El sidebar derecho sigue siendo el unico lugar para `Mis tareas`.
- No hay codigo obsoleto de filtros antiguos.
- Tests relevantes pasan.
- La vista queda validada con `agent-browser`.
- Al final se ejecuta `gleam-refactor` y se aplican mejoras razonables de
  simplicidad, tipado y limpieza.
