# People Coordination View Plan

## Estado

Propuesta cerrada para implementar la mejora de la vista `Personas`.

La vista debe integrarse con el modelo de jerarquia flexible de cards y con la
anatomia comun que ya se esta consolidando en las vistas principales:

```text
Pool
Plan: Estructura | Kanban
Capacidades: Lista | Matriz
Personas
```

## Mision De La Vista

`Personas` no es una pantalla de administracion de usuarios ni una herramienta
para asignar trabajo.

Su mision es:

> Ver quien esta haciendo que dentro del contexto actual, detectar bloqueos o
> sobrecarga y facilitar conversacion sin asignar trabajo directamente.

La vista debe reforzar la filosofia de ScrumBringer:

- visibilidad del trabajo real;
- autoasignacion frente a asignacion directa;
- comunicacion temprana cuando hay bloqueo, sobrecarga o falta de movimiento;
- simplicidad operativa para equipos pequenos o medianos.

## Objetivos

La vista debe responder, con el menor numero posible de controles:

- quien esta trabajando ahora;
- quien tiene tasks reclamadas pero no empezadas;
- quien esta bloqueado;
- quien esta libre dentro del scope actual;
- en que card/contexto ocurre el trabajo;
- donde conviene hablar con alguien antes de que el flujo se deteriore.

La vista no debe responder preguntas de administracion de miembros. Eso sigue
perteneciendo a las pantallas de administracion.

## Estructura Final

La vista usa la misma gramatica visual que `Plan` y `Capacidades`:

```text
WorkSurface
+- Header
|  +- titulo
|  +- proposito
|  +- summary chips
+- Control bar
|  +- scope: Proyecto | Nivel | Card
|  +- busqueda
|  +- filtros especificos
+- Body
   +- filas de personas
```

Wireframe base:

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Personas                                                             │
│ Quién está trabajando en qué dentro del contexto actual.             │
│                                                                      │
│ Scope: [ Proyecto ▼ ]                                                │
│ Buscar: [ persona, task, card, capacidad...                       ]  │
│ Mostrar: [ Todos ▼ ]   Orden: [ Atención ▼ ]                         │
│                                                                      │
│ 8 personas · 3 trabajando · 4 con reclamadas · 1 bloqueada · 2 libres │
├──────────────────────────────────────────────────────────────────────┤
│ Ana Pérez                                      [Trabajando] [2 claim] │
│ API Cleanup > Backend                                                │
│   • Implementar migración de cards        Ongoing · Backend · Hoy     │
│   • Revisar dependencias                  Claimed · Backend           │
│                                                                      │
│ Luis García                                    [Bloqueado] [1 claim]  │
│ Payments > Webhooks                                                  │
│   • Resolver retry policy                  Bloqueada · DevOps         │
│     Bloqueada por: configurar colas                                  │
│                                                                      │
│ Marta Ruiz                                     [Libre en este scope]  │
│ Sin tasks reclamadas dentro del contexto actual                       │
└──────────────────────────────────────────────────────────────────────┘
```

## Scope

La vista debe usar el mismo patron que `Plan` y `Capacidades`:

```text
Scope: [ Proyecto | Nivel | Card ]
```

Significado:

- `Proyecto`: todo el trabajo activo del proyecto.
- `Nivel`: personas implicadas en cards activas de ese nivel.
- `Card`: personas implicadas en esa card y todo su subarbol.

El selector de card debe seguir el patron de combobox con busqueda y path, no un
`select` simple. El objetivo es evitar ambiguedad cuando haya muchas cards o
cards con nombres parecidos.

El scope debe afectar al universo de datos. Los filtros refinan dentro del
scope, pero no sustituyen al scope.

## Filtros

Controles especificos de la vista:

```text
Buscar: persona, task, card, capacidad
Mostrar: Todos | Con trabajo | Atención | Libres
Orden: Atención | Nombre | Más reclamadas
```

### Mostrar

- `Todos`: muestra todas las personas del proyecto, con estado dentro del scope.
- `Con trabajo`: muestra personas con tasks claimed u ongoing dentro del scope.
- `Atencion`: muestra personas con senales que requieren coordinacion.
- `Libres`: muestra personas sin tasks claimed u ongoing dentro del scope.

### Atencion

El filtro `Atencion` incluye:

- personas con tasks bloqueadas;
- personas con carga alta;
- personas con claimed sin actividad;
- vencimientos cercanos o vencidos, si aplica;
- dependencias relevantes que impiden avanzar.

`Atencion` no debe sonar punitivo. Debe presentar senales para conversar, no
para fiscalizar.

### Orden

Ordenes iniciales:

- `Atencion`: bloqueos y sobrecarga primero, despues ongoing, claimed y libres.
- `Nombre`: orden alfabetico.
- `Mas reclamadas`: personas con mas claimed/ongoing dentro del scope primero.

## Header Y Summary

Usar `work_surface.header`.

Summary chips recomendados:

```text
8 personas
3 trabajando
4 con reclamadas
1 bloqueada
2 libres
```

Los chips deben usar la misma familia visual que `Plan` y `Capacidades`:

- `signal_chip` para metricas principales;
- tonos semanticos existentes;
- texto claro, no color como unico canal.

## Body

La primera version debe ser una sola vista: lista de coordinacion por persona.

No se crean modos `Lista | Matriz` inicialmente. La matriz persona/card puede
ser util en el futuro, pero ahora introduce complejidad prematura.

Cada fila de persona muestra:

- nombre;
- estado principal;
- chips de carga;
- card/contexto principal;
- tasks relevantes dentro del scope;
- mensajes breves para bloqueos o carga alta.

Las filas pueden ser expandibles para no saturar la vista.

Estados visuales por persona:

- `Trabajando`: al menos una task ongoing dentro del scope.
- `Con reclamadas`: tiene tasks claimed pero no ongoing dentro del scope.
- `Bloqueada`: tiene al menos una task bloqueada o dependencia bloqueante.
- `Libre en este scope`: no tiene claimed ni ongoing dentro del scope.

## Reglas De Producto

No se puede asignar trabajo desde esta vista.

Acciones permitidas:

- abrir task;
- abrir card/contexto;
- expandir o contraer persona;
- filtrar y buscar.

Acciones no permitidas:

- asignar task;
- reclamar por otra persona;
- mover trabajo;
- cerrar trabajo desde la fila de persona;
- convertir la vista en administracion de miembros.

La vista debe fomentar conversacion, no control centralizado.

## Reutilizacion

Reutilizar de forma prioritaria:

```text
features/layout/work_surface.gleam
features/plan/scope_bar.gleam
features/plan/card_picker.gleam
ui/task_item.gleam
ui/signal_chip.gleam
ui/badge.gleam
ui/empty_state.gleam
```

Decision importante:

- En esta iteracion se puede seguir usando `features/plan/scope_bar.gleam` como
  componente compartido de facto.
- No se debe mover todo `scope_bar` a `features/work_scope` al principio si eso
  retrasa la estabilizacion visual y funcional.
- La primera extraccion recomendada es el calculo compartido de scope.

Extraccion prioritaria:

```text
features/work_scope/queries.gleam
```

Responsabilidades sugeridas:

```text
cards_in_scope(...)
tasks_in_scope(...)
active_cards_in_scope(...)
descendant_card_ids(...)
scope_label(...)
```

Extracciones posteriores, solo cuando el contrato este probado con `Plan`,
`Capacidades` y `Personas`:

```text
features/work_scope/types.gleam
features/work_scope/scope_bar.gleam
features/work_scope/card_picker.gleam
```

No crear todavia:

```text
generic_work_list.gleam
generic_person_table.gleam
generic_row.gleam
```

El cuerpo de `Personas` debe seguir siendo especifico, aunque use piezas
compartidas.

## Tipos Recomendados

Los tipos deben expresar la intencion funcional y evitar booleanos ambiguos.

Ejemplo orientativo:

```gleam
pub type PeopleVisibilityFilter {
  ShowEveryone
  ShowWithWork
  ShowAttention
  ShowFree
}

pub type PeopleSort {
  SortByAttention
  SortByName
  SortByClaimedCount
}

pub type PersonWorkState {
  WorkingNow
  HasClaimedWork
  BlockedWork
  FreeInScope
}

pub type PersonAttentionSignal {
  BlockedTask(task_id: Int)
  HighClaimedLoad(claimed_count: Int)
  ClaimedWithoutMovement(task_id: Int)
  DueSoon(task_id: Int)
  Overdue(task_id: Int)
}
```

Los nombres finales deben ajustarse al estilo de nomenclatura del proyecto, pero
la idea clave es no representar filtros o estados con strings sueltos o
booleanos combinables de forma ilegal.

## Limpieza Obligatoria

Durante la implementacion:

- eliminar filtros globales de `Pool` que aparezcan en `Personas` sin sentido;
- evitar que `Personas` siga calculando sobre todas las tasks cuando haya scope;
- eliminar CSS obsoleto de la vista anterior si queda reemplazado;
- revisar nombres `people-busy`, `busy` o similares si no expresan bien el
  estado de producto;
- no duplicar logica de filtrado de cards/tasks ya disponible o extraible;
- no dejar componentes muertos de la vista anterior.

## Tests

La mejora debe tener tests unitarios y de vista.

### Scope

- `Scope = Proyecto` incluye tasks activas del proyecto.
- `Scope = Nivel` incluye tasks descendientes de cards activas de ese nivel.
- `Scope = Card` incluye tasks de la card seleccionada y todo su subarbol.
- Si `Scope = Card` no tiene seleccion valida, se muestra empty state y no se
  cae al proyecto completo.

### Filtros

- `Todos` muestra todas las personas del proyecto con su estado dentro del scope.
- `Con trabajo` oculta personas sin claimed/ongoing dentro del scope.
- `Libres` muestra personas sin claimed/ongoing dentro del scope.
- `Atencion` muestra personas con bloqueos, alta carga, claimed sin movimiento o
  vencimientos relevantes.
- La busqueda encuentra por persona, task, card y capacidad.

### Orden

- `Atencion` prioriza bloqueos y sobrecarga.
- `Nombre` ordena alfabeticamente.
- `Mas reclamadas` ordena por cantidad de claimed/ongoing dentro del scope.

### Producto

- No se renderizan acciones de asignacion.
- No se renderiza claim por otra persona.
- No se renderiza cierre de task/card desde la fila de persona.
- Click en task abre el detalle de task.
- Click en card/contexto abre el detalle o navegacion de card segun el patron
  existente.

### Visual/UI

- Header, scope bar y body siguen la anatomia compartida con `Plan` y
  `Capacidades`.
- La vista no renderiza filtros propios de `Pool` que no correspondan.
- La vista no tiene overflow horizontal en desktop ni en mobile.
- Los labels largos de personas, cards y tasks se truncan o envuelven sin
  romper la fila.
- Los empty states explican el estado dentro del scope.

## Validacion Con Agent Browser

Validar al menos:

- desktop en la ruta de Personas;
- mobile `390x844`;
- `Scope = Proyecto`;
- `Scope = Nivel`;
- `Scope = Card`;
- filtro `Atencion`;
- filtro `Libres`;
- busqueda por persona;
- busqueda por task;
- busqueda por card;
- fila expandida con ongoing y claimed;
- fila con bloqueo;
- fila libre.

Revisar visualmente:

- consistencia con `Plan` y `Capacidades`;
- densidad correcta;
- ausencia de solapes;
- ausencia de texto cortado;
- dropdown/combobox no recortado por contenedores con overflow;
- foco visible y controles accesibles por teclado cuando sea viable.

## Criterios De Aceptacion

- `Personas` muestra trabajo humano dentro del scope elegido.
- `Personas` usa header y barra de scope coherentes con `Plan` y `Capacidades`.
- `Personas` no permite asignar trabajo ni reclamar por otra persona.
- Los filtros `Todos`, `Con trabajo`, `Atencion` y `Libres` funcionan.
- La busqueda cubre persona, task, card y capacidad.
- El codigo evita duplicar calculos de scope.
- La primera extraccion compartida de scope vive en `features/work_scope/queries.gleam`
  o en una ubicacion equivalente justificada.
- No queda codigo obsoleto de la vista anterior.
- Tests relevantes pasan.
- La validacion con agent-browser no detecta problemas visuales o, si los
  detecta, se corrigen antes del commit.
