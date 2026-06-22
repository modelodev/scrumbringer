# Left Sidebar And Hierarchy UI Iteration

Fecha: 2026-06-20

Este documento registra el barrido de interfaz hecho despues del desarrollo de
la nueva jerarquia de cards y due dates. Su objetivo no es describir una
solucion tecnica cerrada, sino convertir los hallazgos en una iteracion de
producto debatible y ejecutable.

## Contexto

ScrumBringer debe seguir siendo un cockpit de flujo pull. La unidad reclamable
es la task. Las cards sirven para descomponer, preparar, agrupar y activar
trabajo, pero no deben volver a parecer elementos asignables o reclamables.

La reestructuracion reciente introdujo:

- cards jerarquicas;
- tasks como hojas reclamables;
- nombres de niveles de card por proyecto;
- cards en `draft`, `active` y `closed`;
- due dates en tasks y cards;
- senales visuales de vencimiento;
- limite blando de salud del pool;
- operaciones de activacion/cierre/movimiento.

El resultado actual tiene base de dominio valiosa, pero la interfaz no comunica
todavia el modelo mental deseado.

## Barrido De Interfaz

La revision se hizo con `agent-browser` sobre la app local en:

- `http://127.0.0.1:8443`
- proyecto `Default`;
- proyecto `E2E Tree 081743`;
- viewport desktop;
- viewport movil `390x844`.

Capturas guardadas durante la auditoria:

- `/tmp/scrumbringer-ui-audit/01-pool-default.png`
- `/tmp/scrumbringer-ui-audit/02-cards-kanban-default.png`
- `/tmp/scrumbringer-ui-audit/03-depth-initiatives-default.png`
- `/tmp/scrumbringer-ui-audit/04-depth-features-empty-default.png`
- `/tmp/scrumbringer-ui-audit/05-capabilities-default.png`
- `/tmp/scrumbringer-ui-audit/06-people-default.png`
- `/tmp/scrumbringer-ui-audit/07-cards-kanban-e2e-tree.png`
- `/tmp/scrumbringer-ui-audit/08-depth-initiatives-e2e-tree.png`
- `/tmp/scrumbringer-ui-audit/09-depth-features-e2e-tree.png`
- `/tmp/scrumbringer-ui-audit/10-card-detail-e2e-taskgroup.png`
- `/tmp/scrumbringer-ui-audit/11-mobile-kanban-no-nav.png`

Nota: el documento de necesidades de usuarios `temporal.md` no estaba presente
en el arbol de trabajo durante esta revision. Esta iteracion debe contrastarse
con ese documento cuando vuelva a estar disponible.

## Hallazgos

### H1. El sidebar mezcla vistas y niveles

El sidebar izquierdo muestra como entradas hermanas:

- Pool
- Tarjetas
- Initiatives
- Features
- Task groups
- Capacidades
- Personas

Esto comunica que `Initiatives`, `Features` y `Task groups` son vistas
principales equivalentes a `Pool` o `Personas`. En realidad son nombres
configurables de niveles de card dentro de un proyecto.

Codigo relacionado:

- `apps/client/src/scrumbringer_client/features/layout/left_panel.gleam`
- `view_work_section` inserta `Cards` y despues `view_depth_nav_links`.

Riesgo de producto:

- El usuario no entiende si esta navegando por una vista, un tipo de entidad o
  un filtro.
- El sidebar se hace mas largo por cada nivel configurado.
- El modelo deja de parecer simple.

### H2. La vista por nivel es un kanban filtrado, no una vista jerarquica

Al entrar en `Tarjetas`, `Initiatives`, `Features` o `Task groups`, el centro
mantiene el mismo titulo `Kanban` y la misma estructura de columnas:

- Pendiente
- En curso
- Cerrada

La profundidad solo filtra cards en `cards_at_depth`, pero la superficie no
cambia de intencion.

Codigo relacionado:

- `apps/client/src/scrumbringer_client/client_view.gleam`
- `build_center_panel` siempre renderiza `kanban_board.view` para
  `cards_content`.
- `kanban_config` recibe `cards_at_depth(cards, member_card_depth_filter)`.

Riesgo de producto:

- El usuario espera ver una estructura, pero ve un tablero de estados.
- Una vista vacia por nivel parece rota, no una ausencia valida de cards.
- La jerarquia queda invisible justo en la pantalla que deberia explicarla.

### H3. La vista `Tarjetas` aplana cards de distintos niveles

En el proyecto con arbol real, `Tarjetas` muestra juntas cards de niveles
distintos, por ejemplo:

- root;
- initiative;
- task group.

No aparece path, nivel, indentacion, breadcrumb ni relacion padre/hijo clara.

Riesgo de producto:

- Se pierde la ventaja de tener jerarquia.
- Una card de alto nivel parece comparable a una card hoja.
- El usuario no sabe si abrir una card es navegar hacia abajo, gestionarla o
  ejecutarla.

### H4. La vista de jerarquia preparada ya no debe duplicar perfiles

`apps/client/src/scrumbringer_client/features/hierarchy/scope_view.gleam`
contenia conceptos de perfil que solapaban el sidebar:

- `TrackingProfile`;
- `CoordinationProfile`;
- `ExecutionProfile`.

Esos perfiles no deben formar parte de la superficie activa. La UI canonica para
Plan se expresa ahora como:

- `Scope`: `Proyecto`, `Nivel` o `Card`;
- `Mode`: `Estructura` o `Kanban`;
- detalle contextual en el area central.

`scope_view.gleam` queda limitado a scopes reales de jerarquia (`DepthScope` y
`CardScope`) para no mantener un segundo sistema de navegacion.

Riesgo de producto:

- Hay complejidad en codigo sin impacto real en la experiencia.
- Futuras iteraciones pueden duplicar conceptos si no se decide que superficie
  queda como canonica.

### H5. El panel derecho mantiene `Mis tarjetas`

El panel derecho muestra `MIS TARJETAS` cuando una card contiene tareas
reclamadas por el usuario.

Codigo relacionado:

- `apps/client/src/scrumbringer_client/features/layout/right_panel.gleam`
- `apps/client/src/scrumbringer_client/features/layout/right_panel_data.gleam`

Problema:

- La decision de producto fue que una card nunca se reclama.
- El texto `Mis tarjetas` reintroduce el modelo anterior.

Riesgo de producto:

- El usuario puede pensar que tiene ownership de cards.
- La diferencia entre card y task se vuelve ambigua.

### H6. En movil no hay navegacion equivalente

En `max-width: 768px`, el CSS oculta sidebar izquierdo y derecho:

- `.panel-left { display: none; }`
- `.panel-right { display: none; }`

Codigo relacionado:

- `apps/client/src/scrumbringer_client/styles/layout.gleam`

Resultado observado:

- En movil quedan filtros y contenido.
- No hay acceso visible a proyecto, Pool, Plan/Tarjetas, niveles, Capacidades,
  Personas o perfil.

Riesgo de producto:

- La app queda parcialmente no navegable en movil.
- Las vistas nuevas no son validables en responsive.

### H7. Due date esta razonablemente alineado

Durante el barrido, las cards vencidas muestran fecha en rojo/negrita y las
tasks mantienen senales compactas de urgencia. Esto parece alineado con la
decision de producto: due date es una senal de salud del flujo, no una prioridad
automatica ni una asignacion.

Riesgo residual:

- Conviene comprobar que todos los estados historicos (`done`, `closed`) reducen
  severidad visual.
- Conviene validar visualmente hover, pool, card detail y movil en una historia
  especifica.

## Diagnostico

El modelo de dominio va por delante de la interfaz.

El problema no es que falten entidades, sino que la UI no tiene todavia una
arquitectura de informacion que explique:

- donde se planifica;
- donde se activa trabajo;
- donde se reclama;
- donde se ve la salud por capacidades;
- donde se entiende la jerarquia.

La solucion no deberia ser anadir mas vistas al sidebar. Eso agravaria el
problema. La solucion debe reducir el sidebar y mover la complejidad jerarquica
dentro de una superficie principal dedicada.

## Principios Para La Iteracion

1. El sidebar debe contener modos de trabajo, no niveles de datos.
2. Los nombres de niveles del proyecto deben aparecer dentro de la vista de
   planificacion, no como navegacion global.
3. `Pool` debe seguir siendo el lugar de reclamacion.
4. `Capacidades` debe seguir siendo la vista de ejecucion por manos necesarias.
5. `Personas` debe seguir siendo la vista de disponibilidad/equipo.
6. Las cards deben parecer estructura, compromiso y preparacion; no ownership
   personal.
7. El kanban de cards debe ser un modo posible, no la representacion base de
   la jerarquia.
8. Las vistas vacias deben ensenar el modelo, no solo mostrar columnas vacias.
9. La experiencia movil debe tener navegacion propia, no depender de sidebars
   ocultos.

## Decision Fuerte: Sidebar + Scope + Mode

ScrumBringer no debe crear una pantalla distinta por cada entidad, nivel o
pregunta operativa. Las vistas principales deben componerse con tres conceptos:

- `Sidebar`: que vista principal esta usando el usuario.
- `Scope`: sobre que conjunto de trabajo se mira dentro de esa vista.
- `Mode`: variante interna de esa vista cuando aporta claridad.

Esta decision permite cubrir mas necesidades con menos pantallas y evita que la
flexibilidad de niveles de cards convierta la navegacion en una lista creciente
de vistas.

La etiqueta `Lens` no debe aparecer como selector visible si el sidebar ya ha
elegido la vista. Por ejemplo, dentro de `Capacidades` no debe haber otro
control que permita elegir `Kanban`, `Personas` o `Bloqueos`.

Lectura de UI:

```text
Sidebar = Pool | Plan | Capacidades | Personas
Scope = Proyecto | Cards activas | Card | Nivel
Mode = variante propia de la vista actual
Filters = reducen el resultado, no cambian de vista
```

### Scopes

Un `Scope` define el alcance de datos:

```text
Project
ActiveCards
CardSubtree(card_id)
Depth(depth)
```

Lectura de producto:

- `Project`: todo el proyecto.
- `ActiveCards`: todas las cards activas del proyecto.
- `CardSubtree(card_id)`: una card concreta y todo lo que cuelga de ella.
- `Depth(depth)`: todas las cards de un nivel configurado del proyecto.

La vista por card debe mostrar todo lo que exista por debajo de esa card:

- subcards;
- tasks hoja;
- capacidades agregadas desde tasks;
- bloqueos derivados;
- avance global;
- due dates y riesgo;
- personas trabajando en tasks descendientes;
- impacto de activacion o cierre cuando aplique.

La vista por nivel debe mostrar todas las cards de esa profundidad, con su
contexto:

- padre o path;
- estado;
- progreso agregado;
- capacidades pendientes/completadas;
- bloqueos derivados;
- riesgo y vencimiento;
- impacto si una card se activa.

### Regla De Scope Comun

`Plan`, `Capacidades` y `Personas` deben compartir el mismo lenguaje de scope.
No debe existir una barra de filtros propia para `Personas` desconectada del
resto de vistas.

La cabecera de estas vistas debe seguir esta gramatica:

```text
Vista principal
Proposito breve

Scope: [ Proyecto | Nivel | Card ] [ selector contextual ]
Modo:  [ variante propia de la vista ] cuando aplique
Buscar: [ texto dentro del scope ]
Filtros secundarios
Resumen en chips
```

Implicaciones:

- `Personas` puede verse para todo el proyecto, para un nivel o para una card.
- `Scope = Card` en `Personas` muestra personas implicadas en esa card y todo
  su subarbol.
- `Scope = Nivel` en `Personas` muestra coordinacion humana sobre todas las
  cards activas de ese nivel.
- La busqueda de `Personas` debe buscar dentro del scope por persona, task,
  card y capacidad.
- El selector de card no debe ser un `select` simple. Debe comportarse como un
  combobox con busqueda, mostrando cards activas y su path para evitar
  ambiguedad en proyectos grandes.
- Los filtros especificos de cada vista refinan el resultado, pero no cambian
  la vista principal ni sustituyen al scope.

### Vistas Y Modos

```text
Pool
Plan: Estructura | Kanban
Capacidades: Lista | Matriz
Personas
```

Lectura de producto:

- `Pool`: que puedo reclamar ahora.
- `Plan / Estructura`: como se descompone el trabajo y que pasaria si se
  activa, cierra o mueve una rama.
- `Plan / Kanban`: como fluye el trabajo activo por estado inferido.
- `Capacidades / Lista`: que capacidades existen y donde queda actividad.
- `Capacidades / Matriz`: donde se concentra el trabajo por card y capacidad.
- `Personas`: quien esta trabajando en que.

Las preguntas de bloqueos y riesgo se expresan inicialmente como senales,
filtros y columnas dentro de estas vistas. Solo deberian convertirse en vista
principal si despues demuestran una necesidad no cubierta.

### Regla De Producto

No se crean pantallas como `Hitos`, `Entregas`, `Historias`, `Dashboard de
card`, `Dashboard de nivel` o `Bloqueos de card` como rutas principales
separadas. Cada vista principal usa scope y, si hace falta, modo interno.

Ejemplos:

```text
Sidebar: Capacidades
Scope: Card(Q3 Plataforma)
Mode: Matriz
```

Responde: que capacidades tiene esta card por debajo y cuales estan completas.

```text
Sidebar: Plan
Scope: Nivel(Entrega)
Mode: Kanban
```

Responde: como estan todas las entregas del proyecto.

```text
Sidebar: Plan
Scope: Proyecto
Mode: Estructura
Filtro: con bloqueos
```

Responde: que trabajo activo esta esperando dependencias.

Esta decision es base para `Plan` y para cualquier dashboard centralizado. Si
una necesidad nueva no encaja como vista principal + scope + modo/filtro, debe
justificarse antes de crear una nueva pantalla principal.

## Propuesta De Producto

### Sidebar Izquierdo

Reducir la seccion principal de trabajo a:

- Pool
- Plan
- Capacidades
- Personas

`Plan` sustituye a `Tarjetas` como superficie de cards y jerarquia. El termino
`Tarjetas` puede seguir existiendo en copy secundaria si aporta claridad, pero
no debe ser la etiqueta principal si el objetivo es explicar planificacion y
descomposicion.

Estructura propuesta:

```text
Proyecto
[ E2E Tree 081743 v ]

TRABAJO
[ + Nueva tarea   ]
[ + Nueva card    ]

Pool
Plan
Capacidades
Personas

CONFIGURACION
...
```

Razon:

- El sidebar queda estable aunque el proyecto tenga 1, 3 o 5 niveles.
- Los niveles dejan de competir con vistas principales.
- `Plan` nombra la intencion de alto nivel: preparar y ordenar trabajo futuro.

### Vista Plan

`Plan` debe ser la superficie canonica para entender, preparar y modificar la
estructura de cards. No es una vista para reclamar trabajo y no debe competir
con `Pool`, `Capacidades` o `Personas`.

Decision cerrada:

- el sidebar decide la vista principal: `Pool`, `Plan`, `Capacidades`,
  `Personas`;
- `Plan` muestra una cabecera con scope, modo y filtros;
- no hay selector visible de `Lens`, porque seria redundante con el sidebar;
- `Plan / Estructura` es la vista base;
- `Plan / Kanban` es un modo de Plan, no una entrada separada del sidebar;
- el centro funciona como un explorador de estructura: tabla-arbol y detalle
  contextual;
- el panel derecho sigue siendo `Mi trabajo` y no cambia de responsabilidad.

Formula de navegacion:

```text
Sidebar = vista principal
Scope = Proyecto / Nivel / Card
Modo = Estructura / Kanban
Filtros = Estado / Orden / Buscar / Cerradas
Acciones = contextuales por permisos y estructura de card
```

Objetivo de la vista:

```text
Plan
Estructura de cards y trabajo preparado.

Scope: [ Proyecto v ]                       Buscar: [          ]
Modo:  [ Estructura ] [ Kanban ]

Estado: [ Abiertas v ] Orden: [ Riesgo v ] [ ] Cerradas

3 niveles   12 cards   38 tasks   9 disponibles   4 al activar
```

El cuerpo principal es una tabla-arbol densa. No debe parecer un diagrama de
mapa mental ni un backlog tradicional con tarjetas grandes.

```text
+------------------------------------------------------------------------------+
| Card / Arbol                     Estado   Tasks   Al activar    Vence   Acc. |
+------------------------------------------------------------------------------+
| v Hito Q3 Plataforma             Active   12/38   ya activo     30 jun  Ver  |
|   v Entrega Portal clientes      Active   8/21    ya activo     28 jun  Ver  |
|     Historia API Cleanup         Active   3/5     ya activo     vencida Ver  |
|     Historia Checkout nuevo      Draft    0/8     +8            28 jun  Ver  |
|     Historia Emails sistema      Active   2/4     ya activo     -       Ver  |
|   > Entrega Infraestructura      Draft    0/12    +12           -       Ver  |
+------------------------------------------------------------------------------+
```

Cuando `Scope = Nivel`, la misma vista cambia la proyeccion sin crear otra
pantalla. La primera columna usa el nombre visible configurado del nivel.

```text
Plan
Estructura de cards y trabajo preparado.

Scope: [ Nivel v ] [ Historias v ]             Buscar: [ api      ]
Modo:  [ Estructura ] [ Kanban ]
Estado: [ Abiertas v ] Orden: [ Riesgo v ] [ ] Cerradas

9 Historias   18 tasks   6 disponibles   2 bloqueadas

+--------------------------------------------------------------------------------+
| Historia             Padre                 Estado   Tasks   Al activar  Vence |
+--------------------------------------------------------------------------------+
| API Cleanup          Q3 / Portal clientes  Active   3/5     ya activo    vencida|
| Checkout nuevo       Q3 / Portal clientes  Draft    0/8     +8           28 jun |
| Emails sistema       Q3 / Portal Core      Active   2/4     ya activo    -      |
+--------------------------------------------------------------------------------+
```

Cuando `Scope = Card`, el centro puede dividirse en tabla-arbol y detalle
contextual. El detalle vive en el area central, no en el panel derecho global.

```text
+-----------------------------------+------------------------------------------+
| Estructura                        | API Cleanup                              |
|                                   | Active - Historia                        |
| v Q3 Plataforma                   |                                          |
|   v Portal clientes               | 5 tasks - 3 disponibles - 1 bloqueada    |
|     * API Cleanup                 | Backend 3 - QA 1                         |
|     o Checkout nuevo              | Vence: vencida                           |
|                                   |                                          |
|                                   | Contenido                                |
|                                   | Revisar contratos API       disponible  |
|                                   | Migrar auth middleware      reclamada   |
|                                   | Limpiar endpoints legacy    en curso    |
|                                   |                                          |
|                                   | [ + Task ] [ Mas v ]                     |
+-----------------------------------+------------------------------------------+
```

Reglas de contenido:

- Si una card contiene subcards, el detalle prioriza subcards directas.
- Si una card contiene tasks, el detalle prioriza tasks directas.
- No se muestran cards y tasks como colecciones equivalentes si el modelo impide
  mezclar ambas.
- Las capacidades, personas, bloqueos y riesgo aparecen aqui solo como resumen
  compacto; sus vistas completas viven en `Capacidades`, `Personas` o futuras
  vistas especificas.
- `Plan / Estructura` no permite reclamar trabajo. Las acciones sobre tasks
  siguen el modelo de Pool y detalle de task.

Acciones contextuales:

- `+ Subcard`: visible si la card acepta subcards y el usuario puede gestionar
  estructura.
- `+ Task`: visible si la card acepta tasks. En card activa, la task creada
  entra al Pool; en card draft, queda preparada hasta activacion.
- `Activar subarbol`: accion de manager, muestra impacto de tasks que entrarian
  al Pool y aviso si supera el limite blando del proyecto.
- `Cerrar`: accion secundaria, no a mano; bloquea si hay descendant tasks
  claimed/ongoing.
- `Mover a...`: accion secundaria bajo `Mas`, nunca drag/drop libre en esta
  primera version.
- `Eliminar`: deshabilitado si hay historial operativo y explica que debe
  cerrarse en su lugar.

Movimiento de card:

```text
Mas v
  Mover a...
  Cerrar...
  Eliminar   disabled si hay historial

Mover API Cleanup

Padre actual
Q3 Plataforma / Portal clientes

Nuevo padre
[ Buscar entrega... ]

Destinos validos
o Portal Core
o Infraestructura
o Pagos

No disponibles
Checkout nuevo - No es una Entrega
API Cleanup - No puede moverse bajo si misma

[Cancelar] [Mover]
```

La vista cubre una necesidad no cubierta por el resto del sidebar:

- `Pool`: responde que puedo reclamar ahora.
- `Capacidades`: responde que manos hacen falta y donde hay carga.
- `Personas`: responde quien esta haciendo que.
- `Plan / Estructura`: responde que hemos decidido construir, como esta
  descompuesto, donde vive cada cosa y que pasaria si activamos, cerramos o
  movemos una parte del arbol.

Reutilizacion esperada en codigo:

- extraer queries comunes de scope/arbol antes de implementar nueva UI;
- reutilizar `work_surface` para cabecera/resumen;
- generalizar `scope_bar` para que no este acoplado a capacidades;
- crear componentes pequenos para tabla operativa, indentacion de arbol,
  breakdown de estado y celda/accion de drill-down;
- no reutilizar `card_with_tasks_surface` para la tabla-arbol si fuerza un
  patron de cards grandes o nested cards.

Tipos esperados:

```text
PlanScope = ProjectScope | LevelScope(Int) | CardScope(Int)
PlanMode = StructureMode | KanbanMode
PlanFilters = estado + orden + busqueda + include_closed
StructureRow = CardRow(depth, card, path, rollup, allowed_actions)
StructureDetail = SubcardsDetail(...) | TasksDetail(...) | EmptyCardDetail(...)
CardAction = CreateSubcard | CreateTask | ActivateSubtree | MoveCard | CloseCard | DeleteCard
ActionAvailability = Available | Disabled(reason)
```

Estos tipos pueden tener otros nombres si encajan mejor con la nomenclatura
existente, pero deben hacer explicito que una card con subcards y una card con
tasks no son el mismo caso visual.

### Plan De Mejora De La Vista Plan

Revision realizada sobre:

- `http://192.168.1.120:8443/app/pool?project=6&view=cards`;
- scope `Proyecto`, `Nivel` y `Card`;
- modo `Estructura`;
- modo `Kanban`;
- viewport desktop y movil.

Diagnostico:

La implementacion actual ya captura la arquitectura base de la decision
`Sidebar + Scope + Mode`, pero todavia arrastra patrones anteriores de `Pool` y
del kanban antiguo. La vista empieza a comunicar jerarquia, pero no separa con
suficiente claridad planificacion, ejecucion y reclamacion.

Problemas observados:

- La barra superior de filtros sigue pareciendo del `Pool`: `Mis capacidades`,
  `Tipo`, `Capacidad` y `Buscar` aparecen por encima de `Plan`.
- `Scope = Card` sin card seleccionada sigue mostrando el arbol completo.
- El selector de card usa una experiencia tipo `input + datalist`, insuficiente
  para proyectos con muchas cards activas.
- En modo `Kanban`, el titulo principal pasa a `Kanban`; deberia seguir siendo
  `Plan` con `Kanban` como modo interno.
- `Plan / Kanban` permite reclamar tasks, lo que rompe la regla de que el
  trabajo se reclama en `Pool`.
- Cada fila de `Plan / Estructura` muestra demasiadas acciones visibles:
  `Ver`, `+ Subcard`, `+ Task`, `Activar subarbol`, `Mover`, `Cerrar`,
  `Eliminar`.
- Cerrar y eliminar aparecen demasiado a mano, cuando deben comportarse como
  operaciones excepcionales.
- La tabla fuerza columnas estrechas y rompe encabezados como `Estado`,
  `Tasks`, `Al activar` y `Vence`.
- En movil, la tabla se degrada a una lista larga de celdas y acciones
  repetidas; no se siente como una vista movil disenada.
- El sidebar movil sigue sin navegacion primaria equivalente.

Objetivo de mejora:

`Plan` debe sentirse como una superficie de planificacion estructural. Debe
servir para entender, preparar, activar, cerrar o mover partes del arbol, pero
no para reclamar trabajo. La vista debe compartir lenguaje visual y codigo base
con `Capacidades` y `Personas` sin perder su mision propia.

#### Norte Arquitectonico

El destino deseable sigue siendo que `Plan`, `Capacidades` y `Personas`
compartan un contrato comun de scope, cabecera y filtros base. Sin embargo, esa
extraccion no debe abrir la iteracion.

Razon:

- El scope actual ya esta parcialmente compartido, aunque mal nombrado.
- `features/plan/scope_bar.gleam` ya lo consumen `Plan`, `Plan / Kanban` y
  `Capacidades`.
- Moverlo al principio convertiria una mejora de producto en una migracion de
  nombres y API.
- Primero debe estabilizarse el comportamiento visible de `Plan`.

Destino tecnico posterior:

```text
features/work_scope/types.gleam
features/work_scope/queries.gleam
features/work_scope/scope_bar.gleam
features/work_scope/card_picker.gleam
```

Ese destino solo debe abordarse cuando `Plan`, `Plan / Kanban` y `Capacidades`
hayan demostrado un contrato estable.

#### 1. Sacar filtros de `Pool` fuera de `Plan`

`center_panel` no debe renderizar filtros globales antes de todas las vistas.

Regla:

- `Pool` renderiza filtros de trabajo reclamable.
- `Plan` renderiza filtros de estructura.
- `Capacidades` renderiza filtros de capacidades.
- `Personas` renderiza filtros de coordinacion.

Cabecera esperada de `Plan`:

```text
Plan
Estructura de cards y trabajo preparado.

Scope: [ Proyecto v ]
Modo:  [ Estructura ] [ Kanban ]
Buscar: [ card, task... ]
Estado: [ Todas v ] Orden: [ Arbol v ] [ ] Cerradas

10 Cards   3 Tasks   3 Disponibles   0 Al activar   0 Bloqueada
```

No deben aparecer `Mis capacidades`, `Tipo` o `Capacidad` encima de `Plan` salvo
que sean filtros explicitamente propios del modo actual y esten justificados.

Tests minimos:

- `Plan` no renderiza filtros de `Pool`: `Tipo`, `Capacidad` ni
  `Mis capacidades`.
- `Pool` conserva sus filtros actuales.
- `Capacidades` y `Personas` no pierden sus filtros propios.

#### 2. Corregir `Scope = Card`

Si `Scope = Card` no tiene card seleccionada, la vista no debe caer al proyecto
entero.

Estado correcto:

```text
Selecciona una card activa
Busca una card para ver su subarbol, capacidades, tasks y riesgo.

[ Buscar card activa... ]
```

Reglas:

- `Scope = Card` sin seleccion renderiza empty state, no arbol completo.
- El empty state debe mantener visible el selector de card.
- No debe activar automaticamente una card ni cambiar el scope sin accion del
  usuario.

Tests minimos:

- `Scope = Card` sin seleccion no muestra filas del arbol.
- `Scope = Card` con seleccion muestra solo esa card y su subarbol.
- Cambiar de `Card` a `Proyecto` restaura el arbol completo.

#### 3. Separar `Plan / Kanban` del kanban reclamable

El modo `Kanban` de `Plan` no debe reutilizar sin control el kanban que muestra
tasks reclamables. Debe existir una variante especifica de lectura de cards:

```text
features/plan/kanban_view.gleam
```

Reglas:

- El titulo de superficie sigue siendo `Plan`.
- `Kanban` aparece como modo activo.
- No hay botones de reclamar tasks.
- Las columnas representan estado inferido, no transiciones manuales.
- Las cards muestran path, nivel, rollup de tasks, riesgo y acciones
  contextuales.
- El click principal abre detalle de card o entra en la card segun la decision
  de navegacion que se cierre.

Acciones permitidas:

- `Ver`;
- `Entrar` si la card tiene subcards;
- `+ Task` o `+ Subcard` si aplica;
- `Activar subarbol` como accion secundaria y confirmada.

Tests minimos:

- `Plan / Kanban` no renderiza botones de reclamar tasks.
- `Plan / Kanban` no renderiza acciones de arrastrar tasks.
- El titulo de superficie sigue siendo `Plan`; `Kanban` aparece como modo.
- Las columnas siguen siendo lectura inferida, no destinos de drag/drop.

#### 4. Reducir acciones visibles por fila

La fila de `Plan / Estructura` debe optimizar lectura, no exponer toda la
administracion en primer plano.

Acciones visibles recomendadas:

```text
[Ver]  [+]  [...]
```

Lectura:

- `Ver`: abre detalle.
- `+`: crea el unico tipo valido segun el contenido de la card.
- `...`: menu secundario con `Activar subarbol`, `Mover a...`, `Cerrar` y
  `Eliminar`.

Reglas:

- `Cerrar` y `Eliminar` nunca deben ser acciones prominentes.
- `Eliminar` deshabilitado debe explicar que hay historial operativo y que debe
  cerrarse en su lugar.
- `Activar subarbol` debe mostrar impacto de pool antes de confirmar.
- `Cerrar` debe bloquear si existen descendant tasks claimed/ongoing.

Tests minimos:

- La fila renderiza `Ver`, una accion contextual `+` y un menu secundario.
- El menu secundario conserva razones disabled de cerrar/eliminar.
- Cerrar/eliminar no aparecen como acciones prominentes.
- La accion `+` respeta card con subcards, card con tasks y card vacia.

#### 5. Mejorar selector de card

El selector de card actual puede quedarse corto en proyectos grandes. Debe
mejorarse antes de extraerlo como componente compartido.

Requisitos:

- lista solo cards activas;
- muestra titulo, path, nivel visible e id si hace falta desambiguar;
- busca por titulo y path;
- resuelve duplicados por path/id;
- no acepta texto parcial ambiguo como seleccion valida;
- mantiene foco y navegacion por teclado;
- expone estado sin resultados;
- puede reutilizarse posteriormente por `Capacidades` y `Personas`.

Tests minimos:

- dos cards con el mismo titulo se distinguen por path/id.
- escribir texto parcial no cambia scope si no hay seleccion exacta.
- teclado permite navegar resultados y seleccionar.
- cards `Draft` y `Closed` no aparecen como opciones de scope de card activa.

#### 6. Crear una tabla-arbol operacional local a Plan

`ui/data_table.gleam` es valida para tablas generales, pero `Plan` necesita una
tabla-arbol con comportamiento propio.

Propuesta inicial:

```text
features/plan/tree_table.gleam
```

Debe cubrir:

- columna principal flexible con indentacion, toggle, titulo, path y nivel;
- columnas numericas compactas con ancho minimo estable;
- acciones colapsables;
- version movil como lista jerarquica compacta;
- encabezados que no se rompan verticalmente;
- rows keyed para estabilidad en Lustre.

No debe convertirse en una abstraccion enorme para todos los casos. Es un
componente local de `Plan`. Si despues `Capacidades` o `Personas` demuestran
necesidades equivalentes, se sube a `ui/`.

Tests minimos:

- los encabezados no se rompen verticalmente en desktop.
- en movil no se repiten acciones como una tabla colapsada ilegible.
- cada fila mantiene key estable.
- la indentacion comunica jerarquia sin ocultar path ni nivel.

#### 7. Validar responsive especifico

En movil, `Plan / Estructura` no debe depender de una tabla colapsada
automaticamente.

Wireframe movil:

```text
Plan
Scope: Card - Release 1.5
Modo: [Estructura] [Kanban]

v Release 1.5
  Active   0/3 tasks   ya activo

  P6 - Release Notes
  Draft   +0 pool   -
  [Ver] [+] [...]

  P6 - Retrospective
  Draft   +0 pool   -
  [Ver] [+] [...]
```

Validacion:

- `agent-browser` desktop para scope proyecto, nivel y card.
- `agent-browser` movil para legibilidad, acciones y seleccion de card.
- captura de `Plan / Estructura` y `Plan / Kanban` antes de cerrar.

La navegacion movil primaria (`Pool | Plan | Caps | Personas`) queda como
historia separada de navegacion global. No debe mezclarse con esta iteracion de
Plan salvo que bloquee la validacion minima.

#### 8. Extraer `WorkScope` y unificar `work_surface`

`work_surface` debe convertirse en el lenguaje comun de superficies
operativas:

```text
work_surface.header
work_surface.view_controls
work_surface.summary
work_surface.empty_state
```

Debe usarse en:

- `Plan / Estructura`;
- `Plan / Kanban`;
- `Capacidades / Lista`;
- `Capacidades / Matriz`;
- `Personas`.

La reutilizacion debe ser visual y estructural, no una pantalla generica que
oculte las diferencias de mision entre vistas.

Esta extraccion queda deliberadamente al final.

Condiciones para hacerla:

- `Plan / Estructura` tiene UX estable.
- `Plan / Kanban` ya no hereda comportamiento reclamable.
- `Capacidades` mantiene su mision sin forzarse a parecer `Plan`.
- `Personas` tiene definido su uso de scope.

Destino tecnico:

```text
features/work_scope/types.gleam
features/work_scope/queries.gleam
features/work_scope/scope_bar.gleam
features/work_scope/card_picker.gleam

features/layout/work_surface.gleam
```

La extraccion debe mover lo que ya exista en otros sitios si queda obsoleto,
innecesario o incompatible con esta estructura.

#### 9. Tests Y Validacion

Cobertura esperada:

- tests de ausencia de filtros de `Pool` dentro de `Plan`;
- tests de `Scope = Card` sin seleccion;
- tests de que `Plan / Kanban` no renderiza acciones de reclamar tasks;
- tests de que `Plan / Kanban` no renderiza acciones de arrastrar tasks;
- tests de acciones disponibles segun card con subcards, card con tasks y card
  vacia;
- tests de que cerrar/eliminar quedan en acciones secundarias o deshabilitadas
  segun historial;
- tests de card picker con duplicados, path/id y texto ambiguo;
- tests de i18n para labels de scope, modo y empty states;
- validacion `agent-browser` desktop para scope proyecto, nivel y card;
- validacion `agent-browser` movil para navegacion, legibilidad y acciones;
- captura de `Plan / Estructura` y `Plan / Kanban` antes de dar por cerrada la
  historia.

#### Orden De Ejecucion Recomendado

1. Sacar filtros de `Pool` fuera de `Plan` en `center_panel`.
2. Corregir `Scope = Card` vacio con empty state.
3. Crear `Plan / Kanban` especifico, sin reclamacion ni drag de tasks.
4. Reducir acciones visibles de `Plan / Estructura` a `Ver`, `+` contextual y
   menu secundario.
5. Mejorar el selector de card con path, nivel, teclado y resolucion de
   duplicados.
6. Crear `features/plan/tree_table.gleam` o equivalente local.
7. Validar desktop y movil con `agent-browser`.
8. Solo entonces extraer `work_scope` y generalizar `work_surface`.
9. Limpiar codigo obsoleto, nombres incompatibles y tests que validen el modelo
   anterior.

#### 10. Unificar Barra De Control De Vista

Tras estabilizar `Plan / Estructura`, `Plan / Kanban` y `Capacidades`, la
siguiente mejora debe homogeneizar la anatomia de las vistas principales sin
meter filtros innecesarios ni crear una superficie generica que oculte la
mision de cada vista.

Esta seccion prevalece sobre wireframes anteriores del mismo documento cuando
exista conflicto de copy o estructura. En particular, reemplaza la etiqueta
anterior de impacto de activacion por `Al activar` y reemplaza cualquier idea de `filter_bar` separada por una
barra unica de control de vista.

Problema actual:

- `Plan` tiene tres bloques visibles: header, scope y cuerpo.
- `Capacidades` tiene cuatro bloques visibles: configuracion de mis
  capacidades, header, scope y cuerpo.
- Los filtros de `Plan` (`Estado`, `Orden`, `Cerradas`) compiten con el scope
  cuando aparecen como una barra separada.
- El cuerpo pierde altura util en pantallas pequenas.
- El impacto de activacion es correcto tecnicamente, pero no comunica bien al usuario que
  representa una consecuencia de activar una card.

Decision:

Todas las vistas operativas deben seguir la misma anatomia:

```text
[Header de vista]
Titulo + descripcion + chips resumen + acciones propias

[Barra de control de vista]
Contexto: scope + selector dependiente
Modo: variantes internas de la vista
| separador visual |
Refinamiento: filtros minimos propios de esa vista

[Cuerpo]
Contenido principal
```

La barra no debe llamarse `refinement` en la interfaz. Para el usuario es una
unica barra de control de vista. Internamente puede modelarse como:

```text
ViewControls
  context_controls
  mode_controls
  refinement_controls
```

Wireframe desktop para `Plan`:

```text
Plan
Estructura de cards y trabajo preparado.
[10 Tarjetas] [3 Tasks] [3 Disponibles] [0 Al activar] [0 Bloqueadas]

Scope  [Card v] [Release 1.5 - Launch train]
Modo   [Estructura] [Kanban]        |        Estado [Todas v]  Orden [Arbol v]  [ ] Closed

<cuerpo>
```

Wireframe movil para la misma barra:

```text
Plan
Estructura de cards y trabajo preparado.
[10 Tarjetas] [3 Tasks] [3 Disponibles]

Scope
[Card v]
[Release 1.5 - Launch train]

Modo
[Estructura] [Kanban]

Refinar
[Estado v]
[Orden v]
[ ] Closed

<cuerpo>
```

Reglas:

- El header de vista queda arriba y no contiene filtros de detalle.
- La barra de control contiene contexto, modo y refinamientos minimos.
- En desktop, contexto/modo y refinamiento viven en la misma surface separados
  visualmente.
- En movil, la misma barra se apila por grupos; no se fuerza una unica linea.
- Si una vista no necesita refinamiento, esa zona no se renderiza.
- Si los filtros crecen mucho en una vista futura, entonces se permite una barra
  secundaria o panel de filtros, pero no para `Plan` en su estado actual.

#### 11. Filtros De Estado En Plan

El filtro de estado tiene sentido en `Plan / Estructura`, porque esta vista
responde:

```text
Que hemos preparado, que esta activo, que esta cerrado y que pasaria si se
activa una parte del arbol?
```

No debe convertirse en un filtro protagonista ni aplicarse igual a todos los
modos.

Reglas por modo:

- `Plan / Estructura`: permite `Todas`, `Draft`, `Active`, `Closed`.
- `Plan / Kanban`: el universo normal debe ser `Active`; `Closed` puede entrar
  mediante toggle, pero `Draft` no debe mezclarse por defecto porque el kanban
  es lectura de flujo activo.
- `Closed` debe mantener su logica explicita: si el toggle `Closed` esta
  desactivado, las cards cerradas no aparecen aunque exista filtro de estado.
- `Estado` debe vivir en la zona de refinamiento de la barra de control, junto
  a `Orden`.

Tests minimos:

- `Plan / Estructura` renderiza `Estado` y `Orden` dentro de la barra de
  control, no como filtros globales de `Pool`.
- `Plan / Estructura` con `Estado = Draft` muestra solo rows draft dentro del
  scope actual.
- `Plan / Estructura` con `Estado = Active` muestra solo rows active dentro del
  scope actual.
- `Plan / Estructura` con `Estado = Closed` no muestra cerradas si el toggle
  `Closed` esta desactivado.
- `Plan / Estructura` con `Estado = Closed` y toggle `Closed` activado muestra
  solo cerradas dentro del scope actual.
- `Scope = Card` + filtro de estado filtra el subarbol seleccionado, no cae al
  proyecto entero.
- `Plan / Kanban` no ofrece `Draft` como refinamiento principal salvo que se
  decida explicitamente una variante de planificacion distinta.

#### 12. Capacidades Y Configuracion Personal

`Capacidades` debe compartir la misma anatomia de `Plan`, pero no debe copiar
sus filtros. Su mision es distinta: entender que capacidades aparecen en un
scope y donde hay actividad.

Decision:

- `Configuracion de mis capacidades` no debe ser un bloque permanente por
  encima de la vista.
- Debe moverse a una accion propia del header: `Mis capacidades`.
- Solo debe aparecer como bloque visible si hay una situacion accionable:
  usuario sin capacidades configuradas, capacidades incompletas para la vista
  actual o error de configuracion.

Wireframe:

```text
Capacidades                                      [Mis capacidades]
Tasks activas agrupadas por capacidad dentro del scope.
[9 Cards] [18 Tasks activas] [4 Capacidades] [3 Para mi]

Scope  [Nivel v] [Historias v]
Modo   [Lista] [Matriz]          |          [Con trabajo para mi] Estado [Abiertas v] Orden [Riesgo v] [ ] Closed

<cuerpo>
```

Tests minimos:

- `Capacidades` renderiza la accion `Mis capacidades` en el header.
- `Capacidades` no renderiza el bloque de configuracion personal permanente si
  el usuario ya tiene capacidades configuradas y no hay aviso.
- Si el usuario no tiene capacidades configuradas, se renderiza un aviso
  accionable, no una configuracion completa siempre abierta.
- `Capacidades` conserva scope y modo al cambiar entre `Lista` y `Matriz`.
- `Capacidades` no hereda filtros de `Plan` que no tengan sentido para la vista.

#### 13. Renombrar Impacto De Activacion

La metrica `Al activar` representa cuantas tasks entrarian al `Pool` si se activa una
card o subarbol draft. Es una metrica de consecuencia operacional, no una
metrica permanente de estado.

Problema:

Si el seed muestra siempre `0`, la columna parece inutil. En realidad el dato
solo se entiende cuando existen cards `Draft` con tasks disponibles debajo.

Decision de copy:

- Renombrar columna/chip de impacto de activacion a `Al activar`.
- Valores recomendados:
  - `+3 tasks`: si al activar entrarian tres tasks al pool;
  - `ya activo`: si la card ya esta activa;
  - `-`: si no aplica;
  - `bloqueado`: si la activacion no se puede ejecutar.

Reglas:

- `Al activar` aparece en `Plan / Estructura`.
- No aparece como metrica principal en `Pool`.
- Antes de activar un subarbol, la confirmacion debe usar el mismo calculo y el
  mismo lenguaje visual.
- El seed debe incluir al menos una card draft con tasks disponibles debajo para
  que la vista muestre `+N tasks`.

Tests minimos:

- Card `Draft` con descendant tasks disponibles muestra `+N tasks`.
- Card `Active` muestra `ya activo`.
- Card sin impacto muestra `-`.
- La confirmacion de `Activar subarbol` usa el mismo numero que la columna
  `Al activar`.
- Los tests de seeds comprueban que existe al menos un caso visible con impacto
  no cero.

#### 14. Reutilizacion Y Limpieza Tecnica

La mejora debe reutilizar componentes existentes antes de crear abstracciones
nuevas. La extraccion solo esta justificada si elimina duplicacion real entre
`Plan`, `Capacidades` y `Personas`.

Reutilizar primero:

- `work_surface` para header, chips resumen y empty states cuando ya cubra la
  necesidad.
- `features/plan/scope_bar.gleam` como punto de partida del control de scope,
  manteniendo su API estable hasta que haya contrato probado.
- `features/plan/card_picker.gleam` para seleccionar cards activas desde
  `Plan` y `Capacidades`.
- `ui/signal_chip.gleam` para chips resumen y metricas compactas.
- `features/plan/tree_table.gleam` solo como componente local de `Plan` mientras
  ninguna otra vista necesite exactamente la misma tabla-arbol.

Extracciones permitidas despues de estabilizar comportamiento:

```text
features/work_scope/types.gleam
features/work_scope/queries.gleam
features/work_scope/scope_bar.gleam
features/work_scope/card_picker.gleam

features/layout/view_controls.gleam
features/layout/work_surface.gleam
```

Criterios para extraer:

- El mismo patron debe estar usado al menos por dos vistas reales.
- La extraccion debe reducir codigo o estados divergentes, no solo mover
  nombres.
- La API publica debe modelar zonas opcionales con tipos explicitos; no debe
  depender de listas vacias anonimas para indicar ausencia de controles.
- La extraccion debe preservar la mision propia de cada vista: `Plan` prepara y
  activa estructura, `Capacidades` muestra trabajo por capacidad, `Personas`
  muestra distribucion de trabajo por miembro.

Limpieza obligatoria:

- Eliminar filtros antiguos de `Pool` que se rendericen en vistas que no son
  `Pool`.
- Eliminar booleans de configuracion de Kanban que hayan quedado sustituidos
  por ADTs como `KanbanPurpose`.
- Eliminar CSS de barras antiguas si la barra de control unificada lo reemplaza.
- Eliminar nombres ambiguos como `scope_bar` si el modulo ya no pertenece solo
  a `Plan`; moverlo o renombrarlo cuando se extraiga.
- Eliminar tests que validen la estructura anterior si ya contradicen el modelo
  nuevo.
- Revisar seeds para que muestren casos reales de `Draft`, `Active`, `Closed`,
  `Al activar +N`, card con subcards, card con tasks y card sin contenido.

Tests de regresion globales:

- `Plan`, `Capacidades` y `Personas` usan la misma anatomia de header + barra
  de control + cuerpo.
- Ninguna vista principal renderiza filtros de otra vista.
- En desktop la barra de control no empuja el cuerpo innecesariamente.
- En movil la barra se apila sin overflow, solapes ni textos cortados.
- `agent-browser` valida `Plan / Estructura`, `Plan / Kanban`,
  `Capacidades / Lista` y `Capacidades / Matriz` en desktop y `390x844`.
- Las capturas de validacion deben incluir un seed con `Al activar +N`.

### Kanban De Cards

El kanban actual no debe desaparecer necesariamente, pero no debe ser la vista
base para todo.

Uso recomendado:

- modo `Kanban` dentro de `Plan`;
- util para managers que quieren ver pendientes/en curso/cerradas por estado
  inferido;
- debe mostrar nivel/path en cada card;
- debe tener titulo contextual dentro de `Plan`, no una entrada separada del
  sidebar.

Definicion de la vista:

```text
Kanban
Cards activas agrupadas por estado inferido del trabajo.

Scope: [Tipo de scope] [Selector contextual]
[Con trabajo para mi]  Orden: [Riesgo]  [ ] Cerradas
```

El primer control elige el tipo de scope. El segundo control cambia segun ese
tipo:

- `Nivel`: el segundo control selecciona un nivel configurado del proyecto
  (`Hitos`, `Entregas`, `Historias`, etc.).
- `Card`: el segundo control selecciona una card activa concreta. No selecciona
  "historias" como concepto; selecciona cards reales.

El selector de card debe escalar a muchos resultados. No debe ser un `select`
simple si el proyecto puede tener muchas cards activas. Debe comportarse como
combobox con busqueda:

```text
Scope: [Card] [Buscar card activa...]

Resultados:
Checkout nuevo
Q3 Plataforma / Portal clientes / Checkout nuevo
Nivel: Historia
```

Reglas del selector de card:

- Solo lista cards activas.
- Muestra titulo, path y nivel visible.
- Permite buscar por titulo y path.
- No incluye cards `Draft` ni `Closed` como scope seleccionable en Kanban.

El check `Cerradas` no cambia el universo del selector de scope. Solo controla
si la vista incluye elementos cerrados dentro del scope ya elegido.

Valor por defecto de `Cerradas`:

- Scope `Nivel`: desactivado por defecto. Una vista de nivel debe priorizar
  trabajo vivo y evitar que el historico domine el escaneo.
- Scope `Card` en una card de ejecucion o historia que contiene tasks:
  activado por defecto. En ese contexto el usuario suele querer entender el
  estado completo de esa unidad, incluyendo tasks cerradas/completadas.
- Scope `Card` en una card alta que contiene subcards: desactivado por defecto,
  salvo que el usuario active revision historica.

Columnas:

- `Pendientes`: cards activas con trabajo abierto y sin tasks descendientes
  reclamadas/en curso.
- `En curso`: cards activas con al menos una task descendiente reclamada o en
  curso.
- `Cerradas`: solo visible cuando `Cerradas` esta activo.

Las columnas son lectura inferida. No se arrastran cards entre columnas para
cambiar su estado.

### Capacidades

La vista de `Capacidades` es una entrada principal del sidebar. No introduce
fases manuales ni capacidades persistidas en card. Todas las capacidades se
derivan de las tasks descendientes del scope elegido.

Pregunta principal:

```text
Para este scope, que capacidades existen por sus tasks descendientes y cual es
el estado de trabajo de cada una?
```

Esta vista debe servir para:

- ver que capacidades tiene una card o un nivel;
- saber en que capacidades ya se completo toda la actividad;
- detectar capacidades con trabajo pendiente, reclamado, en curso o bloqueado;
- comparar cards entre si por carga de capacidad;
- encontrar donde una persona puede aportar sin asignacion directa.

#### Cabecera

La cabecera reutiliza el patron de scope de `Plan`, pero no muestra selector de
otras vistas principales. El sidebar ya indica que el usuario esta en
`Capacidades`.

```text
Capacidades
Tasks activas agrupadas por capacidad dentro del scope.

Scope: [Tipo de scope] [Selector contextual]

Modo: [Lista] [Matriz]
[Con trabajo para mi]  Estado: [Abiertas]  Orden: [Riesgo]  [ ] Cerradas

9 Cards   18 Tasks activas   4 Capacidades   2 caps completas   3 Para mi
```

Reglas de scope:

- `Nivel`: el segundo control selecciona un nivel configurado del proyecto.
- `Card`: el segundo control selecciona una card activa concreta mediante
  combobox con busqueda, igual que en Kanban.
- Si el scope cambia, se mantiene la vista `Capacidades` y el modo cuando siga
  teniendo sentido.
- Si el usuario cambia de vista desde Kanban a Capacidades, se conserva el
  scope actual.

`Cerradas` mantiene la misma logica por defecto que Kanban:

- scope `Nivel`: desactivado por defecto;
- scope `Card` que contiene tasks: activado por defecto;
- scope `Card` alta que contiene subcards: desactivado por defecto.

#### Modo Lista

El modo `Lista` responde:

```text
Como esta cada capacidad dentro de este scope?
```

Agrupa por capacidad y muestra debajo las cards donde esa capacidad tiene
actividad pendiente o relevante.

```text
+------------------------------------------------------------+
| Capacidades                                                |
| Tasks activas agrupadas por capacidad dentro del scope.    |
|                                                            |
| Scope: [ Nivel v ] [ Historias v ]                         |
|                                                            |
| Modo: [ Lista ] [ Matriz ]                                 |
| [ Con trabajo para mi ] Estado: [ Abiertas v ] [ ] Cerradas|
|                                                            |
| 9 Cards   18 Tasks   4 Capacidades   2 caps completas      |
+------------------------------------------------------------+
| Backend                                                    |
| 8 tasks   4 disponibles   2 reclamadas   1 en curso        |
| 5/8 cerradas                                               |
|                                                            |
| Cards con Backend pendiente                                |
| +--------------------------------------------------------+ |
| | Card A        3 tasks    2 disp.   1 reclamada  [Ver]  | |
| | Card B        1 task     1 curso                [Ver]  | |
| +--------------------------------------------------------+ |
|                                                            |
| QA                                                         |
| 3 tasks   2 disponibles   1 bloqueada                      |
| 0/3 cerradas                                               |
|                                                            |
| Cards con QA pendiente                                     |
| +--------------------------------------------------------+ |
| | Card B        1 task     1 bloqueada           [Ver]   | |
| | Card D        2 tasks    2 disp.               [Ver]   | |
| +--------------------------------------------------------+ |
+------------------------------------------------------------+
```

Reglas:

- Las capacidades completas se muestran con menor peso visual, no con alerta.
- Las capacidades sin actividad dentro del scope no aparecen por defecto.
- Un filtro `Mostrar: Todas / Solo con actividad / Solo pendientes` puede
  aparecer si el proyecto tiene muchas capacidades.
- Cada fila de card conserva path o padre cuando el scope sea `Nivel`.

#### Modo Matriz

El modo `Matriz` toma de herramientas como Monday la densidad escaneable de
tabla, pero no su modelo de edicion manual. Las celdas son lecturas derivadas de
tasks reales; no se editan capacidades ni fases desde la matriz.

Responde:

```text
Donde esta concentrado el trabajo activo por card y capacidad?
```

Mockup con scope `Nivel`:

```text
+----------------------------------------------------------------------------+
| Capacidades                                                                |
| Tasks activas agrupadas por card y capacidad dentro del scope.             |
|                                                                            |
| Scope: [ Nivel v ] [ Historias v ]                                         |
|                                                                            |
| Modo: [ Lista ] [ Matriz ]                                                 |
| [ Con trabajo para mi ] Estado: [ Abiertas v ] Orden: [ Riesgo v ]         |
| [ ] Cerradas                                                               |
|                                                                            |
| 9 Cards   18 Tasks activas   4 Capacidades   2 caps completas  3 Para mi  |
+----------------------+----------+----------+----------+----------+---------+
| Historia             | Backend  | Frontend | QA       | UX       | Total   |
+----------------------+----------+----------+----------+----------+---------+
| API Cleanup          |    3     |    -     |    1     |    -     |   4     |
| Q3 / Plataforma      | 2 disp   |          | 1 blq    |          |         |
|                      | 1 recl   |          |          |          |         |
+----------------------+----------+----------+----------+----------+---------+
| Checkout nuevo       |    1     |    2     | completa | completa |   4     |
| Portal / Pagos       | 1 curso  | 2 disp   |          |          |         |
+----------------------+----------+----------+----------+----------+---------+
| Emails sistema       |    -     |    2     |    -     |    2     |   4     |
| Portal / Core        |          | 1 disp   |          | 2 recl   |         |
|                      |          | 1 recl   |          |          |         |
+----------------------+----------+----------+----------+----------+---------+
| Totales              |    4     |    4     |    1     |    3     |  12     |
+----------------------+----------+----------+----------+----------+---------+
```

Mockup con scope `Card` que contiene subcards:

```text
+----------------------------------------------------------------------------+
| Capacidades                                                                |
| Tasks activas agrupadas por subcard y capacidad dentro de esta card.        |
|                                                                            |
| Scope: [ Card v ] [ Buscar card activa... ]                                |
| Q3 Plataforma / Portal clientes                                            |
|                                                                            |
| Modo: [ Lista ] [ Matriz ]                                                 |
| [ Con trabajo para mi ] Estado: [ Abiertas v ] Orden: [ Riesgo v ]         |
| [ ] Cerradas                                                               |
|                                                                            |
| 4 Subcards   23 Tasks activas   5 Capacidades   6 Para mi                  |
+----------------------+----------+----------+----------+----------+---------+
| Subcard              | Backend  | Frontend | QA       | UX       | Total   |
+----------------------+----------+----------+----------+----------+---------+
| Checkout nuevo       |    5     |    4     |    3     |    1     |  13     |
| Portal / Pagos       | 3 disp   | 2 recl   | 2 blq    | completa |         |
+----------------------+----------+----------+----------+----------+---------+
| Emails sistema       |    -     |    2     |    -     |    2     |   4     |
| Portal / Core        |          | 2 disp   |          | 2 recl   |         |
+----------------------+----------+----------+----------+----------+---------+
```

Mockup con scope `Card` que contiene tasks directamente:

```text
+----------------------------------------------------------------------------+
| Capacidades                                                                |
| Tasks activas agrupadas por capacidad dentro de esta card.                  |
|                                                                            |
| Scope: [ Card v ] [ Checkout nuevo ]                                       |
| Q3 Plataforma / Portal clientes / Checkout nuevo                           |
|                                                                            |
| Modo: [ Lista ] [ Matriz ]                                                 |
| [ Con trabajo para mi ] Estado: [ Abiertas v ] Orden: [ Riesgo v ]         |
| [x] Cerradas                                                               |
|                                                                            |
| 1 Card   13 Tasks   4 Capacidades   1 cap completa                         |
+----------------------+----------+----------+----------+----------+---------+
| Card                 | Backend  | Frontend | QA       | UX       | Total   |
+----------------------+----------+----------+----------+----------+---------+
| Checkout nuevo       |    5     |    4     |    3     |    1     |  13     |
|                      | 3 done   | 2 done   | 2 disp   | completa |         |
|                      | 1 disp   | 1 recl   | 1 blq    |          |         |
+----------------------+----------+----------+----------+----------+---------+
```

#### Filas, Columnas Y Celdas

Filas:

- Scope `Nivel`: cards de ese nivel.
- Scope `Card` con subcards: subcards directas.
- Scope `Card` con tasks: una fila para la propia card.

Columnas:

- capacidades presentes en tasks descendientes del scope;
- ocultar columnas con todo cero por defecto;
- permitir mostrar todas si el usuario necesita auditoria.

Celdas:

- muestran el numero de tasks de esa capacidad para esa fila;
- desglosan estado compacto: disponibles, reclamadas, en curso, bloqueadas,
  cerradas si `Cerradas` esta activo;
- una celda completa puede mostrar `completa` en vez de un numero grande;
- una celda vacia usa `-`, no `0`, para reducir ruido.
- una celda vacia no muestra chevron ni affordance de drill-down;
- una celda con tasks puede ser clicable, pero debe parecer una lectura con
  detalle progresivo, no un campo editable.

El nombre de la primera columna depende del scope:

- Scope `Nivel`: usa el nombre visible del nivel seleccionado, por ejemplo
  `Historia`, `Entrega` o `Hito`.
- Scope `Card` con subcards: usa `Subcard` o el nombre visible del siguiente
  nivel si es claro para el usuario.
- Scope `Card` con tasks: usa `Card`.

La matriz puede tomar como referencia visual `~/tmp/imagen2.png`, con estos
ajustes obligatorios:

- no duplicar en el sidebar entradas por nivel como `Initiatives`, `Features`
  o `Task groups`; los niveles viven dentro del scope de `Plan`;
- no mostrar chevron en celdas vacias;
- llamar al contador de completitud `caps completas`, `capacidades completas`
  o `sin pendiente`, nunca solo `Completas`;
- diferenciar visualmente `disponible` de `completa`: disponible usa punto de
  estado, completa usa badge suave;
- evitar mini-cards pesadas dentro de cada celda; la celda debe ser plana por
  defecto y ganar borde/fondo solo en hover, focus o seleccion;
- mantener la fila `Totales` como informacion secundaria, no como bloque
  dominante.

Interaccion de celda:

```text
Click en: API Cleanup / Backend

+----------------------------------------+
| API Cleanup / Backend                  |
| 3 tasks activas                        |
|                                        |
| Disponible                             |
| - Revisar contratos API        P2      |
| - Limpiar endpoints legacy     P3      |
|                                        |
| Reclamada                              |
| - Migrar auth middleware       Ana     |
|                                        |
| [Ver tasks] [Abrir card]              |
+----------------------------------------+
```

La celda no permite asignar, cambiar capability ni mover tasks. Solo abre
detalle, filtra o navega.

#### Empty States

Scope sin tasks:

```text
No hay tasks en este scope.
Anade tasks a una card activa o activa una rama preparada.
```

Scope con tasks pero sin capacidades visibles por filtros:

```text
No hay capacidades con estos filtros.
Prueba mostrar todas las capacidades o limpiar filtros.
```

Card cerrada vista con `Cerradas` activo:

```text
Esta card esta cerrada.
La matriz muestra resultado historico, no trabajo disponible.
```

### Panel Derecho

Recomendacion inicial:

- Mantener `EN CURSO` y `MIS TAREAS`.
- Eliminar `MIS TARJETAS` o renombrarlo a `Contexto`.

Opcion preferida:

```text
EN CURSO (0)
...

MIS TAREAS (1)
E2E Draft Leaf Task
  E2E Root Epic / E2E Initiative A / E2E Task Group A

CONTEXTO
1 card con tareas mias
```

Razon:

- El ownership sigue estando en la task.
- La card aparece como contexto navegable, no como algo reclamado.

### Movil

Debe existir navegacion primaria movil.

Primera solucion simple:

- top bar compacta con proyecto y menu;
- bottom nav con `Pool`, `Plan`, `Capacidades`, `Personas`;
- panel derecho no aparece como sidebar, pero `Mis tareas` debe tener acceso
  desde Pool o desde una entrada compacta.

Wireframe:

```text
+--------------------------------+
| E2E Tree 081743          [..]   |
+--------------------------------+
| Filtros / vista actual          |
|                                |
| Plan                           |
| ...                            |
+--------------------------------+
| Pool | Plan | Caps | Personas  |
+--------------------------------+
```

## Relacion Con Necesidades De Usuarios

Sin `temporal.md` disponible, esta seccion queda provisional.

Necesidades que probablemente cubre la iteracion:

- Ver fases/avance sin copiar Monday: `Plan / Kanban` permite ver
  pendientes/en curso/cerradas por estado inferido, dentro del modelo de cards
  y tasks.
- Ver hitos/entregas/historias: la vista `Plan` muestra niveles configurados
  por proyecto.
- Preparar trabajo futuro: `draft` vive en Plan y no ensucia el Pool.
- Saber que llega al Pool: cada card/scope muestra impacto de activacion.
- Evitar saturacion: activar subarboles desde Plan debe mostrar impacto y
  limite blando del pool.
- Mantener simplicidad: el sidebar no crece por metodologia ni por niveles.

Necesidades pendientes de confirmar contra `temporal.md`:

- si habia pantallas nuevas pedidas que ahora se sustituyen por vistas, scopes,
  modos o filtros;
- si habia reportes o metricas especificas no cubiertas;
- si habia conceptos tradicionales que necesiten traduccion a ScrumBringer;
- si habia workflows de usuarios que requieren informacion ausente en Plan.

## Iteracion Propuesta

### Objetivo

Corregir la arquitectura de informacion de la jerarquia para que ScrumBringer
explique claramente:

- cards como estructura y preparacion;
- tasks como trabajo reclamable;
- pool como entrada de ejecucion;
- capacidades como manos de completitud;
- personas como disponibilidad.

### Alcance

1. Reestructurar sidebar izquierdo.
2. Crear/ajustar vista `Plan`.
3. Integrar nombres de niveles dentro de `Plan`.
4. Adoptar `Sidebar + Scope + Mode` como contrato de navegacion.
5. Sustituir el kanban base de cards por una vista jerarquica.
6. Mantener kanban como modo dentro de `Plan`.
7. Limpiar `Mis tarjetas` del panel derecho.
8. Anadir navegacion movil minima.
9. Revisar empty states de niveles/cards.
10. Mantener due date y senales de urgencia ya implementadas.

### Fuera De Alcance Inicial

- Rehacer el dominio de cards/tasks.
- Cambiar reglas de activacion/cierre.
- Anadir nuevas entidades.
- Implementar reportes avanzados.
- Reabrir decisiones de due date.

## Historias Iniciales

### Historia 1: Sidebar estable por modos de trabajo

Como usuario quiero que la navegacion principal muestre modos de trabajo, no
los niveles internos del proyecto, para orientarme sin entender aun toda la
jerarquia.

Criterios:

- El sidebar muestra `Pool`, `Plan`, `Capacidades`, `Personas`.
- Los niveles configurados no aparecen como entradas hermanas del sidebar.
- `Nueva tarea` y `Nueva card` mantienen permisos actuales.
- La ruta antigua por profundidad debe revisarse y eliminarse o redirigirse sin
  dejar compatibilidad temporal si se decide que queda obsoleta.
- Validacion visual con `agent-browser` desktop.
- Validacion visual con `agent-browser` movil.

### Historia 2: Plan como vista canonica de jerarquia

Como manager quiero ver la estructura de cards de mi proyecto para entender que
trabajo esta preparado, activo o cerrado sin mezclarlo con el Pool.

Criterios:

- `Plan` abre una vista jerarquica por defecto.
- La vista muestra niveles, padres e hijos.
- Cada card muestra estado, progreso, due date si existe e impacto resumido.
- Una card con subcards muestra subcards.
- Una card con tasks muestra tasks.
- No se presentan cards y tasks como colecciones equivalentes si el modelo no
  permite mezclar ambas.
- Empty states explican como crear la primera card/subcard/task.
- Validacion visual con datos de 1, 2 y 3 niveles.

### Historia 3: Scope y modos dentro de vistas principales

Como usuario quiero elegir el alcance y el modo de la vista actual para
responder preguntas distintas sin saltar entre pantallas innecesarias.

Criterios:

- `Scope` permite elegir proyecto, cards activas, una card o un nivel
  configurado cuando la vista lo necesite.
- `Plan` permite modo `Estructura` y `Kanban`.
- `Capacidades` permite modo `Lista` y `Matriz`.
- El titulo y subtitulo cambian segun la vista, el scope y el modo.
- El selector de modo nunca ofrece vistas principales de otro sidebar item.
- Scopes y modos no se duplican como entradas del sidebar.
- Las URLs son compartibles.

### Historia 4: Card scope claro

Como usuario quiero abrir una card y ver que contiene y que pasaria si se activa
o se cierra para tomar decisiones sin saturar el pool.

Criterios:

- El detalle/scope de card muestra breadcrumb.
- Muestra contenido directo y resumen de trabajo debajo.
- `Activar subarbol` muestra conteo de tasks que entrarian al activar.
- El limite blando del pool aparece como aviso si aplica.
- `Cerrar` no esta demasiado a mano y respeta bloqueo por tasks claimed/ongoing.
- `Mover` no compite visualmente con `Crear task/subcard`.

### Historia 5: Panel derecho sin ownership de cards

Como usuario quiero ver mis tareas y su contexto sin que la interfaz sugiera que
he reclamado cards.

Criterios:

- Desaparece `Mis tarjetas` o se renombra a `Contexto`.
- Las tareas reclamadas muestran path de card cuando aplica.
- Las cards aparecen como contexto navegable, no como propiedad.
- No se pierden accesos utiles a card detail.

### Historia 6: Navegacion movil

Como usuario quiero navegar por las vistas principales en movil aunque los
sidebars no esten visibles.

Criterios:

- Hay selector o indicador de proyecto en movil.
- Hay acceso visible a `Pool`, `Plan`, `Capacidades`, `Personas`.
- No hay dependencia de sidebar oculto para cambiar de vista.
- Los filtros no empujan el contenido principal fuera de uso.
- Validacion con viewport `390x844`.

## Preguntas De Producto Para Decidir

1. La etiqueta `Plan`, es la mejor palabra para sustituir `Tarjetas`?
2. El kanban de cards debe seguir existiendo como modo de `Plan` o eliminarse
   hasta que haya una necesidad mas fuerte?
3. En el panel derecho, preferimos eliminar del todo el bloque de cards o
   renombrarlo a `Contexto`?
4. La vista base de `Plan` debe ser lista jerarquica densa o mapa visual de
   arbol?
5. Debe existir un scope `ActiveCards` separado de `Project`, o basta con
   `Project + filtro estado active`?
6. Que informacion minima necesita ver un manager antes de activar un subarbol?
7. Como debe comportarse `Plan` en proyectos con un solo nivel?
8. Que conceptos del documento de usuarios `temporal.md` quedan todavia sin
   traducir a la filosofia ScrumBringer?

## Recomendacion Actual

La mejor primera iteracion es pequena pero estructural:

1. Cambiar el sidebar a cuatro modos: `Pool`, `Plan`, `Capacidades`, `Personas`.
2. Convertir `Plan` en la vista base de cards usando una lista jerarquica.
3. Mover los niveles configurados a un selector dentro de `Plan`.
4. Adoptar `Sidebar + Scope + Mode` como contrato de navegacion.
5. Mantener kanban como modo de `Plan`, no como vista base.
6. Quitar el lenguaje `Mis tarjetas`.
7. Anadir navegacion movil minima.

Esto aprovecha el modelo jerarquico sin convertir ScrumBringer en una
herramienta tradicional de backlog pesado. La interfaz vuelve a separar
preparacion, ejecucion y salud de flujo.
