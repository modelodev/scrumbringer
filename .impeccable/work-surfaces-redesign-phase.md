# Fase de rediseño: superficies de trabajo

Fecha: 2026-06-11

Estado: Fases 1-5 implementadas y verificadas.

## Objetivo

Convertir las vistas de trabajo de ScrumBringer en un sistema coherente de lentes operativas. Cada vista debe responder a una pregunta distinta sin competir con el Pool ni convertir el producto en una herramienta de asignación push.

La regla central de producto es:

- Pool decide la próxima acción personal.
- Kanban explica avance y salud de cards.
- Capacidades muestra demanda y presión por skill.
- Personas muestra distribución de carga.
- Hitos muestra estructura de objetivo.

## Decisiones confirmadas

- Nombre visible: mantener `Kanban`.
- Concepto interno: kanban de cards, no kanban de tasks.
- Audiencia: todas las vistas sirven a developer, tech lead y scrum master/PM, pero con distinto énfasis.
- Alcance: production-ready por fases.
- Registro visual: producto restringido, operativo y denso; sin decoración ni dashboard ornamental.

## Principios de diseño

1. El Pool no se duplica.
   Las vistas contextuales pueden mostrar tasks y permitir acciones, pero no deben reemplazar el flujo principal de reclamar trabajo.

2. La acción primaria depende de la vista.
   En Pool es reclamar. En Kanban es entender avance de card. En Capacidades es detectar presión. En Personas es entender carga. En Hitos es estructurar entrega.

3. Estado y ownership usan una gramática común.
   Las tasks deben mantener vocabulario consistente: disponible, reclamada, en curso, bloqueada, completada, próxima acción y card de origen.

4. Las cards son contexto de flujo.
   El color de card identifica contexto; no debe confundirse con estado, urgencia o ownership.

5. Las vistas no deben sonar a asignación manual.
   Especialmente Personas y Capacidades deben evitar copy o affordances que sugieran "asignar esta tarea a alguien".

## Fase 1: Kanban

Pregunta principal: que cards estan pendientes, activas o cerradas, y donde hay friccion.

Cambios concretos:

- Mantener la navegacion como `Kanban`.
- Añadir header de superficie con titulo, proposito breve y resumen operativo.
- Usar columnas horizontales reales en desktop: `Pendiente`, `En curso`, `Cerrada`.
- Hacer que cada card muestre una lectura compacta de salud:
  - color/swatch de identidad de card;
  - progreso `x/y`;
  - tasks disponibles;
  - tasks reclamadas;
  - tasks en curso;
  - tasks bloqueadas o stale cuando aplique;
  - proximas 2-3 tasks relevantes.
- Reducir dominancia de acciones de editar/borrar card.
- Mantener crear task en card como accion contextual secundaria.
- Empty states por columna con copy util: no solo "sin tarjetas".
- Mobile: columnas apiladas o selector por columna; nunca tres columnas comprimidas.

Criterios de aceptacion:

- Kanban se lee como tablero de cards, no como lista vertical.
- No compite con Pool como lugar principal para elegir trabajo.
- La primera lectura permite detectar cards paradas, bloqueadas o activas.
- Las cards usan la misma mini-gramatica que Hitos.
- Desktop y mobile no presentan overflow ni columnas ilegibles.

Estado de implementacion, 2026-06-11:

- Aplicada en `features/views/kanban_board.gleam`, `ui/card_with_tasks_surface.gleam`, `ui/card_with_tasks_preview.gleam`, `styles/layout.gleam`, `client_update.gleam`, `client_view.gleam` e i18n.
- Kanban incorpora header de superficie, proposito breve y summary chips operativos.
- Las columnas desktop se mantienen como tablero de tres carriles y en mobile se apilan sin comprimir.
- Las cards muestran identidad por color, progreso, salud de tasks y proximas tasks relevantes.
- Editar/borrar bajan de dominancia y crear task se conserva como accion contextual de card.
- Mobile conserva `/app/pool?view=cards` como Kanban en vez de redirigirlo a MyBar.
- Verificado con `gleam check`, `gleam test` de cliente, detector impeccable limpio y capturas desktop/mobile.

Comando sugerido:

```bash
$impeccable layout apps/client/src/scrumbringer_client/features/views/kanban_board.gleam Implementa Fase 1: Kanban como tablero production-ready de cards, manteniendo el nombre visible Kanban y reforzando señales de pull-flow sin convertirlo en kanban de tasks.
```

## Fase 2: Capacidades

Pregunta principal: donde hay demanda por skill y donde falta traccion.

Cambios concretos:

- Mantener filas por capacidad: Operations, Product, Security, etc.
- Reforzar encabezado de cada capacidad con resumen visible:
  - disponibles;
  - reclamadas;
  - en curso;
  - bloqueadas;
  - antiguedad o stale si existe.
- Ordenar primero las capacidades con mas presion operativa:
  - disponibles sin en curso;
  - bloqueadas;
  - muchas reclamadas y pocas activas;
  - tasks antiguas.
- Mantener claim disponible pero menos dominante que en Pool.
- Diferenciar visualmente esta vista de Kanban: debe leerse como mapa de demanda por skill, no como otro tablero generico.
- Evitar side stripes nuevos; usar chips, contadores y acentos internos controlados.

Criterios de aceptacion:

- La vista responde rapidamente que capacidad necesita atencion.
- Las columnas internas se entienden como estados dentro de una skill, no como Kanban duplicado.
- Claim sigue accesible sin ser la accion principal visual.
- El orden de filas ayuda a priorizar revision.

Estado de implementacion, 2026-06-11:

- Aplicada en `features/capability_board/view.gleam`, `styles/layout.gleam`, i18n y tests de `capability_board_view_test.gleam`.
- Las filas por capacidad muestran resumen de disponibles, reclamadas, en curso, bloqueadas y antiguedad.
- Las capacidades se ordenan por presion operativa: bloqueos, disponibles/reclamadas sin traccion, reclamadas sin suficientes activas y antiguedad.
- Las columnas internas se sustituyen visualmente por grupos compactos de demanda, sin reutilizar el patron Kanban.
- Claim sigue disponible en tareas disponibles, pero con peso visual mas bajo que en Pool.
- Verificado con `gleam check`, `gleam test` de cliente, detector impeccable limpio y capturas desktop/mobile.

Comando sugerido:

```bash
$impeccable layout apps/client/src/scrumbringer_client/features/capability_board Implementa Fase 2: Capacidades como mapa de demanda por skill, con resumen por capacidad y orden por presion operativa.
```

## Fase 3: Personas

Pregunta principal: como esta distribuida la carga del equipo.

Cambios concretos:

- Añadir header de superficie con resumen:
  - personas libres;
  - ocupadas;
  - trabajando ahora;
  - reclamadas totales.
- Cada fila de persona debe mostrar sin expandir:
  - estado;
  - numero de tasks en curso;
  - numero de tasks reclamadas;
  - cards implicadas;
  - senal de carga si hay demasiadas reclamadas.
- Al expandir, separar claramente:
  - En curso;
  - Reclamadas;
  - agrupacion por card cuando aporte lectura.
- Mantener los links a tareas, pero no mostrar acciones que parezcan asignacion.
- Mejorar empty states: libre no es error; debe leerse como capacidad disponible.

Criterios de aceptacion:

- Sin expandir ya se entiende quien esta libre, ocupado o trabajando.
- La vista no sugiere que el lead debe repartir tareas.
- Las tareas conservan contexto de card y estado.
- La busqueda sigue siendo simple y rapida.

Estado de implementacion, 2026-06-11:

- Aplicada en `features/people/view.gleam`, `styles/layout.gleam`, i18n y tests de `people_view_test.gleam`.
- Personas incorpora header de superficie con proposito breve y summary chips de libres, ocupadas, trabajando ahora y reclamadas totales.
- Cada fila muestra en colapsado estado, tareas en curso, tareas reclamadas, cards implicadas y aviso de carga cuando hay demasiadas reclamadas.
- La expansion separa `Active`/`Claimed`, muestra tareas en lista plana y conserva estado de task e identidad de card mediante swatch accesible.
- No se introducen acciones de asignacion; las tareas siguen siendo links de inspeccion.
- Los estados vacios de personas libres se muestran como capacidad disponible, no como error.
- Verificado con `gleam check`, `gleam test` de cliente, detector impeccable limpio y capturas desktop/mobile.

Comando sugerido:

```bash
$impeccable layout apps/client/src/scrumbringer_client/features/people Implementa Fase 3: Personas como balance de carga del equipo, sin patrones de asignacion manual.
```

## Fase 4: Hitos

Pregunta principal: hacia que objetivo se organiza el trabajo.

Cambios concretos:

- Mantener master-detail actual.
- Reforzar resumen del hito:
  - progreso;
  - cards totales;
  - tasks en cards;
  - tasks sueltas;
  - bloqueos;
  - cards vacias.
- Alinear cards internas con la mini-gramatica de Kanban.
- Hacer que tareas sueltas se perciban como problema estructural a resolver.
- Mantener acciones de crear/mover/editar, pero por debajo del estado del hito.

Criterios de aceptacion:

- Hitos explica estructura y salud de entrega, no solo una lista de milestones.
- Las cards dentro del hito se leen igual que en Kanban.
- Las tareas sueltas tienen una llamada clara sin ser alarmismo.
- El master-detail sigue siendo usable en desktop y mobile.

Estado de implementacion, 2026-06-11:

- Aplicada en `features/milestones`, `ui/card_with_tasks_preview.gleam`, `styles/layout.gleam` y tests de Hitos.
- El detalle mantiene master-detail y refuerza una banda de resumen visible con progreso, cards, tasks en cards, tasks sueltas, bloqueos y cards vacias.
- Las acciones de hito quedan por debajo de estado, descripcion, resumen y progreso para no competir con la lectura de salud.
- Las cards internas reutilizan la mini-gramatica de Kanban mediante `card_with_tasks_preview` y chips de salud por disponibles, reclamadas, en curso y bloqueadas.
- Las tareas sueltas se presentan como trabajo estructural pendiente de agrupar, con una llamada visible sin convertirlo en alarma.
- Verificado con `gleam check`, `gleam test` de cliente, detector impeccable limpio y capturas desktop/mobile.

Comando sugerido:

```bash
$impeccable polish apps/client/src/scrumbringer_client/features/milestones Implementa Fase 4: alinear Hitos con la gramatica de Kanban y reforzar resumen estructural.
```

## Fase 5: Contrato comun de superficies

Objetivo: formalizar un patron comun para todas las vistas de trabajo.

Contrato propuesto:

- titulo de superficie;
- proposito breve;
- summary chips operativos;
- filtros;
- accion contextual primaria cuando exista;
- contenido principal;
- estados loading, empty, no-results y error con copy especifico.

Superficies afectadas:

- Pool;
- Kanban;
- Capacidades;
- Personas;
- Hitos.

Criterios de aceptacion:

- Las cinco vistas parecen partes del mismo cockpit.
- Los filtros no compiten con el titulo ni con la accion contextual.
- Cada vista declara su pregunta principal sin meter texto explicativo largo.
- La implementacion reduce duplicacion y conserva patrones existentes.

Estado de implementacion, 2026-06-11:

- Aplicada mediante `features/layout/work_surface.gleam` como contrato comun de header de superficie.
- Pool, Kanban, Capacidades, Personas e Hitos usan el mismo patron de titulo, proposito breve, summary chips, acciones contextuales y contenido principal.
- Pool conserva la accion contextual `Nueva tarea`, mantiene Canvas/List y resume vista activa y disponibles.
- Kanban conserva su lectura de cards por estado y reutiliza el summary operativo comun sin convertirse en Pool.
- Capacidades, Personas e Hitos conservan su pregunta propia y reducen duplicacion de header/summary local.
- Los estados loading, empty, no-results y error existentes se mantienen con copy especifico por superficie.
- Tests de contrato y vistas actualizados para cubrir el componente comun y evitar aserciones fragiles de texto global.
- Verificado con `gleam check`, `gleam test` de cliente, detector impeccable limpio y capturas browser desktop/mobile.

Comando sugerido:

```bash
$impeccable extract apps/client/src/scrumbringer_client/features/layout apps/client/src/scrumbringer_client/features/pool apps/client/src/scrumbringer_client/features/views apps/client/src/scrumbringer_client/features/capability_board apps/client/src/scrumbringer_client/features/people apps/client/src/scrumbringer_client/features/milestones Implementa Fase 5: contrato comun work_surface para vistas de trabajo.
```

## Validacion por fase

Cada fase debe cerrar con:

- `gleam check` en `apps/client`;
- `gleam test` en `apps/client`;
- detector impeccable sobre los ficheros tocados;
- capturas browser desktop 1440x900;
- capturas mobile 390x844 y, cuando haya columnas, 320x720;
- revision de que no se rompen Pool, right panel ni navegacion lateral.

## Riesgos

- Convertir Kanban en otro Pool.
- Hacer Personas demasiado manager-centric.
- Hacer Capacidades demasiado parecida a Kanban.
- Sobrecargar cards con contadores hasta perder escaneo.
- Introducir copy explicativo largo dentro de una herramienta operativa.
- Resolver cada fase con estilos locales sin extraer contrato comun.

## No objetivos

- No redisenar admin en esta fase.
- No cambiar reglas backend de workflow.
- No introducir drag-and-drop nuevo salvo que ya exista en la superficie.
- No eliminar el Pool canvas/list actual.
- No convertir la UI en un dashboard decorativo.
