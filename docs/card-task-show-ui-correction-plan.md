# Card And Task Show UI Correction Plan

## Contexto

Tras ejecutar el bloque `card-task-show-redesign-plan`, las vistas de Card Show
y Task Show incorporan parte de la funcionalidad esperada, pero no alcanzan el
lenguaje visual ni la calidad de interaccion de las superficies principales de
ScrumBringer.

Las vistas principales recientes, especialmente Pool, Plan, Capacidades y
Personas, comparten una gramatica clara:

- cabecera compacta;
- scope y filtros en una franja reconocible;
- chips de resumen;
- cuerpo denso y escaneable;
- acciones primarias visibles y acciones secundarias contenidas;
- sidebar derecho estable para el trabajo propio;
- lenguaje visual sobrio, de herramienta, no de pagina editorial.

Card Show y Task Show han quedado en un patron hibrido de modal/detalle que no
termina de funcionar como superficie de trabajo ni como drawer contextual.

Este documento define el plan de correccion.

## Objetivo

Redisenar Card Show y Task Show para que:

1. usen el mismo lenguaje visual que Pool, Plan, Capacidades y Personas;
2. respeten que Card y Task son entidades distintas;
3. reduzcan ruido visual y niveles de empaquetado innecesarios;
4. hagan visibles las decisiones operativas correctas;
5. eliminen restos de UI anterior, codigo duplicado o componentes obsoletos;
6. validen desktop y mobile con `agent-browser`.

La intencion no es pulir CSS superficialmente. El problema principal es de
composicion, jerarquia, comportamiento y reutilizacion de componentes.

## Diagnostico

### P0 - Card Show mobile no se comporta como show full-screen real

En mobile, abrir una card desde el titulo o desde `Ver` no siempre produce una
experiencia clara de Card Show. En la validacion observada, una URL con
`work_scope=card&card=...` mostro Plan scoped con detalle inline, no Card Show
full-screen.

Esto confunde dos conceptos:

- scope de una vista principal;
- show de una entidad.

La navegacion debe distinguirlos con claridad.

Este punto es bloqueante. Si mobile no abre un Card Show real, la iteracion no
puede considerarse terminada aunque el resto del layout mejore.

### P1 - Resumen de Card Show roto

El resumen actual muestra pares etiqueta/valor pegados:

```text
Tareas3
Tareas completadas0
Progreso0%
```

Esto parece una vista sin maquetar y reduce mucho la calidad percibida.

### P1 - Tabs mal integradas

Las tabs `Resumen`, `Trabajo`, `Notas` y `Actividad` aparecen como botones
grandes dentro de una caja adicional:

```text
card-tabs card-show-tabs detail-tabs
```

Problemas:

- no parecen tabs;
- tienen demasiado peso visual;
- estan mal alineadas con las acciones superiores;
- no tienen buen espaciado respecto a `Nueva tarjeta` / `Anadir tarea`;
- el wrapper anade un nivel visual de empaquetado sin aportar semantica clara;
- en mobile, labels como `Dependencias` quedan comprimidos o truncados.

### P2 - Descripciones sin contexto

Textos como:

```text
Ready root card dominated by loose documentation and compliance tasks, useful to validate the exception treatment in the new view.
```

aparecen sin suficiente contexto, como texto suelto tras metricas. Deben vivir
en una seccion `Descripcion` clara, con label, espaciado y truncado si procede.

### P2 - URLs duplicadas en notas/contexto

Cuando una URL existe tanto en el contenido de la nota como en el campo URL, la
vista puede renderizarla dos veces. Funciona, pero ensucia la lectura y hace que
la nota parezca generada o poco cuidada.

### P2 - Mobile `Mis tareas` pierde identidad

En el panel movil, las tareas pueden aparecer como:

```text
En Mis tareas, lista para empezar
```

en lugar de mostrar el titulo real de la task. Ademas, el target para abrir Task
Show no queda claro y en una prueba un click cerro el panel.

### P2 - Acciones destructivas demasiado visibles

En Task Show mobile y desktop aparecen `Cerrar`, `Eliminar` y la accion
primaria en una barra inferior fija. Para ScrumBringer, cerrar o eliminar una
task/card no debe estar tan a mano; es una accion secundaria, comparable a un
borrado logico.

### P2 - Actividad util pero visualmente cruda

La tab `Actividad` contiene eventos reales, pero se presenta como una lista
cruda en una superficie casi vacia. Falta agrupacion, ritmo, jerarquia de evento
y tratamiento de empty states.

### P2 - Contenido pegado con HTML literal en notas

El contenido de una nota puede incluir texto pegado como:

```text
<b>sin html</b>
```

Debe seguir renderizandose de forma segura, sin interpretar HTML. Aun asi, la UI
debe evitar que parezca markup accidental o una rotura visual si puede
normalizarse o presentarse con mejor contexto.

## Principios De Redisenio

1. **Patron visual compartido, no framework generico.** Card Show y Task Show
   deben compartir lenguaje visual y piezas pequenas, pero no una carcasa
   generica si eso obliga a ocultar diferencias de producto.
2. **Card es contexto.** Una card explica, resume, conecta y permite navegar a
   vistas scoped. No se reclama ni se ejecuta.
3. **Task es ejecucion.** Una task debe dejar clara su accion siguiente:
   reclamar, empezar, completar, liberar o entender por que esta bloqueada.
4. **Menos cajas.** No envolver tabs, resumenes o bloques en cards si el
   contenido ya vive dentro de una superficie contenida.
5. **Accion primaria visible, acciones raras ocultas.** Crear/reclamar/continuar
   puede estar visible. Cerrar, eliminar, mover o acciones administrativas deben
   ir a menu secundario.
6. **Tabs reales.** Las tabs son navegacion dentro del show, no botones de
   comando.
7. **Mobile es una experiencia propia.** En mobile, un show abierto debe sentirse
   full-screen y estable, no como un overlay dudoso encima de otra vista.
8. **Sin legacy.** Si el nuevo patron sustituye el modal anterior, se elimina el
   codigo anterior. No mantener dos sistemas de detalle.

### Mejoras Incorporadas Antes De Ejecutar

Estas decisiones endurecen el plan para evitar que el goal vuelva a mezclar
conceptos o construya abstracciones prematuras.

1. **URL/estado de show explicito.** Se acepta como decision fuerte:
   `work_scope=card&card=...` es scope de vista; `show=card&show_card=...` y
   `show=task&task=...` son detalle abierto. El goal no puede usar una
   convencion implicita ni reutilizar `card` para dos significados.
2. **Componentes compartidos minimos.** Se crean o corrigen con prioridad tabs,
   metric strip y menu secundario. Shell/header/notas/actividad compartidos solo
   se extraen si durante la implementacion queda duplicacion real, API pequena y
   codigo eliminado.
3. **Task state y work session separados.** Claim, now working, release y
   complete deben mantenerse separados en tipos, update, UI y tests.
4. **Accesibilidad como gate.** Foco, Escape, retorno de foco, tabs navegables y
   menus secundarios accesibles son criterios bloqueantes, no polish opcional.
5. **Card vacia sin decision arbitraria.** Una card vacia ofrece dos opciones
   equilibradas: anadir task o anadir subcard. No se elige una primaria por el
   usuario.
6. **HTML en notas seguro y bien presentado.** No se interpreta HTML. La mejora
   es evitar duplicados, dar contexto y hacer que contenido literal no parezca
   una rotura.
7. **Mobile Card Show P0.** Si en mobile `Ver` no abre Card Show full-screen
   real, el goal esta incompleto.
8. **Selectores estables en targets reales.** Los `data-testid` se ponen en
   controles accionables y superficies raiz, no en contenedores ambiguos.

### Decision Sobre Las Mejoras Revisadas

Se incorporan estas mejoras como criterios de ejecucion, no como ideas
opcionales:

| Mejora | Decision | Motivo |
| --- | --- | --- |
| URL/estado de show explicito | Aceptada | Evita que `work_scope=card&card=...` vuelva a confundirse con Card Show |
| Componentes compartidos | Aceptada con limite | Crear tabs/metric strip/menu si aporta claridad; shell/header solo si la API resulta evidente |
| Task state vs work session | Aceptada | ScrumBringer no debe mezclar reclamar, trabajar ahora, liberar y completar |
| Accesibilidad/foco/teclado | Aceptada como gate | No es polish: afecta a cierre, deep links, mobile y uso real |
| Card vacia con dos opciones | Aceptada | Una card vacia aun no ha elegido si contiene tasks o subcards |
| HTML literal en notas | Aceptada con seguridad | No se interpreta HTML; se mejora la presentacion y deduplicacion |
| Card Show mobile P0 | Aceptada como bloqueante | Si mobile no abre show real, el objetivo central falla |
| `data-testid` estables | Aceptada con moderacion | Deben estar en targets reales para validar sin ensuciar todo el DOM |

Se rechaza convertir esta iteracion en un framework generico de `EntityShow`.
La unificacion correcta es de lenguaje visual y piezas pequenas. Card y Task
siguen teniendo misiones distintas y cuerpos especificos.

Tambien se rechaza interpretar HTML de notas, mover acciones destructivas al
primer plano, o resolver mobile con una excepcion distinta al contrato de URL:
desktop y mobile deben compartir estado; solo cambia la presentacion.

### Mejoras Previas A La Ejecucion

Antes de ejecutar este plan, el goal debe asumir estas correcciones de
direccion. Su objetivo es reducir interpretacion, no aumentar alcance.

1. **Primero contrato, despues composicion.** El orden real debe ser:
   URL/estado, apertura/cierre, componentes minimos, Card Show, Task Show,
   mobile, limpieza. Cambiar CSS antes de separar scope/show puede producir una
   pantalla mas bonita pero seguir dejando roto el comportamiento central.
2. **El show no es una vista principal mas.** Card Show y Task Show son
   superficies de detalle. Pueden enlazar a Plan, Kanban, Capacidades y Personas
   con scope cargado, pero no deben duplicar esas vistas completas dentro del
   show.
3. **Card Show y Task Show no comparten mision.** Comparten lenguaje visual,
   componentes pequenos y estado de overlay. No deben compartir una abstraccion
   de entidad que fuerce a Card a parecer ejecutable o a Task a parecer un
   dashboard.
4. **Los cambios visuales se validan contra densidad operativa.** El resultado
   debe ser compacto, escaneable y alineado con Pool/Plan/Capacidades/Personas.
   Evitar cajas anidadas, sombras decorativas, tabs como botones y headers
   sobredimensionados.
5. **No se cierra un slice con deuda visible.** Cada slice debe dejar tests
   verdes y retirar el codigo que haya vuelto obsoleto. No aplazar limpieza de
   legacy a un bloque final si ese legacy ya dejo de usarse en el slice.
6. **Agent-browser no es solo captura final.** Debe usarse como validacion de
   producto: abrir, navegar, usar tabs, cerrar, comprobar foco/targets y mirar
   mobile. Si la prueba visual detecta que la UI se empobrecio, el goal debe
   corregir antes de comitear.

7. **Lo ya implementado se audita, no se reescribe por reflejo.** Si una parte
   del contrato ya existe en codigo, el goal debe verificarla con tests y
   limpieza antes de cambiarla. Rehacer codigo funcional solo esta justificado
   si simplifica, elimina deuda o corrige un defecto visible.

8. **Cada mejora debe tener un fallo que evita.** Si un cambio no evita un bug,
   una ambiguedad, duplicacion real, mala accesibilidad o una inconsistencia de
   producto, debe dejarse fuera de este plan.

### Criterio De Minimalismo

El plan permite rehacer cosas, pero no invita a crear una plataforma generica de
shows.

Extraer un componente solo es correcto si cumple al menos una de estas
condiciones:

- elimina duplicacion real entre Card Show y Task Show;
- encapsula una responsabilidad pequena ya estable, como tabs, metricas,
  acciones secundarias, notas o actividad;
- mejora accesibilidad o testing sin esconder estados de dominio;
- permite borrar codigo anterior.

No extraer si:

- obliga a pasar muchos callbacks opcionales;
- introduce flags tipo `is_card`, `is_task`, `show_delete`, `show_navigation`;
- hace que los tests verifiquen configuracion interna en vez de comportamiento
  de usuario;
- no permite eliminar nada.

## Contrato De Navegacion Y URL

Separar de forma explicita el estado de scope de una vista principal y el estado
de show de una entidad.

Decision:

```text
work_scope=card&card=413
```

significa que la vista principal actual se filtra o contextualiza por esa card.
Por ejemplo, Plan scoped, Capacidades scoped o Personas scoped.

```text
show=card&show_card=413
```

significa que Card Show esta abierto.

```text
show=task&task=825
```

significa que Task Show esta abierto.

Motivo de usar `show_card` en vez de reutilizar `card`: el codigo actual usa
`card` para el scope (`work_scope=card&card=...`). Si una vista principal esta
scoped a una card y se abre el show de otra card, reutilizar `card` produciria
un estado ambiguo. El goal debe evitar esa ambiguedad en el tipo de URL, no
resolverla con convenciones implicitas.

Contrato tipado recomendado:

```gleam
pub type ShowParam {
  CardShowParam(card_id: Int)
  TaskShowParam(task_id: Int)
}
```

`UrlState` debe poder representar, de forma independiente:

- proyecto actual;
- vista principal actual;
- scope de la vista principal;
- show de entidad abierto.

El contrato conceptual es obligatorio: scope y show no son intercambiables.

### Invariantes Del Contrato

| URL / estado | Significado | Debe ocurrir | No debe ocurrir |
| --- | --- | --- | --- |
| `work_scope=card&card=413` | La vista principal esta contextualizada por la card 413 | Plan/Kanban/Capacidades/Personas muestran datos scoped | No abre Card Show |
| `show=card&show_card=413` | Card Show de la card 413 esta abierto | Se abre/restaura Card Show | No cambia el scope de la vista principal |
| `show=task&task=825` | Task Show de la task 825 esta abierto | Se abre/restaura Task Show | No reclama, inicia ni modifica la task |
| `work_scope=card&card=1&show=card&show_card=2` | Vista scoped a card 1 con show de card 2 | Ambos ids se conservan separados | No se sobrescribe `card=1` con `show_card=2` |

Regla fuerte: los parametros de URL deben modelarse con tipos distintos. Si el
router necesita distinguir `card` de scope y `show_card` de show, esa distincion
debe existir en `UrlState`, tests de parseo y tests de serializacion.

Reglas:

- abrir `Ver` sobre una card abre Card Show, no una vista scoped;
- abrir `Ver en Plan` abre Plan con scope card;
- abrir una task abre Task Show;
- cerrar un show devuelve el foco y el contexto a la vista que lo abrio;
- si se abre Card Show desde Task Show, no se deben apilar overlays ambiguos:
  reemplazar el show actual o navegar a un estado de URL claro;
- deep-link de Card Show y Task Show debe restaurar el show correcto;
- abrir/cerrar Card Show o Task Show debe sincronizar la URL desde el update
  raiz o desde el adaptador de ruta correspondiente, nunca desde componentes de
  vista;
- aplicar una URL con show debe reutilizar los handlers de apertura existentes
  para cargar notas, dependencias y actividad, en vez de duplicar esa logica en
  el router;
- si la entidad del show no existe o no pertenece al proyecto actual, cerrar el
  show y dejar la vista principal intacta.

### Gate De Navegacion Antes De UI

Antes de rehacer CSS o layout, el goal debe cerrar este gate:

- `UrlState` representa `show` como ADT, no como flags sueltos;
- parsear y serializar scope + show no pierde ningun id;
- abrir/cerrar Card Show y Task Show sincroniza la URL;
- `work_scope=card&card=...` no abre show;
- `show=card&show_card=...` no cambia scope;
- `show=task&task=...` restaura Task Show usando los handlers existentes;
- mobile y desktop comparten el mismo contrato de estado, aunque el layout
  visual cambie.

Si este gate no esta verde en tests, no avanzar a redisenar Card Show/Task Show.

Hallazgos actuales que debe tener en cuenta el goal:

- `url_state.gleam` no tiene actualmente un campo `show`;
- `work_scope=card&card=...` ya existe y no debe ser reinterpretado como show;
- Card Show vive en `member.pool.card_show_open`;
- Task Show vive en `member.notes.member_notes_task_id`;
- los handlers de apertura actuales cargan datos remotos del show, por lo que
  no conviene saltarselos desde el parseo de URL.

## Arquitectura Visual Objetivo

### Patron Visual De Show

Definir un patron visual compartido, sin obligar todavia a crear un componente
`entity_show_shell`:

```text
┌──────────────────────────────────────────────────────────────┐
│ [x] Path / contexto                                           │
│ Titulo de la entidad                                [chips...] │
│ Descripcion breve / subtitulo                                 │
│                                                              │
│ [Accion primaria] [...]        Navegar: [Plan] [Capacidades] │
│                                                              │
│ Resumen   Trabajo   Notas   Actividad                        │
│ ───────                                                      │
│                                                              │
│ Contenido de tab                                             │
└──────────────────────────────────────────────────────────────┘
```

El patron debe resolver:

- cierre;
- header;
- chips;
- accion primaria;
- menu secundario;
- tabs;
- layout desktop;
- layout mobile;
- scroll interno;
- estados vacios.

### Desktop

En desktop, el show puede abrirse como panel amplio contextual si mantiene una
relacion clara con la vista subyacente. Aun asi, debe parecer una superficie de
detalle bien compuesta, no un modal CRUD.

Reglas:

- ancho suficiente para leer contenido sin lineas demasiado largas;
- no apilar overlays sobre overlays;
- al navegar desde Task Show a Card Show, reemplazar el show actual o navegar a
  una ruta clara, no superponer detalles;
- el fondo puede quedar visible, pero no debe competir.

### Mobile

En mobile, Card Show y Task Show deben comportarse como full-screen.

Reglas:

- abrir `Ver` en card abre Card Show full-screen;
- abrir una task abre Task Show full-screen;
- `work_scope=card&card=...` no debe sustituir al show;
- el show debe tener header fijo o suficientemente estable;
- tabs con scroll horizontal;
- acciones secundarias en menu;
- no usar barra inferior con acciones destructivas siempre visibles.

### Accesibilidad Y Teclado

Los shows deben comportarse como superficies interactivas accesibles.

Criterios:

- al abrir un show, el foco inicial debe ir al titulo, cierre o accion primaria
  segun sea mas razonable para el flujo;
- `Escape` cierra el show cuando no haya un dialogo interno abierto;
- al cerrar, el foco vuelve al elemento que abrio el show si sigue existiendo;
- tabs navegables por teclado;
- menu secundario `...` navegable por teclado;
- botones icon-only con `aria-label` claro;
- `Cerrar`, `Abrir tarea`, `Abrir tarjeta`, `Acciones`, `Ver en Plan` y
  equivalentes tienen nombre accesible estable;
- los estados disabled explican razon cuando sea importante para la decision del
  usuario.

Estos criterios son bloqueantes, no opcionales:

- Card Show mobile debe abrirse como show real, no como Plan scoped;
- Task Show mobile debe abrirse como show real, no como cierre accidental del
  panel inferior;
- `Escape` no debe cerrar el show si hay un dialogo interno activo que deba
  recibir primero el cierre;
- los targets de apertura deben tener identificadores estables para
  `agent-browser` y tests automatizados.

## Card Show

### Mision

Responder rapidamente:

- que representa esta card;
- donde esta en el arbol;
- que estado global tiene;
- que trabajo contiene;
- que capacidades y personas estan implicadas;
- que bloqueos o vencimientos afectan al arbol;
- como saltar a Plan, Kanban, Capacidades o Personas con esta card como scope.

### Header

```text
People QA - Coordination stream > People QA - Release readiness

People QA - Release readiness                      [Active] [3 tasks] [1 bloqueada]
Task leaf for release readiness coordination.

[+ Anadir tarea] [...]       Abrir en: [Plan] [Kanban] [Capacidades] [Personas]
```

Reglas:

- titulo alineado a la izquierda;
- path por encima o bajo el titulo, pero siempre visible;
- chips compactos;
- descripcion con contexto, no texto suelto;
- accion principal contextual: `+ Task` o `+ Subcard`;
- acciones raras en menu `...`;
- navegacion scoped como grupo secundario `Abrir en`.

### Card Vacia

Una card vacia todavia no ha elegido si contendra tasks o subcards. La UI no
debe decidirlo por defecto.

Recomendacion:

```text
Esta card aun no tiene trabajo.

[Anadir task] [Anadir subcard]
```

Reglas:

- no mostrar una unica accion primaria arbitraria para card vacia;
- las dos opciones deben tener peso equilibrado dentro del empty state;
- una vez se crea la primera task, la card queda orientada a tasks;
- una vez se crea la primera subcard, la card queda orientada a subcards;
- si la politica de permisos impide una accion, mostrarla deshabilitada con
  razon o retirarla si no aporta aprendizaje.

### Tabs

Las tabs deben usar un patron compartido ligero. La primera opcion es corregir o
envolver los componentes existentes (`ui/tabs.gleam` / `ui/detail_tabs.gleam`).
Solo crear `entity_tabs` si aporta una API mas pequena y elimina duplicacion
real.

```text
Resumen   Trabajo   Notas   Actividad
────────
```

Reglas:

- eliminar el wrapper visual pesado si no aporta funcion;
- no renderizarlas como cuatro botones rellenos;
- separar las acciones de entidad de las tabs;
- desktop: una linea estable;
- mobile: scroll horizontal con ancho minimo por tab;
- foco y estado activo accesibles;
- labels i18n, sin truncado accidental.
- si se mantiene `detail_tabs.gleam`, su responsabilidad debe ser semantica de
  tabs, no conservar clases o padding del diseno anterior.

### Resumen

Sustituir el bloque actual por metricas maquetadas.

```text
Resumen operativo

┌──────────────┬─────────────────┬───────────┬────────────┐
│ 3            │ 0               │ 0%        │ 1          │
│ Tareas       │ Completadas     │ Progreso  │ Bloqueada  │
└──────────────┴─────────────────┴───────────┴────────────┘

Descripcion
Ready root card dominated by loose documentation and compliance tasks...
```

Reglas:

- no concatenar label/valor;
- si no hay descripcion, mostrar empty state discreto;
- truncar descripcion larga en resumen con opcion de verla completa en su
  propio bloque o tab si procede;
- mostrar vencimiento y bloqueo como indicadores compactos, no como texto largo
  que deforme la vista.

### Trabajo

La card puede contener solo subcards o solo tasks.

```text
Trabajo

3 tasks

Task                                      Estado        Capacidad      Vence
People QA - Release checklist blocker    Disponible    Operations     -
People QA - Facilitate rollout sync      Reclamada     Operations     Hoy
People QA - Blocked deploy approval      Bloqueada     Product        -
```

Si contiene subcards:

```text
Subcards

Card                          Estado       Tasks       Bloqueos
API handoff                   Active       0/2         0
Release readiness             Active       0/3         1
UI polish                     Active       0/4         0
```

Reglas:

- no duplicar Plan completo dentro de Card Show;
- mostrar una preview util y enlace a Plan scoped;
- `+ Task` solo si la card contiene tasks o esta vacia;
- `+ Subcard` solo si contiene subcards o esta vacia.
- en card vacia, usar el empty state con dos acciones equilibradas, no una
  accion primaria unica.

### Notas

```text
Notas fijadas

Decision de alcance                           ana@example.com · 22 jun
Se usara el endpoint actual hasta cerrar QA.
[Abrir documento]

Conversacion
...
```

Reglas:

- notas fijadas arriba;
- campo URL como recurso principal;
- evitar duplicar la misma URL si ya esta en contenido;
- notas normales debajo;
- empty state breve y accion clara;
- no convertir notas en chat completo ni wiki.

### Actividad

```text
Actividad

2026-06-22
● ana@example.com activo la card
  10:34
● luis@example.com anadio una task
  11:02

2026-06-21
● admin@example.com creo la card
  06:25
```

Reglas:

- agrupar por fecha;
- evento en lenguaje humano;
- actor y hora visibles;
- evitar timeline decorativo pesado;
- empty state si no hay eventos.

## Task Show

### Mision

Responder rapidamente:

- que hay que hacer;
- en que card vive;
- si puedo actuar sobre ella;
- si esta bloqueada;
- quien la tiene;
- cuando vence;
- que notas/contexto necesita;
- que ha ocurrido.

### Header

```text
People QA - Release readiness

People QA - Release checklist blocker        [Disponible] [Task] [P4]
Plan QA fixture task

[Reclamar tarea] [...]       Abrir: [Card] [Plan]
```

Reglas:

- accion primaria depende del estado:
  - disponible: `Reclamar tarea`;
  - reclamada por mi: `Empezar` o `Liberar`;
  - en curso: `Completar` o accion equivalente;
  - bloqueada: mostrar razon y no ofrecer accion imposible;
- `Cerrar` y `Eliminar` van a menu secundario;
- si pertenece a card, mostrar enlace claro a Card Show y Plan scoped.

### Task State Vs Work Session

No mezclar lifecycle de task, claim y sesion de trabajo.

Definiciones:

- **Disponible:** task abierta y claimable, si no esta bloqueada.
- **Reclamada:** una persona la ha tomado. Ya no es equivalente a estar
  trabajando ahora.
- **Now working / en curso:** la persona esta trabajando activamente en una
  sesion de trabajo.
- **Liberar:** la task deja de estar reclamada.
- **Completar/cerrar:** cambia el lifecycle de la task y puede disparar reglas
  de workflow.

La accion primaria debe derivarse de esta diferencia:

```text
Disponible        -> Reclamar tarea
Reclamada por mi  -> Empezar
En curso por mi   -> Completar
Reclamada por otro-> Sin accion primaria, mostrar responsable
Bloqueada         -> Sin accion primaria, mostrar razon
Closed            -> Sin accion primaria operativa
```

Acciones secundarias:

- `Liberar` va al menu secundario cuando la task esta reclamada por mi;
- `Pausar` solo aparece si ya existe una accion clara de sesion de trabajo y
  tiene sentido en el modelo actual;
- `Eliminar` y cierre/cancelacion logica van siempre al menu secundario;
- si una accion no procede por bloqueo, propiedad o historial operativo, debe
  mostrarse deshabilitada con razon solo si esa razon ayuda al usuario; si no,
  se retira para reducir ruido.

El codigo actual ya distingue `Claimed(Taken)` y `Claimed(Ongoing)`. El goal
debe mapear esas variantes al nuevo lenguaje visual sin inventar estados nuevos
ni colapsarlas en un booleano.

### Diferencia Operativa Obligatoria

El redisenio debe conservar esta diferencia en tipos, update y UI:

- reclamar una task no significa estar trabajando;
- empezar una sesion de trabajo no significa reclamar por primera vez;
- liberar una task no es completar;
- completar/cerrar puede disparar reglas y actividad;
- una task bloqueada puede estar visible, pero no debe ofrecer una accion
  imposible como primaria.

Esto debe reflejarse en tests de footer/header de Task Show y en las
validaciones con `agent-browser`.

### Tabs

```text
Detalles   Dependencias   Notas   Actividad
────────
```

Reglas:

- mismo patron ligero que Card Show;
- reutilizar `ui/tabs.gleam` / `ui/detail_tabs.gleam` si se puede corregir sin
  API inflada;
- mobile con scroll horizontal;
- `Dependencias` no debe quedar comprimido;
- no usar wrappers pesados.

### Detalles

```text
Resumen operativo

Estado          Disponible
Tipo            Task
Capacidad       Operations
Responsable     Sin asignar
Prioridad       P4
Vence           Sin vencimiento
Bloqueos        Sin bloqueos activos

Descripcion
Plan QA fixture task
```

Reglas:

- usar pares label/valor alineados;
- no meter todo en una gran card si el shell ya contiene la superficie;
- mantener densidad;
- editar como accion secundaria o boton discreto en la seccion.

### Dependencias

```text
Dependencias

Bloqueada por
No hay dependencias activas

Bloquea a
No bloquea otras tasks
```

Si hay bloqueos:

```text
Bloqueada por
● Deploy approval               Product · Bloqueada

Bloquea a
● Release checklist             Operations · Disponible
```

Reglas:

- mostrar que dependencias estan abiertas/cerradas;
- si una dependencia se cierra o elimina, la task se desbloquea
  automaticamente segun la decision de producto;
- no permitir acciones que creen ciclos.

### Notas

Mismo patron que Card Show, pero orientado a ejecucion:

- notas fijadas;
- enlaces/documentos;
- discusiones breves;
- evitar URLs duplicadas.

### Actividad

```text
2026-05-28
● admin@example.com reclamo la task
  16:25
● admin@example.com libero la task
  16:25

2026-06-21
● admin@example.com creo la task
  06:25
```

Reglas:

- eventos reales;
- lenguaje humano;
- sin lista cruda en una superficie vacia.

## Mobile My Work Correction

El panel movil de `Mis tareas` debe conservar identidad de task.

Estado actual observado:

```text
En Mis tareas, lista para empezar
```

Objetivo:

```text
People QA - Facilitate rollout sync
Lista para empezar

[Abrir] [Empezar]
```

Reglas:

- mostrar titulo real;
- truncado controlado;
- target explicito `Abrir tarea`;
- tocar la fila no debe cerrar el panel si el usuario espera abrir la task;
- botones compactos y coherentes con el resto de ScrumBringer.

## Componentizacion

### Extraccion Incremental

La implementacion debe evitar crear un framework interno de `EntityShow`.
Compartir componentes solo donde la responsabilidad comun sea evidente.

Extraccion recomendada, entendida como responsabilidad compartida y no
necesariamente como fichero nuevo:

1. **Resolver seguro**
   - tabs ligeras de entidad;
   - metric strip label/valor;
   - menu de acciones secundarias.

   Si `ui/tabs.gleam`, `ui/detail_tabs.gleam`, `ui/action_menu.gleam` o un
   componente existente pueden cubrir esta responsabilidad con una API pequena,
   se mejoran o envuelven. No crear un modulo nuevo por nombre si el existente
   ya tiene la responsabilidad correcta.

2. **Extraer si la duplicacion queda clara durante la implementacion**
   - `ui/entity_activity.gleam`
   - `ui/entity_notes.gleam`
   - `ui/contextual_navigation.gleam`

3. **Retrasar salvo API evidente**
   - `ui/entity_show_shell.gleam`
   - `ui/entity_show_header.gleam`

Motivo: Card Show y Task Show deben compartir lenguaje visual, pero no deben
quedar forzados dentro de una abstraccion generica que oculte su mision.

### Regla Anti-Framework Interno

No crear `entity_show_shell`, `entity_show_header`, builders genericos ni tipos
con muchos slots hasta que Card Show y Task Show esten rehechos y la API sea
obvia.

Senales de sobreingenieria:

- el componente compartido necesita muchas funciones opcionales;
- hay que pasar flags para distinguir Card de Task;
- el tipo generico oculta estados relevantes del dominio;
- los tests verifican plumbing del componente en vez de comportamiento de
  producto;
- cambiar una accion de Task obliga a tocar Card Show o viceversa.

En esos casos, mantener componentes especificos y compartir solo piezas
pequenas: tabs, metricas, notas, actividad o menu, segun proceda.

### Componentes Candidatos, No Obligatorios

- `ui/entity_show_shell.gleam` **no obligatorio**
  - layout desktop/mobile;
  - cierre;
  - scroll;
  - slots de header, tabs y body.
- `ui/entity_show_header.gleam` **no obligatorio**
  - path;
  - titulo;
  - descripcion;
  - chips;
  - accion primaria;
  - menu secundario.
- `ui/entity_tabs.gleam`
  - tabs ligeras;
  - estado activo;
  - scroll mobile;
  - labels y contadores opcionales.
- `ui/entity_metric_strip.gleam`
  - metricas compactas para resumen;
  - evita textos pegados.
- `ui/entity_activity.gleam`
  - eventos agrupados por fecha.
- `ui/entity_notes.gleam`
  - notas fijadas/no fijadas;
  - links;
  - deduplicacion visual de URLs.
- `ui/contextual_navigation.gleam`
  - links a Plan, Kanban, Capacidades, Personas con scope.
- `ui/secondary_actions_menu.gleam`
  - acciones raras/peligrosas;
  - disabled reasons.

Estos nombres describen responsabilidades posibles. El goal puede resolverlas
reutilizando componentes existentes si el resultado queda mas simple, mas claro
y con menos codigo.

### Componentes Que Si Son Prioridad

Para evitar sobreingenieria, esta iteracion solo debe tratar como contratos
prioritarios:

1. **Tabs de entidad**
   - aspecto ligero, sin caja extra;
   - estado activo y foco visibles;
   - scroll horizontal en mobile;
   - labels tipados por Card Show y Task Show, no strings sueltos.

2. **Metric strip**
   - pares label/valor separados;
   - layout compacto;
   - sin concatenaciones visuales;
   - reutilizable por Card Show y, si encaja sin forzar, Task Show.

3. **Menu secundario**
   - acciones raras, destructivas o administrativas;
   - disabled reasons;
   - accesible por teclado;
   - reutilizar o mejorar `ui/action_menu.gleam` antes de crear otro menu.

Todo lo demas queda condicionado a duplicacion real. Si notas, actividad,
header o shell aun no tienen una API evidente, se dejan especificos y se
comparten clases/tokens menores.

### Reutilizacion Existente A Revisar Antes De Crear Componentes

El goal debe revisar primero estos componentes existentes:

- `ui/tabs.gleam`: ya tiene semantica de tablist y navegacion con teclado. La
  extraccion a `entity_tabs` debe reutilizar o envolver este componente, no
  reimplementar tabs desde cero.
- `ui/detail_tabs.gleam`: puede quedar como wrapper transitorio solo si se
  simplifica; si mantiene clases pesadas como `detail-tabs`, debe retirarse o
  reemplazarse.
- `ui/action_menu.gleam`: ya cubre menu secundario con disabled reasons. Antes
  de crear `secondary_actions_menu`, evaluar si basta con mejorar este
  componente y sus clases.
- `ui/note_content.gleam`: el problema de URLs duplicadas probablemente vive
  aqui; corregirlo en el renderer compartido evita arreglos por vista.
- `ui/activity_feed.gleam`: ya agrupa parte de la actividad. Reutilizarlo si
  puede alcanzar el lenguaje visual objetivo sin duplicar otro timeline.
- `features/layout/right_panel.gleam` y `ui/task_item.gleam`: revisar targets y
  labels antes de redisenar `Mis tareas` mobile.

### Limites Contra Sobreingenieria

No crear abstracciones genericas si solo una entidad las usa.

Regla:

- compartir tabs, metricas y acciones secundarias desde el inicio;
- compartir notas, actividad, navegacion contextual, shell o header solo si la
  duplicacion real y la API pequena quedan claras durante la implementacion;
- mantener especificos los cuerpos `CardSummary`, `CardWork`, `TaskDetails` y
  `TaskDependencies`;
- no crear un renderer generico de entidades que esconda la diferencia entre
  Card y Task;
- si `shell` o `header` compartidos obligan a pasar demasiados slots, callbacks
  o flags, mantenerlos especificos y compartir solo tokens/clases/componentes
  menores.
- si una extraccion obliga a introducir tipos genericos complejos, builders
  extensos o muchos parametros opcionales, abortar la extraccion y dejar el
  codigo especifico mas claro.

### Orden De Reutilizacion

Antes de escribir un modulo nuevo, el goal debe responder en el propio diff o
en notas de implementacion:

1. que componente existente se reviso;
2. por que no basta con corregirlo;
3. que responsabilidad concreta tendra el nuevo modulo;
4. que codigo quedara eliminado gracias a esa extraccion.

Si no hay codigo eliminado, menos duplicacion real o un contrato mas claro, no
extraer.

### Auditoria De Componentes Afectados

El goal debe hacer una pasada explicita por estos puntos antes de cerrar:

- `ui/tabs.gleam` y `ui/detail_tabs.gleam`: decidir si `detail_tabs` queda como
  wrapper ligero o si se elimina. No debe conservar padding/caja del patron
  anterior.
- `ui/action_menu.gleam`: comprobar que cubre menu secundario de Card y Task
  sin duplicar otro componente.
- `ui/note_content.gleam`: resolver deduplicacion de URLs y presentacion segura
  de HTML literal en el renderer compartido.
- `ui/activity_feed.gleam`: reutilizarlo o justificar por que no sirve para una
  actividad agrupada, densa y legible.
- `features/layout/right_panel.gleam` y `ui/task_item.gleam`: asegurar que el
  panel movil de `Mis tareas` conserva titulo real y targets claros.
- `client_update.gleam`, `client_view.gleam` y `url_state.gleam`: validar que
  apertura/cierre de shows queda centralizada y no dispersa en componentes de
  vista.

## Limpieza De Codigo

El goal debe revisar y eliminar:

- wrappers de tabs antiguos si solo sostienen el diseno anterior;
- clases CSS como `card-tabs`, `card-show-tabs`, `detail-tabs` si dejan de
  aportar semantica;
- modal/detalle viejo si el nuevo show lo sustituye;
- codigo de bridges o hosts que serialicen innecesariamente entidades si ya no
  hacen falta;
- tests que validen contratos visuales antiguos;
- labels internos filtrados a UI, como `domain_task.Task`;
- duplicacion entre Card Show y Task Show en notas, actividad, header y tabs;
- estilos de barra inferior con acciones destructivas siempre visibles.

No debe quedar compatibilidad temporal para dos sistemas de show.

## Tipado Y Estado

Mantener tabs como ADT cerrados:

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

Si se extrae una shell compartida, puede recibir una lista de tabs renderizadas,
pero el estado de cada show debe seguir tipado con su ADT especifico.

Modelar acciones primarias de Task Show segun estado:

```gleam
pub type TaskPrimaryAction {
  ClaimTask
  StartWorkSession
  CompleteTask
  NoPrimaryAction(reason: String)
}
```

`ReleaseClaim` no debe estar en `TaskPrimaryAction`: liberar es accion
secundaria. Si en el futuro se decide que liberar puede ser primaria en algun
contexto, debe cambiarse como decision explicita de producto y no como atajo de
implementacion.

Modelar acciones primarias de Card Show segun contenido:

```gleam
pub type CardPrimaryAction {
  AddTask
  AddSubcard
  ChooseCardContentKind
  NoCardPrimaryAction(reason: String)
}
```

`ChooseCardContentKind` representa card vacia: no decide por el usuario si la
card contendra tasks o subcards, sino que muestra dos acciones equilibradas.

Evitar bools como `can_delete`, `can_close`, `show_action` cuando el estado
necesita razon o variante.

## Tests

### Selectores Estables

Anadir `data-testid` solo en targets criticos para tests y `agent-browser`, sin
llenar el markup de ids innecesarios.

Selectores recomendados:

```text
data-testid="card-show"
data-testid="task-show"
data-testid="mobile-card-open"
data-testid="mobile-task-open"
data-testid="card-show-open"
data-testid="task-show-open"
data-testid="entity-show-close"
data-testid="entity-tabs"
data-testid="secondary-actions-menu"
```

Si ya existe una convencion equivalente en el proyecto, usar esa convencion en
lugar de inventar otra.

Reglas:

- el selector de apertura debe estar en el control accionable real, no solo en
  el contenedor;
- el selector del show debe estar en la superficie raiz visible;
- no anadir `data-testid` masivos a cada nodo interno si no son necesarios para
  validar comportamiento o accesibilidad.

### Tests De Vista

Incluir tests para:

- Card Show renderiza path, titulo, chips, descripcion y navegacion scoped;
- Card Show no concatena `Tareas0`, `Tareas completadas0` ni `Progreso0%`;
- Card Show renderiza metricas como nodos separados label/valor;
- Card Show muestra descripcion bajo label `Descripcion`;
- Task Show renderiza accion primaria segun estado;
- Task Show no muestra `Cerrar` y `Eliminar` como acciones primarias;
- Task Show muestra dependencia bloqueante cuando exista;
- Notas no duplican visualmente la misma URL;
- Activity renderiza eventos agrupados por fecha;
- tabs usan labels correctos e i18n;
- no aparece `domain_task.Task` ni otros nombres internos en UI.
- Card Show vacia muestra dos acciones equilibradas: anadir task y anadir
  subcard;
- Task Show distingue task reclamada de task en sesion de trabajo.

### Tests De Estado Y Update

Incluir tests para:

- cambiar tab de Card Show;
- cambiar tab de Task Show;
- abrir Card Show desde Plan;
- abrir Card Show desde Task Show;
- abrir Task Show desde Pool;
- parsear `show=card&show_card=...` sin activar `work_scope`;
- parsear `work_scope=card&card=...` sin abrir Card Show;
- parsear `show=task&task=...` y restaurar Task Show;
- serializar URL con scope y show sin colisionar ids;
- cerrar Card Show limpia solo el show, no el scope;
- cerrar Task Show limpia solo el show, no filtros ni scope;
- navegar desde Card Show a Plan/Kanban/Capacidades/Personas con scope card;
- acciones secundarias abren menu y respetan disabled reasons;
- abrir un show en mobile no deja overlays apilados.
- `Escape` cierra el show y devuelve foco al origen;
- tabs y menu secundario son navegables por teclado.

### Tests De Responsive / DOM

Cuando sea posible, anadir tests o validaciones que cubran:

- tabs mobile tienen scroll horizontal o no se comprimen;
- titulo de `Mis tareas` mobile aparece;
- botones `Abrir` y `Empezar` en mobile son targets diferenciados;
- no hay textos pegados por falta de spacing.
- `data-testid="card-show"` y `data-testid="task-show"` aparecen cuando el show
  correspondiente esta abierto.

## Validacion Con Agent Browser

El goal debe ejecutar una validacion visual y funcional con `agent-browser`.

### Desktop

1. Login con seed dev.
2. Abrir Pool.
3. Abrir Task Show desde una task disponible.
4. Validar header, chips, tabs, detalles, notas y actividad.
5. Abrir la card asociada desde Task Show.
6. Validar que Card Show reemplaza/navega correctamente, sin overlay apilado.
7. Desde Card Show abrir:
   - Plan scoped;
   - Kanban scoped;
   - Capacidades scoped;
   - Personas scoped.
8. Volver a Card Show y revisar tabs `Resumen`, `Trabajo`, `Notas`,
   `Actividad`.
9. Abrir Card Show desde Plan `Ver`.
10. Confirmar que no aparecen labels internos ni metricas rotas.

### Mobile

1. Viewport movil.
2. Abrir Pool.
3. Abrir Task Show.
4. Confirmar full-screen estable.
5. Confirmar tabs con scroll horizontal y sin truncado grave.
6. Confirmar que acciones destructivas estan en menu secundario.
7. Abrir Card Show desde Task Show.
8. Confirmar Card Show full-screen real.
9. Abrir panel `Mis tareas`.
10. Confirmar que muestra titulo real, `Abrir` y accion operativa.

### Casos De Datos

Las seeds o fixtures deben permitir validar:

- card con tasks;
- card con subcards;
- card sin contenido;
- card closed;
- task disponible;
- task reclamada por mi;
- task reclamada por otra persona;
- task en curso;
- task bloqueada;
- task vencida;
- task closed;
- task sin card;
- usuario sin permisos para una accion secundaria;
- loading state;
- error state recuperable;
- notas con URL estructurada;
- notas con URL duplicada en contenido;
- nota con HTML literal escapado;
- actividad con varios eventos;
- actividad vacia.

Si las seeds actuales no cubren estos casos, el goal debe actualizarlas o crear
fixtures especificos.

## Criterios De Aceptacion

La iteracion se considera terminada cuando:

1. Card Show y Task Show comparten gramatica visual con Pool, Plan,
   Capacidades y Personas.
2. Card Show mobile es full-screen real y no se confunde con Plan scoped.
3. Task Show mobile es full-screen real y mantiene accion primaria clara.
4. Las tabs parecen tabs, no botones grandes dentro de una caja innecesaria.
5. No existen textos pegados como `Tareas0` o `Progreso0%`.
6. Las descripciones tienen contexto.
7. Notas no duplican visualmente URLs identicas.
8. HTML literal en notas se mantiene seguro y no parece una rotura visual.
9. `Mis tareas` mobile muestra el titulo real de la task.
10. `Cerrar` y `Eliminar` no estan como acciones primarias visibles.
11. No aparecen nombres internos de tipos en UI.
12. La actividad es legible, agrupada y no cruda.
13. Claim, now working, release y complete no se mezclan conceptualmente.
14. Card vacia no fuerza una unica accion primaria arbitraria.
15. Foco, Escape, tabs y menu secundario son accesibles por teclado.
16. El codigo obsoleto del patron anterior se elimina.
17. Los tests cubren casos no happy path.
18. La validacion con `agent-browser` se ejecuta en desktop y mobile.
19. El goal termina con refactorizacion Gleam, limpieza y commit.

## Decisiones Cerradas Para Evitar Ambiguedad

- No usar `show=card&card=...` si existe la posibilidad de combinar scope y
  show. El plan usa `show_card` para mantener `card` como id del scope.
- No crear `entity_show_shell` ni `entity_show_header` como primer paso. Son
  candidatos, no requisitos. Primero estabilizar Card Show y Task Show.
- No convertir `Liberar` en accion primaria. La accion primaria representa el
  siguiente avance natural; liberar es una salida secundaria.
- No interpretar HTML en notas. El render debe seguir siendo seguro. La mejora
  consiste en presentarlo con contexto y evitar duplicados visuales, no en
  aceptar markup.
- No apilar Task Show y Card Show como overlays simultaneos. Al abrir una card
  desde Task Show, reemplazar el show o navegar a un estado claro.
- No mantener dos sistemas de show por compatibilidad temporal. Si el nuevo
  contrato sustituye al anterior, se retira el codigo obsoleto.
- No redisenar el sidebar derecho completo dentro de este goal. Solo corregir
  `Mis tareas` mobile cuando afecte a apertura/identidad de Task Show.

## Fronteras Con Otros Planes

Este plan debe ejecutarse sin invadir responsabilidades ya asignadas a otros
bloques.

- `docs/pool-work-surface-unification-plan.md`: define la unificacion de Pool.
  Este plan solo toca Pool cuando sea necesario para abrir Task Show, Card Show
  o conservar targets/labels de task. No debe redisenar filtros, ordenacion ni
  layout completo de Pool.
- `docs/fin_refactor.md`: define wizard, reglas/workflows y cierre final de
  refactor. Este plan puede mostrar actividad, notas, vencimientos y origen de
  workflow si los datos ya existen, pero no debe redisenar el motor de reglas.
- `docs/card-task-show-redesign-plan.md`: queda como origen conceptual. Este
  documento manda sobre la correccion actual si hay conflicto entre ambos.
- Vistas Plan/Kanban/Capacidades/Personas: Card Show debe enlazar a ellas con
  scope card, no reimplementar sus cuerpos.

Regla: si durante la implementacion aparece una mejora interesante pero no
afecta a apertura/show, tabs, resumen, notas, actividad, acciones o mobile
`Mis tareas`, debe anotarse fuera del diff o dejarse para el plan que
corresponda.

## Orden De Ejecucion Recomendado

1. **Preflight de realidad actual**
   - Ejecutar una pasada corta con `agent-browser` en desktop y mobile antes de
     tocar codigo.
   - Registrar capturas o notas concretas de Card Show mobile, Task Show
     mobile, tabs actuales, resumen de card y `Mis tareas` mobile.
   - Revisar los componentes existentes candidatos a reutilizacion.

   Gate de salida:
   - el goal sabe si corrige un bug existente o una regresion nueva;
   - quedan identificadas las rutas reales por las que se abren Card Show y
     Task Show;
   - se confirma que el trabajo no debe ampliar el alcance al sidebar derecho
     completo.

2. **Congelar comportamiento esperado**
   - Convertir este documento en checklist del goal.
   - Identificar rutas actuales de Card Show y Task Show.
   - Identificar componentes existentes reutilizables.

   Gate de salida:
   - se entiende que componentes actuales se reutilizaran;
   - se identifica que codigo antiguo quedara eliminado;
   - no hay nuevas abstracciones propuestas sin codigo duplicado real.

3. **Corregir arquitectura de navegacion**
   - Separar show de entidad y scope de vista.
   - Definir URL/estado de show.
   - Definir comportamiento desktop/mobile.
   - Evitar overlays apilados.

   Gate de salida:
   - tests de parseo/serializacion de URL verdes;
   - tests de update/apertura/cierre verdes;
   - `work_scope=card&card=...` no abre show;
   - deep-link de Card Show y Task Show restaura el show correcto.

4. **Resolver componentes minimos**
   - tabs ligeras, reutilizando `ui/tabs.gleam` si encaja;
   - metric strip label/valor;
   - menu secundario, reutilizando `ui/action_menu.gleam` si encaja.
   - Posponer shell/header compartidos salvo API evidente.
   - Layout responsive.

   Gate de salida:
   - no quedan tabs con apariencia de botones pesados;
   - no se introduce `entity_show_shell` sin API pequena;
   - el diff elimina o simplifica estilos/componentes anteriores.

5. **Rehacer Card Show**
   - Header.
   - Resumen maquetado.
   - Trabajo.
   - Notas.
   - Actividad.
   - Navegacion scoped.

   Gate de salida:
   - Card Show empty ofrece `Anadir task` y `Anadir subcard`;
   - metricas no se concatenan;
   - descripcion tiene seccion y contexto;
   - navegacion a Plan/Kanban/Capacidades/Personas scoped funciona.

6. **Rehacer Task Show**
   - Header operativo.
   - Accion primaria por estado.
   - Detalles.
   - Dependencias.
   - Notas.
   - Actividad.

   Gate de salida:
   - disponible -> reclamar;
   - reclamada por mi -> empezar;
   - en curso por mi -> completar;
   - reclamada por otro/bloqueada/closed -> sin primaria imposible;
   - liberar/cerrar/eliminar no aparecen como acciones primarias visibles.

7. **Corregir mobile `Mis tareas`**
   - Titulo real.
   - Targets claros.
   - No cerrar panel por error.

   Gate de salida:
   - el control accionable tiene `data-testid="mobile-task-open"`;
   - abrir Task Show desde mobile no cierra accidentalmente el panel;
   - Card Show y Task Show se comportan como full-screen en mobile.

8. **Eliminar legacy**
   - Clases, componentes, hosts, modales, tests y helpers obsoletos.

   Gate de salida:
   - no quedan clases o wrappers que solo sostengan el patron visual anterior;
   - no quedan tests que afiancen el layout antiguo;
   - no hay compatibilidad temporal de dos sistemas de show.

9. **Tests**
   - Vista.
   - Update.
   - Estados edge.
   - i18n.
   - Accesibilidad/teclado.
   - Selectores estables.

10. **Agent-browser**
   - Desktop.
   - Mobile.
   - Capturas.
   - Correcciones iterativas.

11. **Refactor final**
    - Pasar `gleam-refactor`.
    - Eliminar sobreingenieria.
    - Repetir tests, incluyendo `gleam test --target erlang` y
      `gleam test --target javascript` cuando apliquen al paquete tocado.
    - Commit.

### Evidencia Obligatoria Por Slice

Cada slice debe dejar evidencia concreta antes de pasar al siguiente:

| Slice | Evidencia minima |
| --- | --- |
| Navegacion/URL | tests de parseo/serializacion; tests de abrir/cerrar; URL con scope + show sin colision |
| Componentes minimos | tests o snapshots HTML de tabs, metric strip y menu secundario; eliminacion o simplificacion de estilos viejos |
| Card Show | tests de empty card, metricas, descripcion, trabajo, navegacion scoped y mobile show |
| Task Show | tests de accion primaria por estado, release secundario, bloqueos, dependencias, notas y actividad |
| Mobile `Mis tareas` | test/validacion de titulo real, targets `Abrir`/accion y no cierre accidental |
| Limpieza | `rg` sobre clases/componentes legacy; eliminacion de tests que afiancen el patron viejo |
| Agent-browser | notas o capturas desktop/mobile; defectos corregidos y revalidados |

No basta con que compile: si un slice cambia una superficie visual, debe quedar
validado por test de HTML/estado y por una comprobacion visual cuando aplique.

### Auditoria Final De Homogeneidad

Antes de ejecutar `gleam-refactor` y comitear, el goal debe hacer una auditoria
manual contra el resto de superficies redisenadas.

Comparar Card Show y Task Show con:

- Pool;
- Plan;
- Kanban;
- Capacidades;
- Personas;
- sidebar derecho / `Mis tareas`.

Comprobar especificamente:

- los headers no tienen jerarquia mayor que una vista principal;
- las tabs tienen el mismo peso visual y comportamiento que el resto de
  navegacion interna;
- los chips usan la misma gramatica de estado;
- las acciones primarias/secundarias siguen el mismo patron de botones y menu
  `...`;
- no hay cards dentro de cards salvo items repetidos o empty states reales;
- la densidad es operativa, no editorial;
- las metricas no parecen dashboard decorativo;
- mobile usa full-screen/sheet de forma coherente con el shell actual;
- ningun texto interno de tipo, seed o fixture se filtra como copy de producto.

Si esta auditoria detecta que Card Show o Task Show parecen una superficie de
otra aplicacion, el goal debe corregir el lenguaje visual antes de cerrar.

### Auditoria Final De Codigo

El goal debe cerrar con una pasada explicita de codigo antes del commit.

Busqueda minima:

```text
rg "card-tabs|task-tabs|detail-tabs|domain_task.Task|Tareas0|Progreso0"
rg "work_scope=card"
rg "show_card|ShowParam|TaskShowParam|CardShowParam"
rg "ReleaseClaim|StartWorkSession|CompleteTask"
```

La busqueda no implica borrar todo resultado: `work_scope=card` y los ADT
deben existir donde corresponda. El objetivo es detectar:

- CSS o wrappers que solo mantengan el patron viejo;
- strings internos filtrados a UI;
- tests que afiancen la UI anterior;
- serializacion de URL ambigua;
- acciones primarias mal modeladas;
- duplicacion innecesaria entre Card Show y Task Show.

Si aparece codigo muerto, compatibilidad temporal o componentes que ya no se
usan tras el redisenio, se eliminan en el mismo goal. No se deja una fase
posterior de limpieza para este bloque.

### Condiciones De Parada

El goal debe detenerse y corregir antes de avanzar si ocurre cualquiera de
estos puntos:

- `work_scope=card&card=...` abre Card Show;
- `show=card&show_card=...` cambia el scope principal;
- Card Show mobile no abre full-screen;
- Task Show mobile se cierra al intentar abrir una task desde `Mis tareas`;
- tabs vuelven a renderizarse como botones pesados dentro de una caja;
- una accion destructiva aparece como accion primaria;
- el nuevo componente compartido necesita flags o callbacks especificos de Card
  y Task para casi todo;
- aparece codigo legacy para mantener simultaneamente dos contratos de show.

## Prompt Sugerido Para El Goal

```text
Crea y ejecuta un goal para implementar al completo
docs/card-task-show-ui-correction-plan.md.

Objetivo:
- redisenar Card Show y Task Show para que compartan el lenguaje visual de
  Pool, Plan, Capacidades y Personas;
- separar de forma explicita scope de vista y show de entidad, definiendo el
  estado/URL correspondiente; usa `work_scope=card&card=...` para scope y
  `show=card&show_card=...` / `show=task&task=...` para shows, evitando que
  `card` tenga dos significados simultaneos;
- corregir el comportamiento mobile para que los shows sean full-screen reales;
- redisenar tabs, resumen, notas, actividad, acciones primarias/secundarias y
  navegacion scoped;
- corregir defectos visibles como Tareas0/Progreso0%, URLs duplicadas,
  domain_task.Task en UI, HTML literal mal presentado y perdida de identidad en
  Mis tareas mobile;
- distinguir correctamente task reclamada, sesion de trabajo, liberar y
  completar;
- asegurar accesibilidad de foco, Escape, tabs y menus secundarios;
- eliminar todo codigo, CSS, tests o componentes obsoletos del patron anterior;
- mantener tipado Gleam con ADT y evitar bools ambiguos;
- no introducir compatibilidad legacy ni sobreingenieria.

Proceso:
1. Antes de tocar codigo, revisa el documento completo y ejecuta un preflight
   con agent-browser en desktop y mobile para capturar el estado real de Card
   Show, Task Show, tabs, resumen de card y Mis tareas mobile.
2. Trata Card Show mobile como P0: si no abre como full-screen real desde Ver,
   la iteracion no puede darse por finalizada.
3. Implementa por slices pequenos siguiendo los gates del documento:
   preflight, navegacion/URL, componentes minimos, Card Show, Task Show, mobile
   Mis tareas, limpieza.
4. En cada slice, anade o actualiza tests antes de cerrar el cambio.
5. Reutiliza componentes existentes cuando encajen. Resuelve de forma segura
   tabs ligeras, metric strip label/valor y menu secundario, pero no crees
   modulos nuevos solo por nombre si `ui/tabs.gleam`, `ui/detail_tabs.gleam`,
   `ui/action_menu.gleam` u otro componente existente pueden cubrir la
   responsabilidad con una API pequena. Extrae notes, activity,
   contextual_navigation, shell o header solo si la duplicacion real y la API
   pequena son evidentes.
6. Antes de crear componentes nuevos, revisa `ui/tabs.gleam`,
   `ui/detail_tabs.gleam`, `ui/action_menu.gleam`, `ui/note_content.gleam`,
   `ui/activity_feed.gleam`, `features/layout/right_panel.gleam` y
   `ui/task_item.gleam` para decidir si basta con mejorar o envolver lo
   existente.
7. No generalices cuerpos especificos de Card y Task si eso oculta su mision.
   Una card vacia debe ofrecer anadir task y anadir subcard como opciones
   equilibradas, no una primaria arbitraria.
8. No hagas de `ReleaseClaim` una accion primaria de Task Show. Liberar va al
   menu secundario salvo decision explicita posterior.
9. Mantén separados en tipos, update, UI y tests: task disponible, reclamada,
   now working/en curso, liberar, completar y closed. No los colapses en bools.
10. Los selectores estables deben estar en targets reales:
   `card-show`, `task-show`, `mobile-card-open`, `mobile-task-open`,
   `card-show-open`, `task-show-open`, `entity-show-close`, `entity-tabs` y
   `secondary-actions-menu`, usando convenciones existentes si las hay.
11. Respeta las fronteras con otros planes: no redisenes Pool completo, no
   rehagas workflows/reglas y no dupliques Plan/Kanban/Capacidades/Personas
   dentro de Card Show. Solo toca esas superficies cuando sea necesario para
   abrir shows, navegar con scope o corregir targets/labels relacionados.
12. Deja evidencia por slice: tests de URL/update, tests de componentes,
   validaciones de HTML/DOM, limpieza por `rg` de legacy y notas/capturas de
   agent-browser cuando haya cambio visual.
13. Respeta las condiciones de parada del documento. Si una condicion falla,
   corrige antes de avanzar a otro slice.
14. Antes del refactor final, ejecuta la auditoria de homogeneidad contra Pool,
   Plan, Kanban, Capacidades, Personas y sidebar derecho. Corrige cualquier
   diferencia de lenguaje visual que haga que Card Show o Task Show parezcan
   superficies ajenas al producto.
15. Ejecuta la auditoria final de codigo indicada en el documento. Usa `rg`
   para localizar clases, labels, tests, URL handling y acciones obsoletas o
   ambiguas. Elimina todo codigo innecesario, duplicado, legacy o de
   compatibilidad temporal que haya quedado tras el cambio.
16. Al finalizar, pasa la skill gleam-refactor, elimina sobreingenieria y
   vuelve a ejecutar tests.
17. Disena y ejecuta casos de uso con agent-browser para desktop y mobile,
   incluyendo abrir tasks/cards desde Pool y Plan, navegar a vistas scoped,
   revisar tabs, notas, actividad, acciones secundarias, bloqueos,
   vencimientos, card vacia, task sin card, task closed y card closed.
18. Corrige todos los defectos encontrados y repite la validacion hasta que no
   queden problemas visibles o funcionales.
19. Ejecuta tests relevantes y, antes del commit, la suite completa en los
   targets aplicables.
20. Comitea el resultado final.
```
