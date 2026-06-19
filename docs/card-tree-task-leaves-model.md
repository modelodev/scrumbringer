# Card Tree And Task Leaves Model

Fecha: 2026-06-19

Este documento registra las decisiones de producto y dominio para evolucionar
ScrumBringer hacia un modelo jerarquico configurable sin perder la ejecucion
pull simple.

La direccion elegida es `Card tree + Task leaves`:

- `Card`: contenedor jerarquico, agregacion y navegacion.
- `Task`: hoja ejecutable.
- Solo las tasks se reclaman, se trabajan y entran al Pool.
- Las cards agregan estado, capacidades, bloqueos, vencimiento y avance desde
  sus descendientes.

No se adopta un `WorkItem` generico ni una task recursiva. La flexibilidad viene
de nombrar y perfilar niveles de cards por proyecto, no de convertir cualquier
nodo en cualquier cosa.

## Lectura Del Documento De Usuarios

El documento `temporal.md` pide hito, entregable, tarjeta operativa, tarea,
fases, bloqueos, dashboard y multiples tablas. La necesidad real no es crear
todas esas entidades como tablas independientes, sino responder a estas
preguntas:

- Que trabajo de alto nivel existe.
- Como se descompone ese trabajo.
- Que piezas son ejecutables ahora.
- Que capacidades faltan para completar una unidad mayor.
- Que esta bloqueado y quien debe desbloquearlo.
- Que hito o agrupador esta en riesgo.

La traduccion compatible con ScrumBringer es:

```text
Card depth 1: Hito / Sprint / Release / cualquier nombre del proyecto
  Card depth 2: Entregable / Historia / Feature / Modulo
    Card depth 3: Tarjeta operativa / Area / Paquete
      Task leaf: trabajo claimable
```

Los nombres son configurables por proyecto. Internamente seguimos teniendo
`cards` y `tasks`.

## Decisiones Registradas

### D1: Dos Recursos Reales

El modelo tiene dos recursos reales:

- `Card`: estructura, navegacion y agregacion.
- `Task`: ejecucion.

Esto conserva el modelo mental de ScrumBringer: el equipo reclama piezas
concretas de trabajo, no contenedores.

### D1.1: Sin Entidades Legacy Ni Compatibilidad Temporal

La reestructuracion no debe dejar entidades legacy ni capas de compatibilidad
temporal mantenidas. Si una entidad o campo queda sustituido por el nuevo modelo,
debe migrarse al nuevo concepto y despues eliminarse de la base de codigo.

Regla general:

```text
No legacy mode.
No rutas paralelas.
No adaptadores permanentes.
No entidades antiguas representando conceptos nuevos.
```

La migracion puede preservar datos, pero no debe preservar modelos obsoletos.
Ejemplos:

- `milestones` desaparece como entidad. Un hito es una `Card` raiz cuyo nombre
  visible viene de la configuracion del proyecto para profundidad 1.
- `milestone_id` desaparece como relacion de dominio. La jerarquia se expresa
  con `parent_card_id` en cards y `parent_card_id`/`card_id` equivalente para
  ubicar tasks bajo cards.
- Las antiguas cards planas pasan a ser nodos del arbol de cards; no queda una
  entidad paralela `legacy card`.
- `CardState` antiguo (`Pendiente`, `EnCurso`, `Cerrada`) se sustituye por
  `CardExecutionState` persistido y lecturas derivadas como
  `DerivedCardState`/`ClosedCardOutcome`.
- `TaskStatus.Completed` se reinterpreta como `TaskExecutionState.Closed(Done)`;
  no debe quedar un modelo paralelo donde `Completed` compita con `Closed`.
- Fases, entregables, hitos o releases del documento de usuarios no se crean
  como tablas independientes: son nombres/profiles de niveles de cards o
  rollups derivados.

Despues de la migracion deben eliminarse endpoints, vistas, tests, copy,
documentacion y helpers que traten los conceptos antiguos como entidades vivas.

### D2: Una Card Nunca Es Claimable

Una card nunca se reclama, aunque este vacia. Si el usuario quiere trabajar una
card, primero crea una task dentro de ella.

Reglas de UI:

- En una card `Draft`, el control `+` permite seguir descomponiendo, pero lo
  creado no entra al Pool si queda bajo una card no activa.
- En una card `Active`, el control `+` puede crear una task; esa task entra al
  Pool si cumple permisos, capacidad y ausencia de bloqueos.
- La accion de cerrar manualmente una card vive en acciones secundarias, cerca
  de eliminar. No debe ser una accion principal ni frecuente.

### D3: Una Card No Mezcla Hijas Cards Y Tasks

Una card puede estar en uno de estos modos estructurales:

- Sin hijas.
- Con cards hijas.
- Con tasks hijas.

No puede contener cards y tasks a la vez. El modo se decide al insertar el
primer hijo. Para cambiar de modo hay que vaciarla o usar una conversion
explicita.

### D4: Draft Permite Preparacion Real

`Draft` no significa "solo metadatos". En una card `Draft` se puede crear
estructura completa: cards hijas y tasks hijas.

La diferencia es que `Draft` no representa trabajo liberado. Es una zona de
preparacion y descomposicion.

Crear cards o tasks dentro de una rama `Draft` requiere permisos de gestion:
`ManageStructure` para crear cards y `ManageFlow` para crear tasks que formaran
parte de una futura liberacion al Pool. En el MVP ambos permisos los tienen
`Project Manager` y `Org Admin`.

### D5: Active Abre Un Subarbol Y Propaga Hacia Abajo

Una card puede pasar a `Active` aunque este vacia. Activar una card:

- propaga siempre hacia abajo a todas sus cards descendientes,
- nunca propaga hacia arriba,
- muestra antes cuantas tasks del subarbol pasaran al Pool por esa accion.

Si la card no tiene tasks descendientes, la activacion sigue permitida. La UI
muestra impacto `0 tasks entraran al Pool`; no se trata como error ni como
alerta critica.

Activar una card es una operacion de gestion de flujo: libera trabajo al Pool.
Por tanto requiere permiso interno `ManageFlow`, derivado inicialmente de los
roles visibles `Project Manager` y `Org Admin`.

No existe `Undo` de activacion en el MVP. La UI debe mostrar confirmacion de
impacto obligatoria y, si el usuario acepta, la transicion queda auditada.

`Active` registra quien y cuando activo la card:

```gleam
pub type CardExecutionState {
  Draft
  Active(
    activated_at: DateTime,
    activated_by: UserId,
    source: ActivationSource,
  )
  Closed(reason: CardClosedReason, closed_at: DateTime, closed_by: ClosedBy)
}

pub type ActivationSource {
  DirectActivation
  ActivatedByAncestor(CardId)
}
```

La confirmacion debe mostrar:

```text
Activar Q3 Plataforma

Se activaran:
8 entregables
17 cards

Entraran al Pool:
24 tasks

Esta accion no se puede deshacer.
[Cancelar] [Activar]
```

En una rama `Active`, los miembros con `ExecuteWork` pueden crear nuevas tasks
operativas dentro de cards que aceptan tasks (`Empty` o `TaskGroup`). La task
creada entra al Pool si cumple las reglas de claimability; no se asigna
automaticamente al creador.

Crear y reclamar son acciones separadas. No existe auto-claim al crear una task
ni accion inicial `Crear y reclamar` en el MVP. Si el usuario quiere trabajarla,
debe reclamarla desde el Pool.

Crear cards hijas sigue siendo una operacion estructural y requiere
`ManageStructure`.

Ejemplo:

```text
a -> b
a -> c
b -> t1
b -> t2
c -> t3
c -> t4
```

Si se activa `b`, entran al Pool `t1` y `t2`.

Si se activa `a`, se activa todo su subarbol y entran al Pool `t1`, `t2`, `t3`
y `t4`, salvo las tasks que ya estuviesen cerradas, bloqueadas o no claimables
por otras reglas.

Una task es claimable si:

- esta abierta,
- su card contenedora esta `Active`,
- ningun ancestro esta `Closed`,
- cumple las reglas de permisos, capacidad y bloqueo.

No se exige que todos los ancestros esten `Active`; esto permite activar un
subarbol futuro sin activar todo el arbol padre.

### D5.1: Creacion Contextual De Tasks Y Efecto En Pool

La creacion de tasks debe ser contextual, no un formulario central que obligue a
elegir ubicacion en cada caso.

Reglas de producto:

- Desde el Pool, `+ Task` crea una `RootPool` task. Requiere `ManageFlow` porque
  publica trabajo directamente en el Pool raiz.
- Desde una card `Active`, `+ Task` crea una task bajo esa card y entra al Pool
  al crearse. Requiere `ExecuteWork`, porque el espacio de trabajo ya fue
  abierto por gestion.
- Desde una card `Draft`, `+ Task` crea una task preparada bajo esa card y no
  entra al Pool hasta activar la card. Requiere `ManageFlow`.
- Desde una card `Closed`, no se pueden crear tasks.

La interfaz debe explicar el efecto en el lugar donde ocurre la accion:

```text
Pool
[+ Task]  Crear en Pool raiz
          Requiere gestionar flujo

Card Active
[+ Task]  Entrara al Pool al crearla

Card Draft
[+ Task]  Quedara preparada hasta activar esta card

Card Closed
[+ Task bloqueado]  La card esta cerrada
```

El criterio visible no es "quien puede crear", sino "que impacto tiene crear
aqui". Esto evita que el permiso parezca arbitrario y mantiene la filosofia pull
de ScrumBringer.

### D5.2: Pool Sano Y Saturacion

El Pool no es un backlog visible. Es la superficie de trabajo disponible para
ser reclamada ahora. Un Pool saturado genera frustracion, reduce autonomia real y
convierte ScrumBringer en una lista de pendientes tradicional.

Regla de producto:

- Cada proyecto define un `healthy_pool_limit`.
- El valor recomendado inicial es 20 tasks abiertas.
- Superar ese umbral no bloquea el sistema automaticamente, pero se trata como
  una senal de salud de flujo.
- La excepcion esperable es el arranque de un sprint/ciclo, donde puede haber un
  pico temporal. Aun asi, el producto debe hacerlo visible como pico, no
  normalizarlo.
- La configuracion debe mostrar una leyenda clara: el objetivo del limite es
  evitar saturacion y frustracion del equipo. Es un limite blando: avisa, pero
  no bloquea.

Respuesta de UI recomendada:

```text
Pool · 27 abiertas

El Pool esta alto. Considera activar menos ramas o cerrar trabajo que ya no deba
reclamarse ahora.

[Ver ramas activas] [Revisar antiguedad]
```

Al activar una card, la confirmacion debe incluir el impacto sobre el tamano del
Pool:

```text
Entraran al Pool:
14 tasks

Pool despues de activar:
31 tasks abiertas

Esto puede saturar al equipo.
[Cancelar] [Activar de todos modos]
```

La advertencia no debe sonar punitiva. Debe ayudar al manager a proteger el foco
del equipo. La accion puede seguir permitida porque puede haber contextos
validos, pero el producto debe hacer explicito el coste.

La performance tecnica debe soportar arboles grandes, pero la experiencia
principal no debe disenar para un Pool masivo como si fuera normal.

### D6: Closed Cierra Una Rama Completa

`Closed` es estado final. En cards, puede llegar por dos caminos:

- Rollup automatico: todos sus hijos directos estan cerrados.
- Cierre manual: un usuario confirma cerrar esa rama.

El cierre manual de una card cierra todo su subarbol. La confirmacion debe
mostrar impacto, incluyendo:

- tasks disponibles que se cerraran,
- tasks reclamadas que se cerraran,
- cards descendientes afectadas.

El cierre manual es equivalente en peso a un borrado logico: deja rastro y no
debe estar excesivamente a mano.

### D7: Delete Real Solo Sin Historial Operativo

Debe existir `Delete` real solo para cards/tasks sin historial operativo.

No bloquean delete:

- cambios de titulo,
- descripcion,
- due date,
- capacidad,
- otros metadatos.

Bloquean delete:

- claim,
- completion,
- cierre,
- bloqueo,
- comentario,
- eventos de workflow relevantes.

Cuando no se pueda eliminar, la UI debe mostrar `Eliminar` deshabilitado dentro
del menu secundario con una ayuda contextual: no se puede eliminar porque tiene
historial operativo; debe cerrarse en su lugar.

### D8: Task Closed Reason, Card Closed Reason

`Closed` es el estado final comun. La razon explica como se llego ahi.

En UI, una task `Closed(Done)` se muestra como "Done" o "Completada"; no como
"Cerrada".

```gleam
pub type CardExecutionState {
  Draft
  Active
  Closed(reason: CardClosedReason, closed_at: DateTime, closed_by: ClosedBy)
}

pub type CardClosedReason {
  Rollup
  ManuallyClosed
}

pub type TaskExecutionState {
  Open(status: TaskOpenStatus)
  Closed(reason: TaskClosedReason, closed_at: DateTime, closed_by: ClosedBy)
}

pub type TaskOpenStatus {
  Unclaimed
  Claimed(by: UserId, claimed_at: DateTime)
}

pub type TaskClosedReason {
  Done
  ManuallyClosed
  ClosedByAncestor
}
```

Una card no tiene `Done` como razon propia. Si todas las tasks descendientes se
cerraron por `Done`, la UI puede mostrar la card como completada, pero eso es
una lectura derivada de descendientes.

### D8.1: Cierre Manual Y Tasks Reclamadas

El cierre manual de una card no puede interrumpir trabajo reclamado por una
persona.

Reglas:

- Si cualquier task descendiente esta `Claimed(...)`, no se puede cerrar la card
  manualmente.
- No se distingue entre `Claimed(Taken)` y `Claimed(Ongoing)` para esta
  validacion.
- Para cerrar la rama, esas tasks deben completarse, liberarse al Pool o
  cerrarse individualmente por quien corresponda.
- Si solo hay tasks `Available` o `Closed(...)`, el cierre manual puede estar
  disponible segun permisos normales.

La UI debe explicar el bloqueo antes de ejecutar la accion:

```text
┌────────────────────────────────────────────────────────────┐
│ No se puede cerrar esta card                               │
├────────────────────────────────────────────────────────────┤
│ Hay tasks reclamadas dentro de esta rama.                  │
│                                                            │
│ • Ana tiene "Integrar callback PSP"                         │
│ • Luis esta trabajando en "Regresion checkout movil"        │
│                                                            │
│ Para cerrar esta card, primero deben completarse,           │
│ liberarse o cerrarse esas tasks.                            │
│                                                            │
│                                      [Entendido]           │
└────────────────────────────────────────────────────────────┘
```

`Claimed` se trata como una senal social, no solo tecnica: alguien ha tirado de
esa task y la plataforma debe forzar comunicacion antes de cancelar la rama.

Cuando el cierre manual si esta permitido, todas las tasks descendientes
`Available` se cierran automaticamente como `Closed(ClosedByAncestor)`.

Las tasks descendientes ya cerradas conservan su razon original. Las cards
descendientes pasan a `Closed(ManuallyClosed)` o quedan cerradas por rollup
segun la estrategia de implementacion, pero el resultado visible es que toda la
rama queda fuera de ejecucion.

El motivo humano opcional del cierre manual de card no forma parte del ADT ni de
un campo estructurado inicial. Si se informa, se persiste como nota automatica
en la card cerrada. La razon tipada sigue siendo `CardClosedReason.ManuallyClosed`.

Cuando el cierre manual de card cierra tasks descendientes `Available` como
`Task.Closed(ClosedByAncestor)`, no se crea una nota automatica en cada task. La
trazabilidad se conserva mediante:

- la nota automatica en la card cerrada, si hubo motivo;
- los eventos de cierre;
- la razon tipada `ClosedByAncestor` en cada task afectada.

### D9: Rollup Automatico Por Hijos Directos

Una card pasa automaticamente a `Closed(Rollup)` cuando todos sus hijos directos
estan en estado final:

- si contiene tasks, cuando todas sus tasks estan `Closed(...)`;
- si contiene cards, cuando todas sus cards estan `Closed(...)`.

El rollup sube nivel a nivel. No salta cards intermedias mirando todas las tasks
descendientes de golpe.

### D9.1: Metricas De Completitud Y Cierre

Completitud y cierre operativo son lecturas distintas.

Reglas:

- `Task.Closed(Done)` cuenta como completitud real.
- `Task.Closed(ClosedByAncestor)` y `Task.Closed(ManuallyClosed)` cuentan como
  trabajo cerrado/cancelado, pero no como completado.
- Cualquier `Closed(...)` cuenta como estado final para rollup.
- Una card puede estar `Closed(Rollup)` aunque no este completada al 100% si sus
  hojas fueron cerradas por razones distintas a `Done`.

Esto evita inflar progreso, throughput o velocity con trabajo cancelado.

### D9.2: Resultado Visible De Cards Cerradas

Una card cerrada mantiene `Closed` como estado principal. La UI anade un
resultado derivado:

- `Completada`: todas las hojas cerradas relevantes terminaron con
  `Task.Closed(Done)`.
- `Cerrada sin completar`: al menos una hoja termino con
  `Task.Closed(ClosedByAncestor)` o `Task.Closed(ManuallyClosed)`.

No se introducen estados principales paralelos `Completed` y `Closed` en card.
La diferencia vive en la lectura derivada para evitar duplicar el modelo.

Ejemplo:

```text
Checkout nuevo    Closed · Completada            13/13 done
Portal clientes   Closed · Cerrada sin completar 7 done · 3 canceladas
```

### D10: Capacidades Solo En Tasks

La relacion entre cards y capabilities es meramente transitiva:

```text
Card -> descendants -> Tasks -> Capability
```

No existe `CardCapability`, capacidad esperada, ni fase abstracta en card.

Cada task tiene exactamente una capability obligatoria. Si algo necesita Backend
y QA, deben existir dos tasks.

### D11: Fases Visibles Son Capacidades Agregadas

Las "fases de avance" del documento de usuarios se interpretan como capacidades
agregadas desde tasks descendientes.

No son columnas manuales por las que una task debe pasar. Tampoco son requisitos
de card persistidos. Si falta QA, se crea una task de QA; entonces QA aparece en
la card.

Una card puede responder preguntas derivadas:

- cuantas tasks de Backend tiene debajo,
- cuantas estan abiertas, reclamadas o cerradas,
- si QA existe o no existe en ese subarbol,
- que capacidades tienen trabajo pendiente,
- que capacidades estan completas.

### D11.1: Dependencias Solo Entre Tasks

Las dependencias siguen siendo una relacion de ejecucion entre tasks. No se
introducen dependencias entre cards en el MVP.

Reglas:

- una task puede depender de otra task;
- la dependencia puede cruzar cards o ramas siempre que ambas tasks pertenezcan
  al mismo proyecto;
- no se permiten dependencias entre proyectos en el MVP;
- una task bloqueada por dependencias no puede reclamarse;
- una card muestra dependencias bloqueantes como rollup derivado desde sus tasks
  descendientes;
- las cards no guardan dependencias propias como fuente de verdad.

Esto mantiene las dependencias en la unidad ejecutable y evita duplicar
bloqueos/planificacion en contenedores.

Una dependencia bloquea solo mientras la task dependida sigue abierta:

```text
Available -> bloquea
Claimed   -> bloquea
Closed    -> no bloquea
Deleted   -> no bloquea porque la relacion desaparece
```

`Closed(Done)` y `Closed` no-done desbloquean por igual. Esto no afecta
metricas: solo `Closed(Done)` cuenta como completitud.

Tipos y funciones base:

```gleam
pub type TaskDependency {
  TaskDependency(
    task_id: TaskId,
    depends_on_task_id: TaskId,
  )
}

pub type DependencySummary {
  DependencySummary(
    depends_on_task_id: TaskId,
    title: String,
    state: TaskExecutionState,
  )
}

pub type AddDependencyError {
  SameTask
  DifferentProject
  DependencyAlreadyExists
  DependencyWouldCreateCycle
  TaskNotFound
  DependsOnTaskNotFound
}

pub fn dependency_blocks(state: TaskExecutionState) -> Bool {
  case state {
    Available -> True
    Claimed(..) -> True
    Closed(..) -> False
  }
}
```

`DependencyWouldCreateCycle` ocurre cuando la nueva relacion haria que una task
dependa directa o indirectamente de si misma. Ejemplo:

```text
A depende de B
B depende de C

No se puede anadir:
C depende de A
```

En persistencia, si una task se elimina, sus relaciones de dependencia deben
desaparecer con `ON DELETE CASCADE`. `Deleted` no es estado de dominio para
dependencias.

Cuando todas las dependencias de una task dejan de bloquear, no se crea un
estado visual nuevo. La task vuelve a ser claimable y aparece en el Pool si
cumple el resto de reglas. Cualquier aviso adicional debe implementarse como
workflow/notificacion, no como estado de dominio.

Las cards muestran un rollup derivado cuando tienen tasks descendientes
bloqueadas por dependencias. La etiqueta no debe ser `Bloqueada`, para no
confundir dependencias con bloqueos explicitos.

Etiqueta recomendada:

```text
[2 esperando dependencia]
```

En cards compactas puede abreviarse:

```text
[2 esperando]
```

Detalle de card:

```text
Senales
[2 esperando dependencia] [1 reclamada] [vence 28 Jun]

Esperando dependencias
• Casos checkout fallido espera "Contrato PSP"
• Regresion checkout movil espera "Ambiente QA"
```

Si una card tiene bloqueos explicitos y dependencias pendientes, se muestran
ambas senales:

```text
[Bloqueada] [2 esperando dependencia]
```

### D12: Nombres Por Profundidad Y Wizard De Proyecto

Cada proyecto define los nombres de sus niveles de cards durante un wizard
obligatorio de creacion de proyecto.

El wizard debe:

- partir de una plantilla,
- pedir cuantas capas de cards tendra el proyecto,
- pedir nombre singular y plural por cada profundidad,
- pedir o confirmar el limite sano del Pool (`healthy_pool_limit`), con valor
  recomendado inicial 20,
- permitir revisar antes de crear el proyecto.

No se guarda una "intencion funcional" separada del nombre visible, porque puede
duplicar o contradecir el lenguaje elegido por el equipo. La intencion queda
expresada por el nombre y por el anidamiento elegido.

Los niveles no son entidades de dominio. Se infieren por la profundidad de cada
card dentro del arbol. La configuracion del proyecto solo nombra y perfila esas
profundidades.

Reglas de modificacion tras crear el proyecto:

- se pueden cambiar `singular_name` y `plural_name` de una profundidad;
- no se reordenan profundidades, porque la profundidad nace de la estructura del
  arbol;
- no se borra un nivel como entidad, porque no existe tal entidad;
- si hay cards existentes en una profundidad, esa profundidad sigue existiendo
  por inferencia;
- las vistas historicas usan el nombre actual configurado para esa profundidad;
- los cambios de configuracion quedan auditados.

```gleam
pub opaque type CardHierarchy {
  CardHierarchy(depth_names: NonEmpty(CardDepthName))
}

pub opaque type CardDepthName {
  CardDepthName(
    singular_name: NonEmptyString,
    plural_name: NonEmptyString,
  )
}

pub opaque type HealthyPoolLimit {
  HealthyPoolLimit(Int)
}

pub type CardProfile {
  TrackingProfile
  CoordinationProfile
  ExecutionProfile
}

pub type CardHierarchyError {
  EmptyHierarchy
  InvalidDepth(Int)
  EmptyDepthName
}

pub fn nesting_depth(hierarchy: CardHierarchy) -> Int

pub fn name_for_depth(
  hierarchy: CardHierarchy,
  depth: Int,
) -> Result(CardDepthName, CardHierarchyError)

pub fn profile_for_depth(
  hierarchy: CardHierarchy,
  depth: Int,
) -> Result(CardProfile, CardHierarchyError)

pub fn depths(hierarchy: CardHierarchy) -> List(#(Int, CardDepthName))
```

Ejemplo de proyecto con tres niveles maximos de anidamiento:

```gleam
let hierarchy =
  card_hierarchy.new([
    CardDepthName(singular_name: "Hito", plural_name: "Hitos"),
    CardDepthName(singular_name: "Entrega", plural_name: "Entregas"),
    CardDepthName(singular_name: "Historia", plural_name: "Historias"),
  ])
```

Ese proyecto permite esta forma:

```text
Hito
+-- Entrega
    +-- Historia
        +-- Task
```

Y no permite colgar tasks en niveles intermedios ni crear cards por debajo del
ultimo nivel:

```text
Hito
+-- Task                  // invalido

Hito
+-- Entrega
    +-- Task              // invalido

Hito
+-- Entrega
    +-- Historia
        +-- Card          // invalido
```

Los nombres visibles no crean tipos distintos. `Hito`, `Entrega` e `Historia`
son nombres configurados para profundidades de `Card`; `Task` sigue siendo la
unica hoja ejecutable.

```gleam
pub type ProjectSettings {
  ProjectSettings(
    card_hierarchy: CardHierarchy,
    healthy_pool_limit: HealthyPoolLimit,
    version: Version,
  )
}
```

```gleam
pub fn healthy_pool_limit_from_int(
  value: Int,
) -> Result(HealthyPoolLimit, HealthyPoolLimitError)
```

La configuracion de `healthy_pool_limit` debe incluir ayuda contextual:

```text
Limite sano del Pool

Ayuda a evitar saturacion y frustracion. Es un limite blando: ScrumBringer avisa
cuando el Pool supera este numero de tasks abiertas, pero no bloquea el trabajo.
```

### D13: Profiles De Vista Por Nivel

La profundidad define jerarquia. El nombre define lenguaje. El profile define
experiencia de vista, pero no se configura como entidad independiente.

El profile se deriva del anidamiento:

```text
1 capa de cards:
  depth 1 -> Ejecucion
  Task    -> Pool

2 capas de cards:
  depth 1 -> Seguimiento
  depth 2 -> Ejecucion
  Task    -> Pool

3+ capas de cards:
  depth 1       -> Seguimiento
  depth 2..n-1  -> Coordinacion
  depth n       -> Ejecucion
  Task          -> Pool
```

Profiles derivados:

```gleam
pub type CardProfile {
  TrackingProfile
  CoordinationProfile
  ExecutionProfile
}
```

Los nombres internos son orientativos. La UI debe mostrar el nombre configurado
por el proyecto, no el nombre tecnico del profile.

### D14: Scope Por Nivel Y Scope Por Card

Cada profile puede operar sobre dos scopes:

```gleam
pub type CardScope {
  DepthScope(depth: Int)
  CardScope(card_id: CardId)
}
```

`DepthScope(depth)` muestra todas las cards de una profundidad concreta.

`CardScope(card_id)` muestra una card concreta y sus hijas directas, usando el
profile que corresponda al nivel de esas hijas o al contexto de navegacion.

Ejemplos:

```text
Seguimiento + DepthScope(1)
-> todos los hitos

Seguimiento + CardScope(hito_id)
-> detalle del hito + sus hijos directos

Coordinacion + DepthScope(2)
-> todos los entregables, agrupables por padre

Coordinacion + CardScope(hito_id)
-> kanban de entregables dentro de ese hito

Ejecucion + DepthScope(3)
-> todas las cards ejecutivas con senales compactas

Ejecucion + CardScope(card_id)
-> capacidades + tasks de esa card
```

### D15: Movimiento De Cards Restringido Al Mismo Nivel

En el MVP no se permite reorganizacion libre del arbol. Se permite mover una
card a otro padre solo si conserva su profundidad y su nombre visible.

Esto significa que se puede cambiar `parent_card_id`, pero solo hacia un padre
de la profundidad inmediatamente superior. La operacion resuelve casos comunes
como:

```text
Mover un Entregable de un Hito a otro Hito.
Mover una Card de un Entregable a otro Entregable.
```

No se permite mover una card a una posicion que cambie su nivel:

```text
Entregable -> Hito
Card -> Entregable
```

Reglas iniciales:

- la card movida no puede estar `Closed`;
- el destino no puede estar `Closed`;
- el destino debe estar en el nivel padre correcto;
- el destino debe aceptar cards hijas: `Empty` o `CardGroup`;
- no se puede crear un ciclo;
- la profundidad efectiva de la card movida no puede cambiar.

La UI debe exponer esto como accion secundaria `Mover a...`, no como
drag-and-drop libre ni como reorganizacion estructural avanzada.

Wireframe:

```text
┌────────────────────────────────────────────────────────────┐
│ Mover Entregable                                           │
├────────────────────────────────────────────────────────────┤
│ Checkout nuevo                                             │
│                                                            │
│ Padre actual                                               │
│ Q3 Plataforma                                              │
│                                                            │
│ Nuevo padre                                                │
│ [Buscar hito...]                                           │
│                                                            │
│ Hitos disponibles                                          │
│ ○ Q3 Plataforma                         actual             │
│ ○ Q4 Plataforma                         4 entregables      │
│ ○ Operaciones                           2 entregables      │
│ × Portal cerrado                        cerrado            │
│                                                            │
│ Impacto                                                    │
│ Nivel: Entregable, sin cambios                            │
│ Subarbol: 3 cards, 13 tasks                                │
│ Pool: sin cambios                                          │
│ Historial: se registra el movimiento                       │
│                                                            │
│                              [Cancelar] [Mover]            │
└────────────────────────────────────────────────────────────┘
```

Para una card de nivel operativo:

```text
┌────────────────────────────────────────────────────────────┐
│ Mover Card                                                 │
├────────────────────────────────────────────────────────────┤
│ API pagos                                                  │
│                                                            │
│ Padre actual                                               │
│ Checkout nuevo                                             │
│                                                            │
│ Nuevo padre                                                │
│ [Buscar entregable...]                                     │
│                                                            │
│ Entregables disponibles                                    │
│ ○ Checkout nuevo                        actual             │
│ ○ Portal clientes                       5 cards            │
│ ○ Facturacion                          3 cards            │
│ × QA hardening                         contiene tasks      │
│                                                            │
│ Impacto                                                    │
│ Nivel: Card, sin cambios                                  │
│ Tasks: 5, mantienen estado y capacidad                     │
│                                                            │
│                              [Cancelar] [Mover]            │
└────────────────────────────────────────────────────────────┘
```

Mover cards es una operacion de estructura y requiere el permiso interno
`ManageStructure`, derivado inicialmente de `Project Manager` y `Org Admin`.

### D16: Roles Visibles Y Privilegios Internos

El producto mantiene roles visibles simples:

```text
Org Admin
Project Manager
Project Member
```

Internamente, el codigo debe razonar en terminos de privilegios operativos, no
comparando roles directamente en cada mutacion.

Privilegios conceptuales iniciales:

```gleam
pub type ManageFlow
pub type ManageStructure
pub type ManageCatalog
pub type ExecuteWork
pub type ReadHistory

pub opaque type Authorized(privilege) {
  Authorized(user_id: UserId, project_id: ProjectId)
}
```

Mapeo MVP:

```text
Org Admin
  -> ManageFlow
  -> ManageStructure
  -> ManageCatalog
  -> ExecuteWork
  -> ReadHistory

Project Manager
  -> ManageFlow
  -> ManageStructure
  -> ManageCatalog
  -> ExecuteWork
  -> ReadHistory

Project Member
  -> ExecuteWork
  -> ReadHistory
```

Las operaciones sensibles reciben tokens tipados:

```gleam
pub fn activate_card(
  card: Card,
  actor: Authorized(ManageFlow),
  now: DateTime,
) -> Result(CardActivationPlan, ActivateCardError)

pub fn move_card_to_parent(
  card: Card,
  actor: Authorized(ManageStructure),
  destination_parent: Option(CardId),
  tree: CardTree,
) -> Result(Card, CardMoveError)

pub fn claim_task(
  task: Task,
  actor: Authorized(ExecuteWork),
  now: DateTime,
) -> Result(Task, ClaimTaskError)
```

La forma de obtener esos tokens vive en funciones especificas:

```gleam
pub fn require_manage_flow(
  user: User,
  project: Project,
) -> Result(Authorized(ManageFlow), AuthorizationError)

pub fn require_manage_structure(
  user: User,
  project: Project,
) -> Result(Authorized(ManageStructure), AuthorizationError)
```

No se expone configuracion de permisos finos en MVP. Si en el futuro se anade
RBAC granular, cambia la implementacion de `require_*`, no las operaciones de
dominio.

La definicion de permisos debe estar centralizada en un modulo compartido, con
documentacion de intencion por permiso. Ejemplo:

```gleam
//// ManageFlow permite cambiar que trabajo esta disponible para el equipo:
//// activar cards, cerrar ramas cuando este permitido y liberar tasks al Pool.
pub type ManageFlow

//// ManageStructure permite cambiar el arbol de trabajo:
//// crear cards, mover cards, configurar niveles y editar jerarquia.
pub type ManageStructure

//// ExecuteWork permite participar en la ejecucion pull:
//// ver Pool, reclamar, liberar, completar tasks y crear tasks operativas
//// dentro de grupos activos.
pub type ExecuteWork
```

El codigo de UI puede usar helpers `can_*`, pero las mutaciones sensibles deben
usar `require_*` y recibir `Authorized(permission)`.

### D17: Migracion Sin Legacy

La migracion a `Card tree + Task leaves` debe hacerse como corte de modelo. No
habra modo mixto donde `milestones`, `CardState` antiguo o `TaskStatus.Completed`
convivan como conceptos vivos con el modelo nuevo.

Principios de ejecucion:

- Migrar datos al modelo nuevo.
- Cambiar contratos compartidos, endpoints, SQL, vistas y tests en la misma
  linea de trabajo.
- Eliminar codigo sustituido, no envolverlo con adaptadores permanentes.
- No mantener rutas paralelas para clientes antiguos.
- No introducir entidades nuevas para conceptos que ya resuelve el arbol de
  cards.

Inventario actual que debe desaparecer o transformarse:

```text
DB
  milestones
  cards.milestone_id
  tasks.milestone_id
  task_milestone_exclusive
  idx_*_milestone*
  unico milestone active por proyecto

Shared domain
  domain/milestone*
  CardState(Pendiente, EnCurso, Cerrada)
  TaskStatus.Completed como estado independiente
  codecs/payloads que serialicen milestones o estados antiguos

Server
  http/milestones*
  services/milestones_db
  sql/milestones_*
  rutas /api/v1/projects/:id/milestones
  rutas /api/v1/milestones/:id
  rutas /api/v1/milestones/:id/activate

Client
  api/milestones
  features/milestones/*
  rutas/paneles/copy que llamen milestone a un concepto vivo
  movimiento basado en milestone destino

Tests/docs
  tests que validen endpoints antiguos
  docs que describan milestones como entidad
  fixtures/seeds que creen milestones en vez de cards raiz
```

Modelo de datos destino:

```text
cards
  id
  project_id
  parent_card_id NULL
  title
  description
  color
  execution_state
  activated_at
  activated_by
  activation_source
  closed_at
  closed_by
  closed_reason
  due_date
  created_by
  created_at

tasks
  id
  project_id
  card_id NULL
  capability_id
  execution_state
  claimed_by
  claimed_at
  claimed_mode
  closed_at
  closed_by
  closed_reason
  due_date
  ...

project_settings
  project_id
  healthy_pool_limit
  version

project_card_depth_names
  project_id
  depth
  singular_name
  plural_name
```

`tasks.card_id NULL` representa una task sin card padre. Decision cerrada: se
permiten tasks sin card padre. No son legacy; son tasks de Pool raiz.

En dominio deben modelarse de forma explicita para evitar que `None` sea
ambiguo:

```gleam
pub type TaskPlacement {
  RootPool
  UnderCard(CardId)
}
```

Reglas de `RootPool`:

- aparece en el Pool si esta `Available`, no bloqueada y el usuario cumple las
  reglas de capacidad/permisos;
- no depende de activacion ni cierre de ninguna card;
- no cuenta en rollups de cards;
- si cuenta en metricas de proyecto, persona y capacidad.

Estrategia de migracion de datos:

1. Crear configuracion de niveles por proyecto.
   - Nuevos proyectos usan el wizard y perfiles iniciales.
   - Proyectos existentes reciben una configuracion generada desde su estructura
     real migrada.
   - Para proyectos existentes, la migracion preserva la profundidad real:
     `Hito actual > Card actual > Task`.
   - Por tanto, los hitos actuales pasan a ser cards de nivel 1 y las cards
     actuales pasan a ser cards de nivel 2. No se crea un nivel 1 vacio ni un
     contenedor invisible.
2. Convertir cada milestone existente en una card raiz.
   - `milestones.name` -> `cards.title`.
   - `milestones.description` -> `cards.description`.
   - `ready` -> `Draft`.
   - `active` -> `Active(activated_at, activated_by desconocido/sistema si no
     existe dato historico)`.
   - `completed` -> `Closed(Rollup)` si todas las hojas migradas estan cerradas;
     si no, registrar inconsistencia antes de cortar.
3. Convertir cada card existente en card hija del hito/card raiz que le
   correspondia.
   - `cards.milestone_id` deja de existir.
   - La relacion pasa a `cards.parent_card_id`.
4. Reubicar tasks existentes.
   - Tasks con `card_id` quedan bajo esa card.
   - Tasks con `milestone_id` y sin `card_id` quedan bajo la card raiz si no hay
     subcards; si hay subcards, se crea una card hija explicita para mantener la
     regla "card contiene solo cards o solo tasks".
   - Tasks sin `card_id` ni `milestone_id` se migran como `RootPool`.
5. Mapear estado de task.
   - `available` -> `Available`.
   - `claimed` -> `Claimed(by, claimed_at, mode)`.
   - `completed` -> `Closed(Done, completed_at, closed_by sistema/usuario si
     existe dato historico)`.
6. Recalcular rollups de cards tras migrar tasks.
   - Una card sin hijas puede quedar `Draft`/`Active` segun el estado migrado.
   - Una card con todas sus hijas cerradas puede pasar a `Closed(Rollup)`.
   - Una card activa con hojas abiertas mantiene `Active`.

Politica para conflictos de estructura:

- Si un nodo migrado tendria simultaneamente cards hijas y tasks hijas, se crea
  una card agrupadora con nombre visible y estable, por ejemplo `Trabajo directo`.
- Esa card no es legacy: es una card normal creada por la migracion para hacer
  representable una estructura antes invalida.
- La migracion debe emitir un informe con cards agrupadoras creadas y numero de
  tasks afectadas.

Orden tecnico recomendado:

1. Escribir tests de contrato de dominio para ADTs, transiciones y errores.
2. Definir ADTs compartidos nuevos y codecs nuevos hasta poner esos tests en
   verde.
3. Escribir tests de migracion con fixtures de la BBDD actual.
4. Crear migracion SQL destructiva/controlada de schema y datos hasta poner esos
   tests en verde.
5. Definir contratos API compartidos de request/response en `shared/src/api`
   para endpoints usados por frontend y server.
6. Definir casos de uso en `apps/server/src/use_case` con `Command`, permisos,
   version, transaccion, repositorios y auditoria.
7. Escribir tests de servidor para endpoints nuevos y desaparicion de endpoints
   legacy.
8. Reescribir queries de cards/tasks sobre `parent_card_id`, `card_id` y
   `execution_state`.
9. Sustituir endpoints de milestones por endpoints de cards:
   - activar card,
   - cerrar card,
   - mover card,
   - listar por scope (`DepthScope`/`CardScope`),
   - obtener detalle con rollups.
10. Escribir tests de cliente/componentes para Pool, scopes, perfiles, acciones y
   estados cerrados.
11. Reescribir cliente quitando `features/milestones/*` y creando vistas por
   perfiles/scope.
12. Actualizar seeds y fixtures al modelo nuevo.
13. Sustituir tests legacy por tests del modelo nuevo.
14. Ejecutar barridos `rg` para confirmar que no quedan conceptos vivos
   obsoletos.

Estrategia red/green/refactor:

- Cada capa empieza con un test fallando del contrato publico, no de detalles de
  implementacion.
- Los tests deben usar constructores y tipos reales del dominio. No se crean
  duplicados semanticos solo para pruebas.
- En Gleam se usa `let assert`; no se usa `gleeunit/should`.
- Los tests de codecs de dominio hacen round-trip entre ADT y JSON solo cuando
  ese ADT sea un contrato compartido real.
- Los tests de codecs API hacen round-trip de request/response compartidos entre
  frontend y server.
- Los tests de mappers cubren `Row` SQL -> dominio y dominio -> `View` o
  `Response` API cuando corresponda.
- Los tests de migracion usan fixtures representativas:
  - milestone con cards y tasks,
  - task directa en milestone sin card,
  - task sin milestone ni card,
  - milestone activa,
  - milestone completada,
  - task available,
  - task claimed,
  - task completed.
- Los tests de endpoints validan tanto la nueva conducta como que las rutas
  legacy ya no existen.
- Los tests de UI cubren estado visible y acciones disponibles, no estructura
  interna del DOM salvo que sea un contrato reusable del sistema de componentes.
- El refactor solo ocurre con tests verdes y mantiene los contratos publicos.

Checks de limpieza:

```text
rg "milestone|Milestone|milestones|milestone_id" shared/src apps/server/src apps/client/src
rg "CardState|Pendiente|EnCurso|Cerrada" shared/src apps/server/src apps/client/src
rg "TaskStatus|Completed" shared/src apps/server/src apps/client/src
```

La expectativa no es necesariamente cero en migraciones historicas si no se
rebasa la historia SQL. Pero en codigo activo, shared domain, cliente, servidor,
tests vivos, seeds y documentacion funcional no debe quedar el modelo antiguo.

Si se decide rebasar/squashear migraciones para esta reestructuracion, entonces
tambien debe desaparecer de `db/migrations` y `db/schema.sql`. Esa decision es
operativa del repositorio, no una excepcion de producto.

Decision cerrada: se prefiere la opcion mas limpia posible siempre que exista
un camino fiable para migrar datos desde la BBDD actual a la BBDD final. El
schema final no debe cargar con estructuras antiguas por compatibilidad.

## Boceto De Tipos ADT

Estos tipos son bocetos de dominio. No son codigo final, pero marcan la
direccion para hacer estados ilegales irrepresentables.

### Identificadores

```gleam
pub opaque type CardId {
  CardId(Int)
}

pub opaque type TaskId {
  TaskId(Int)
}

pub opaque type ProjectId {
  ProjectId(Int)
}

pub opaque type OrgId {
  OrgId(Int)
}

pub opaque type UserId {
  UserId(Int)
}

pub opaque type CapabilityId {
  CapabilityId(Int)
}

pub opaque type Version {
  Version(Int)
}
```

### Card Structure

```gleam
pub type CardStructure {
  Empty
  TaskGroup(tasks: NonEmpty(TaskId))
  CardGroup(cards: NonEmpty(CardId))
}

pub opaque type NonEmpty(a) {
  NonEmpty(head: a, tail: List(a))
}
```

### Card

```gleam
pub type Card {
  Card(
    id: CardId,
    project_id: ProjectId,
    parent: Option(CardId),
    title: String,
    description: Option(String),
    structure: CardStructure,
    execution_state: CardExecutionState,
    due_date: Option(due_date.DueDate),
    version: Version,
    created_at: DateTime,
  )
}
```

### Task

```gleam
pub type Task {
  Task(
    id: TaskId,
    project_id: ProjectId,
    parent: Option(CardId),
    title: String,
    description: Option(String),
    capability_id: CapabilityId,
    priority: Int,
    execution_state: TaskExecutionState,
    due_date: Option(due_date.DueDate),
    version: Version,
    created_at: DateTime,
  )
}
```

### Derived Capability Rollup

```gleam
pub type CapabilityRollup {
  CapabilityRollup(
    capability_id: CapabilityId,
    total_tasks: Int,
    open_tasks: Int,
    claimed_tasks: Int,
    closed_tasks: Int,
    active_blockers: Int,
  )
}

pub type DerivedCapabilityStatus {
  NoWork
  Pending
  InProgress
  Blocked
  Satisfied
}
```

`NoWork` es informativo cuando se comparan capacidades del proyecto, pero no
implica que una card esperaba esa capacidad.

### Derived Card State

```gleam
pub type DerivedCardState {
  Empty
  Drafting
  ReadyWork
  InProgress
  Blocked
  AtRisk
  Completed
  Closed
}

pub type ClosedCardOutcome {
  CompletedOutcome
  ClosedIncompleteOutcome
}
```

`DerivedCardState` no sustituye `CardExecutionState`. Es lectura de UI calculada
desde estructura, tasks, blockers, due dates y razones de cierre.

Para metricas de avance deben existir lecturas separadas:

```gleam
pub type CompletionRollup {
  CompletionRollup(
    done_tasks: Int,
    closed_not_done_tasks: Int,
    open_tasks: Int,
  )
}
```

### Blocker

```gleam
pub type BlockerTarget {
  BlocksTask(TaskId)
  BlocksCard(CardId)
}

pub type Blocker {
  Blocker(
    id: BlockerId,
    target: BlockerTarget,
    kind: BlockerKind,
    impact: BlockerImpact,
    owner: BlockerOwner,
    state: BlockerState,
    reason: String,
    next_action: Option(String),
  )
}

pub type BlockerState {
  Active(created_at: DateTime)
  Resolved(created_at: DateTime, resolved_at: DateTime)
}

pub type BlockerImpact {
  Low
  Medium
  High
}

pub type BlockerOwner {
  UserOwner(UserId)
  CapabilityOwner(CapabilityId)
  ExternalOwner(label: String)
}
```

### Child Mode Validation

```gleam
pub type ChildInsertError {
  CannotAddTaskToCardGroup
  CannotAddCardToTaskGroup
  CannotAddChildToClosedCard
  ParentNotFound
}

pub type CardMoveError {
  CannotMoveClosedCard
  CannotMoveIntoClosedCard
  DestinationDoesNotAcceptCards
  DestinationAtWrongDepth
  MoveWouldChangeDepth
  MoveWouldCreateCycle
  CardNotFound
  DestinationNotFound
}

pub type ManualCardCloseError {
  CannotCloseClosedCard
  ClaimedTasksInSubtree(List(TaskId))
  PermissionDenied
  CardNotFound
}

pub fn add_task_child(card: Card, task_id: TaskId) ->
  Result(Card, ChildInsertError)

pub fn add_card_child(card: Card, child_card_id: CardId) ->
  Result(Card, ChildInsertError)

pub fn move_card_to_parent(
  card: Card,
  actor: Authorized(ManageStructure),
  destination_parent: Option(CardId),
  tree: CardTree,
) -> Result(Card, CardMoveError)

pub fn close_card_manually(
  card: Card,
  actor: UserId,
  tree: CardTree,
) -> Result(CardClosurePlan, ManualCardCloseError)
```

## Profiles Iniciales Y Wireframes

Los wireframes usan el lenguaje de la plantilla por defecto:

```text
Hitos -> Entregables -> Cards -> Tasks
```

En un proyecto real, cada etiqueta se sustituye por los nombres configurados.

### TrackingProfile: Seguimiento

Para niveles altos: hitos, releases, ciclos, iniciativas.

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ Hitos                                    [Filtrar] [Ordenar] [+ Hito]      │
│ Proyecto / Hitos                                                           │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│ Nombre                 Estado     Progreso     Vence       Riesgo   ...    │
│ ────────────────────────────────────────────────────────────────────────   │
│ Q3 Plataforma          Active     █████░ 18/24  30 Jun      Medio    ...   │
│ Portal clientes        Draft      ░░░░░ 0/12    15 Jul      Bajo     ...   │
│ Migracion billing      Active     ███░░ 9/21    Vencida     Alto     ...   │
│ API partners           Closed     █████ 16/16   10 Jun      -        ...   │
│                                                                            │
├────────────────────────────────────────────────────────────────────────────┤
│ Seleccionado: Q3 Plataforma                                                │
│                                                                            │
│ Entregables        8 total   5 active   2 draft   1 closed                 │
│ Tasks              24 total  6 pool     3 claimed 15 closed                │
│ Capacidades        Backend pendiente · QA bloqueada · UX completa          │
│ Bloqueos           2 activos                                               │
│                                                                            │
│ [Entrar] [Activar subarbol] [Crear entregable]                      [...]  │
└────────────────────────────────────────────────────────────────────────────┘
```

Representa una vista de control, no de ejecucion. Su objetivo es comparar ramas
grandes por avance, fecha, riesgo, volumen y bloqueo.

### CoordinationProfile: Coordinacion

Para niveles intermedios: entregables, features, modulos, work packages.

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ Entregables / Q3 Plataforma              [Todos] [Active] [+ Entregable]   │
│ Hitos / Q3 Plataforma                                                      │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│ Draft                         Active                         Closed         │
│ ─────────────────────         ─────────────────────          ────────────   │
│ ┌──────────────────┐          ┌──────────────────┐           Portal auth    │
│ │ Portal clientes  │          │ Checkout nuevo   │           █████ 12/12    │
│ │ 0/12 tasks       │          │ ███░░ 7/13       │                         │
│ │ Vence 15 Jul     │          │ Backend 3 · QA 2 │                         │
│ │ [+] [...]        │          │ 2 pool · 1 claim │                         │
│ └──────────────────┘          │ Vence 28 Jun     │                         │
│                               │ [Entrar] [...]   │                         │
│ ┌──────────────────┐          └──────────────────┘                         │
│ │ Emails sistema   │                                                       │
│ │ 3/9 tasks        │          ┌──────────────────┐                         │
│ │ UX pendiente     │          │ Facturacion      │                         │
│ │ [+] [...]        │          │ █░░░░ 2/17       │                         │
│ └──────────────────┘          │ Bloqueada        │                         │
│                               │ [Entrar] [...]   │                         │
│                               └──────────────────┘                         │
└────────────────────────────────────────────────────────────────────────────┘
```

El kanban aqui no representa fases estilo Monday/Jira. Las columnas son estado
de card: `Draft`, `Active`, `Closed`. Las capacidades aparecen dentro de cada
card como lectura agregada.

### ExecutionProfile: Ejecucion

Para el nivel que contiene tasks directamente.

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ Card / Checkout nuevo                         [+ Task] [Activar] [...]     │
│ Hitos / Q3 Plataforma / Entregables / Checkout nuevo                       │
├────────────────────────────────────────────────────────────────────────────┤
│ Resumen                                                                    │
│ ███░░ 7/13 closed       2 pool       1 claimed       Vence 28 Jun          │
│                                                                            │
├────────────────────────────────────────────────────────────────────────────┤
│ Capacidades                                                                │
│                                                                            │
│ Backend              Frontend             QA                  UX            │
│ ───────────────      ───────────────      ───────────────     ───────────   │
│ 3 closed / 5         2 closed / 4         0 closed / 3        2 closed / 2  │
│ 1 pool               1 claimed            2 pool              completa      │
│                                                                            │
│ Tasks                                                                      │
│                                                                            │
│ Backend                                                                    │
│ [Pool] Validar contrato de pago        P2   vence 25 Jun       [...]       │
│ [Claimed Ana] Integrar callback PSP    P1   vence hoy          [...]       │
│ [Done] Persistir intento de pago       Done 20 Jun             [...]       │
│                                                                            │
│ QA                                                                         │
│ [Pool] Casos checkout fallido          P1   vence 27 Jun       [...]       │
│ [Pool] Regresion checkout movil        P2   vence 28 Jun       [...]       │
└────────────────────────────────────────────────────────────────────────────┘
```

Esta vista permite entender y preparar ejecucion, pero el claim principal sigue
viviendo en el Pool. Crear task usa `+ Task`. Cerrar manualmente vive en `...`.

## Implicaciones De UI

### Sidebar Izquierdo

La navegacion debe apoyarse en scopes y profiles, no en cinco pantallas rigidas.
Estructura propuesta:

```text
Proyecto
[selector proyecto]
[scope activo]

Crear
+ Nueva task
+ Nueva card

Ejecutar
Pool
Kanban

Organizar
Arbol de trabajo
Cards por nivel

Diagnosticar
Capacidades
Personas
Bloqueos

Configuracion
```

### Sidebar Derecho

El sidebar derecho actual puede mantenerse como foco personal:

- trabajo en curso,
- mis tasks,
- mis cards/contextos recientes,
- bloqueos relevantes,
- senales personales de foco.

No debe convertirse en una segunda navegacion estructural.

### Pool

El Pool muestra solo tasks abiertas y claimables. Nunca muestra cards como
unidades claimables ni tasks cerradas.

Las tasks `Closed(...)` aparecen en detalles de card, historial, metricas y
vistas de revision, pero no en la superficie principal de pull.

Una task cerrada es final: no se reabre y sus metadatos quedan congelados para
usuarios normales. Puede recibir notas/comentarios posteriores para contexto
historico. Si hace falta nuevo trabajo, se crea una nueva task.

El cierre manual de una task individual sigue las reglas de ejecucion actuales:

- `Available`: cualquier miembro del proyecto puede cerrarla manualmente.
- `Claimed`: solo el usuario que la tiene reclamada puede cerrarla manualmente.
- `Closed`: no se reabre ni se vuelve a cerrar.

El cierre manual de task produce `Task.Closed(ManuallyClosed)`, no `Done`.

El motivo humano opcional del cierre no forma parte del ADT ni de un campo
estructurado inicial. Si el usuario lo informa, se persiste como nota automatica
asociada al cierre. La razon tipada sigue siendo `ManuallyClosed`.

Para no sobrecargar superficies densas:

- Pool compacto: no muestra `Cerrar task...` como boton visible.
- Sidebar de foco: no muestra `Cerrar task...` como accion principal.
- Menus compactos pueden preferir `Ver detalle` antes que exponer cierre.
- Task detail muestra `Cerrar task...` como accion secundaria/destructiva.

Confirmacion recomendada:

```text
Cerrar task

"Integrar callback PSP" dejara de estar disponible y no contara como completada.

Esta accion no se puede deshacer.

Motivo opcional
[________________________________]

[Cancelar] [Cerrar task]
```

### Vistas Globales

Las vistas globales como `Cards por nivel`, `Capacidades` y `Personas` ocultan
cards cerradas por defecto. Deben ofrecer un filtro explicito `Incluir cerradas`
para revision historica o auditoria.

La navegacion principal debe priorizar trabajo vivo. El historico existe, pero
no domina el escaneo operativo.

### Card Detail

Una card detail debe mostrar acciones segun estructura:

- `Empty`: puede crear card hija o task hija.
- `CardGroup`: puede crear card hija.
- `TaskGroup`: puede crear task hija.

No debe mostrar simultaneamente "anadir task" y "anadir card" en cards que ya
tienen modo estructural decidido.

La accion `Mover a...` aparece en el menu secundario cuando la card no esta
cerrada y existen destinos validos del nivel padre correcto.

En cards abiertas con tasks, la vista muestra por defecto:

- tasks abiertas visibles;
- tasks cerradas colapsadas en una seccion `Cerradas`;
- resumen de completitud y cierre separado.

En cards cerradas, la vista puede abrirse en modo resumen/historial, mostrando
el resultado derivado (`Completada` o `Cerrada sin completar`) y permitiendo
inspeccionar las tasks cerradas.

Cuando se inspeccionan tasks cerradas, `Task.Closed(Done)` y `Closed` no-done
se separan por resultado:

```text
Cerradas

Completadas · 5
[Done] Persistir intento de pago
[Done] Anadir validacion backend

Cerradas sin completar · 2
[Closed] Spike PSP antiguo       Cerrada manualmente
[Closed] Copy temporal           Cerrada por cierre de card
```

No se usa `canceladas` como etiqueta generica, porque `ClosedByAncestor` o
`ManuallyClosed` pueden significar descarte, recorte de alcance, duplicado o
cambio de direccion. La etiqueta estable es `Cerradas sin completar`.

En vistas operativas, las cerradas quedan colapsadas o fuera del foco. En vistas
de revision, cards cerradas y metricas, la separacion entre `Completadas` y
`Cerradas sin completar` debe ser visible.

Las cards cerradas pueden recibir nuevas notas/comentarios. `Closed` congela
estructura y ejecucion, pero no la conversacion historica. No se pueden crear
nuevas tasks/cards hijas bajo una card cerrada.

Los metadatos de una card cerrada quedan congelados para usuarios normales:
titulo, descripcion, color, due date y estructura no se editan. Si hiciera falta
una correccion administrativa, debe ser excepcional y auditada. La via normal
para anadir contexto posterior es una nota.

### Due Date

`DueDate` es una fecha de calendario (`Date`), no un `DateTime`.

Reglas:

- Se interpreta en la timezone del proyecto.
- Una task/card con due date `2026-06-19` vence al final del dia `2026-06-19`
  en la timezone del proyecto.
- Empieza a estar vencida el dia siguiente en esa timezone.
- Si el proyecto no tiene timezone, se usa la timezone de la organizacion.
- Si la organizacion tampoco tiene timezone, el fallback interno es `UTC`.
- La UI muestra fecha, no hora.

El due date de cards se muestra como senal agregada y de planificacion. En
cards vencidas no cerradas, la fecha se muestra en danger y semibold/bold. No se
anade animacion a cards por vencimiento.

El due date de tasks participa en el efecto de urgencia del Pool, combinado con
el envejecimiento existente usando la mayor severidad.

## Implicaciones Para Auditoria

El modelo actual de `task_events` es insuficiente para el nuevo dominio: solo
representa eventos de task y no cubre cards, settings, impacto en Pool,
movimiento, cierre por ancestor ni configuracion por profundidad. En el modelo
final debe sustituirse por una auditoria generica de producto.

Nombre recomendado de tabla/modulo: `audit_events`.

Principios:

- El evento de auditoria es append-only.
- El usuario no edita eventos de auditoria.
- Cada mutacion de dominio relevante emite cero o mas eventos como parte de la
  misma transaccion.
- El evento guarda un target tipado y un kind tipado.
- En DB puede persistirse como `event_type` + `payload_json`, pero el borde de
  dominio usa ADTs y codecs compartidos.
- `task_events` desaparece como entidad viva; las metricas pasan a leer
  `audit_events` o vistas/materializaciones derivadas.

Modelo de dominio propuesto:

```gleam
pub opaque type AuditEventId {
  AuditEventId(Int)
}

pub type AuditEvent {
  AuditEvent(
    id: AuditEventId,
    org_id: OrgId,
    project_id: ProjectId,
    actor_id: UserId,
    target: AuditTarget,
    kind: AuditEventKind,
    occurred_at: DateTime,
  )
}

pub type AuditTarget {
  ProjectSettingsTarget(ProjectId)
  CardTarget(CardId)
  TaskTarget(TaskId)
  TaskDependencyTarget(task_id: TaskId, depends_on_task_id: TaskId)
}
```

`AuditEventKind` debe ser especifico, no un string libre:

```gleam
pub type AuditEventKind {
  CardActivated(
    previous: CardExecutionState,
    next: CardExecutionState,
    impact: PoolImpact,
  )
  CardClosedManually(
    previous: CardExecutionState,
    next: CardExecutionState,
    impact: CardClosureImpact,
  )
  CardClosedByRollup(
    previous: CardExecutionState,
    next: CardExecutionState,
  )
  CardMoved(
    previous_parent: Option(CardId),
    next_parent: Option(CardId),
    depth: Int,
  )
  RootPoolTaskCreated
  CardTaskCreated(placement: TaskPlacement)
  TaskClaimed(
    previous: TaskExecutionState,
    next: TaskExecutionState,
  )
  TaskReleased(
    previous: TaskExecutionState,
    next: TaskExecutionState,
  )
  TaskClosed(
    previous: TaskExecutionState,
    next: TaskExecutionState,
  )
  TaskClosedByAncestor(
    ancestor_card_id: CardId,
    previous: TaskExecutionState,
    next: TaskExecutionState,
  )
  DependencyAdded
  DependencyRemoved
  ProjectSettingsChanged(changes: List(ProjectSettingsChange))
}
```

Impactos tipados:

```gleam
pub type PoolImpact {
  PoolImpact(
    open_before: Int,
    opened_by_action: Int,
    open_after: Int,
    healthy_pool_limit: HealthyPoolLimit,
    health: PoolHealth,
  )
}

pub type PoolHealth {
  WithinHealthyLimit
  ExceedsHealthyLimit
}

pub type CardClosureImpact {
  CardClosureImpact(
    closed_available_tasks: Int,
    already_closed_tasks: Int,
    blocked_claimed_tasks: Int,
  )
}

pub type ProjectSettingsChange {
  HealthyPoolLimitChanged(
    previous: HealthyPoolLimit,
    next: HealthyPoolLimit,
  )
  CardDepthNameChanged(
    depth: Int,
    previous: CardDepthName,
    next: CardDepthName,
  )
}
```

Reglas:

- `target` identifica la entidad principal afectada; `kind` no repite ese id.
  Solo incluye ids secundarios necesarios para explicar la relacion o impacto.
- `previous` y `next` se incluyen en variantes donde el cambio de estado es el
  dato importante.
- No se usa un campo generico `previous_state`/`next_state` opcional en todos
  los eventos, porque produciria estados vacios o ambiguos.
- `impact` se incluye solo cuando ayuda a explicar el efecto operativo:
  activacion, cierre de rama, saturacion del Pool.
- Los eventos de auditoria no sustituyen las notas ni los comentarios.
- Los workflows pueden reaccionar a eventos, pero el modelo de auditoria no debe
  depender de workflows.

## Implicaciones Para Metricas Y Reporting

Al sustituir `task_events` por `audit_events`, las metricas deben dejar de
depender de eventos legacy y de conceptos `milestone`. El reporting se
reconstruye sobre:

- estado actual de `tasks` y `cards`;
- `audit_events` para transiciones historicas;
- rollups derivados del arbol de cards;
- `ProjectSettings.healthy_pool_limit` para salud del Pool.

Metricas que sobreviven:

- `claimed_count`: cuenta `AuditEventKind.TaskClaimed`.
- `released_count`: cuenta `AuditEventKind.TaskReleased`.
- `completed_count`: cuenta `AuditEventKind.TaskClosed` donde `next` sea
  `TaskExecutionState.Closed(Done, ...)`.
- `time_to_first_claim`: primer `TaskClaimed` menos creacion de task.
- `release_rate`: releases / claims en ventana.
- `pool_flow_ratio`: completadas / entradas al Pool o completadas / abiertas
  segun definicion actual revisada en implementacion.
- `wip_count`: tasks en `Claimed`.
- `ongoing_count`: tasks `Claimed(..., Ongoing)`.
- `stale_claims_count`: tasks claimed por encima del umbral de antiguedad.

Metricas nuevas o renombradas:

- `pool_open_count`: tasks claimables abiertas actualmente.
- `pool_health`: `WithinHealthyLimit | ExceedsHealthyLimit`, derivado de
  `pool_open_count` y `healthy_pool_limit`.
- `pool_over_limit_by`: exceso sobre el limite sano.
- `activation_count`: numero de `CardActivated` por proyecto/actor/ventana.
- `activation_opened_tasks`: suma de `PoolImpact.opened_by_action`.
- `manual_close_count`: cierre manual de cards/tasks.
- `closed_not_done_count`: tasks cerradas sin `Done`.
- `closed_not_done_ratio`: cerradas sin completar / cerradas totales.
- `card_completion_ratio`: hojas `Closed(Done)` / hojas cerradas o totales,
  segun contexto de vista.

Metricas que desaparecen o se reemplazan:

- `MilestoneModalMetrics` desaparece. Un hito es una card raiz; usa
  `CardMetrics`/`CardRollupMetrics`.
- `most_activated` basado en milestone se reemplaza por activaciones de cards o
  ramas.
- Cualquier metrica basada en `task_events` se reescribe sobre `audit_events`.
- `TaskStatus.Completed` no se usa en metricas; completitud significa
  `TaskExecutionState.Closed(Done, ...)`.

Tipos recomendados. `PoolHealth` se reutiliza del dominio de salud de Pool
definido para impactos/auditoria:

```gleam
pub type PoolHealthMetric {
  PoolHealthMetric(
    open_count: Int,
    healthy_pool_limit: HealthyPoolLimit,
    over_limit_by: Int,
    health: PoolHealth,
  )
}

pub type TaskFlowMetrics {
  TaskFlowMetrics(
    claimed_count: Int,
    released_count: Int,
    completed_count: Int,
    closed_not_done_count: Int,
    time_to_first_claim: SampledMetric,
    release_rate_percent: Option(Int),
  )
}

pub type CardRollupMetrics {
  CardRollupMetrics(
    descendant_cards: Int,
    descendant_tasks: Int,
    open_tasks: Int,
    claimed_tasks: Int,
    closed_done_tasks: Int,
    closed_not_done_tasks: Int,
    blocked_tasks: Int,
    dependency_waiting_tasks: Int,
    pool_health: PoolHealthMetric,
  )
}
```

Reglas:

- Las metricas operativas deben priorizar trabajo vivo sobre historico.
- El historico existe para auditoria, aprendizaje y salud de flujo, no para
  convertir ScrumBringer en dashboard decorativo.
- Las vistas de Pool deben mostrar saturacion como senal accionable, no como
  grafico ornamental.
- Las metricas de completitud nunca cuentan `Closed(ManuallyClosed)` ni
  `Closed(ClosedByAncestor)` como completadas.
- Las metricas deben tener tests que comparen `audit_events` equivalentes a los
  antiguos `task_events` para preservar claims/releases/completions relevantes.

## Implicaciones Para Workflows

Los workflows deben distinguir eventos de ejecucion y eventos estructurales.

```gleam
pub type WorkflowTarget {
  TaskTarget(TaskId)
  CardTarget(CardId)
}

pub type WorkflowEvent {
  TaskCreated(TaskId)
  TaskClaimed(TaskId, UserId)
  TaskClosed(TaskId, TaskClosedReason)
  CardCreated(CardId)
  CardActivated(CardId)
  CardClosed(CardId, CardClosedReason)
  CardClosedByRollup(CardId)
  BlockerActivated(BlockerId)
  BlockerResolved(BlockerId)
}

pub type WorkflowScope {
  SelfOnly
  Ancestors
  Descendants
  Tree
}
```

Reglas de producto:

- un workflow puede reaccionar a rollups,
- no puede crear tasks bajo una card que ya contiene cards,
- no puede crear cards bajo una card que ya contiene tasks,
- no puede hacer claimable una card,
- no puede reabrir una rama cerrada sin pasar por una transicion explicita.

## Backlog Tecnico Inicial

Este backlog esta ordenado para trabajar en ciclos red/green/refactor. Cada
historia empieza por tests del contrato publico afectado. Los nombres `HT-*`
son identificadores de trabajo, no nombres de modulos definitivos.

### Regla Transversal De Validacion Visual

Las historias que modifican UI o flujos visibles deben cerrarse con validacion
en navegador usando `agent-browser`. No basta con que compile o pasen tests de
dominio.

Matriz minima:

```text
HT-01  Sin browser obligatorio: dominio/codecs.
HT-02  Browser opcional si cambia el formulario de creacion.
HT-03  Browser obligatorio: activacion y aparicion en Pool.
HT-04  Browser obligatorio: cierre, bloqueos y outcomes visibles.
HT-05  Browser obligatorio solo para estados de permiso/acciones ocultas.
HT-06  Sin browser obligatorio: migracion/schema; se valida por tests DB.
HT-07  Browser opcional: endpoints se validan por API; si cambia UI, obligatorio.
HT-08  Browser obligatorio: Pool, dependencias y claimability visible.
HT-09  Browser obligatorio: vistas, scopes, sidebar y responsive.
HT-10  Browser obligatorio: card detail, acciones, movimiento y ayudas.
HT-11  Browser obligatorio: due date y urgencia visual.
HT-12  Browser obligatorio: recorrido final desktop/mobile.
```

Checklist `agent-browser` para historias con UI:

- abrir la app con seed representativa de la historia;
- tomar snapshot interactivo antes de actuar;
- ejecutar el flujo principal con clicks/fills reales;
- tomar snapshot despues de actuar;
- capturar screenshots desktop y mobile;
- comprobar que no hay overflow, solapes ni textos cortados;
- comprobar que acciones deshabilitadas explican el motivo cuando sea relevante;
- comprobar foco visible y targets tactiles en mobile;
- registrar en el cierre de la historia las rutas visitadas, viewport usado y
  capturas generadas.

### Regla Transversal De Cobertura Rica

Cada historia debe empezar con una matriz de tests que cubra mas que el happy
path. Si una dimension no aplica, el modulo de test debe dejarlo claro con una
nota breve.

Dimensiones obligatorias:

- camino feliz;
- errores esperados;
- permisos positivos y negativos;
- estados vacios y limites;
- estados cerrados/finales;
- datos inconsistentes o legacy en migracion;
- serializacion/codec cuando cruce cliente-servidor;
- mapper DB -> dominio cuando lea SQL;
- ausencia de regresion visual si toca UI;
- idempotencia o concurrencia cuando haya transiciones o versionado;
- invariantes de arbol y ciclos cuando haya jerarquia;
- accesibilidad basica cuando haya interaccion visible.

Matriz minima por historia:

```text
HT-01
  - round-trip JSON de cada ADT;
  - decodificacion rechaza variantes legacy/desconocidas;
  - campos obligatorios ausentes devuelven error;
  - exhaustividad de conversiones a label/copy;
  - compatibilidad Erlang/JavaScript si el modulo shared se usa en ambos targets.

HT-02
  - Empty -> primer hijo card;
  - Empty -> primera task;
  - CardGroup rechaza task;
  - TaskGroup rechaza card;
  - Closed rechaza cualquier hijo;
  - destinos inexistentes o de otro proyecto devuelven error tipado.

HT-03
  - activar card vacia;
  - activar card con subarbol profundo;
  - activar subarbol no activa ancestros;
  - activar dos veces no duplica eventos ni pool impact;
  - activar rama que deja Pool bajo/sobre `healthy_pool_limit`;
  - RootPool sigue claimable sin card;
  - draft/closed/blocked/dependency/capability excluyen claimability.

HT-04
  - cierre automatico por rollup;
  - cierre manual bloqueado por Claimed;
  - cierre manual permite Available y preserva Closed previas;
  - closed no-done no cuenta como completado;
  - cierre de rama grande devuelve impacto correcto;
  - intentar reabrir o mutar closed falla.

HT-05
  - matriz Org Admin / Project Manager / Project Member;
  - usuario fuera de proyecto;
  - usuario sin capability;
  - permisos para RootPool, Draft, Active y movimiento;
  - helpers UI `can_*` alineados con `require_*`;
  - errores de autorizacion no filtran datos innecesarios.

HT-06
  - milestone ready/active/completed;
  - card actual bajo milestone;
  - task bajo card;
  - task directa bajo milestone;
  - task sin card ni milestone -> RootPool;
  - mezcla cards+tasks crea agrupadora;
  - migracion idempotente o protegida contra doble ejecucion;
  - rollback o informe claro si hay inconsistencia no migrable.

HT-07
  - endpoints nuevos happy path;
  - ids invalidos / no encontrados / otro proyecto;
  - permisos denegados;
  - request invalido;
  - conflicto de version si aplica;
  - rutas legacy devuelven 404;
  - contratos JSON decodifican con shared codecs.

HT-08
  - Pool con RootPool;
  - Pool con task de card Active;
  - Pool excluye Draft/Closed;
  - dependencies bloquean Available y Claimed;
  - closed/deleted dependency desbloquea;
  - ciclo de dependencias rechazado;
  - owner de Claimed puede cerrar manualmente, otro usuario no.

HT-09
  - nombres de nivel desde config;
  - proyecto sin cards;
  - nivel sin cards;
  - muchas cards en el mismo nivel;
  - scopes por nivel y por card;
  - cerradas ocultas y visibles con filtro;
  - desktop/tablet/mobile sin overflow.

HT-10
  - Empty muestra acciones correctas;
  - CardGroup y TaskGroup restringen acciones;
  - Pool/Draft/Active explican impacto diferente;
  - Closed bloquea creacion;
  - mover solo al mismo nivel;
  - destinos invalidos deshabilitados con motivo;
  - delete deshabilitado con historial operativo.

HT-11
  - sin due date;
  - due date futuro;
  - due date hoy;
  - due date vencido;
  - card vencida abierta;
  - card vencida cerrada sin alarma;
  - timezone de proyecto;
  - urgencia usa max(edad, vencimiento).

HT-12
  - seeds cubren todos los perfiles y estados;
  - barridos anti-legacy;
  - auditoria cubre cards, tasks y settings;
  - metricas se recalculan desde audit_events y estado actual;
  - migracion de datos reales o fixture equivalente;
  - smoke test completo por rol;
  - agent-browser desktop/tablet/mobile;
  - snapshot review humano si se usa Birdie.
```

### HT-01: ADTs Base De Cards Y Tasks

Objetivo: sustituir el modelo plano por tipos que representen `Card` como
contenedor y `Task` como hoja ejecutable.

Tests primero:

- `task_placement_root_pool_roundtrip_test`
- `task_placement_under_card_roundtrip_test`
- `card_execution_state_roundtrip_test`
- `task_execution_state_roundtrip_test`
- `completed_legacy_is_not_a_public_task_state_test`
- `unknown_task_execution_state_decoder_fails_test`
- `missing_required_state_fields_decoder_fails_test`

Criterios de aceptacion:

- Existe `TaskPlacement = RootPool | UnderCard(CardId)`.
- Existe `CardExecutionState = Draft | Active(...) | Closed(...)`.
- Existe `TaskExecutionState = Available | Claimed(...) | Closed(...)`.
- `Completed` no existe como estado publico paralelo.
- Codecs JSON hacen round-trip de los ADTs nuevos.
- Los tests usan `let assert` y tipos reales del dominio.

Dependencias: ninguna.

### HT-02: Invariantes Del Arbol De Cards

Objetivo: hacer irrepresentable o rechazable que una card mezcle cards hijas y
tasks hijas.

Tests primero:

- `empty_card_accepts_first_child_card_test`
- `empty_card_accepts_first_child_task_test`
- `card_group_rejects_task_child_test`
- `task_group_rejects_card_child_test`
- `closed_card_rejects_new_children_test`
- `child_from_other_project_is_rejected_test`
- `moving_card_under_descendant_is_rejected_test`

Criterios de aceptacion:

- El dominio distingue `Empty`, `CardGroup` y `TaskGroup`.
- Una card cerrada no acepta hijos nuevos.
- Los errores son ADTs especificos, no strings.
- El servidor no puede crear una task bajo una card que ya contiene cards.
- El servidor no puede crear una card bajo una card que ya contiene tasks.

Dependencias: HT-01.

### HT-03: Activacion Y Claimability

Objetivo: modelar que solo las tasks son claimables y que una card activa libera
su subarbol hacia el Pool.

Tests primero:

- `card_is_never_claimable_test`
- `root_pool_task_is_claimable_without_card_activation_test`
- `task_under_draft_card_is_not_claimable_test`
- `task_under_active_card_is_claimable_test`
- `activation_counts_descendant_available_tasks_test`
- `activation_propagates_down_not_up_test`
- `activating_empty_card_reports_zero_pool_impact_test`
- `activating_already_active_card_is_idempotent_test`
- `activation_excludes_closed_blocked_and_unclaimable_tasks_test`
- `activation_warns_when_pool_exceeds_project_healthy_limit_test`

Criterios de aceptacion:

- No existe operacion de claim sobre card.
- `RootPool` no depende de activacion de card.
- Activar una card calcula cuantas tasks entraran al Pool.
- Activar una card afecta descendientes, nunca ancestros.
- Activar requiere `Authorized(ManageFlow)`.
- El evento registra `activated_at`, `activated_by` y `ActivationSource`.
- Validacion `agent-browser`: confirmar que activar card muestra impacto en Pool,
  exige confirmacion y que las tasks descendientes aparecen en Pool tras aceptar.

Dependencias: HT-01, HT-02.

### HT-04: Cierre, Rollup Y Resultado Visible

Objetivo: cerrar ramas sin reapertura, bloquear cierre manual si hay trabajo
reclamado y separar completitud de cierre.

Tests primero:

- `manual_card_close_blocks_when_descendant_claimed_test`
- `manual_card_close_closes_available_descendant_tasks_test`
- `rollup_closes_parent_when_all_direct_children_closed_test`
- `closed_done_counts_as_completed_test`
- `closed_manually_does_not_count_as_completed_test`
- `closed_card_outcome_completed_when_all_leaves_done_test`
- `closed_card_outcome_not_completed_when_any_leaf_closed_without_done_test`
- `manual_card_close_preserves_existing_closed_task_reasons_test`
- `closed_card_cannot_be_reopened_test`
- `closed_task_cannot_be_claimed_or_completed_again_test`

Criterios de aceptacion:

- Card/task `Closed` es final.
- Cierre manual de card bloquea si existe cualquier descendant task `Claimed`.
- Tasks disponibles cerradas por una card quedan `Closed(ClosedByAncestor)`.
- `Task.Closed(Done)` suma a completitud.
- `Task.Closed(ManuallyClosed | ClosedByAncestor)` no suma a completitud.
- Cards muestran resultado derivado: `Completada` o `Cerrada sin completar`.
- Validacion `agent-browser`: cierre manual de card con descendant `Claimed`
  muestra bloqueo comprensible; cards cerradas separan `Completadas` y `Cerradas
  sin completar`.

Dependencias: HT-01, HT-02.

### HT-05: Permisos Tipados

Objetivo: centralizar permisos y evitar checks dispersos por rol en mutaciones
de dominio.

Tests primero:

- `project_manager_gets_manage_flow_test`
- `project_member_does_not_get_manage_flow_test`
- `project_member_gets_execute_work_test`
- `activate_card_requires_manage_flow_test`
- `create_root_pool_task_requires_manage_flow_test`
- `create_task_in_draft_card_requires_manage_flow_test`
- `create_task_in_active_task_group_requires_execute_work_test`
- `move_card_requires_manage_structure_test`
- `user_outside_project_gets_no_project_privileges_test`
- `ui_can_helpers_match_require_authorization_test`
- `authorization_errors_do_not_leak_cross_project_data_test`

Criterios de aceptacion:

- Existen privilegios internos `ManageFlow`, `ManageStructure`,
  `ManageCatalog`, `ExecuteWork`, `ReadHistory`.
- Las mutaciones sensibles reciben `Authorized(privilege)`.
- La definicion de permisos vive en un modulo central documentado.
- No se expone RBAC granular en UI MVP.
- Task execution mantiene reglas actuales de miembros: no se introduce
  distincion manager/member para ejecutar trabajo.
- Crear `RootPool` task requiere `ManageFlow`.
- Crear task en card `Draft` requiere `ManageFlow`.
- Crear task en card `Active` requiere `ExecuteWork`.
- Validacion `agent-browser`: usuarios sin permiso no ven acciones peligrosas o
  las ven deshabilitadas con motivo; usuarios con permiso ven la accion y pueden
  completar el flujo.

Dependencias: HT-01.

### HT-06: Migracion De Datos Sin Legacy

Objetivo: migrar datos actuales a schema final sin conservar entidades antiguas
como modelo vivo.

Tests primero:

- `migration_maps_milestone_to_root_card_test`
- `migration_maps_existing_card_to_level_2_card_test`
- `migration_maps_task_without_card_or_milestone_to_root_pool_test`
- `migration_maps_task_under_milestone_without_card_test`
- `migration_creates_grouping_card_when_node_would_mix_children_test`
- `migration_maps_completed_task_to_closed_done_test`
- `migration_removes_milestone_columns_from_final_schema_test`
- `migration_maps_ready_active_and_completed_milestone_states_test`
- `migration_reports_inconsistent_completed_milestone_test`
- `migration_is_protected_against_double_execution_test`

Criterios de aceptacion:

- Hitos actuales migran a cards nivel 1.
- Cards actuales migran a cards nivel 2.
- Tasks sin card ni hito migran a `RootPool`.
- Si una card migrada mezclaria cards y tasks, se crea una card agrupadora
  normal, por ejemplo `Trabajo directo`.
- `milestones`, `cards.milestone_id`, `tasks.milestone_id` y restricciones
  asociadas no existen en schema final.
- La migracion produce informe de agrupadoras creadas y posibles
  inconsistencias.

Dependencias: HT-01, HT-02, HT-04.

### HT-07: Endpoints De Cards Y Eliminacion De Milestones

Objetivo: sustituir APIs de milestones por APIs de cards, scopes y acciones
estructurales.

Tests primero:

- `list_cards_by_depth_scope_test`
- `get_card_scope_detail_includes_rollups_test`
- `activate_card_api_contract_roundtrip_test`
- `close_card_api_contract_roundtrip_test`
- `move_card_api_contract_roundtrip_test`
- `activate_card_endpoint_returns_pool_impact_test`
- `close_card_endpoint_blocks_claimed_descendant_test`
- `move_card_endpoint_rejects_cross_level_move_test`
- `legacy_milestones_routes_return_not_found_test`
- `card_endpoints_reject_invalid_ids_test`
- `card_endpoints_reject_cross_project_access_test`
- `card_endpoints_reject_invalid_requests_test`

Criterios de aceptacion:

- Los request/response compartidos de cards viven en `shared/src/api/cards`.
- Los codecs de esos contratos usan sufijo `_codec` y son usados por cliente y
  servidor.
- Existen endpoints para listar por `DepthScope` y `CardScope`.
- Activar card devuelve impacto antes/como parte de confirmacion.
- Cerrar card valida tasks claimed descendientes.
- Mover card solo permite cambio de padre al mismo nivel.
- Rutas `/milestones` desaparecen.
- No queda `http/milestones*`, `services/milestones_db` ni `sql/milestones_*`
  en codigo activo.

Dependencias: HT-03, HT-04, HT-05, HT-06.

### HT-08: Tasks RootPool, Card Tasks Y Dependencias

Objetivo: adaptar listados, claim, cierre, dependencias y mappers al placement
nuevo de tasks.

Tests primero:

- `pool_includes_available_root_pool_task_test`
- `pool_excludes_task_under_draft_card_test`
- `pool_includes_task_under_active_card_test`
- `close_task_api_contract_roundtrip_test`
- `task_dependencies_api_contract_roundtrip_test`
- `dependency_blocks_available_and_claimed_tasks_test`
- `dependency_unblocks_when_dependency_closed_test`
- `delete_dependency_target_unblocks_task_test`
- `manual_close_claimed_task_allowed_only_for_owner_test`
- `dependency_would_create_cycle_is_rejected_test`
- `cross_project_dependency_is_rejected_test`
- `pool_filters_by_user_capabilities_test`

Criterios de aceptacion:

- Los request/response compartidos de cierre y dependencias viven en
  `shared/src/api/tasks`.
- Los contratos API de tasks no duplican tipos de dominio; los referencian o los
  componen.
- Pool lista `RootPool` claimables.
- Pool lista tasks bajo cards activas si cumplen capability/permisos/bloqueos.
- Pool excluye tasks bajo cards draft o cerradas.
- Dependencias solo existen entre tasks del mismo proyecto.
- Cerrar o eliminar la task dependida desbloquea automaticamente.
- Cierre manual de task claimed solo lo puede hacer quien la tiene reclamada.
- Validacion `agent-browser`: Pool muestra diferenciadas `RootPool`, tasks de
  card activa y tasks esperando dependencia; tras cerrar/eliminar la dependencia
  la task desbloqueada aparece sin refresco manual indebido.

Dependencias: HT-01, HT-03, HT-04, HT-05.

### HT-09: Vistas Por Nivel, Scope Y Sidebar Izquierdo

Objetivo: reemplazar la experiencia de milestones por navegacion basada en
nombres por profundidad, scopes y profiles derivados del anidamiento.

Tests primero:

- `left_sidebar_renders_depth_names_from_project_config_test`
- `tracking_profile_hides_closed_cards_by_default_test`
- `coordination_profile_groups_cards_by_execution_state_test`
- `execution_profile_groups_tasks_by_capability_test`
- `card_scope_shows_direct_subcards_or_tasks_test`
- `include_closed_filter_reveals_closed_cards_test`
- `depth_scope_empty_state_is_actionable_test`
- `many_cards_in_depth_remain_scannable_test`
- `mobile_sidebar_navigation_preserves_current_scope_test`

Criterios de aceptacion:

- Sidebar izquierdo muestra vistas principales: Pool, Cards por nivel,
  Capacidades, Hitos/Tracking segun perfiles, Personas.
- Los nombres visibles salen de configuracion de proyecto.
- `DepthScope` muestra todas las cards de esa profundidad.
- `CardScope` muestra descendencia directa de la card seleccionada.
- Las cards cerradas se ocultan por defecto y aparecen con `Incluir cerradas`.
- No queda UI que trate milestone como entidad viva.
- Validacion `agent-browser`: capturas desktop y mobile de `TrackingProfile`,
  `CoordinationProfile`, `ExecutionProfile`, sidebar izquierdo, `DepthScope`,
  `CardScope` y filtro `Incluir cerradas`, sin overflow ni solapes.

Dependencias: HT-07, HT-08.

### HT-10: Card Detail, Acciones Y Movimiento

Objetivo: adaptar detalle de card a estructura, estado, permisos y movimiento
restringido.

Tests primero:

- `empty_card_detail_offers_create_card_or_task_test`
- `card_group_detail_offers_create_card_only_test`
- `task_group_detail_offers_create_task_only_test`
- `pool_create_task_explains_root_pool_manage_flow_impact_test`
- `draft_card_create_task_does_not_auto_claim_test`
- `draft_card_create_task_explains_prepared_until_activation_test`
- `active_card_create_task_adds_task_to_pool_test`
- `active_card_create_task_explains_pool_entry_test`
- `move_card_dialog_lists_only_valid_same_level_destinations_test`
- `delete_disabled_when_card_has_operational_history_test`
- `closed_card_detail_disables_create_actions_with_reason_test`
- `move_card_dialog_explains_invalid_destinations_test`
- `create_task_never_auto_claims_for_creator_test`

Criterios de aceptacion:

- Card detail no muestra acciones incompatibles con su `CardStructure`.
- Crear task en card activa la deja disponible en Pool, no auto-claim.
- Crear task desde el Pool crea `RootPool` y muestra que requiere gestion de
  flujo.
- Crear task en card `Draft` muestra que quedara preparada hasta activacion.
- Crear task en card `Active` muestra que entrara al Pool al crearla.
- Crear cards requiere `ManageStructure`.
- Crear tasks en ramas activas requiere `ExecuteWork`.
- Movimiento usa accion secundaria `Mover a...`, no drag/drop libre.
- Delete real solo aparece habilitado sin historial operativo.
- Validacion `agent-browser`: ejecutar creacion contextual desde Pool, card
  `Draft` y card `Active`; capturar ayudas visibles, estados deshabilitados de
  card `Closed`, dialogo `Mover a...`, tooltip de delete deshabilitado y ausencia
  de acciones incompatibles.

Dependencias: HT-02, HT-05, HT-07, HT-09.

### HT-11: Due Date En Tasks Y Cards

Objetivo: incorporar due date al modelo nuevo sin crear ruido visual ni reglas
especiales inconsistentes.

Tests primero:

- `task_due_date_roundtrip_test`
- `card_due_date_roundtrip_test`
- `task_due_urgency_uses_max_of_age_and_due_date_test`
- `overdue_open_card_uses_danger_due_date_style_test`
- `closed_card_does_not_show_overdue_alarm_test`
- `due_date_today_is_not_overdue_until_next_project_day_test`
- `due_date_uses_project_timezone_test`
- `missing_due_date_has_neutral_urgency_test`

Criterios de aceptacion:

- Tasks y cards tienen due date opcional.
- Tasks usan el efecto de urgencia del Pool segun mayor severidad entre edad y
  vencimiento.
- Cards vencidas no cerradas muestran fecha en danger y semibold/bold.
- Cards no reciben animacion por due date.
- Cards cerradas no generan alarma visual de vencimiento.
- Validacion `agent-browser`: capturas de Pool con tasks vencidas y no vencidas,
  card abierta vencida, card cerrada vencida sin alarma, y comparacion desktop /
  mobile verificando contraste y legibilidad de fechas.

Dependencias: HT-01, HT-09, HT-10.

### HT-12: Cleanup Anti-Legacy Y Gate Final

Objetivo: asegurar que el corte de modelo quedo completo.

Tests primero:

- `legacy_terms_do_not_exist_in_active_shared_server_client_code_test`
- `active_code_respects_final_architecture_boundaries_test`
- `domain_types_are_not_duplicated_in_server_or_client_test`
- `api_contracts_live_under_shared_api_test`
- `use_cases_do_not_live_in_generic_services_test`
- `codecs_use_aspect_or_contract_codec_suffix_test`
- `mutating_use_cases_persist_state_and_audit_event_atomically_test`
- `mutating_use_cases_do_not_emit_audit_event_on_conflict_test`
- `lustre_mutations_update_model_from_api_response_test`
- `lustre_update_does_not_reimplement_server_transaction_rules_test`
- `legacy_milestone_routes_are_absent_test`
- `schema_final_has_no_milestone_tables_or_columns_test`
- `seed_data_uses_card_tree_and_root_pool_tasks_test`
- `seed_data_covers_card_profiles_due_dates_and_closed_outcomes_test`
- `ui_validation_covers_main_flows_and_responsive_states_test`
- `seed_data_covers_roles_permissions_and_capabilities_test`
- `seed_data_covers_healthy_and_saturated_pool_limits_test`
- `full_flow_smoke_test_for_manager_and_member_test`
- `docs_and_i18n_do_not_expose_legacy_concepts_test`
- `audit_events_replace_task_events_as_live_model_test`
- `audit_event_kind_codec_roundtrip_test`
- `metrics_are_derived_from_audit_events_not_task_events_test`
- `milestone_metrics_are_removed_or_replaced_by_card_rollup_metrics_test`
- `final_full_refactor_review_has_no_required_changes_left_test`
- `final_cleanup_removes_obsolete_unnecessary_and_incompatible_code_test`

Criterios de aceptacion:

- Barridos anti-legacy pasan en codigo activo:
  - `milestone|Milestone|milestones|milestone_id`
  - `CardState|Pendiente|EnCurso|Cerrada`
  - `TaskStatus|Completed`
- Barridos y revision de imports confirman que el codigo activo cumple la
  arquitectura final:
  - dominio compartido en `shared/src/domain/<entidad>/<aspecto>.gleam`;
  - contratos API compartidos en `shared/src/api/<recurso>/<accion>.gleam`;
  - codecs junto al aspecto/contrato y con sufijo `_codec`;
  - casos de uso en `apps/server/src/use_case/<recurso>/<accion>.gleam`;
  - HTTP en `apps/server/src/http`;
  - persistencia en `apps/server/src/repository`;
  - UI y modelos locales en `apps/client/src`;
  - no quedan nuevos `services` genericos para operaciones de producto.
- La ejecucion del goal debe mover, dividir o eliminar cualquier modulo activo
  que contradiga la arquitectura final. No basta con crear modulos nuevos si el
  codigo anterior sigue siendo la fuente real.
- Los casos de uso mutantes persisten cambios de estado y `audit_events` en la
  misma transaccion. No hay evento sin cambio ni cambio sin evento cuando el
  evento sea obligatorio.
- Los conflictos de version, permisos o invariantes no emiten eventos de
  auditoria ni cambios parciales.
- Los flujos Lustre de mutacion usan mensajes `User...` y `ApiReturned...`,
  efectos API en el borde y actualizan el `Model` desde `Response`/`View`; no
  reimplementan reglas transaccionales del server en `update`.
- `task_events` no queda como modelo vivo; si existe durante migracion, se
  transforma a `audit_events` o desaparece tras el rebase/squash.
- Las metricas de claims, releases, completions y time-to-first-claim leen
  `audit_events` o vistas derivadas de `audit_events`, no `task_events`.
- Las metricas de milestone desaparecen o se reemplazan por rollups de cards
  raiz/profundidad.
- Seeds y fixtures quedan redisenadas para el modelo nuevo. Deben crear:
  - un `Org Admin`,
  - un `Project Manager`,
  - al menos dos `Project Member`,
  - usuarios con y sin capacidades relevantes,
  - cards nivel 1 y nivel 2 migradas,
  - cards `Draft`, `Active` y `Closed`,
  - cards con subcards,
  - cards con tasks,
  - `RootPool` tasks,
  - tasks `Available`, `Claimed` y `Closed`,
  - tasks con dependencias bloqueantes y desbloqueadas,
  - due dates futuras, de hoy y vencidas,
  - cards cerradas completadas y cerradas sin completar,
  - un proyecto bajo `healthy_pool_limit`,
  - un proyecto por encima de `healthy_pool_limit` para validar aviso blando.
- Las validaciones de interfaz cubren, como minimo:
  - Pool con `RootPool` y tasks de cards activas,
  - aviso de Pool saturado cuando supera el limite sano configurable,
  - creacion contextual desde Pool, card `Draft` y card `Active`,
  - activacion de card con impacto visible en Pool,
  - cierre manual bloqueado por tasks `Claimed`,
  - cards vencidas no cerradas con fecha danger/semibold,
  - tasks vencidas con efecto de urgencia del Pool,
  - vistas `TrackingProfile`, `CoordinationProfile` y `ExecutionProfile`,
  - filtro `Incluir cerradas`,
  - sidebar izquierdo redisenado,
  - sidebar derecho sin regresiones funcionales.
- Las validaciones de usabilidad se ejecutan con navegador sobre desktop y
  mobile:
  - viewports minimos: desktop operativo, tablet estrecho y mobile,
  - no hay texto solapado ni overflow visible,
  - targets tactiles cumplen minimo 44px en mobile,
  - foco visible en acciones principales,
  - contraste legible en estados danger/warning/success,
  - animaciones respetan `prefers-reduced-motion`,
  - acciones destructivas/cierre no quedan demasiado a mano,
  - tooltips o ayudas explican acciones deshabilitadas relevantes.
- Docs funcionales no describen milestones como entidad.
- `gleam test` y `gleam check` pasan.
- Si hay snapshots, quedan en estado revisado por humano antes de considerarse
  verificados.
- El cierre final del goal deja documentado que `gleam-refactor` se ejecuto
  sobre el diff completo de `new_hierarchy`, que sus hallazgos fueron corregidos
  o rechazados con justificacion, y que no quedan limpiezas obvias pendientes.
- El cierre final confirma que se eliminaron restos obsoletos, innecesarios,
  duplicados o incompatibles con la arquitectura nueva.

Dependencias: HT-01 a HT-11.

## Refuerzos Antes De Lanzar El Goal

Antes de ejecutar un goal de desarrollo completo, conviene dejar estos aspectos
como restricciones explicitas del trabajo:

- Arquitectura de ADTs:
  - decision cerrada: usar `shared/src/domain/<entidad>/<aspecto>.gleam` como
    estructura canonica de dominio compartido;
  - decision cerrada: usar `shared/src/api/<recurso>/<accion>.gleam` para
    request/response compartidos por frontend y backend;
  - decision cerrada: usar `apps/server/src/use_case/<recurso>/<accion>.gleam`
    para operaciones de aplicacion, no `services` genericos;
  - la arquitectura final es criterio de cierre del goal completo: no basta con
    anadir modulos nuevos; todo codigo activo debe quedar movido, dividido o
    eliminado si contradice estas fronteras;
  - decision cerrada: aplicar nomenclatura por sufijo/rol de tipo:
    - entidad real persistente: `Card`, `Task`, `ProjectSettings`;
    - dominio derivado de producto: `CardRollup`, `PoolHealth`,
      `CapabilityRollup`;
    - contrato de entrada API: `ActivateCardRequest`, `MoveCardRequest`;
    - contrato de salida de accion API: `ActivateCardResponse`,
      `CloseTaskResponse`;
    - lectura de pantalla/API: `CardScopeView`, `DepthScopeView`, `PoolView`,
      `SidebarView`, `PersonWorkloadView`;
    - representacion compacta reutilizable: `CardSummary`, `TaskSummary`,
      `PersonSummary`;
    - intencion validada de caso de uso: `ActivateCardCommand`,
      `CloseTaskCommand`;
    - fila de persistencia interna server: `CardRow`, `TaskRow`,
      `AuditEventRow`;
    - evento de auditoria/dominio: `AuditEvent`, `CardActivated`,
      `TaskClosed`;
  - no se usaran nombres genericos como `Data`, `Info`, `Dto` o `Payload` para
    tipos nuevos salvo en un borde tecnico heredado que desaparezca en la misma
    reestructuracion;
  - se usaran submodulos especificos para estados, estructura, placement,
    dependencias, permisos, due date, jerarquia, rollups, settings y auditoria;
  - `shared/src/domain/card.gleam`, `shared/src/domain/task.gleam` y
    `shared/src/domain/project.gleam` quedan como fachadas publicas de entidad,
    no como megamodulos;
  - los codecs compartidos viven junto al aspecto o contrato que serializan y
    siempre usan sufijo `_codec`;
  - no se usara un modulo generico `codec.gleam` por entidad para el modelo
    nuevo, porque tiende a convertirse en un segundo megamodulo;
  - los codecs actuales `shared/src/domain/<entidad>/codec.gleam` deben
    repartirse durante la reestructuracion entre modulos de aspecto como
    `state_codec.gleam`, `entity_codec.gleam`, `settings_codec.gleam` o
    `dependency_codec.gleam`, o moverse a `shared/src/api` si realmente
    representan request/response de endpoints;
  - `shared/src/domain` no contiene payloads HTTP, formularios ni detalles de
    rutas; contiene tipos puros, invariantes y reglas de dominio;
  - `shared/src/api` contiene contratos de frontera usados por cliente y
    servidor, por ejemplo `ActivateCardRequest`, `ActivateCardResponse`,
    `MoveCardRequest` o `CloseTaskResponse`;
  - `apps/server/src/http` conserva rutas, handlers, lectura de request,
    status codes y wiring HTTP;
  - `apps/server/src/use_case` conserva `Command`, autorizacion ya resuelta,
    version esperada, transacciones, orquestacion de repositorios y emision de
    auditoria;
  - por defecto los tipos `*Command` viven en `apps/server/src/use_case`, no en
    `shared`, salvo que sean intenciones puras de dominio sin actor,
    autorizacion, repositorio ni contexto server;
  - `apps/server/src/repository` conserva mappers SQL/DB y no dicta la forma del
    dominio;
  - `apps/client/src` conserva componentes, mensajes, modelos de vista y wiring
    de fetch; para endpoints usa contratos de `shared/src/api`;
  - flujo canonico de mutacion:
    `Request -> http handler -> Command -> use_case.run -> domain/repository ->
    Response`;
  - los casos de uso mutantes siguen siempre este ciclo:
    leer estado actual, validar permisos/version/invariantes, calcular `Plan`
    interno, persistir cambios y `audit_events` en una unica transaccion, y
    devolver `Response` o `View`;
  - `*Plan` es un tipo interno de `use_case` o helper de dominio; no se expone en
    `shared/src/api` ni al frontend;
  - si falla persistir el evento de auditoria, falla la mutacion completa; si
    falla la mutacion, no se persiste evento;
  - los casos de uso idempotentes no deben duplicar eventos de auditoria ni
    impacto en Pool;
  - Lustre consume mutaciones como efectos API atomicos: `User...` dispara el
    efecto, `ApiReturned...` actualiza el `Model` con la `Response`/`View`;
  - el frontend puede mostrar estado `Submitting`, `Activating` o equivalente,
    pero no duplica transacciones, auditoria, versionado ni rollups del server;
  - convencion de funciones dentro de un modulo `_codec`:
    - `decoder()` cuando el modulo ya identifica el tipo, por ejemplo
      `card/state_codec.decoder()`;
    - `to_json(value)` para encoding a `gleam/json.Json`;
    - nombres especificos solo cuando un mismo modulo tenga mas de un contrato
      real y no convenga separarlo en otro aspecto;
  - estructura objetivo inicial:
    - `shared/src/domain/card/entity.gleam`
    - `shared/src/domain/card/entity_codec.gleam`
    - `shared/src/domain/card/state.gleam`
    - `shared/src/domain/card/state_codec.gleam`
    - `shared/src/domain/card/structure.gleam`
    - `shared/src/domain/card/structure_codec.gleam`
    - `shared/src/domain/card/hierarchy.gleam`
    - `shared/src/domain/card/hierarchy_codec.gleam`
    - `shared/src/domain/card/placement.gleam`
    - `shared/src/domain/card/rollup.gleam`
    - `shared/src/domain/task/entity.gleam`
    - `shared/src/domain/task/entity_codec.gleam`
    - `shared/src/domain/task/state.gleam`
    - `shared/src/domain/task/state_codec.gleam`
    - `shared/src/domain/task/placement.gleam`
    - `shared/src/domain/task/placement_codec.gleam`
    - `shared/src/domain/task/dependency.gleam`
    - `shared/src/domain/task/dependency_codec.gleam`
    - `shared/src/domain/task/due_date.gleam`
    - `shared/src/domain/task/due_date_codec.gleam`
    - `shared/src/domain/project/settings.gleam`
    - `shared/src/domain/project/settings_codec.gleam`
    - `shared/src/domain/project/permissions.gleam`
    - `shared/src/domain/audit/event.gleam`
    - `shared/src/domain/audit/event_codec.gleam`
    - `shared/src/api/cards/activate.gleam`
    - `shared/src/api/cards/activate_codec.gleam`
    - `shared/src/api/cards/close.gleam`
    - `shared/src/api/cards/close_codec.gleam`
    - `shared/src/api/cards/move.gleam`
    - `shared/src/api/cards/move_codec.gleam`
    - `shared/src/api/cards/scope.gleam`
    - `shared/src/api/cards/scope_codec.gleam`
    - `shared/src/api/cards/scope_view.gleam`
    - `shared/src/api/cards/scope_view_codec.gleam`
    - `shared/src/api/cards/depth_scope_view.gleam`
    - `shared/src/api/cards/depth_scope_view_codec.gleam`
    - `shared/src/api/pool/view.gleam`
    - `shared/src/api/pool/view_codec.gleam`
    - `shared/src/api/sidebar/view.gleam`
    - `shared/src/api/sidebar/view_codec.gleam`
    - `shared/src/api/tasks/close.gleam`
    - `shared/src/api/tasks/close_codec.gleam`
    - `shared/src/api/tasks/dependencies.gleam`
    - `shared/src/api/tasks/dependencies_codec.gleam`
    - `apps/server/src/use_case/cards/activate.gleam`
    - `apps/server/src/use_case/cards/close.gleam`
    - `apps/server/src/use_case/cards/move.gleam`
    - `apps/server/src/use_case/tasks/close.gleam`
    - `apps/server/src/use_case/tasks/dependencies.gleam`
  - cualquier tipo, helper, estado, codec o aspecto de dominio equivalente que
    hoy viva en server, client u otro modulo compartido debe moverse a
    `shared/src/domain/<entidad>/<aspecto>.gleam` o al modulo compartido de
    dominio que corresponda;
  - cualquier contrato request/response compartido que hoy viva solo en server o
    client debe moverse a `shared/src/api/<recurso>/<accion>.gleam`;
  - cualquier operacion de producto que hoy viva en `services`, handlers HTTP o
    modulos de persistencia debe moverse a `apps/server/src/use_case` si
    coordina permisos, version, transaccion, repositorios o auditoria;
  - HT-01 debe empezar con un repaso general de la estructura actual para mover
    codigo existente a la nueva ubicacion cuando corresponda, no solo anadir
    archivos nuevos;
  - server y frontend solo deben conservar traducciones propias de su capa:
    HTTP, DB, comandos, queries, componentes, mensajes, estilos y wiring;
  - no se permiten duplicados semanticos entre client/server/shared tras la
    reestructuracion;
  - no se introduce `WorkItem` ni recurso generico equivalente.
- Performance de arbol:
  - validar listados con arboles profundos y muchas tasks descendientes;
  - distinguir capacidad tecnica de salud de Pool: el sistema debe soportar
    arboles grandes, pero el Pool sano deberia mantenerse alrededor de 20 tasks
    abiertas o menos;
  - crear seeds de arbol grande donde solo una parte pequena este activa en el
    Pool, y una seed especifica de Pool saturado para validar advertencias;
  - evitar recomputar rollups completos en cada render si el coste crece mal;
  - medir queries principales de Pool, scope por nivel y card detail;
  - validar que activar una rama muestra el tamano estimado del Pool tras la
    activacion y avisa si supera el umbral saludable.
- Concurrencia y versionado:
  - `cards`, `tasks` y `ProjectSettings` tienen `version: Version`;
  - la version se autoincrementa automaticamente en servidor/DB al persistir
    una mutacion exitosa;
  - el usuario nunca ve ni edita la version;
  - las mutaciones sensibles envian `expected_version`;
  - si `expected_version` no coincide con la version actual, se devuelve
    `Conflict(StaleVersion)`;
  - activar/cerrar/mover usan version o conflicto detectable;
  - evitar doble activacion y doble cierre con eventos duplicados;
  - no perder cambios si dos usuarios editan estructura cercana.
- Auditoria:
  - registrar activacion, cierre manual, cierre por ancestor, movimiento,
    creacion RootPool y cambios de configuracion de nombres/perfiles por
    profundidad;
  - conservar `actor`, fecha, target tipado e impacto cuando aplique;
  - sustituir `task_events` por `audit_events` como modelo vivo;
  - mantener codecs compartidos para `AuditEventKind`;
  - si una respuesta API expone eventos o timeline, su request/response vive en
    `shared/src/api`, no dentro del dominio de auditoria.
- Migracion:
  - se adopta schema final limpio con migracion/importador explicito desde la
    BBDD actual;
  - si el repositorio lo permite, se rebasea/squashea la historia SQL para que
    las migraciones activas y `db/schema.sql` no arrastren `milestones`;
  - no se acepta compatibilidad runtime ni rutas legacy como sustituto de una
    migracion de datos;
  - ejecutar dry-run o fixture equivalente antes de tocar schema final;
  - producir informe de agrupadoras creadas, inconsistencias y conteos migrados;
  - documentar claramente como pasar de BBDD actual a BBDD final limpia.
- i18n/copy:
  - actualizar textos en ES/EN para RootPool, Active/Draft/Closed, outcomes,
    permisos y ayudas contextuales;
  - comprobar que los textos largos no rompen layout.
- Accesibilidad:
  - foco visible, accion por teclado, labels de botones icon-only y tooltips
    accesibles;
  - no depender solo de color para due date, bloqueo o cierre.
- Observabilidad de pruebas:
  - cada historia con UI debe dejar rutas, usuario usado, viewport y capturas;
  - cada historia de migracion debe dejar datos de entrada/salida verificables.

## Protocolo De Ejecucion Del Goal

El desarrollo debe ejecutarse como un goal unico en la rama integradora
`new_hierarchy`: completar la reestructuracion `Card tree + Task leaves`, due
dates, migracion sin legacy, redisenos de UI, tests, seeds, validaciones
visuales y cleanup final. Aunque el goal sea unico, la ejecucion interna se
divide obligatoriamente por historias `HT-*`.

La rama `new_hierarchy` es la unica rama de integracion del goal. Cada historia
sale de `new_hierarchy`, vuelve a `new_hierarchy` y no se pasa a la siguiente
historia hasta que el merge de la anterior este completado.

Cada historia se trabaja en una rama independiente:

```text
new_hierarchy
  -> new_hierarchy/ht-01-adts-base
  -> merge back to new_hierarchy
  -> new_hierarchy/ht-02-card-tree-invariants
  -> merge back to new_hierarchy
  -> ...
```

Flujo obligatorio por historia:

1. Actualizar y situarse en `new_hierarchy`.
2. Crear rama de historia desde `new_hierarchy`.
3. Bajar la historia a tests concretos con nombres de modulos reales.
4. Escribir tests rojos antes de implementar.
5. Implementar la historia en ciclos red/green/refactor.
6. Ejecutar gates tecnicos de la historia.
7. Ejecutar revision con la skill `gleam-refactor` sobre el diff de la rama
   contra su padre.
8. Corregir todo lo detectado por `gleam-refactor`.
9. Ejecutar validacion con `agent-browser` si la historia toca UI o flujo
   visible; si no toca UI, registrar explicitamente por que no aplica.
10. Corregir todo lo detectado por `agent-browser`.
11. Ejecutar gate final de la historia.
12. Commit de la historia.
13. Merge a `new_hierarchy`.
14. Solo entonces pasar a la siguiente historia.

`gleam-refactor` debe aplicarse con su contrato completo:

- resolver rama padre;
- revisar solo el diff de la historia;
- auditar arquitectura, reutilizacion, superficie publica y tests;
- ejecutar formato/tests requeridos;
- devolver informe de parent branch, diff scope, mejoras aplicadas,
  mejoras rechazadas y verificacion.

`agent-browser` debe aplicarse con sesion aislada por historia cuando haya UI:

- abrir la app con seed representativa;
- tomar snapshot interactivo antes de actuar;
- ejecutar clicks/fills reales;
- re-snapshot tras cada cambio relevante;
- capturar screenshots desktop y mobile;
- validar ausencia de overflow, solapes y textos cortados;
- validar estados deshabilitados, foco, targets tactiles y contraste;
- cerrar la sesion al terminar.

No se permite acumular varias historias sin commit/merge intermedio. Si una
historia revela trabajo previo incompleto, se corrige dentro de esa historia
antes de comitear, o se documenta un bloqueo real si impide continuar.

Tras completar y mergear todas las historias en `new_hierarchy`, se ejecuta un
cierre final obligatorio antes de considerar el goal terminado:

1. Ejecutar `gleam-refactor` sobre el diff completo de `new_hierarchy` contra su
   rama padre.
2. Aplicar las mejoras de arquitectura, simplificacion, tipado, reutilizacion y
   reduccion de superficie publica que el repaso encuentre.
3. Ejecutar un repaso completo de limpieza: eliminar codigo obsoleto,
   innecesario, duplicado, incompatible con la arquitectura final o restos de
   conceptos legacy.
4. Ejecutar validacion completa con `agent-browser` sobre los flujos principales
   desktop/tablet/mobile.
5. Ejecutar gates finales: formato, tests, checks, migracion/seeds y barridos
   anti-legacy/arquitectura.
6. Corregir todo lo detectado y hacer el commit final de cierre en
   `new_hierarchy`.

El primer paso de ejecucion es HT-01: bajar sus tests concretos a nombres de
modulos reales del repo y hacer inventario de los tipos actuales que deben
moverse a `shared/src/domain/<entidad>/<aspecto>.gleam`, `shared/src/api` o
`apps/server/src/use_case` segun corresponda.
