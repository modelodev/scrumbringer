# Plan De Mejora: Mover Cards En Plan / Estructura

Este documento define como debe funcionar `Mover a...` para cards. El objetivo
es corregir el flujo actual, hacerlo usable y mantener coherencia con la
filosofia de ScrumBringer, la interfaz existente y la arquitectura de
componentes actual.

## Diagnostico Actual

El flujo actual no es suficientemente usable:

- El menu `...` de la fila no queda bien expuesto como control accesible
  independiente.
- `Mover a...` no abre un flujo de movimiento; llama a la misma accion que
  `Ver`.
- El usuario termina en el detalle de la card y tiene que pulsar de nuevo
  `Mover`.
- El dialogo de mover muestra copy en ingles.
- El dialogo muestra destinos invalidos antes que una accion clara.
- Los destinos se renderizan como elementos no accionables; no hay una accion
  evidente `Mover aqui`.
- Si no hay destinos validos, la accion aparece como si fuese ejecutable.

Problema de producto:

Mover una card es una accion espacial. El usuario necesita entender donde esta
la card y donde quedara. Sacar esta accion a un modal por defecto pierde
contexto, especialmente cuando `Plan / Estructura` ya muestra el arbol.

## Decision

`Mover a...` debe activar un modo temporal dentro de `Plan / Estructura`:

```text
Modo normal
  -> usuario pulsa [...] > Mover a...
Modo mover card
  -> tabla mantiene el arbol visible
  -> card origen queda resaltada
  -> destinos validos muestran [Mover aqui]
  -> destinos invalidos aparecen atenuados con motivo breve
  -> usuario confirma destino o cancela
```

No se debe empezar por drag and drop. Primero debe existir un flujo de click
accesible, testeable y claro. Drag and drop puede llegar despues como acelerador
del mismo modo.

## Modelo Mental

`Mover a...` significa cambiar el padre de una card manteniendo su nivel
semantico.

Ejemplo:

```text
Hito
  Entrega A
    Historia X
  Entrega B
```

Mover `Historia X` debe permitir elegir otra `Entrega`, no convertirla en
`Entrega` ni en `Hito`.

Regla:

```text
Card movida: nivel N
Destino valido: card de nivel N - 1 que acepte subcards
```

Si la card es de nivel 1, no tiene padre alternativo. `Mover a...` debe aparecer
deshabilitado con motivo:

```text
No disponible: las cards raiz no tienen un padre alternativo.
```

## Wireframe Desktop

Modo normal:

```text
Plan
Estructura de cards y trabajo preparado.
[13 Tarjetas] [3 Tasks] [3 Disponibles] [0 Al activar] [0 Bloqueadas]

Scope [Proyecto]       Modo [Estructura] [Kanban]       Estado [Todas] Orden [Arbol] [ ] Closed

CARD / ARBOL                              ESTADO    TASKS   AL ACTIVAR   ACCIONES
--------------------------------------------------------------------------------
Hito Q3                                   Active    0/3     ya activo    [Ver] [+] [...]
  Entrega Portal clientes                 Active    0/3     ya activo    [Ver] [+] [...]
    Historia API Cleanup                  Draft     0/0     +0 tasks     [Ver] [+] [...]
```

Tras `... > Mover a...`:

```text
Plan                                           Moviendo: Historia API Cleanup
Estructura de cards y trabajo preparado.       [Cancelar]
[13 Tarjetas] [3 Tasks] [3 Disponibles] [0 Al activar] [0 Bloqueadas]

Scope [Proyecto]       Modo [Estructura] [Kanban]       Buscar destino [Entrega...]

CARD / ARBOL                              ESTADO    ACCIONES
--------------------------------------------------------------------------------
Hito Q3                                   Active
  Entrega Portal clientes                 Active
    Historia API Cleanup                  Draft     Moviendo

  Entrega Mobile                          Active    [Mover aqui]
  Entrega Backoffice                      Draft     [Mover aqui]
  Entrega Delivery tasks                  Active    No disponible
                                                    contiene tasks directas
```

## Wireframe Mobile

En mobile, si la tabla no ofrece espacio suficiente, se permite un bottom sheet
como fallback. Debe reutilizar el mismo modelo de destinos y el mismo buscador.

```text
Moviendo
Historia API Cleanup
Actual: Hito Q3 / Entrega Portal clientes

Buscar destino
[ Entrega... ]

Destinos validos
[ Entrega Mobile                 Mover aqui ]
[ Entrega Backoffice             Mover aqui ]

No disponibles (3)  v
Entrega Delivery tasks
Contiene tasks directas.

[Cancelar]
```

El bottom sheet mobile es una adaptacion responsive del mismo flujo, no un
segundo modelo.

## Reglas De Destino

Un destino valido debe cumplir:

- pertenece al mismo proyecto;
- no es la propia card;
- no es descendiente de la card movida;
- no esta closed;
- esta en profundidad `card_depth(card_movida) - 1`;
- acepta subcards;
- no es el padre actual.

Razones de bloqueo recomendadas:

```gleam
pub type MoveBlockedReason {
  RootCardCannotMove
  SameParent
  ClosedDestination
  DestinationContainsTasks
  WouldChangeLevel
  WouldCreateCycle
  SelfOrDescendant
}
```

Copy recomendado:

```text
RootCardCannotMove: Las cards raiz no tienen un padre alternativo.
SameParent: Ya esta dentro de esta card.
ClosedDestination: La card de destino esta cerrada.
DestinationContainsTasks: Contiene tasks directas y no puede recibir subcards.
WouldChangeLevel: Cambiaria el nivel de la card.
WouldCreateCycle: No se puede mover una card dentro de si misma o de su arbol.
SelfOrDescendant: No se puede elegir la propia card ni una descendiente.
```

## Estado Frontend

Anadir estado explicito para el modo mover:

```gleam
pub type MoveMode {
  NotMoving
  MovingCard(card_id: Int, destination_query: String)
}
```

El estado debe vivir en el area de Plan, no dentro del modal de detalle. Mover
cards es una operacion de `Plan / Estructura`.

Datos derivados:

```gleam
pub type MoveDestination {
  ValidDestination(card: Card)
  InvalidDestination(card: Card, reason: MoveBlockedReason)
}
```

Reglas:

- `MovingCard` se cancela al cambiar de modo a `Kanban`.
- `MovingCard` se cancela si se cambia a un scope donde la card origen ya no
  esta visible.
- `MovingCard` conserva query mientras el usuario filtra destinos.
- Al completar movimiento, se recargan cards y se sale del modo mover.
- Si la API devuelve error, se mantiene el modo mover y se muestra feedback
  accionable.

## Reutilizacion De Componentes

Reutilizar antes de extraer.

### `features/plan/tree_table.gleam`

Debe seguir siendo la base visual de `Plan / Estructura`.

Cambios esperados:

- Permitir que la fila reciba estado visual de movimiento:
  - origen;
  - destino valido;
  - destino invalido;
  - normal.
- No convertir `tree_table` en componente global todavia.
- No meter logica de negocio de movimiento dentro de `tree_table`.

### `features/plan/card_picker.gleam`

Debe reutilizarse para el buscador de destino, pero sin forzarlo a listar solo
cards activas.

Evolucion recomendada:

```gleam
pub type CardOption {
  CardOption(
    id: Int,
    title: String,
    path: String,
    level_name: String,
    label: String,
    disabled_reason: Option(String),
  )
}
```

Funciones recomendadas:

```gleam
scope_options(...)
move_destination_options(...)
filter_options(...)
selected_label(...)
```

Si mover esto a `features/work_scope/card_picker.gleam` es prematuro, mantenerlo
en `features/plan/card_picker.gleam` y solo extraer cuando otra vista lo use de
forma real.

### `features/cards/detail_policy.gleam`

Debe ser la fuente de verdad de:

- destinos validos;
- razones de destino invalido;
- reglas de profundidad;
- reglas de ciclo;
- reglas de destino con tasks.

No duplicar estas reglas en la vista.

### `features/layout/work_surface.gleam`

Debe conservar header, chips y acciones de superficie. El modo mover puede
aparecer como estado contextual del contenido o como accion compacta en el
header:

```text
Moviendo: Historia API Cleanup     [Cancelar]
```

No convertir `work_surface` en una pantalla generica.

### `features/plan/scope_bar.gleam`

No debe absorber el modo mover. `scope_bar` sirve para contexto, modo y
refinamiento. El modo mover es un estado operativo del cuerpo de Plan.

### `ui/action_menu.gleam`

El menu `...` de Plan debe usar un menu accesible basado en botones, no
`details/summary` local si eso impide que el control quede expuesto y testeable.

Requisitos:

- trigger con `aria-label`;
- items con `role=menuitem`;
- estado abierto testeable;
- soporte keyboard basico;
- no quedar recortado por overflow;
- estilos coherentes con el resto de botones.

## Flujo De Interaccion

### Entrada

Desde fila:

```text
[...] > Mover a...
```

Si la card no puede moverse:

```text
Mover a... disabled
title / tooltip con razon
```

Desde detalle:

El boton `Mover` tambien debe activar el mismo modo inline de Plan si el usuario
esta en Plan / Estructura. No debe abrir un segundo flujo distinto.

### Seleccion De Destino

El usuario puede:

- pulsar `Mover aqui` en una fila destino valida;
- buscar destino con el picker y elegir un resultado valido;
- cancelar.

### Confirmacion

Para movimientos simples no hace falta modal de confirmacion adicional. La
accion ya esta explicitamente en modo mover.

Si el movimiento afecta a un subarbol grande, se puede mostrar confirmacion
ligera:

```text
Mover "Entrega Portal" a "Hito Q4"
Esto movera 8 cards y 23 tasks dentro del subarbol.
[Cancelar] [Mover]
```

El umbral puede definirse despues. En primera version, no bloquear por esta
confirmacion salvo que ya exista conteo fiable y copy claro.

### Salida

Tras mover:

- mostrar feedback breve;
- refrescar cards;
- salir del modo mover;
- mantener `Plan / Estructura`;
- conservar scope si sigue siendo valido;
- si el scope deja de contener la card, mostrar estado claro o volver al scope
  proyecto.

## Drag And Drop

Drag and drop es una mejora posterior, no la primera entrega.

Condiciones para introducirlo:

- existe modo mover inline por click;
- reglas de destino estan centralizadas;
- destinos validos e invalidos ya se calculan y muestran bien;
- agent-browser valida la experiencia sin drag;
- el movimiento por API esta cubierto por tests.

Cuando se implemente:

- solo activo dentro de modo mover o modo `Reorganizar`;
- nunca activo en modo normal;
- drag handle visible;
- destinos validos resaltados;
- destinos invalidos atenuados con razon;
- drop target debe decir `Soltar dentro de <card>`;
- no mostrar drop entre filas hasta que exista `cards.position`;
- debe existir fallback keyboard/click equivalente.

Mockup:

```text
Moviendo: Historia API Cleanup     [Cancelar]

☰ Historia API Cleanup

Entrega Mobile
┌──────────────────────────────────────┐
│ Soltar aqui como subcard             │
│ Hito Q3 / Entrega Mobile             │
└──────────────────────────────────────┘

Entrega Delivery tasks
No disponible: contiene tasks directas.
```

## API Y Persistencia

La UI debe llamar al endpoint existente de movimiento de card o al contrato
equivalente:

```text
PATCH /api/v1/cards/:id
{ "parent_card_id": <destino> }
```

O endpoint dedicado si ya existe:

```text
POST /api/v1/cards/:id/move
{ "parent_card_id": <destino> }
```

Reglas:

- la API debe validar ciclo;
- la API debe validar mismo proyecto;
- la API debe validar que el destino acepta subcards;
- la API debe validar que no cambia el nivel;
- la UI no debe asumir que su validacion es suficiente.

## Tests

### Unitarios De Politica

- card raiz no tiene destinos.
- no se puede mover a su padre actual.
- no se puede mover a si misma.
- no se puede mover a descendiente.
- no se puede mover a card closed.
- no se puede mover a card con tasks directas.
- no se puede mover cambiando nivel.
- destino valido aparece como `ValidDestination`.
- cada razon de bloqueo produce copy en espanol.

### Unitarios De Vista

- `Mover a...` disponible solo cuando hay destinos validos.
- `Mover a...` disabled muestra motivo cuando no hay destinos.
- al pulsar `Mover a...` aparece modo mover inline.
- el origen muestra `Moviendo`.
- destinos validos muestran `Mover aqui`.
- destinos invalidos muestran motivo breve.
- buscador filtra por titulo, path e id.
- cancelar sale del modo mover.
- al cambiar a Kanban se cancela modo mover.
- menu `...` expone trigger e items accesibles.

### Integracion Cliente/API

- pulsar `Mover aqui` llama a la API con `parent_card_id` correcto.
- exito refresca cards y sale del modo mover.
- error mantiene modo mover y muestra mensaje.
- el detalle de card usa el mismo flujo de movimiento, no un modal paralelo.

### Browser Con `agent-browser`

Validar desktop:

1. abrir `Plan / Estructura`;
2. abrir `...`;
3. verificar que `Mover a...` es visible o disabled con razon;
4. iniciar modo mover;
5. verificar origen resaltado;
6. verificar destinos validos;
7. filtrar destino con buscador;
8. ejecutar `Mover aqui`;
9. verificar que la card aparece bajo nuevo padre;
10. verificar que se sale de modo mover.

Validar mobile:

1. abrir `Plan / Estructura` en viewport movil;
2. iniciar `Mover a...`;
3. verificar fallback usable;
4. verificar sin overflow ni solapes;
5. cancelar;
6. repetir con destino valido si el seed lo permite.

Capturas recomendadas:

- modo normal;
- menu abierto;
- modo mover con destinos validos;
- modo mover sin destinos validos;
- mobile fallback.

## Limpieza Obligatoria

Eliminar o corregir:

- `types.MoveCard -> #("Mover a...", config.on_card_click(card.id))`;
- dialogo de movimiento que renderiza destinos como `div` sin accion;
- copy en ingles dentro de UI en espanol;
- menu local `details/summary` si no queda accesible/testeable;
- CSS del modal de mover si deja de usarse;
- tests que esperen el flujo viejo de detalle/modal;
- duplicacion de reglas entre vista y `detail_policy`.

No eliminar:

- API/backend de movimiento si ya esta funcionando;
- validaciones server-side;
- `card_picker` existente, salvo que se mueva con una extraccion justificada.

## Criterios De Cierre

La mejora esta terminada cuando:

- `Mover a...` no abre `Ver`.
- `Mover a...` activa modo inline de movimiento en `Plan / Estructura`.
- El usuario puede completar el movimiento sin abrir el detalle.
- El detalle reutiliza el mismo flujo o queda claramente subordinado a Plan.
- El menu de acciones es accesible y testeable.
- El buscador reutiliza la logica de `card_picker`.
- Las reglas de destino viven en `detail_policy` o modulo equivalente de
  politica, no en la vista.
- No queda copy en ingles en la UI.
- Desktop y mobile han sido revisados con `agent-browser`.
- `gleam format`, `gleam check` y `gleam test` pasan.
- `gleam-refactor` se ejecuta al final y todo lo detectado se corrige.
- El commit final incluye solo cambios necesarios para esta mejora.
