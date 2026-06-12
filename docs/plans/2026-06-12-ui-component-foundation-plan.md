# UI Component Foundation Plan

Fecha: 2026-06-12

## Objetivo

Preparar la base tecnica para evolucionar ScrumBringer hacia un lenguaje visual
unificado sin aumentar deuda de codigo. La fase no busca cambiar la filosofia
del producto ni redisenar todas las pantallas de golpe. Busca convertir patrones
visuales ya validados en primitivas reutilizables, tipadas y testeadas.

El resultado esperado es que Pool, Kanban, Capacidades, Personas, Hitos y Admin
usen el mismo vocabulario para:

- tonos semanticos de estado y salud del flujo;
- chips, badges y senales compactas;
- acciones globales, acciones de vista y acciones de entidad;
- estados vacios, loading y error;
- headers, filtros y composicion de superficies;
- identidad visual de card en tareas y vistas relacionadas.

## Skills y criterios aplicados

- Impeccable: mantener registro de producto, consistencia visual, jerarquia de
  acciones, estados vacios productivos y lenguaje visual unificado.
- gleam-lustre-development: componentes simples como funciones para UI
  estatica, componentes stateful solo cuando encapsulen estado real, listas
  dinamicas keyed, accesibilidad y mensajes event-driven cuando haya interaccion.
- gleam-testing: tests con `let assert`, fixtures usando tipos reales, matriz de
  happy path, edge cases y errores, snapshots solo con revision humana si se
  usan.
- gleam-type-system: ADTs para tonos, variantes y estados; opaque types donde
  haya invariantes; evitar strings y bool flags que codifiquen multiples
  estados.
- gleam-code-review: refactor solo si reduce conceptos, elimina ramas, aclara
  ownership o mejora la capacidad de test.

## Principios de extraccion

1. Extraer por semantica de producto, no por parecido superficial.
2. No crear componentes genericos con muchas flags.
3. Mantener comportamiento de dominio cerca de su feature.
4. Usar tipos para impedir combinaciones invalidas.
5. Migrar incrementalmente con tests antes o junto a cada extraccion.
6. Eliminar fragmentos obsoletos en la misma fase en que dejan de usarse.
7. Mantener CSS de compatibilidad solo con una razon explicita y temporal.
8. No extraer estado a un componente Lustre stateful salvo que encapsule estado
   real; para UI estatica, preferir funciones puras que devuelven `Element(msg)`.
9. No duplicar tipos de dominio en UI. La UI puede definir tipos visuales, pero
   cards, tasks, capabilities, milestones y users siguen viniendo de `domain/*`.

No se debe crear un componente tipo `GenericPanel(mode, compact, special_case)`.
Si un componente necesita muchas excepciones por vista, la extraccion esta mal
cortada.

## Modelo de ownership

Para evitar que la nueva capa compartida se convierta en otro lugar de deuda, el
ownership queda dividido asi:

| Capa | Que posee | Que no posee |
| --- | --- | --- |
| `domain/*` | entidades, estados de negocio, decoders compartidos | clases CSS o decisiones visuales |
| `features/*` | queries de vista, filtros de negocio, ordenacion, permisos, handlers | tonos visuales duplicados, botones manuales repetidos |
| `ui/*` | primitivas visuales reutilizables, accesibilidad, clases canonicas | reglas de negocio o fetch de datos |
| `styles/*` | implementacion CSS de tokens/componentes | nombres de estado inventados por feature |
| `i18n/*` | copy visible y labels por locale | strings hardcoded dentro de componentes compartidos |

Regla practica: si una funcion necesita saber por que una tarea esta disponible,
pertenece a `features` o `domain`. Si solo necesita renderizar una senal
`Available`, pertenece a `ui`.

## Escalera de componentes

Cada fragmento debe pasar por esta escalera antes de convertirse en componente
compartido:

1. `Local helper`: una funcion privada dentro de una vista. Correcto cuando solo
   existe un uso y el patron no representa una regla del producto.
2. `Feature helper`: modulo dentro de `features/<area>`. Correcto cuando varias
   sub-vistas de la misma area comparten una semantica propia.
3. `UI primitive`: modulo `ui/*`. Correcto cuando dos o mas superficies usan la
   misma semantica visual o accesible.
4. `Work surface primitive`: modulo de layout compartido. Correcto cuando afecta
   a Pool, Kanban, Capacidades, Personas o Hitos.
5. `Stateful Lustre component`: solo si hay estado interno, eventos propios,
   keyboard behavior no trivial o una frontera clara parent-child.

No se debe saltar directamente de HTML local a componente stateful.

## Contratos publicos de componentes

Cada componente nuevo o evolucionado debe definir:

- tipos publicos pequenos y exhaustivos;
- constructor o builder que impida estados invalidos cuando aplique;
- `view` como funcion pura siempre que sea posible;
- `attributes` o `testid` solo cuando el consumidor necesita extender el
  contrato;
- documentacion publica breve para tipos y funciones exportadas;
- nombres de clase canonicos que no incluyan la feature salvo que sean layout
  local.

Contratos que deben permanecer estables durante la migracion:

- `data-testid` usados por tests y flujos E2E;
- labels i18n visibles;
- `aria-label`, `aria-expanded`, `aria-controls`, `disabled`;
- estructura interactiva basica: button sigue siendo button, link sigue siendo
  link.

Si un componente compartido necesita exponer demasiadas clases externas para ser
usable, todavia no es una buena abstraccion.

## Estado actual resumido

Ya existe una base aprovechable:

- `theme.gleam`: tokens de color, tipografia, spacing, radios y transiciones.
- `features/layout/work_surface.gleam`: header comun para superficies de trabajo.
- `ui/admin_surface.gleam`: composicion admin header/filtros/contenido.
- `ui/data_table.gleam`: tabla reusable con remote state.
- `ui/empty_state.gleam`: empty states con icono, titulo, descripcion y accion.
- `ui/badge.gleam`: badge tipado con variantes.
- `ui/action_buttons.gleam` y `ui/task_actions.gleam`: acciones icon-only y de
  tarea.
- `ui/task_item.gleam`: item reusable para tareas compactas.
- `ui/card_badge.gleam`: identidad visual de card.

La duplicacion que queda es real pero localizada:

- Kanban, Capacidades, Hitos y WorkSurface definen chips de senal parecidos con
  clases distintas.
- Personas y Capacidades renderizan estados loading/error/empty/no-results
  propios en vez de pasar por una primitiva comun.
- Varios botones siguen usando clases manuales en lugar de una jerarquia de
  acciones.
- Filtros y toolbars repiten estructura y spacing en Pool, Admin, Hitos y panel
  central.
- Algunas clases CSS antiguas quedan como nombres especificos aunque ya expresan
  patrones generales.

## Fase 0: Inventario y red de seguridad

Objetivo: saber exactamente que se va a consolidar antes de tocar componentes
compartidos.

Tareas:

- Registrar todos los productores de chips/badges/estado:
  - `features/layout/work_surface.gleam`
  - `features/views/kanban_board.gleam`
  - `features/capability_board/view.gleam`
  - `features/people/view.gleam`
  - `features/milestones/content_pane.gleam`
  - `ui/badge.gleam`
  - `ui/card_state_badge.gleam`
- Registrar estados vacios/loading/error propios por feature.
- Registrar botones manuales con clases `btn-*` en vistas principales.
- Registrar CSS que representa componentes candidatos:
  - `work-surface-*`
  - `milestone-structure-chip`
  - `kanban-health-*`
  - `capability-board-summary-chip`
  - `people-state`
  - `capability-board-state`
  - `filters-bar`, `filter-group`
- Marcar cada fragmento como:
  - `migrate`: debe moverse a primitiva comun;
  - `keep-local`: expresa dominio especifico;
  - `delete-after-migration`: queda obsoleto cuando el consumidor migre.
- Crear un registro de obsolescencia con:
  - identificador;
  - fichero/clase/funcion afectada;
  - consumidor que la reemplaza;
  - fase de eliminacion;
  - test que protege la migracion.
- Clasificar modulos grandes de UI por responsabilidad. Si una migracion aumenta
  un modulo por encima de 700 lineas o mezcla responsabilidades, dividir antes
  de seguir.

Tests/gate:

- No cambios funcionales.
- `gleam check` en `apps/client`.
- Documento de inventario breve en el propio PR o anexo del plan.
- `rg` inicial de clases y helpers candidatos guardado en el PR para comparar
  contra el final de cada fase.

## Fase 1: Tonos semanticos y SignalChip

Objetivo: unificar el vocabulario visual de senales sin tocar layout de vistas.

Nuevos modulos propuestos:

- `apps/client/src/scrumbringer_client/ui/tone.gleam`
- `apps/client/src/scrumbringer_client/ui/signal_chip.gleam`

Modelo propuesto:

```gleam
pub type Tone {
  Neutral
  Primary
  Available
  Claimed
  Ongoing
  Blocked
  Warning
  Success
  Danger
  Info
}

pub opaque type SignalChip {
  SignalChip(label: String, value: Option(String), tone: Tone)
}
```

API esperada:

- `signal_chip.text(label, tone)`
- `signal_chip.metric(label, value, tone)`
- `signal_chip.metric_if_positive(label, value, tone)`
- `signal_chip.view(chip)`

Migraciones:

- `work_surface.SummaryChip` debe usar `ui/tone.Tone` o delegar en
  `signal_chip`.
- `kanban_board.view_health_chip` desaparece.
- `capability_board.view_summary_chip` desaparece o queda como wrapper de
  dominio sobre `signal_chip` si conserva nombres de fila.
- `milestones/content_pane.summary_chip` desaparece o queda como wrapper de
  dominio si aporta nombres de hito.

Limpieza:

- Eliminar clases CSS duplicadas que solo cambian tono.
- Mantener clases de layout local cuando expresen posicion, no tono.
- Evitar nuevos strings de tono como `"blocked"` o `"warning"` fuera de
  `ui/tone.gleam`.

Tests:

- `ui_signal_chip_test.gleam`
  - renderiza label-only;
  - renderiza metric con valor;
  - `metric_if_positive` oculta cero;
  - cada `Tone` produce clase semantica esperada;
  - density compact/default produce clase esperada.
- Tests de migracion en vistas:
  - Kanban sigue mostrando available/claimed/ongoing/blocked.
  - Capacidades sigue mostrando resumen por fila.
  - Hitos sigue ocultando ceros sanos.

Gate:

- `gleam check`
- `gleam test` en `apps/client`
- `rg` sin productores antiguos: `view_health_chip|view_summary_chip|milestone-structure-chip .* tone manual`

Estado 2026-06-12:

- Implementado `ui/tone.gleam` como fuente unica de tonos semanticos.
- Implementado `ui/signal_chip.gleam` para chips compactos de texto y metrica.
- Migrados `work_surface`, Kanban, Hitos, Capacidades, Personas y Pool para no
  depender de un enum local en `work_surface`.
- Conservadas temporalmente clases de compatibilidad:
  - `work-surface-chip`, `work-surface-chip-value`, `work-surface-chip-label`
  - `kanban-health-chip`, `kanban-health-value`, `kanban-health-label`
  - `milestone-structure-chip` con modificadores de negocio como `progress`,
    `cards`, `loose`, `blocked`, `empty`, `no-progress`
  - `capability-summary-chip`, `capability-summary-value`,
    `capability-summary-label`
- Eliminado el enum local `ChipTone` y la logica manual de mapping de tono en
  `work_surface`.
- Tests nuevos:
  - `apps/client/test/ui_signal_chip_test.gleam`
- Tests actualizados:
  - `work_surface_test`
  - `pool_chrome_test`
  - `milestones_chrome_test`
- Gate ejecutado:
  - `gleam check` en `apps/client`
  - `gleam test` en `apps/client`

## Fase 2: Jerarquia de acciones y Button API

Objetivo: convertir la jerarquia de acciones en codigo compartido y no solo en
CSS.

Nuevo modulo propuesto:

- `apps/client/src/scrumbringer_client/ui/button.gleam`

Modelo propuesto:

```gleam
pub type Intent {
  Primary
  Secondary
  Ghost
  Danger
}

pub type Scope {
  GlobalAction
  ViewAction
  EntityAction
}

pub type Shape {
  Text
  Icon
  IconText
}
```

Uso esperado:

- Acciones globales: crear tarea, crear card, crear hito.
- Acciones de vista: filtros, agrupacion, toggle de resumen.
- Acciones de entidad: claim, release, complete, edit, delete, abrir detalle.

Migraciones:

- `action_buttons.gleam` puede seguir existiendo, pero debe delegar en
  `ui/button.gleam`.
- `task_actions.gleam` mantiene semantica de tarea, pero no define estructura
  visual propia.
- Botones manuales en Pool, Hitos, Admin y Kanban migran gradualmente.

Limpieza:

- Reducir clases manuales tipo `"btn-sm btn-primary ..."` en vistas.
- Eliminar variantes especificas que ya no aporten comportamiento.
- Revisar tooltips y `aria-label` para icon-only.

Tests:

- `ui_button_test.gleam`
  - primary/global renderiza clase y aria correcta;
  - icon-only exige label accesible;
  - disabled renderiza `disabled`;
  - danger/entity usa clase de peligro;
  - botones con testid lo conservan.
- Tests de feature:
  - Pool mantiene boton Nueva tarea en header.
  - Claim sigue icon-only en Pool y Kanban.
  - Acciones de Hitos no se apilan de forma ambigua en desktop/mobile.

Gate:

- Sin botones icon-only sin `aria-label` o `title`.
- Sin acciones globales dentro de contenedores de filtros salvo decision
  documentada.

## Fase 3: Estados vacios, loading y error productivos

Objetivo: que ausencia de datos signifique algo de forma consistente.

Modulos a evolucionar:

- `ui/empty_state.gleam`
- `ui/remote.gleam`
- `ui/loading.gleam`

Modelo propuesto:

```gleam
pub type EmptyMeaning {
  HealthyEmpty
  NoResults
  NeedsSetup
  Onboarding
  ErrorState
  LoadingState
}
```

Migraciones:

- `people-state`, `capability-board-state`, `milestone_chrome.loading/error` y
  estados sueltos de Pool deben usar la misma primitiva visual.
- Los textos siguen viviendo en i18n de cada feature.
- Las vistas pueden elegir icono y CTA, pero no reinventar estructura.

Limpieza:

- Eliminar `view_state_message` locales que solo pintan texto.
- Consolidar CSS de `.empty`, `.empty-state`, `.task-empty-state`,
  `.detail-empty-state` cuando no haya diferencia semantica.
- Mantener empty states especificos solo si tienen layout propio justificado.

Tests:

- `ui_empty_state_test.gleam`
  - empty con CTA renderiza boton accesible;
  - no-results no renderiza accion si no se pasa;
  - loading tiene rol o texto verificable;
  - error usa tono/estructura de error.
- Tests de vistas:
  - Personas: loading, error, empty roster, no-results.
  - Capacidades: loading, error, empty active work, no-results.
  - Hitos: loading/error/no-results.

Gate:

- Todas las vistas principales tienen estados loading/error/empty/no-results
  cubiertos.
- Ningun empty state nuevo dice solo "No hay datos" sin significado.

## Fase 4: WorkSurface 2 y FilterBar

Objetivo: unificar ritmo de superficie sin encerrar todas las vistas en un
componente generico.

Modulos propuestos:

- `features/layout/work_surface.gleam` ampliado.
- `ui/filter_bar.gleam`

WorkSurface debe cubrir:

- header;
- summary;
- action slot;
- optional filter slot;
- content slot;
- state slot.

FilterBar debe cubrir:

- search;
- select;
- checkbox/toggle;
- segmented controls;
- action slot separado.

Migraciones:

- Pool: filtros y accion de nueva tarea deben quedar visualmente separados por
  jerarquia, no por clases ad hoc.
- Admin: revisar que `admin_surface` y `filter_bar` no dupliquen responsabilidades.
- Hitos: filtros de lista y toggles usan ritmo comun.
- Panel central: filtros de tipo/capacidad/scope usan `filter_bar` si no aumenta
  complejidad.

Limpieza:

- Eliminar wrappers locales de filtros que solo ordenan controles.
- Reducir clases `filters-inline`, `filter-group`, `milestones-filter-row` si se
  vuelven alias.
- Documentar excepciones donde una feature conserve layout propio.

Tests:

- `ui_filter_bar_test.gleam`
  - search input conserva value, placeholder y testid;
  - select renderiza opciones y selected;
  - checkbox/toggle dispara mensaje;
  - action slot no se mezcla con filter groups.
- `work_surface_test.gleam`
  - header sin acciones no deja basura visual;
  - header con summary renderiza chips;
  - filters slot aparece entre header y content;
  - content conserva keyed/list semantics donde aplique.

Gate:

- Pool, Kanban, Capacidades, Personas e Hitos comparten header/surface rhythm.
- Filtros no dominan mobile por defecto.
- Acciones globales no parecen filtros.

## Fase 5: Identidad de card y TaskItem convergence

Objetivo: que la card se identifique igual en sidebar, tareas, Personas,
Capacidades, Hitos, Kanban y busquedas.

Modulos a consolidar:

- `ui/card_badge.gleam`
- `ui/task_item.gleam`
- posibles helpers nuevos: `ui/card_identity.gleam`

API deseada:

- identidad compacta: swatch/initials + tooltip;
- identidad inline para tareas;
- identidad row para listas;
- sin recrear "card completa dentro de task".

Migraciones:

- Personas: chips de cards deben usar identidad compacta comun.
- Capacidades: tareas mantienen swatch de card con la misma fuente.
- Hitos: CTA a card usa identidad comun sin volver a mostrar tareas dentro de
  card row.
- Pool/Kanban: task item usa la misma identidad cuando proceda.

Limpieza:

- Eliminar estilos locales de card chip que dupliquen `card_badge`.
- Eliminar helpers que calculen initials fuera de `card_badge`/`card_identity`.
- Revisar que no vuelvan las side-stripes nuevas.

Tests:

- `ui_card_identity_test.gleam`
  - initials para una palabra, dos palabras y vacio;
  - color `None` usa neutral;
  - swatch renderiza variable CSS correcta;
  - inline identity incluye tooltip accesible.
- Tests de vistas:
  - Personas muestra identidad de card sin titulo largo redundante si no cabe.
  - Capacidades mantiene el mismo simbolo que sidebar.
  - Hitos permite navegar a card sin sobrecargar filas.

Gate:

- Una sola fuente para initials/color class.
- No hay helpers duplicados de card identity.

## Fase 6: CSS y comentarios

Objetivo: eliminar residuos tras las migraciones.

Limpieza CSS:

- Quitar clases sin uso con `rg`.
- Agrupar reglas por componente real, no por historia antigua.
- Mantener tokens en `theme.gleam`; evitar valores magic nuevos en CSS.
- Sustituir reglas locales por roles semanticos existentes:
  - `--sb-gap-related`
  - `--sb-gap-group`
  - `--sb-gap-section`
  - `--sb-gap-surface`
- Revisar contraste de tonos nuevos en light/dark.

Limpieza de codigo:

- Eliminar imports muertos tras migraciones.
- Eliminar funciones wrapper que solo delegan sin aclarar semantica.
- Eliminar bool flags que codifiquen variantes multiples si puede usarse ADT.
- Mantener comentarios publicos utiles; quitar comentarios de historia,
  checklist o narracion obvia.

Tests/gate:

- `gleam format`
- `gleam check`
- `gleam test`
- `git diff --check`
- `rg` de clases/componentes obsoletos documentados en cada fase.

## Fase 7: Documentacion viva y catalogo de componentes

Objetivo: que la nueva base cohesionada sea mantenible por el siguiente cambio,
no solo por quien hizo la refactorizacion.

Documentos a revisar:

- `DESIGN.md`: actualizar lenguaje visual si cambian nombres de tonos, chips,
  acciones o empty states.
- `docs/architecture/lustre-components.md`: aclarar que esta fase usa
  principalmente componentes stateless; reservar custom elements para estado
  encapsulado real.
- `docs/ui-architecture.md` o documento equivalente: listar primitivas UI
  canonicas y cuando usarlas.
- Tests de componente: documentar convencion de `element.to_document_string`,
  asserts pequenos y uso excepcional de Birdie.

Entregables:

- Tabla de componentes canonicos:
  - `tone`
  - `signal_chip`
  - `button`
  - `empty_state`
  - `filter_bar`
  - `work_surface`
  - `card_identity`
  - `task_item`
- Tabla de componentes legacy eliminados o reemplazados.
- Reglas de decision para nuevos componentes.

Gate:

- La documentacion nombra los componentes que realmente existen.
- No hay componentes documentados como canonicos que no tengan tests.
- No hay componentes nuevos sin mencion en el catalogo si son de uso compartido.

## Matriz de tests por tipo de cambio

| Cambio | Tests requeridos |
| --- | --- |
| Nuevo tipo visual (`Tone`, `Intent`, `Scope`) | Unit tests de mapping a clase + exhaustividad por compilador |
| Nuevo componente stateless | Render tests por variante + edge cases |
| Nuevo componente interactivo | Render + evento + accesibilidad + disabled/error |
| Migracion de vista | Test existente actualizado + test de regresion del contrato visual |
| Eliminacion de helper/CSS | `rg` sin referencias + test de vista que cubra el reemplazo |
| Snapshot Birdie | Solo si el HTML es grande; requiere revision humana antes de marcar done |

Preferencia: assertions pequenas sobre HTML renderizado. Birdie solo cuando el
output sea demasiado grande para asserts legibles.

El cliente usa `target = "javascript"` en `apps/client/gleam.toml`; por tanto,
`gleam test` dentro de `apps/client` valida el target relevante para estos
componentes. Si una primitiva se mueve a `shared/` o a un paquete cross-target,
entonces debe validarse explicitamente en los targets afectados.

## Estrategia de tests de UI

Los tests se organizan en tres niveles:

1. Tests de primitiva: comprueban HTML, clases canonicas, atributos accesibles,
   disabled/error/loading y edge cases.
2. Tests de contrato de vista: verifican que la vista sigue exponiendo las
   senales de producto esperadas tras migrar a componentes compartidos.
3. Tests de comportamiento: solo cuando hay interaccion real, comprobar evento,
   estado expandido/colapsado, filtros, toggles o accion.

Reglas:

- Usar `let assert`, no `gleeunit/should`.
- Preferir `element.to_document_string` y asserts pequenos sobre fragmentos
  estables.
- No testear orden o markup interno si no es contrato de producto.
- Reusar fixtures y tipos reales de `domain/*`.
- Usar snapshots Birdie solo con revision humana y solo para HTML demasiado
  grande para asserts claros.
- Las listas dinamicas migradas deben seguir usando rendering keyed cuando ya lo
  hacian o cuando los datos puedan reordenarse.

Contratos visuales minimos por superficie:

| Superficie | Contrato a proteger |
| --- | --- |
| Pool | accion global separada de filtros, claim icon-only, empty/no-results productivos |
| Kanban | columnas por estado, health chips, cards con tareas relevantes, CTA de task |
| Capacidades | demanda por pending/claimed/ongoing/blocked, filas por capacidad, unassigned claro |
| Personas | disponibilidad, WIP, tareas agrupadas, identidad de card compacta |
| Hitos | Delivery Plan compacto, ceros sanos ocultos, CTA a card, tareas sin card separadas |
| Admin | header/filtros/contenido con ritmo comun, tablas y empty states consistentes |

## Validacion visual y accesibilidad

Las fases que cambien layout o jerarquia visual deben incluir validacion visual
ademas de tests unitarios:

- desktop y mobile para la superficie migrada;
- light/dark si se tocan tonos o tokens;
- foco visible en botones, filtros y toggles;
- touch targets minimos en mobile para acciones interactivas;
- contraste de texto y chips en estados semanticos;
- no overflow de textos largos en labels, buttons, chips o headers;
- reduccion de movimiento si se introduce transicion nueva.

Cuando haya servidor disponible, validar con navegador y capturas. Si no lo hay,
dejar anotado que queda pendiente de QA visual.

## Registro de obsolescencia

Cada fase debe cerrar con una lista pequena:

```text
Eliminado:
- old_helper/old_class -> reemplazado por new_component, cubierto por test_x

Conservado temporalmente:
- old_class -> requerido por vista_y hasta Fase N

Keep-local:
- helper_z -> comportamiento especifico de Hitos, no es UI comun
```

No se considera fase terminada si queda una clase o helper marcado como
`delete-after-migration` sin eliminar o sin razon temporal.

## Definition of Done por fase

- La fase tiene tests nuevos o actualizados antes de eliminar el codigo viejo.
- No quedan imports muertos ni funciones obsoletas del area migrada.
- No quedan clases CSS sin uso del area migrada.
- Las vistas migradas conservan i18n y `data-testid` relevantes.
- Los componentes interactivos tienen estado disabled/focus/accessibility.
- `gleam check` y `gleam test` pasan en `apps/client`.
- El plan o PR documenta cualquier excepcion `keep-local`.
- El registro de obsolescencia de la fase queda cerrado o con excepciones
  temporales fechadas.
- Si se toco layout o tono, hay evidencia de validacion visual o una nota
  explicita de pendiente.

## Riesgos y mitigaciones

Riesgo: sobreparametrizar componentes.
Mitigacion: preferir componentes pequenos (`signal_chip`, `button`,
`filter_bar`) frente a un unico contenedor generico.

Riesgo: perder lenguaje de dominio por abstraer demasiado.
Mitigacion: los modulos de feature siguen calculando datos; UI comun solo
renderiza primitivas.

Riesgo: romper layouts responsive.
Mitigacion: migrar una superficie por fase y validar desktop/mobile con tests y
captura visual cuando haya cambios de layout.

Riesgo: CSS residual crea falsos positivos de soporte.
Mitigacion: cada fase incluye busqueda `rg` de clases obsoletas y eliminacion
inmediata si no hay referencias.

Riesgo: snapshots bloquean automatizacion.
Mitigacion: no usar Birdie salvo que mejore claramente la revision; si se usa,
marcar `needs_review` hasta aprobacion humana.

## Secuencia recomendada de implementacion

1. Fase 0: inventario y mapa de migracion.
2. Fase 1: `tone` + `signal_chip`.
3. Fase 3: empty/loading/error productivos.
4. Fase 2: jerarquia de acciones y `button`.
5. Fase 4: `work_surface` ampliado + `filter_bar`.
6. Fase 5: identidad de card y convergencia con `task_item`.
7. Fase 6: limpieza final CSS/comentarios/imports.
8. Fase 7: documentacion viva y catalogo de componentes.

El orden prioriza bajo riesgo primero: tonos y chips son visibles, repetidos y
poco acoplados a negocio. `filter_bar` y `work_surface` deben esperar a que los
tokens visuales y acciones esten estabilizados.

## Primer incremento sugerido

Implementar solo Fase 1 sobre tres consumidores:

- `work_surface.gleam`
- `kanban_board.gleam`
- `milestones/content_pane.gleam`

Esto validara el corte de `Tone` y `SignalChip` sin tocar todas las vistas a la
vez. Si el componente se mantiene pequeno y los tests son claros, se extiende a
Capacidades y Personas.

## Check final de cohesion

Antes de dar la evolucion por cerrada, responder afirmativamente:

- Existe una unica fuente para tonos visuales semanticos.
- Existe una unica primitiva para chips/senales compactas.
- Las acciones principales respetan una jerarquia codificada, no solo visual.
- Los empty states principales comparten estructura y explican significado.
- Pool, Kanban, Capacidades, Personas e Hitos comparten ritmo de superficie.
- La identidad de card sale de una unica fuente.
- No quedan helpers locales que dupliquen componentes compartidos.
- No quedan clases CSS sin uso del area migrada.
- Los tests de componentes cubren variantes, accesibilidad y edge cases.
- La documentacion describe la base real, no una aspiracion.
