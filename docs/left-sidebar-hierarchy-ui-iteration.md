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

### H4. Existe una vista de jerarquia parcialmente preparada pero no integrada

Existe `apps/client/src/scrumbringer_client/features/hierarchy/scope_view.gleam`
con conceptos como:

- `DepthScope`;
- `CardScope`;
- `TrackingProfile`;
- `CoordinationProfile`;
- `ExecutionProfile`.

Sin embargo, el flujo principal de `Cards` no usa esta vista. Esto sugiere que
la idea de producto fue modelada parcialmente, pero no llego a la navegacion
principal.

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
7. El kanban de cards debe ser una lente posible, no la representacion base de
   la jerarquia.
8. Las vistas vacias deben ensenar el modelo, no solo mostrar columnas vacias.
9. La experiencia movil debe tener navegacion propia, no depender de sidebars
   ocultos.

## Decision Fuerte: Scope + Lens

ScrumBringer no debe crear una pantalla distinta por cada entidad, nivel o
pregunta operativa. Las vistas principales deben componerse con dos conceptos:

- `Scope`: sobre que conjunto de trabajo se mira.
- `Lens`: que pregunta se quiere responder sobre ese conjunto.

Esta decision permite cubrir mas necesidades con menos pantallas y evita que la
flexibilidad de niveles de cards convierta la navegacion en una lista creciente
de vistas.

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

### Lenses

Una `Lens` define la pregunta:

```text
Structure
Flow
Capabilities
Blockers
People
Risk
```

Lectura de producto:

- `Structure`: como se descompone el trabajo.
- `Flow`: que esta abierto, reclamado, en curso o cerrado.
- `Capabilities`: que manos hacen falta y cuales ya terminaron su actividad.
- `Blockers`: que tasks esperan dependencias y donde impactan.
- `People`: quien esta trabajando en que.
- `Risk`: due dates, Pool alto, antiguedad y senales de saturacion.

### Regla De Producto

No se crean pantallas como `Hitos`, `Entregas`, `Historias`, `Dashboard de
card`, `Dashboard de nivel` o `Bloqueos de card` como rutas principales
separadas. Se crea una superficie con selector de `Scope` y `Lens`.

Ejemplos:

```text
Scope: CardSubtree(Q3 Plataforma)
Lens: Capabilities
```

Responde: que capacidades tiene esta card por debajo y cuales estan completas.

```text
Scope: Depth(Entrega)
Lens: Flow
```

Responde: como estan todas las entregas del proyecto.

```text
Scope: ActiveCards
Lens: Blockers
```

Responde: que trabajo activo esta esperando dependencias.

Esta decision es base para `Plan` y para cualquier dashboard centralizado. Si
una necesidad nueva no encaja como `Scope + Lens`, debe justificarse antes de
crear una nueva pantalla principal.

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

`Plan` debe ser la superficie canonica para cards.

Debe permitir dos escalas:

- vista por nivel;
- vista por card/scope.

Debe ofrecer scopes y lentes internas, no rutas hermanas del sidebar:

- `Mapa`: estructura padre/hijo;
- `Nivel`: cards de un nivel concreto;
- `Estado`: draft/active/closed;
- `Riesgo`: due dates, bloqueo, pool impact.

Primera version recomendada:

```text
Plan
Estructura de cards y trabajo preparado para el pool.

[Mapa] [Nivel] [Estado]

Nivel: [Todos v]   Estado: [Abiertas v]   Buscar: [          ]

Resumen
3 niveles - 6 cards - 12 tasks hoja - 4 listas para pool

Hito: E2E Root Epic                         Closed
  Entrega: E2E Initiative A                 Active
    Historia: E2E Task Group A              Active - 0/1
      Task: E2E Draft Leaf Task             Claimed
```

La vista no tiene que parecer un diagrama complejo. Puede ser una lista
jerarquica densa con indentacion, chips y acciones contextuales.

### Vista Por Nivel Dentro De Plan

Cuando el usuario elige un nivel, el titulo debe usar el nombre configurado:

```text
Plan / Features
Cards de nivel 2 del proyecto.

[Mapa] [Nivel] [Estado]
Nivel: Features

Feature                     Padre             Estado   Tasks   Vence
E2E Initiative A            E2E Root Epic      Active   1       -
```

La vista debe explicar claramente:

- que nivel se esta viendo;
- de que padres cuelgan esas cards;
- cuantas tasks hoja hay debajo;
- cuantas tasks entrarian al pool si se activa esa card/subarbol;
- si la card esta `draft`, `active` o `closed`.

### Vista Por Card

Al abrir una card, la pantalla debe comportarse como scope operativo:

```text
Plan / E2E Root Epic

E2E Root Epic                         Closed
root

Camino
Root

Contenido directo
Entregas (1)
  E2E Initiative A                    Active

Trabajo debajo
1 card activa - 1 task hoja - 1 claimed - 0 disponibles

Acciones
[+ Crear subcard] [Activar subarbol] [Mas]
```

Si la card contiene tasks directamente:

```text
Plan / E2E Task Group A

E2E Task Group A                      Active - 0/1
leaf

Tasks
E2E Draft Leaf Task                   Claimed - admin@example.com

[+ Crear task]
```

Reglas:

- Si una card contiene cards, el foco visual son subcards.
- Si una card contiene tasks, el foco visual son tasks.
- No mostrar cards y tasks como si fueran colecciones equivalentes si el
  modelo impide mezclar ambas.

### Kanban De Cards

El kanban actual no debe desaparecer necesariamente, pero no debe ser la vista
base para todo.

Uso recomendado:

- lente `Estado` dentro de `Plan`;
- util para managers que quieren ver draft/active/closed;
- debe mostrar nivel/path en cada card;
- debe tener titulo contextual, por ejemplo `Plan / Estado`, no solo `Kanban`.

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

La vista de `Capacidades` es una lente dentro de `Plan`. No introduce fases
manuales ni capacidades persistidas en card. Todas las capacidades se derivan de
las tasks descendientes del scope elegido.

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

La cabecera reutiliza el patron `Scope + Lens` de Kanban. El scope se mantiene
al cambiar entre Kanban, Capacidades, Bloqueos y Personas.

```text
Capacidades
Tasks activas agrupadas por capacidad dentro del scope.

Scope: [Tipo de scope] [Selector contextual]
Vista: [Kanban] [Capacidades] [Bloqueos] [Personas]

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
| Vista: [ Kanban ] [ Capacidades ] [ Bloqueos ] [ Personas ]|
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
| Vista: [ Kanban ] [ Capacidades ] [ Bloqueos ] [ Personas ]                |
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
| Vista: [ Kanban ] [ Capacidades ] [ Bloqueos ] [ Personas ]                |
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
| Vista: [ Kanban ] [ Capacidades ] [ Bloqueos ] [ Personas ]                |
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

- Ver fases/avance sin copiar Monday: la lente `Estado` permite ver
  draft/active/closed, pero dentro del modelo de cards y tasks.
- Ver hitos/entregas/historias: la vista `Plan` muestra niveles configurados
  por proyecto.
- Preparar trabajo futuro: `draft` vive en Plan y no ensucia el Pool.
- Saber que llega al Pool: cada card/scope muestra impacto de activacion.
- Evitar saturacion: activar subarboles desde Plan debe mostrar impacto y
  limite blando del pool.
- Mantener simplicidad: el sidebar no crece por metodologia ni por niveles.

Necesidades pendientes de confirmar contra `temporal.md`:

- si habia pantallas nuevas pedidas que ahora se sustituyen por lentes de Plan;
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
4. Adoptar `Scope + Lens` como contrato para Plan y dashboard.
5. Sustituir el kanban base de cards por una vista jerarquica.
6. Mantener kanban como lente de estado dentro de `Plan`.
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

### Historia 3: Scope + Lens dentro de Plan

Como usuario quiero elegir el alcance y la lente del plan para responder
preguntas distintas sin saltar entre pantallas distintas.

Criterios:

- `Scope` permite elegir proyecto, cards activas, una card con su subarbol o
  un nivel configurado.
- `Lens` permite elegir estructura, flujo, capacidades, bloqueos, personas o
  riesgo.
- La combinacion `CardSubtree + Capabilities` muestra capacidades agregadas de
  esa card y su subarbol.
- La combinacion `Depth + Flow` muestra todas las cards de ese nivel con estado
  y progreso.
- La combinacion `ActiveCards + Blockers` muestra dependencias pendientes en
  trabajo activo.
- El titulo y subtitulo cambian segun el scope y la lente.
- Scopes y lenses no se duplican en el sidebar.
- Las URLs son compartibles.

### Historia 4: Card scope claro

Como usuario quiero abrir una card y ver que contiene y que pasaria si se activa
o se cierra para tomar decisiones sin saturar el pool.

Criterios:

- El detalle/scope de card muestra breadcrumb.
- Muestra contenido directo y resumen de trabajo debajo.
- `Activar subarbol` muestra conteo de tasks que entrarian al pool.
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
2. El kanban de cards debe seguir existiendo como lente `Estado` o eliminarse
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
4. Adoptar `Scope + Lens` como contrato de vistas para card, nivel y dashboard.
5. Mantener kanban como lente `Estado`, no como vista base.
6. Quitar el lenguaje `Mis tarjetas`.
7. Anadir navegacion movil minima.

Esto aprovecha el modelo jerarquico sin convertir ScrumBringer en una
herramienta tradicional de backlog pesado. La interfaz vuelve a separar
preparacion, ejecucion y salud de flujo.
