# Plan de unificacion visual de metricas y estados de tareas

## Contexto

En varias superficies del producto se muestran contadores y estados de tareas con lenguajes visuales distintos. Algunas vistas usan chips de texto con color, otras usan iconos parciales, otras usan abreviaturas compactas y alguna todavia usa simbolos manuales.

Las metricas afectadas son:

- tareas totales;
- disponibles;
- reclamadas;
- en curso;
- cerradas;
- bloqueadas.

El problema no es solo estetico. La misma informacion aparece implementada con componentes distintos (`work_surface.summary_chip`, `signal_chip.metric_int`, `workload_breakdown`, spans locales de estado), lo que dificulta mantener consistencia visual, reutilizar tests y evolucionar accesibilidad.

## Objetivo

Unificar el lenguaje visual de las metricas y estados de tareas con una API semantica unica, reutilizable y testeable.

Despues de la migracion, una persona debe reconocer el mismo significado por el mismo icono, tono, etiqueta y tooltip en cualquier vista del producto.

La solucion debe mejorar:

- lenguaje visual unificado;
- base de codigo mas DRY;
- testeabilidad mediante componentes comunes;
- accesibilidad en escritorio, movil y lectores de pantalla;
- limpieza de codigo local que quede obsoleto.

## Inventario actual

### Encabezados de superficies de trabajo

Usan `work_surface.summary_chip`, que renderiza texto + numero + tono mediante `signal_chip`, sin icono.

- Pool: `apps/client/src/scrumbringer_client/features/pool/view.gleam`
- Plan: `apps/client/src/scrumbringer_client/features/plan/structure_view.gleam`
- Kanban: `apps/client/src/scrumbringer_client/features/views/kanban_board.gleam`
- Capacidades: `apps/client/src/scrumbringer_client/features/capability_board/view.gleam`
- Personas: `apps/client/src/scrumbringer_client/features/people/view.gleam`
- Consola de automatizaciones: usa el mismo componente, pero sus metricas no son estados de tareas y no entran en el nucleo de esta migracion.

Codigo base:

- `features/layout/work_surface.gleam`
- `ui/signal_chip.gleam`

### Chips locales de health en Kanban

Kanban usa un helper local `view_health_chip` que vuelve a montar `signal_chip.metric_int` con clases propias:

- `features/views/kanban_board.gleam`
- clases CSS: `kanban-health-chip`, `kanban-health-value`, `kanban-health-label`

Esto duplica el patron de chip operativo.

### Chips locales en Capacidades

La vista de Capacidades define otro helper local `view_summary_chip` para:

- totales, cerradas y bloqueadas por seccion;
- disponibles, reclamadas y en curso por bloque;
- totales de matriz.

Codigo afectado:

- `features/capability_board/view.gleam`
- clases CSS: `capability-summary-chip`, `capability-summary-value`, `capability-summary-label`

Esta es la superficie mas visible del problema porque mezcla badges de texto con otros marcadores visuales dentro de bloques densos.

### Breakdown compacto de Capacidades

`ui/workload_breakdown.gleam` renderiza `valor + etiqueta compacta` y se usa desde Capacidades.

Codigo afectado:

- `ui/workload_breakdown.gleam`
- `features/capability_board/view.gleam`
- test: `apps/client/test/ui_workload_breakdown_test.gleam`

Es el caso mas divergente: no usa iconos y depende de abreviaturas.

### Estados inline de task

Varias filas de task muestran estados con texto local:

- `ui/card_with_tasks_surface.gleam`
- `features/views/grouped_list.gleam`
- `features/capability_board/view.gleam`
- `features/people/view.gleam`
- `features/plan/structure_view.gleam`

Tambien existen iconos parciales para reclamadas/en curso mediante:

- `ui/task_status_utils.gleam`
- clase CSS `task-claimed-icon`

La informacion equivalente aparece como texto, icono parcial o nada segun la vista.

### Iconos existentes no unificados

Ya hay iconos utiles en `ui/icons.gleam`:

- `List`
- `InboxEmpty`
- `HandRaised`
- `ClipboardDoc`
- `CheckCircle`
- `Warning`
- `Pause`
- `Play`

Otros puntos ya iconifican parcialmente estados:

- `ui/task_blocked_badge.gleam`: bloqueos con `Warning`;
- `features/pool/task_dependencies.gleam`: dependencias con `CheckCircle` / `Warning`;
- `features/cards/show.gleam`: estado con simbolos Unicode manuales.

## Decision de interfaz

Usar una gramatica visual comun basada en:

- icono;
- numero;
- etiqueta visible cuando haya espacio;
- tooltip en hover/focus;
- `aria-label` equivalente;
- tono cromatico consistente.

No usar iconos como unica fuente semantica. El color tampoco debe ser la unica pista.

### Variantes de render

Definir dos variantes, no una casuistica por vista:

```text
Full    -> icono + numero + etiqueta visible
Compact -> icono + numero, con title/aria-label
```

Uso recomendado:

- `Full`: encabezados de superficies y zonas con espacio suficiente.
- `Compact`: bloques densos de Capacidades, breakdowns y health chips dentro de tarjetas.

### Hover, focus y accesibilidad

Los iconos y chips deben tener hover/focus, pero el hover no debe ser la unica forma de entender la informacion.

Reglas:

- Todo chip compacto debe tener `title` y `aria-label`, por ejemplo `Disponibles: 4`.
- Todo chip completo puede tener el mismo `title` por consistencia.
- Si el chip es interactivo en el futuro, usar `button`; si solo informa, usar `span`.
- El foco visible debe existir cuando el elemento sea focusable.
- En movil, la informacion esencial debe seguir estando disponible sin depender de hover.

### Mapeo visual canonico

El mapeo debe vivir en codigo comun, no repetirse por vista.

```text
Total       -> List o ClipboardDoc -> Neutral
Available   -> InboxEmpty o HandRaised -> Available
Claimed     -> ClipboardDoc o Pause -> Claimed
Ongoing     -> Play -> Ongoing
Closed      -> CheckCircle -> Success/Neutral segun contexto
Blocked     -> Warning -> Blocked
```

Decision recomendada:

- `Total`: `List`
- `Available`: `InboxEmpty`
- `Claimed`: `ClipboardDoc`
- `Ongoing`: `Play`
- `Closed`: `CheckCircle`
- `Blocked`: `Warning`

No usar `Pause` para reclamadas como icono canonico de metrica: comunica pausa, no reserva. Puede seguir usandose en estados inline si el estado real es `Taken` y se quiere distinguirlo de `Ongoing`.

## Diseño tecnico

### Nuevo modulo semantico

Crear:

```text
apps/client/src/scrumbringer_client/ui/task_metric.gleam
```

Responsabilidades:

- Definir el ADT de metrica.
- Resolver icono, tono, label y tooltip.
- Centralizar las decisiones de i18n.
- Exponer helpers puros testeables.

API orientativa:

```gleam
pub type TaskMetricKind {
  Total
  Available
  Claimed
  Ongoing
  Closed
  Blocked
}

pub type TaskMetric {
  TaskMetric(kind: TaskMetricKind, value: Int)
}
```

Funciones recomendadas:

- `label(locale, kind) -> String`
- `icon(kind) -> icons.NavIcon`
- `tone(kind) -> tone.Tone`
- `title(locale, metric) -> String`
- `testid(kind) -> String`

### Nuevo componente de chip

Crear:

```text
apps/client/src/scrumbringer_client/ui/task_metric_chip.gleam
```

Responsabilidades:

- Renderizar `Full` y `Compact`.
- Usar `task_metric` para semantica.
- Renderizar icono desde `ui/icons.gleam`.
- Mantener `title` y `aria-label`.
- Permitir clases extra solo para layout, no para redefinir semantica.

API orientativa:

```gleam
pub type Variant {
  Full
  Compact
}

pub type Config {
  Config(
    locale: Locale,
    metric: task_metric.TaskMetric,
    variant: Variant,
    extra_class: Option(String),
    testid: Option(String),
  )
}
```

No crear un sistema generico de icon chips. Este componente es de producto y resuelve solo metricas de tareas.

### Relacion con `signal_chip`

`signal_chip` ya es una primitiva util. No debe convertirse en un componente de producto.

Decision:

- mantener `signal_chip` para chips genericos;
- implementar `task_metric_chip` encima de primitivas HTML/iconos y, si encaja sin forzar API, reutilizar partes visuales de `signal_chip`;
- no anadir `TaskMetricKind` a `signal_chip`.

Esto evita mezclar semantica de tareas con una utilidad general usada tambien por automatizaciones u otras areas.

### Relacion con `work_surface.summary_chip`

Evolucionar `work_surface.SummaryChip` para poder aceptar metricas de tarea cuando aplique.

Opcion recomendada:

```gleam
pub type SummaryChip {
  SummaryChip(label: String, value: String, tone: tone.Tone)
  TaskSummaryChip(metric: task_metric.TaskMetric)
}
```

`SummaryChip` existente se mantiene para metricas no relacionadas con tareas, como automatizaciones o limites.

El render de `TaskSummaryChip` debe usar `task_metric_chip.Full`.

## Paquetes de trabajo

### Paquete 1: Nucleo semantico y componente compartido

Objetivo:

- Introducir `task_metric` y `task_metric_chip`.

Tareas:

- Crear `ui/task_metric.gleam`.
- Crear `ui/task_metric_chip.gleam`.
- Definir `TaskMetricKind`.
- Definir mapeo de iconos, tonos y labels.
- Implementar variantes `Full` y `Compact`.
- Anadir `title` y `aria-label`.
- Anadir estilos base para:
  - `task-metric-chip`;
  - `task-metric-chip-icon`;
  - `task-metric-chip-value`;
  - `task-metric-chip-label`;
  - modificadores de tono ya alineados con `tone.class_name`.

Tests:

- `task_metric_test.gleam`: icono/tono/label por cada kind.
- `task_metric_chip_test.gleam`: render `Full`, render `Compact`, `title`, `aria-label`, `data-testid`.

Criterios de aceptacion:

- No hay iconos decididos en vistas para estas metricas.
- Cada metrica canonica tiene mapping exhaustivo.
- `Compact` no renderiza etiqueta visible pero conserva significado accesible.
- Tests usan `let assert`.

### Paquete 2: Migracion de Capacidades

Objetivo:

- Resolver primero la vista donde el problema es mas visible.

Tareas:

- Reemplazar `view_summary_chip` local por `task_metric_chip.Compact` o `Full` segun contexto.
- Usar `Full` en encabezado general si se migra via `work_surface`.
- Usar `Compact` en bloques/list rows/matrix cells.
- Reemplazar `workload_breakdown` por el nuevo componente compacto o adaptar `workload_breakdown` para delegar en `task_metric_chip`.
- Mantener `title` equivalente a las etiquetas actuales.

Codigo a eliminar o dejar obsoleto:

- `view_summary_chip` local en `features/capability_board/view.gleam`.
- `compact_metrics` si solo alimenta `workload_breakdown` con labels compactas.
- `compact_available_label`, `compact_claimed_label`, `compact_ongoing_label`, `compact_blocked_label` si quedan sin usos.
- Import de `ui/workload_breakdown` desde Capacidades si se reemplaza por `task_metric_chip`.
- CSS `capability-summary-chip`, `capability-summary-value`, `capability-summary-label` si no queda uso.

Tests:

- Actualizar `capability_board_view_test.gleam` para buscar `task-metric-chip`.
- Aserciones por `aria-label` o `title`: disponibles, reclamadas, en curso, cerradas, bloqueadas.
- Asercion negativa de que no aparece `capability-summary-chip` si se elimina.

Criterios de aceptacion:

- Capacidades no tiene helper local para chips de metricas de tarea.
- Los badges densos usan icono + numero + tooltip.
- No quedan abreviaturas como sustituto principal del significado.

### Paquete 3: Migracion de Kanban

Objetivo:

- Eliminar el health chip local de Kanban.

Tareas:

- Reemplazar `view_health_chip` por `task_metric_chip.Compact`.
- Mantener logica actual de ocultar bloqueadas cuando el valor es cero, si sigue siendo deseable.
- Mantener orden actual: disponibles, reclamadas, en curso, bloqueadas.

Codigo a eliminar o dejar obsoleto:

- `view_health_chip` en `features/views/kanban_board.gleam`.
- CSS `kanban-health-chip`, `kanban-health-value`, `kanban-health-label` si no queda uso.
- Tests que prueban custom class de `signal_chip` solo para Kanban, si dejan de aportar valor.

Tests:

- Actualizar `kanban_task_item_test.gleam`.
- Mantener cobertura de `title="Available: 2"` o equivalente i18n.
- Anadir asercion de icono/testid semantico para cada metrica renderizada.

Criterios de aceptacion:

- Kanban no decide iconos ni estilos propios para metricas de tarea.
- Los contadores compactos se leen igual que en Capacidades.

### Paquete 4: Migracion de encabezados `work_surface`

Objetivo:

- Unificar los contadores principales de superficies sin romper metricas no-task.

Tareas:

- Extender `work_surface.SummaryChip` con variante de metrica de tarea.
- Anadir helper:
  - `work_surface.task_summary_chip(kind, value)`
  - o equivalente con `task_metric.TaskMetric`.
- Migrar:
  - Pool: abiertas/disponibles/bloqueadas cuando correspondan a metricas canonicas.
  - Plan: tareas/disponibles/bloqueadas.
  - Kanban: disponibles/reclamadas/en curso/bloqueadas.
  - Capacidades: disponibles/reclamadas/en curso/bloqueadas.
  - Personas: atencion/en curso/reclamadas/disponibles solo cuando el significado sea equivalente.
- Dejar como `SummaryChip` generico:
  - numero de cards;
  - numero de capacidades;
  - healthy limit;
  - metricas de automatizaciones;
  - cualquier metrica que no sea estado/cantidad de tareas.

Codigo a eliminar o dejar obsoleto:

- Labels hardcodeadas de tarea en headers donde exista label canonica.
- Tests que solo verifican clases antiguas sin comprobar semantica.

Tests:

- Actualizar `work_surface_test.gleam`.
- Actualizar tests de Pool, Kanban, People y Plan que busquen `work-surface-chip`.
- Mantener compatibilidad para chips genericos.

Criterios de aceptacion:

- `work_surface` sigue soportando chips genericos.
- Las metricas de tareas de headers usan icono + numero + texto visible.
- Las metricas no-task no reciben iconos incorrectos.

### Paquete 5: Estados inline de task

Objetivo:

- Unificar como se muestra el estado de una task individual.

Tareas:

- Crear o ampliar un componente:

```text
apps/client/src/scrumbringer_client/ui/task_status_indicator.gleam
```

- Centralizar:
  - disponible;
  - reclamada/taken;
  - en curso;
  - cerrada;
  - bloqueada cuando aplique como badge complementario.
- Reutilizar `task_status_utils.label`.
- Reutilizar iconos canonicos o especificos de estado real (`Pause` para `Taken`, `Play` para `Ongoing`).
- Ofrecer variantes:
  - `InlineCompact`: icono + texto corto o solo icono con label accesible;
  - `InlineFull`: icono + label visible.

Codigo a eliminar o dejar obsoleto:

- Spans locales `task-status-muted` donde solo renderizan label de estado.
- Spans locales `task-status` si se reemplazan por el indicador comun.
- Uso directo de `task_status_utils.claimed_icon` desde vistas.
- Unicode manual de `features/cards/show.gleam`.
- CSS `card-task-status` si ya no se usa.

Tests:

- Nuevo `task_status_indicator_test.gleam`.
- Actualizar:
  - `grouped_list_task_item_test.gleam`;
  - `kanban_task_item_test.gleam`;
  - `my_bar_task_row_view_test.gleam` si aplica;
  - tests de cards show si cubren el icono Unicode actual.

Criterios de aceptacion:

- Ninguna vista decide manualmente el icono de estado de una task.
- No quedan emojis/Unicode como sistema de estado.
- Estados inline tienen tooltip/aria cuando el texto visible se oculta.

### Paquete 6: Limpieza de `workload_breakdown`

Objetivo:

- Decidir si el componente sigue aportando valor.

Opciones:

1. Eliminar `ui/workload_breakdown.gleam` si solo servia a Capacidades y su funcion queda cubierta por `task_metric_chip.Compact`.
2. Mantenerlo como layout wrapper si representa una fila compacta reusable, pero internamente debe aceptar `TaskMetric` y delegar en `task_metric_chip`.

Decision recomendada:

- Eliminarlo si tras migrar Capacidades no hay mas usos.

Codigo a eliminar:

- `ui/workload_breakdown.gleam`
- `apps/client/test/ui_workload_breakdown_test.gleam`
- CSS `workload-breakdown`, `workload-breakdown-item`, `workload-breakdown-value`, `workload-breakdown-label`

Criterios de aceptacion:

- No queda un segundo sistema paralelo de metricas compactas.
- Si se mantiene un wrapper, no tiene labels compactas propias.

### Paquete 7: Limpieza CSS y tokens visuales

Objetivo:

- Quitar estilos duplicados y dejar un unico set de clases para metricas de tareas.

Tareas:

- Consolidar estilos en `styles/layout.gleam` o el modulo de estilos que corresponda.
- Eliminar clases sin referencias:
  - `kanban-health-chip`;
  - `kanban-health-value`;
  - `kanban-health-label`;
  - `capability-summary-chip`;
  - `capability-summary-value`;
  - `capability-summary-label`;
  - `workload-breakdown*`;
  - `card-task-status` si se migra Cards show;
  - usos redundantes de `task-status-muted` si quedan solo para texto generico.
- Mantener clases de layout propias de cada superficie solo cuando posicionan el chip, no cuando redefinen su significado visual.

Criterios de aceptacion:

- `rg` no encuentra clases eliminadas en `src` ni `test`.
- La UI no depende de estilos locales para comunicar significado de metrica.

### Paquete 8: Refactor general de cierre

Objetivo:

- Rematar la migracion sin dejar deuda accidental.

Tareas:

- Pasada `rg` por:
  - `summary_chip(`
  - `metric_int(`
  - `workload_breakdown`
  - `task-status-muted`
  - `card-task-status`
  - `claimed_icon`
  - `kanban-health-chip`
  - `capability-summary-chip`
- Verificar que los usos restantes son genericos o justificados.
- Renombrar helpers si quedaron demasiado ligados a una vista.
- Reducir imports muertos.
- Revisar i18n: eliminar labels compactas o claves no usadas.
- Revisar tests: evitar que haya multiples snapshots/aserciones probando el mismo detalle de markup.
- Ejecutar formateo y test suite relevante.

Criterios de aceptacion:

- No quedan implementaciones locales de chips para las seis metricas canonicas.
- No queda codigo muerto ni CSS sin uso de la migracion.
- Los tests cubren la semantica comun, no detalles duplicados por vista.
- Las vistas migradas tienen aserciones de accesibilidad (`title`/`aria-label`) para chips compactos.

## Orden recomendado de ejecucion

1. Paquete 1: nucleo semantico y chip comun.
2. Paquete 2: Capacidades.
3. Paquete 3: Kanban.
4. Paquete 4: encabezados `work_surface`.
5. Paquete 5: estados inline.
6. Paquete 6: decidir y limpiar `workload_breakdown`.
7. Paquete 7: limpieza CSS.
8. Paquete 8: refactor general de cierre.

Este orden reduce riesgo porque primero introduce una API testeada, despues migra las superficies con mayor divergencia visual y solo al final toca los estados inline, que tienen mas variacion contextual.

## Testing recomendado

Tests unitarios nuevos:

- `task_metric_test.gleam`
- `task_metric_chip_test.gleam`
- `task_status_indicator_test.gleam` si se implementa el paquete 5

Tests a actualizar:

- `ui_signal_chip_test.gleam`: mantener como test de primitiva generica.
- `work_surface_test.gleam`: cubrir chips genericos y chips de task.
- `ui_workload_breakdown_test.gleam`: eliminar o reorientar si el componente sobrevive.
- `capability_board_view_test.gleam`
- `kanban_task_item_test.gleam`
- `people_view_test.gleam`
- `grouped_list_task_item_test.gleam`

Reglas:

- Usar `let assert`.
- No introducir snapshots grandes para estos chips.
- Preferir aserciones de:
  - `data-testid`;
  - clase semantica;
  - `title`;
  - `aria-label`;
  - presencia de icono;
  - ausencia de clases obsoletas cuando se eliminen.

## Riesgos y decisiones abiertas

### Personas no siempre habla de tareas directamente

En People, etiquetas como `Attention`, `Working now`, `With work`, `Available` resumen estado de personas, no siempre conteo directo de tasks. Solo deben migrarse a `TaskMetricKind` cuando el significado sea realmente equivalente.

Si el dato representa personas, debe quedarse como chip generico o tener otra semantica en el futuro.

### `Closed` puede no querer color success en todos los contextos

En conteos historicos, `Closed` puede ser neutral. En estados de task individual, puede usar `CheckCircle` con tono success. El modulo comun debe permitir decidir tono por contexto si aparece esta necesidad real.

No introducir configuracion prematura; empezar con un mapeo canonico y ajustar solo donde haya conflicto visual probado.

### No todo `summary_chip` debe iconificarse

`work_surface.summary_chip` tambien se usa para cards, capacidades, limites y automatizaciones. El plan no debe forzar iconos de tarea sobre metricas que no son de tarea.

## Definicion de hecho

La migracion esta terminada cuando:

- Las seis metricas canonicas usan el mismo icono, tono, label y tooltip en todas las vistas migradas.
- Los chips compactos tienen hover/focus semantico mediante `title` y accesibilidad mediante `aria-label`.
- No quedan helpers locales de chips para metricas de tarea en Kanban o Capacidades.
- No quedan abreviaturas de texto como sustituto principal de metricas compactas.
- No quedan emojis/Unicode manuales para estado de task.
- El codigo obsoleto identificado se elimina o queda justificado en comentarios/tests.
- La suite relevante de cliente pasa.

## Estado de cierre

Implementado:

- Paquete 1: `task_metric`, `task_metric_chip` y `task_status_indicator` centralizan icono, tono, label, `title` y `aria-label`.
- Paquete 2: Capacidades usa chips comunes para available/claimed/ongoing/blocked y conserva chips genericos para cards/capabilities.
- Paquete 3: Kanban usa `work_surface.task_summary_chip` en cabecera y `task_metric_chip.Compact` en cards.
- Paquete 4: `work_surface` expone `TaskSummaryChip` para metricas canonicas y mantiene `SummaryChip` para datos no-task.
- Paquete 5: Card show, task show, listas agrupadas y superficies con tasks usan `task_status_indicator` para estado inline.
- Paquete 6: `workload_breakdown` y sus tests se eliminan al quedar sustituido por el componente comun.
- Paquete 7: Se limpian clases y helpers obsoletos (`kanban-health-chip`, `capability-summary-chip`, `card-health-*`, `card-task-info`, `task-claimed-icon`, `claimed_icon`).
- Paquete 8: El refactor final renombra restos heredados para que el codigo exprese la semantica comun (`view_task_metric_chip`, `card-task-status-indicator`).

Restos revisados y aceptados:

- `work_surface.summary_chip` sigue existiendo para cards, capacidades, limites, personas y automatizaciones. No debe migrarse porque no representa siempre metricas canonicas de task.
- `signal_chip.metric` sigue cubierto por tests como primitiva generica del sistema visual.
- `task_state.label` y `task_status_utils.label` quedan para textos contextuales, tooltips y badges especificos, no como sustituto visual de los indicadores compactos.
- Los emojis de `ui/color_picker.gleam` pertenecen al selector de color de cards, no al estado de tasks.
- Los `text(int.to_string(claimed))` de `features/metrics/view.gleam` son celdas de analitica/tablas, no badges de estado.

Barridos de cierre recomendados:

- `rg "workload_breakdown|kanban-health-chip|capability-summary-chip|card-health|card-task-info|task-claimed-icon|claimed_icon|\\(claimed\\)" apps/client/src/scrumbringer_client apps/client/test`
- `rg "work_surface\\.summary_chip\\(|signal_chip\\.metric|task_state\\.label|task_status_utils\\.label" apps/client/src/scrumbringer_client apps/client/test`
