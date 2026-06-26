# Plan de unificacion de filtros de trabajo

## Contexto

El filtro de capacidades propias esta modelado como `CapabilityScope` (`all` / `mine`) y afecta a varias superficies de trabajo. Actualmente no siempre se renderiza con el mismo control ni con la misma semantica visual.

El caso problematico principal esta en la vista de Capacidades: hay un boton "Mis capacidades" que activa `scope=mine`, pero no muestra el estado activo ni permite volver directamente a ver todas las capacidades desde el mismo control. Esto crea un filtro unidireccional y ambiguo.

## Objetivo

Unificar los filtros de trabajo en un unico patron reutilizable, reversible y visible en todas las vistas que consumen ese estado.

El usuario nunca debe quedar en una vista filtrada por `scope=mine` sin ver un control local que permita volver a `scope=all`.

## Decision de interfaz

Usar un control segmentado unico para el scope de capacidades:

```text
Capacidades   [ Todas | Mias ]
```

No usar "Mis capacidades" como boton de accion. Ese texto sugiere una pantalla de perfil o edicion, mientras que el comportamiento real es filtrar el trabajo visible.

La etiqueta recomendada es:

- Label: `Capacidades`
- Opcion por defecto: `Todas`
- Opcion filtrada: `Mias`

Para usuarios no manager, `Todas` significa "todas las tareas visibles para mi", ya que el backend puede seguir aplicando restricciones de visibilidad por capacidades asignadas.

## Diseño tecnico

Crear un componente de filtros de trabajo:

```text
apps/client/src/scrumbringer_client/features/work_filters_bar.gleam
```

Responsabilidades:

- Renderizar controles comunes de filtros de trabajo.
- Permitir activar/desactivar por configuracion:
  - busqueda;
  - tipo de tarea;
  - capacidad;
  - scope de capacidades `Todas / Mias`;
  - visibilidad del Pool.
- Mantener el mismo lenguaje visual, clases y accesibilidad.
- Exponer `data-testid` estables por control.
- Emitir cambios hacia el estado existente, sin duplicar estado local.

No debe convertirse en un framework generico de formularios. Es un componente de producto para filtros de trabajo.

El proyecto ya tiene `apps/client/src/scrumbringer_client/ui/filter_bar.gleam`, que ofrece primitivas genericas para barras de filtros. La decision es:

- `ui/filter_bar.gleam` sigue siendo una utilidad generica;
- `features/work_filters_bar.gleam` concentra semantica de producto: busqueda de trabajo, tipo, capacidad, scope `Todas / Mias` y visibilidad del Pool;
- si reutilizar `ui/filter_bar.gleam` reduce duplicacion sin forzar la API, `work_filters_bar` debe componerlo internamente;
- no duplicar otra abstraccion generica paralela.

El componente debe exponer funciones con nombres concretos:

- `view_bar(config)`: barra completa para Pool u otra superficie que no tenga barra estructural propia;
- `view_refinement_controls(config) -> List(Element(msg))`: controles sueltos para insertar en `plan/scope_bar.gleam`;
- `view_capability_scope_control(config)`: control segmentado aislado para tests y para superficies que solo necesiten `Todas / Mias`.

Esto es importante porque `plan_scope_bar` no representa filtros de trabajo: representa alcance estructural del plan (`Proyecto / Nivel / Tarjeta`) y controles propios como `Cerradas`. Las vistas de Plan y Capacidades deben poder insertar filtros de trabajo dentro de `refinement_controls` sin reemplazar el scope estructural.

### API propuesta del componente

El componente debe tener una configuracion explicita, no una lista generica de campos arbitrarios.

Entradas minimas:

- `locale`;
- `task_types`;
- `capabilities`;
- `type_filter`;
- `capability_filter`;
- `search_query`;
- `capability_scope`;
- callbacks de cambio. Preferencia de diseno:
  - el componente comun emite valores tipados (`Option(Int)`, `CapabilityScope`, `PoolVisibility`);
  - los adaptadores de superficie convierten a mensajes existentes si todavia esperan `String`;
  - no repetir parsing de strings en cada vista.

Configuracion de controles:

- `show_search`;
- `show_type`;
- `show_capability`;
- `show_capability_scope`;
- `show_pool_visibility`.

Durante la implementacion, revisar si estos `show_*` deben mantenerse como flags simples o si conviene reemplazarlos por un ADT de superficie (`PoolSurface`, `CapabilityBoardSurface`, `ExecutionKanbanSurface`, `PlanKanbanSurface`). La decision debe tomarse con este criterio: si los flags permiten combinaciones invalidas reales, usar ADT; si solo encarecen la API, mantener flags.

Para Pool, incluir tambien:

- `visibility`;
- `on_visibility_change`.

La busqueda no debe asumir que todas las superficies usan exactamente la misma semantica. Plan estructura puede seguir usando `member_filters_q` como busqueda contextual sin mostrar `capability_scope`.

### `data-testid` canonicos

Usar un namespace comun para los controles nuevos:

- `work-filter-bar`;
- `work-filter-search`;
- `work-filter-type`;
- `work-filter-capability`;
- `work-filter-capability-scope`;
- `work-filter-capability-scope-all`;
- `work-filter-capability-scope-mine`;
- `work-filter-visibility`.

Pool puede conservar temporalmente `pool-filter-*` como aliases si evita un cambio masivo de tests, pero el objetivo final es que las pruebas de filtros de trabajo apunten al namespace `work-filter-*`. No mantener dos namespaces indefinidamente.

### i18n

No reutilizar `MyCapabilitiesLabel` como label del control segmentado. El label del nuevo control debe ser `Capacidades` / `Capabilities`.

Agregar o reutilizar claves con esta semantica:

- `CapabilityScopeLabel`: `Capacidades` / `Capabilities`;
- `ScopeAll`: `Todas` / `All`;
- `ScopeMine`: `Mias` / `Mine`.

Despues de migrar, eliminar solo las claves realmente sin referencias:

- `MyCapabilitiesOn`;
- `MyCapabilitiesOff`;
- `MyCapabilitiesHint`;
- revisar `MyCapabilitiesLabel` segun quede o no uso vivo fuera del filtro.

No eliminar `MySkills` / `MySkillsHelp` solo por parecer similares: pertenecen a la vista o estado de capacidades personales si esa UI sigue viva.

## Directrices Gleam, Lustre y testing

Estas reglas refinan el diseno para que la implementacion sea idiomatica en Gleam/Lustre y para que la cobertura mejore de forma medible.

### Tipado Gleam

- Modelar variantes con custom types, no con combinaciones sueltas de booleanos cuando haya estados mutuamente excluyentes.
- Evitar que `work_filters_bar.Config` permita estados invalidos, por ejemplo `show_pool_visibility=True` sin `visibility` ni callback.
- Preferir callbacks tipados en el componente comun:
  - `on_capability_scope_change: fn(CapabilityScope) -> msg`;
  - `on_type_filter_change: fn(Option(Int)) -> msg`;
  - `on_capability_filter_change: fn(Option(Int)) -> msg`;
  - `on_search_change: fn(String) -> msg`;
  - `on_visibility_change: fn(PoolVisibility) -> msg` solo cuando aplique.
- Si los mensajes existentes todavia reciben `String`, hacer la conversion en el adaptador de cada superficie, no dentro de varias vistas.
- Usar pattern matching exhaustivo para politica de superficie. No dejar `_ ->` en decisiones de visibilidad de filtros si existen variantes conocidas.
- Mantener tipos de dominio existentes (`CapabilityScope`, `TaskType`, `Capability`, `ViewMode`, `PlanMode`, `PoolVisibility`) en la API publica. No crear aliases UI que dupliquen esos conceptos.

Tipos recomendados para `work_filters_bar`:

```gleam
pub type RenderMode {
  FullBar
  RefinementControls
}

pub type VisibilityControl(msg) {
  NoVisibilityControl
  PoolVisibilityControl(
    visibility: pool_visibility.Visibility,
    on_change: fn(pool_visibility.Visibility) -> msg,
  )
}

pub type WorkFilterControls {
  WorkFilterControls(
    search: Bool,
    task_type: Bool,
    capability: Bool,
    capability_scope: Bool,
  )
}
```

Si al implementarlo se ve que los `Bool` de `WorkFilterControls` generan demasiadas combinaciones, elevarlos a variantes de superficie:

```gleam
pub type WorkFilterSurface {
  PoolSurface
  CapabilityBoardSurface
  ExecutionKanbanSurface
  PlanKanbanSurface
}
```

El criterio es pragmatico: usar ADT cuando reduzca estados invalidos reales; no crear un framework generico.

### Lustre

- `work_filters_bar` debe ser un componente simple de funciones `view`, sin `Model`, `Msg` ni efectos propios.
- El componente debe ser controlado por el padre: recibe valores actuales y callbacks, renderiza, y no guarda estado local.
- Los eventos DOM (`on_input`, `on_change`, `on_click`) deben transformarse a mensajes tipados en el borde mas cercano al componente.
- Las listas dinamicas de opciones de tipo/capacidad deben renderizarse con orden estable. Si el render usa nodos dinamicos con identidad relevante, usar rendering keyed.
- El control segmentado debe cumplir accesibilidad minima:
  - label visible o `aria-label`;
  - `aria-pressed` en cada opcion;
  - `type="button"` en botones;
  - foco visible por CSS comun;
  - `disabled`/estado inerte si en el futuro se bloquea por carga.
- No crear IDs hardcodeados reutilizables si puede haber mas de una barra en pantalla. Los `id` deben derivar de un prefijo estable de config; los `data-testid` pueden ser canonicos.

### Testing Gleam

- Usar `let assert`, no `gleeunit/should`.
- Reutilizar constructores y tipos de dominio en fixtures; no crear fixtures que representen tareas/capacidades con estructuras paralelas.
- Priorizar tests puros para politica y filtrado, y tests de render pequenos para HTML/testids/accesibilidad.
- Evitar snapshots grandes. Si se usa Birdie para HTML, las snapshots quedan sujetas a revision humana; no deben ser la unica prueba del comportamiento.
- Cada paquete debe cubrir:
  - happy path;
  - edge case relevante;
  - ausencia de estado invalido;
  - regresion del comportamiento anterior que se elimina;
  - contrato DRY: el comportamiento vive en una funcion/componente comun, no duplicado.

## Paquetes de trabajo detallados

Estos paquetes convierten la decision de producto en cambios ejecutables por componente. El orden importa: primero se crea el componente comun y su contrato; despues se migran superficies; por ultimo se limpian rutas, tests, i18n y CSS.

### Paquete 0: contrato de filtros de trabajo

Impacto: alto. Sin este paquete, cada vista puede interpretar `scope`, `type`, `cap` y `search` de forma distinta.

Archivos a revisar o tocar:

- `apps/client/src/scrumbringer_client/features/work_filters.gleam`;
- `apps/client/src/scrumbringer_client/capability_scope.gleam`;
- `apps/client/src/scrumbringer_client/client_state/member/pool.gleam`;
- `apps/client/src/scrumbringer_client/url_state.gleam`;
- `apps/client/test/capability_scope_test.gleam`;
- `apps/client/test/url_state_test.gleam`;
- `apps/client/test/pool_filters_test.gleam`;
- `apps/client/test/pool_available_tasks_test.gleam`.

Cambios:

- declarar explicitamente que los filtros de trabajo son:
  - `type_filter`;
  - `capability_filter`;
  - `search_query`;
  - `capability_scope`;
  - `my_capability_ids`;
  - `task_types` solo como dato auxiliar para resolver capacidad desde tipo de tarea.
- mantener `features/work_filters.gleam` como unica fuente de verdad para decidir si una tarea cumple esos filtros;
- prohibir que una vista replique la logica de `scope=mine` con comparaciones locales;
- documentar que `capability_scope=AllCapabilities` no significa permiso global: significa "todo el trabajo visible en esta superficie";
- documentar que `capability_scope=MyCapabilities` es filtro visual/frontend sobre el trabajo ya visible.

Tests:

- mantener tests puros de `work_filters.matches`;
- anadir un caso que cubra tarea sin capacidad cuando `scope=mine`;
- anadir un caso que cubra tarea cuyo `task_type.capability_id` pertenece a `my_capability_ids`;
- revisar que los tests no presenten la restriccion backend como si fuera el filtro visual.

Criterio de salida:

- cualquier superficie que filtre tareas por capacidad llama a `work_filters.matches` o recibe ya una lista filtrada por esa funcion;
- no aparece logica local equivalente a `list.contains(my_capability_ids, capability_id)` en vistas.

### Paquete 1: componente `features/work_filters_bar.gleam`

Impacto: alto. Este paquete concentra lenguaje visual, accesibilidad y testids.

Archivo nuevo:

- `apps/client/src/scrumbringer_client/features/work_filters_bar.gleam`.

Archivos relacionados:

- `apps/client/src/scrumbringer_client/ui/filter_bar.gleam`;
- `apps/client/src/scrumbringer_client/i18n/text.gleam`;
- `apps/client/src/scrumbringer_client/i18n/i18n.gleam`;
- estilos donde vivan `filter-bar`, `plan-filter-control`, `scope-toggle` o equivalentes;
- nuevo test `apps/client/test/work_filters_bar_test.gleam`.

API propuesta:

- `pub type Config(msg)`;
- `pub fn view_bar(config: Config(msg)) -> Element(msg)`;
- `pub fn view_refinement_controls(config: Config(msg)) -> List(Element(msg))`;
- `pub fn view_capability_scope_control(config: Config(msg)) -> Element(msg)`.

Config minima:

- `locale`;
- `task_types`;
- `capabilities`;
- `type_filter`;
- `capability_filter`;
- `search_query`;
- `capability_scope`;
- `controls` o `surface`, segun se decida entre flags simples y ADT;
- `visibility_control`, con variante `NoVisibilityControl` o `PoolVisibilityControl`;
- `on_type_filter_change: fn(Option(Int)) -> msg`;
- `on_capability_filter_change: fn(Option(Int)) -> msg`;
- `on_search_change: fn(String) -> msg`;
- `on_capability_scope_change: fn(CapabilityScope) -> msg`.

Cambios:

- componer `ui/filter_bar.gleam` para busqueda/selects si la API encaja sin retorcerla;
- implementar el control segmentado `Capacidades [Todas | Mias]` una sola vez;
- usar `aria-pressed` en botones segmentados;
- usar grupo con label accesible para el scope;
- emitir callbacks tipados desde el componente comun;
- si el estado existente todavia espera strings, convertir en el adaptador de superficie;
- no introducir estado local;
- aceptar una configuracion de controles que evite listas condicionales a mano en cada vista;
- mantener `view_capability_scope_control` pequeno y testeable.

`data-testid` canonicos:

- `work-filter-bar`;
- `work-filter-search`;
- `work-filter-type`;
- `work-filter-capability`;
- `work-filter-capability-scope`;
- `work-filter-capability-scope-all`;
- `work-filter-capability-scope-mine`;
- `work-filter-visibility`.

Tests:

- renderiza label `Capacidades` y opciones `Todas` / `Mias`;
- marca `Mias` con `aria-pressed="true"` cuando `capability_scope=MyCapabilities`;
- marca `Todas` con `aria-pressed="true"` por defecto;
- no renderiza busqueda si `show_search=False`;
- no renderiza tipo si `show_type=False`;
- no renderiza capacidad si `show_capability=False`;
- no renderiza visibilidad si `show_pool_visibility=False`;
- conserva los valores seleccionados en selects;
- `view_refinement_controls` devuelve controles sin envolverlos en una segunda barra visual incompatible con `plan_scope_bar`;
- los testids `work-filter-*` aparecen una sola vez en un render normal.

Criterio de salida:

- el unico render de `AllCapabilities` / `MyCapabilities` como control visual vive en `work_filters_bar`;
- las vistas solo configuran que controles mostrar y que callbacks usar.

### Paquete 2: Pool como adaptador de superficie

Impacto: alto. Pool tiene hoy la implementacion local mas completa y debe convertirse en consumidor del componente comun.

Archivos a tocar:

- `apps/client/src/scrumbringer_client/features/pool/control_bar.gleam`;
- `apps/client/src/scrumbringer_client/features/pool/view_config.gleam`;
- `apps/client/test/pool_control_bar_test.gleam`;
- tests de composicion Pool que dependan de `pool-filter-*`.

Cambios:

- sustituir render local de busqueda, tipo, capacidad, scope y visibilidad por `work_filters_bar.view_bar`;
- mantener en `control_bar.gleam` solo la composicion propia de Pool:
  - wrapper `pool-control-bar`;
  - toggle `Lienzo / Lista`;
  - adaptacion desde `control_bar.Config` hacia `work_filters_bar.Config`.
- eliminar `view_capability_scope_filter`;
- eliminar `view_scope_button`;
- eliminar clases CSS que solo existan para esos renders locales si no las usa el componente comun;
- durante una fase corta, se pueden mantener aliases `pool-filter-*` solo si evita un cambio masivo de tests, pero no deben quedar como API final.

Tests:

- `pool_control_bar_renders_pool_owned_work_filters_test` debe pasar a validar `work-filter-search`, `work-filter-type`, `work-filter-capability`, `work-filter-capability-scope`;
- mantener test de `pool-view-mode-toggle`, porque no pertenece al componente comun;
- anadir test de que `work-filter-visibility` se renderiza en Pool;
- anadir test de que `pool-filter-capability-scope` ya no aparece cuando se retire el alias.

Criterio de salida:

- Pool muestra el mismo control reversible que el resto de superficies;
- `features/pool/control_bar.gleam` no contiene logica visual de `AllCapabilities` / `MyCapabilities`.

### Paquete 3: vista Capacidades

Impacto: alto. Es la superficie con el problema original: boton unidireccional y estado no visible.

Archivos a tocar:

- `apps/client/src/scrumbringer_client/features/capability_board/view.gleam`;
- `apps/client/test/capability_board_view_test.gleam`;
- i18n y estilos del boton antiguo si quedan sin uso.

Cambios:

- eliminar `view_my_capabilities_action`;
- retirar `data-testid="capability-my-capabilities-action"`;
- insertar `work_filters_bar.view_refinement_controls` dentro de `plan_scope_bar` mediante `refinement_controls`;
- conservar los controles propios actuales de tipo, capacidad, busqueda y cerradas, pero renderizados desde el componente comun cuando correspondan;
- mantener la cabecera libre de filtros de accion;
- no cambiar la logica de `matches_active_filters`: debe seguir delegando en `work_filters.matches`.

Orden recomendado de controles:

- tipo;
- capacidad;
- scope `Capacidades [Todas | Mias]`;
- busqueda;
- cerradas.

Tests:

- actualizar `capability_board_list_groups_tasks_by_capability_and_card_test` para esperar `work-filter-capability-scope`;
- anadir asercion negativa para `capability-my-capabilities-action`;
- en `capability_board_scope_mine_filters_to_my_capabilities_test`, anadir que `work-filter-capability-scope-mine` esta activo;
- cubrir que el usuario puede volver a `all` desde la misma superficie mediante el control renderizado.

Criterio de salida:

- no existe boton "Mis capacidades" en cabecera;
- si la vista aplica `capability_scope`, el control reversible esta visible en sus filtros.

### Paquete 4: Kanban de ejecucion

Impacto: alto. La vista filtra por `capability_scope`, pero hoy no muestra refinamiento de filtros de trabajo.

Archivos a tocar:

- `apps/client/src/scrumbringer_client/features/views/kanban_board.gleam`;
- `apps/client/src/scrumbringer_client/client_view.gleam`;
- `apps/client/test/kanban_board_test.gleam`;
- `apps/client/test/kanban_task_item_test.gleam` si necesita actualizar config;
- tests nuevos o existentes de render Kanban.

Cambios:

- ampliar `KanbanConfig` con callbacks de filtros de trabajo:
  - `on_type_filter_change`;
  - `on_capability_filter_change`;
  - `on_search_change`;
  - `on_capability_scope_change`.
- construir `work_filters_bar.view_refinement_controls` en `view_scope_bar`;
- pasar esos controles a `scope_bar.Config.refinement_controls`;
- mantener `show_closed_control=True` como control estructural propio;
- no mezclar el scope estructural de plan con el scope de capacidades.

Tests:

- cuando `capability_scope=MyCapabilities`, `work-filter-capability-scope-mine` aparece y esta activo;
- cuando se renderiza Kanban, existen `work-filter-type`, `work-filter-capability` y `work-filter-search`;
- los callbacks nuevos se cablean desde `client_view.gleam` sin crear estado paralelo;
- mantener tests de filtrado de tareas en Kanban.

Criterio de salida:

- una URL con `scope=mine` no deja Kanban filtrado sin control visible;
- `KanbanConfig` no solo recibe valores de filtros, tambien recibe callbacks para modificarlos.

### Paquete 5: Plan Kanban

Impacto: alto. Comparte componente Kanban, pero la politica de URL y refresco debe ser explicita.

Archivos a tocar:

- `apps/client/src/scrumbringer_client/features/views/kanban_board.gleam`;
- `apps/client/src/scrumbringer_client/client_view.gleam`;
- `apps/client/test/plan_kanban_view_test.gleam`;
- tests de ruta que cubran `mode=kanban`.

Decision:

- Plan Kanban mantiene los filtros de trabajo visibles y aplicados;
- no se debe ignorar `scope`, `type`, `cap` o `search` en esta superficie mientras esos parametros viajen en la URL member.

Cambios:

- usar el mismo `work_filters_bar.view_refinement_controls` que Kanban de ejecucion;
- asegurar que `purpose=PlanKanban` no desactiva el scope de capacidades;
- mantener controles estructurales de plan (`Proyecto / Nivel / Tarjeta`, card search, cerradas) separados de filtros de trabajo.

Tests:

- `plan_kanban_view_test.gleam` debe comprobar `work-filter-capability-scope`;
- anadir caso con `capability_scope=MyCapabilities` y `my_capability_ids` para validar render + filtrado;
- comprobar que `mode=kanban&scope=mine` produce una vista con control reversible.

Criterio de salida:

- Plan Kanban y Kanban de ejecucion comparten el mismo patron visual para filtros de trabajo;
- la diferencia entre ambos queda en `purpose`, no en un segundo render de filtros.

### Paquete 6: Plan estructura

Impacto: medio-alto. No debe mostrar scope de capacidades, pero tampoco debe aplicar filtros invisibles de trabajo.

Archivos a tocar:

- `apps/client/src/scrumbringer_client/features/plan/structure_view.gleam`;
- `apps/client/src/scrumbringer_client/features/pool/member_refresh_filters.gleam`;
- `apps/client/src/scrumbringer_client/client_update.gleam`;
- `apps/client/test/member_refresh_filters_test.gleam`;
- tests de Plan estructura si existen o se anaden.

Problema actual:

- `member_refresh_filters.task_filters` recibe `view_mode.Cards`, no el `plan_mode`;
- por tanto puede enviar `type`, `cap` y `q` al backend tanto para Plan Kanban como para Plan estructura;
- `structure_view.gleam` usa `search_query` como busqueda/chip contextual de tarjetas, no como busqueda de tareas;
- esto puede dejar filtros de trabajo aplicados sin control visual en Plan estructura.

Cambios:

- introducir una politica explicita de refresco para distinguir:
  - Pool;
  - Capacidades;
  - Plan Kanban;
  - Plan estructura;
  - People.
- para Plan estructura, no enviar filtros de trabajo (`type`, `cap`, `q`) al refrescar tareas, salvo que se decida mostrar controles equivalentes;
- separar la busqueda contextual de Plan estructura de `member_filters_q`, o retirar el chip si no hay control visible que lo gobierne;
- mantener `scope_bar` estructural y sus filtros propios (`Estado`, `Orden`, `Cerradas`);
- no renderizar `work-filter-capability-scope` en Plan estructura.

Tests:

- `member_refresh_filters_test.gleam` debe cubrir Plan estructura como caso distinto de Plan Kanban;
- Plan estructura no renderiza `work-filter-capability-scope`;
- Plan estructura no aplica `capability_scope=MyCapabilities`;
- si conserva busqueda de tarjetas, esa busqueda tiene estado/testid propio y no usa `work-filter-search`.

Criterio de salida:

- Plan estructura no muestra ni aplica filtros de trabajo invisibles;
- `member_filters_q` deja de tener doble significado en esta superficie.

### Paquete 7: politica de rutas member y navegacion entre superficies

Impacto: alto. La UI puede estar unificada y aun asi perder o conservar filtros de forma incoherente al navegar.

Archivos a tocar:

- `apps/client/src/scrumbringer_client/features/layout/left_panel_data.gleam`;
- `apps/client/src/scrumbringer_client/features/pool/view_mode_update.gleam`;
- `apps/client/src/scrumbringer_client/client_update.gleam`;
- `apps/client/src/scrumbringer_client/url_state.gleam`;
- `apps/client/test/left_panel_data_test.gleam`;
- `apps/client/test/pool_view_mode_update_test.gleam`;
- `apps/client/test/router_test.gleam`;
- `apps/client/test/url_state_test.gleam`.

Problema actual:

- `left_panel_data.member_state` preserva `scope`, `type`, `cap` y `search`;
- `view_mode_update.view_mode_changed` y `plan_mode_changed` reconstruyen rutas desde `url_state.empty()` con proyecto/vista/modo, perdiendo filtros;
- `client_update.current_route` serializa filtros member de forma amplia y luego depende de reglas de URL para omitir algunos parametros.

Cambios:

- crear una funcion pura de politica member que reciba estado actual, destino y plan mode;
- usar esa politica tanto en `left_panel_data` como en `view_mode_update`;
- preservar filtros de trabajo entre Pool, Capacidades, Kanban y Plan Kanban;
- limpiar filtros de trabajo al entrar en Plan estructura si no se muestran alli;
- no aplicar `scope=mine` a People;
- mantener `card_depth` y `card_work_scope` solo en superficies donde existan controles estructurales visibles.

Tests:

- `ViewModeChanged(Capabilities)` preserva `scope=mine`, `type`, `cap` y `search`;
- `MemberPlanModeChanged("kanban")` preserva esos filtros;
- `MemberPlanModeChanged("structure")` limpia o separa filtros de trabajo segun la decision del Paquete 6;
- las rutas derivadas por panel lateral y por cambio de modo coinciden para el mismo destino.

Criterio de salida:

- no hay dos politicas de URL member divergentes;
- ningun filtro queda aplicado tras navegar a una vista que no lo renderiza.

### Paquete 8: cambio de proyecto y filtros dependientes de proyecto

Impacto: medio. Evita estados obsoletos cuando cambian tipos, capacidades o tarjetas.

Archivos a tocar:

- `apps/client/src/scrumbringer_client/client_update.gleam`;
- `apps/client/src/scrumbringer_client/client_state/member/pool.gleam`;
- tests de cambio de proyecto o nuevos tests especificos.

Riesgo actual:

- al cambiar de proyecto, los recursos se recargan, pero algunos filtros seleccionados pueden seguir apuntando a IDs del proyecto anterior;
- el codigo limpia `member_filters_type_id` cuando no hay proyecto, pero el cambio A -> B necesita una politica igual de clara.

Cambios:

- al cambiar de proyecto, limpiar:
  - `member_filters_type_id`;
  - `member_filters_capability_id`;
  - `member_card_depth_filter`;
  - `member_plan_scope_card_id`;
  - cualquier seleccion de tarjeta abierta que pertenezca al proyecto anterior.
- decidir si `member_capability_scope` se conserva como preferencia de usuario o vuelve a `AllCapabilities`;
- si se conserva `MyCapabilities`, mostrar estado de carga/empty correcto mientras llegan `my_capability_ids`.

Tests:

- cambio de proyecto A -> B elimina filtros por tipo/capacidad antiguos;
- cambio de proyecto no deja `card` o `work_scope_card` apuntando a IDs anteriores;
- si se conserva `scope=mine`, la vista muestra el control activo y no falla con capacidades aun no cargadas.

Criterio de salida:

- no quedan filtros por IDs de proyecto anterior tras seleccionar otro proyecto.

### Paquete 9: normalizacion de busqueda

Impacto: medio. Reduce diferencias sutiles entre URL, frontend y backend.

Archivos a tocar:

- `apps/client/src/scrumbringer_client/helpers/options.gleam`;
- `apps/client/src/scrumbringer_client/features/pool/filters.gleam`;
- `apps/client/src/scrumbringer_client/features/work_filters.gleam`;
- servidor: parser de filtros de tareas si aplica;
- tests de filtros y URL.

Problema actual:

- `helpers/options.empty_to_opt` decide con `string.trim(value)`, pero devuelve `Some(value)` sin trim;
- `work_filters.matches` normaliza busqueda para comparar;
- el backend puede recibir espacios si el valor original no se normaliza antes.

Cambios:

- crear helper explicito `search_to_opt` o ajustar `empty_to_opt` solo si no rompe otros usos;
- almacenar o serializar busquedas trimmeadas;
- evitar que `" bug "` y `"bug"` generen URLs o requests distintas;
- no duplicar normalizacion en cada vista.

Tests:

- `empty_to_opt("   ") == None`;
- el nuevo helper devuelve `Some("bug")` para `" bug "`;
- URL serializada no conserva espacios laterales;
- refresh backend recibe `q=Some("bug")`, no `Some(" bug ")`.

Criterio de salida:

- busqueda se normaliza una sola vez en el borde de estado/URL/API.

### Paquete 10: API cliente de capacidades de miembro

Impacto: medio. Mejora DRY, pero puede separarse si amenaza el refactor visual.

Archivos a revisar:

- `apps/client/src/scrumbringer_client/api/projects.gleam`;
- `apps/client/src/scrumbringer_client/api/tasks/capabilities.gleam`;
- llamadas desde admin/asignaciones;
- llamadas desde flujo de "mis capacidades";
- tests API o de update que dependan de esos wrappers.

Problema actual:

- dos modulos llaman al mismo endpoint;
- un wrapper devuelve `MemberCapabilities`;
- el otro devuelve `List(Int)`.

Decision recomendada:

- escoger un modulo canonico `api/member_capabilities.gleam` o mantener uno de los existentes y eliminar el otro;
- definir contrato canonico:
  - para lectura personal puede exponerse helper que devuelva `List(Int)`;
  - internamente el contrato completo puede seguir siendo `MemberCapabilities` si admin necesita `user_id`.

Tests:

- ambos flujos siguen leyendo/escribiendo los mismos IDs;
- no se rompe admin;
- no se rompe la carga de `my_capability_ids` usada por `scope=mine`.

Criterio de salida:

- solo queda un wrapper HTTP canonico para el endpoint;
- si no se ejecuta en este refactor, queda issue/follow-up explicito con motivo.

### Paquete 11: i18n, CSS y deuda visual

Impacto: medio. Este paquete cierra el objetivo de lenguaje visual unificado.

Archivos a tocar:

- `apps/client/src/scrumbringer_client/i18n/text.gleam`;
- `apps/client/src/scrumbringer_client/i18n/i18n.gleam`;
- estilos de Pool, Plan, Capability Board y filtros comunes;
- tests que validan textos/testids antiguos.

Cambios:

- anadir `CapabilityScopeLabel`, `ScopeAll`, `ScopeMine` si no existen;
- retirar `MyCapabilitiesOn`, `MyCapabilitiesOff`, `MyCapabilitiesHint` cuando no queden referencias;
- revisar `MyCapabilitiesLabel` antes de borrarlo;
- mover estilos reutilizables del scope segmentado a una ubicacion comun;
- evitar variantes visuales por superficie para el mismo control;
- mantener densidad compacta y tono operativo segun `PRODUCT.md` / `DESIGN.md`.

Tests:

- busqueda `rg "MyCapabilitiesOn|MyCapabilitiesOff|MyCapabilitiesHint" apps/client/src apps/client/test` sin referencias;
- tests de render no dependen de textos obsoletos;
- `work-filter-capability-scope` mantiene la misma estructura en Pool, Capacidades, Kanban y Plan Kanban.

Criterio de salida:

- una sola nomenclatura visual y textual para el scope de capacidades.

### Paquete 12: validacion final y evidencias

Impacto: alto. Garantiza que el plan cumple los objetivos de UI, DRY y testeabilidad.

Comandos minimos:

- `cd apps/client && gleam test`;
- `cd apps/server && gleam test` o tests backend relevantes de visibilidad;
- `rg "capability-my-capabilities-action|view_my_capabilities_action|view_capability_scope_filter|view_scope_button" apps/client/src apps/client/test`;
- `rg "work-filter-capability-scope" apps/client/src apps/client/test`.

Validacion visual:

- Pool con `scope=mine`;
- Capacidades con `scope=mine`;
- Kanban de ejecucion con `scope=mine`;
- Plan Kanban con `scope=mine`;
- Plan estructura con una URL que incluya `scope=mine`, verificando que no aplica ni muestra ese filtro.

Evidencias a registrar al cerrar:

- funciones eliminadas;
- componentes nuevos;
- tests nuevos;
- tests actualizados;
- i18n eliminado;
- CSS eliminado;
- decision final sobre API cliente;
- decision final sobre conservacion o reseteo de `member_capability_scope` al cambiar de proyecto.

## Criterios de aceptacion por paquete

Estos criterios deben evaluarse al cerrar cada paquete. Si un paquete se divide en PRs, cada PR debe declarar que criterios cubre y cuales quedan pendientes.

### Paquete 0: contrato de filtros de trabajo

Calidad de codigo:

- `work_filters.Filters` sigue siendo el contrato central para filtrado de trabajo.
- Los casos sobre `CapabilityScope` se resuelven con pattern matching exhaustivo.
- No se introducen catch-all `_` en decisiones donde las variantes son conocidas.

DRY:

- No aparece una segunda implementacion de `scope=mine` fuera de `features/work_filters.gleam`.
- Cualquier helper nuevo vive junto al contrato comun, no en una vista.

Testeabilidad:

- Tests puros cubren `AllCapabilities`, `MyCapabilities`, tarea sin capacidad, tarea con capacidad directa y tarea cuya capacidad viene de `TaskType`.
- Los tests usan `let assert` y fixtures con tipos de dominio reales.

### Paquete 1: `work_filters_bar`

Calidad de codigo:

- El componente es stateless: no define `Model`, `Msg`, `init`, `update` ni efectos.
- La config no permite `PoolVisibilityControl` incompleto.
- Los callbacks publicos son tipados o la conversion `String -> tipo` queda encapsulada en un unico adaptador.
- Las funciones publicas tienen anotacion de tipo clara y documentan la intencion.

DRY:

- El render de `Capacidades [Todas | Mias]` existe una sola vez.
- Busqueda/selects reutilizan `ui/filter_bar.gleam` si reduce duplicacion sin forzar la semantica.
- No se crea una segunda utilidad generica de formularios.

Testeabilidad:

- `work_filters_bar_test.gleam` cubre render completo, controles sueltos y control de scope aislado.
- Se valida accesibilidad minima: `aria-pressed`, `type="button"`, label/testid estable.
- Se prueba ausencia de controles desactivados y presencia de controles activados.

### Paquete 2: Pool

Calidad de codigo:

- `features/pool/control_bar.gleam` queda como adaptador fino de superficie.
- El toggle `Lienzo / Lista` permanece fuera de `work_filters_bar`.
- Conversiones de eventos de filtro estan en un punto, no repartidas entre helpers privados.

DRY:

- Se eliminan `view_capability_scope_filter` y `view_scope_button`.
- Los testids finales de filtros de trabajo usan `work-filter-*`.

Testeabilidad:

- Tests de Pool validan que el adaptador pasa valores al componente comun.
- Tests de Pool siguen cubriendo visibilidad y toggle de vista como comportamiento propio.
- Hay asercion negativa para el namespace antiguo cuando se retire el alias.

### Paquete 3: Capacidades

Calidad de codigo:

- La cabecera no contiene filtros de accion.
- `capability_board.view` no replica parsing ni render de filtros de trabajo.
- El filtrado sigue delegando en `work_filters.matches`.

DRY:

- Se elimina `view_my_capabilities_action`.
- Se eliminan testids/clases exclusivas del boton antiguo si quedan sin uso.

Testeabilidad:

- Tests de vista prueban que el control reversible esta visible cuando `scope=mine`.
- Tests de comportamiento prueban que el contenido se filtra por `my_capability_ids`.
- Tests negativos verifican que `capability-my-capabilities-action` ya no aparece.

### Paquete 4: Kanban de ejecucion

Calidad de codigo:

- `KanbanConfig` no queda en estado medio: si recibe filtros tambien recibe callbacks para modificarlos.
- Los controles de trabajo entran por `scope_bar.refinement_controls`.
- El scope estructural y el scope de capacidades quedan separados por tipos/nombres.

DRY:

- Kanban usa `work_filters_bar`, no una variante local del control.
- El filtrado de tareas sigue usando `work_filters.matches`.

Testeabilidad:

- Test de render cubre `scope=mine` activo y posibilidad visual de volver a `all`.
- Test de comportamiento cubre filtrado por capacidad en Kanban.
- Test de configuracion o integracion cubre cableado desde `client_view`.

### Paquete 5: Plan Kanban

Calidad de codigo:

- La diferencia entre Plan Kanban y Kanban de ejecucion esta modelada por `KanbanPurpose`.
- `PlanKanban` no tiene ramas especiales que dupliquen controles de trabajo.

DRY:

- Comparte el mismo constructor de refinamientos de filtros que Kanban de ejecucion.
- No hay testids `plan-kanban-filter-*` para controles que ya tienen `work-filter-*`.

Testeabilidad:

- Tests cubren render y filtrado con `capability_scope=MyCapabilities`.
- Tests de URL cubren `mode=kanban&scope=mine`.
- Tests verifican que el control comun esta visible en la vista filtrada.

### Paquete 6: Plan estructura

Calidad de codigo:

- La politica de refresco distingue `PlanStructure` de `PlanKanban` con tipos, no con strings sueltos.
- `member_filters_q` deja de tener doble significado o queda documentado y aislado hasta su separacion.
- Plan estructura no interpreta `capability_scope`.

DRY:

- No se crea un segundo sistema de busqueda de trabajo oculto.
- La busqueda de tarjetas, si existe, tiene contrato propio.

Testeabilidad:

- Tests puros de `member_refresh_filters` cubren People, Pool, Capabilities, Plan Kanban y Plan estructura.
- Test de render verifica ausencia de `work-filter-capability-scope`.
- Test de ruta confirma que una URL con `scope=mine` no deja filtro invisible aplicado en Plan estructura.

### Paquete 7: rutas member

Calidad de codigo:

- Existe una unica funcion pura para derivar rutas member con filtros.
- `left_panel_data` y `view_mode_update` usan esa misma politica.
- Pattern matching exhaustivo sobre destino de navegacion y `PlanMode`.

DRY:

- No hay dos construcciones paralelas de `UrlState` para la misma navegacion member.
- La preservacion/limpieza de filtros vive en un modulo de politica, no en handlers dispersos.

Testeabilidad:

- Tests comparan rutas generadas desde panel lateral y cambio de modo.
- Tests cubren preservar filtros en superficies que los muestran.
- Tests cubren limpiar o separar filtros al entrar en superficies que no los muestran.

### Paquete 8: cambio de proyecto

Calidad de codigo:

- La limpieza de IDs dependientes de proyecto se implementa en una funcion pura testeable.
- La decision sobre conservar o resetear `member_capability_scope` queda explicitada en codigo y tests.

DRY:

- No se repite limpieza de filtros en varios handlers de cambio de proyecto.
- Los mismos helpers sirven para ruta inicial, cambio de proyecto y reset de proyecto.

Testeabilidad:

- Tests cubren cambio A -> B, proyecto -> none y none -> proyecto.
- Tests verifican que IDs de tipo/capacidad/tarjeta anteriores no sobreviven.
- Tests cubren el caso `scope=mine` durante recarga de capacidades personales.

### Paquete 9: normalizacion de busqueda

Calidad de codigo:

- La normalizacion se hace en un helper con nombre semantico, por ejemplo `search_to_opt`.
- No se cambia `empty_to_opt` si tiene usos no relacionados que requieran conservar espacios.

DRY:

- URL, refresh API y filtros frontend usan el mismo helper o una capa comun.
- No hay `string.trim` repetidos en vistas.

Testeabilidad:

- Tests cubren string vacio, espacios, valor con espacios laterales y valor interno con espacios significativos.
- Tests cubren serializacion de URL y request backend.
- Tests mantienen comportamiento de busqueda en `work_filters.matches`.

### Paquete 10: API cliente de capacidades de miembro

Calidad de codigo:

- El contrato canonico se decide antes de mover llamadas.
- Si se usa un modulo nuevo, los anteriores quedan como wrappers transitorios o se eliminan en el mismo paquete.

DRY:

- Solo queda un punto canonico para construir requests al endpoint de capacidades de miembro.
- No quedan dos decoders equivalentes para el mismo payload.

Testeabilidad:

- Tests cubren lectura y escritura desde admin.
- Tests cubren lectura y escritura desde flujo personal si sigue vivo.
- Tests verifican que `my_capability_ids` sigue alimentando `scope=mine`.

### Paquete 11: i18n, CSS y deuda visual

Calidad de codigo:

- Las claves i18n expresan semantica de filtro, no accion.
- Los estilos comunes no dependen del nombre de una superficie concreta.
- Los estados hover/focus/active/disabled se definen una vez.

DRY:

- No quedan estilos duplicados para el mismo segmented control.
- No quedan textos antiguos sin referencias.

Testeabilidad:

- Busquedas `rg` forman parte del cierre del paquete.
- Tests de render no dependen de clases internas cuando el testid comun basta.
- Validacion visual comprueba al menos Pool, Capacidades y una vista Kanban.

### Paquete 12: validacion final

Calidad de codigo:

- `gleam format --check` pasa en cliente y servidor si se tocaron ambos.
- No quedan warnings relevantes ni imports muertos.
- Los modulos nuevos tienen responsabilidades acotadas.

DRY:

- Las busquedas de funciones/testids antiguos no devuelven resultados.
- Las implementaciones comunes aparecen referenciadas por todas las superficies previstas.

Testeabilidad:

- `cd apps/client && gleam test` pasa.
- `cd apps/server && gleam test` o tests backend relevantes pasan.
- Cualquier snapshot nueva queda en estado revisado por humano antes de marcar el paquete como completo.

## Vistas afectadas

### Pool

Usar `work_filters_bar` para:

- busqueda;
- tipo;
- capacidad;
- scope `Todas / Mias`;
- visibilidad;
- mantener aparte el toggle de modo `Lienzo / Lista`, porque no es un filtro de trabajo.

Eliminar el render local de `view_capability_scope_filter` y `view_scope_button` de `features/pool/control_bar.gleam`.

`features/pool/control_bar.gleam` puede quedar como adaptador de la superficie Pool si sigue aportando el toggle `Lienzo / Lista`, pero la renderizacion de filtros de trabajo debe delegarse al componente comun.

### Capacidades

Eliminar el boton de cabecera `Mis capacidades`.

Renderizar el mismo scope `Todas / Mias` dentro del bloque de refinamiento/filtros junto a:

- tipo;
- capacidad;
- busqueda;
- cerradas.

La cabecera queda reservada para titulo, proposito y resumen; no para filtros unidireccionales.

### Kanban de ejecucion

La vista ya consume `capability_scope`, `type_filter`, `capability_filter` y `search_query`. Debe mostrar el mismo control de scope si el scope se aplica al filtrado.

Objetivo: si el usuario llega con `scope=mine`, ve `Capacidades [Todas | Mias]` y puede volver a `Todas`.

Como esta vista ya renderiza `plan/scope_bar.gleam`, insertar los filtros de trabajo mediante `refinement_controls` en lugar de reemplazar el scope estructural.

### Plan Kanban

Decision final: Plan Kanban mantiene el filtrado por `capability_scope` y debe mostrar `Capacidades [Todas | Mias]` dentro de `refinement_controls`.

Motivo: los parametros URL `scope`, `type`, `cap` y `search` se heredan al navegar entre superficies member. Si Plan Kanban ignorase `scope`, la misma URL tendria efectos distintos segun la vista. La opcion mas consistente es aplicar el filtro y hacerlo visible.

### Plan estructura

No mostrar el scope de capacidades. Actualmente no usa `capability_scope`, asi que mostrarlo seria ruido.

## Backend

No eliminar la restriccion de visibilidad de tareas por capacidades en `tasks_list.sql`.

Esa restriccion no es el filtro visual `Mias`; es una regla de visibilidad/autorizacion para miembros. Debe mantenerse mientras el modelo de producto limite lo que un miembro puede ver segun sus capacidades asignadas.

Lo que si debe limpiarse es la confusion en tests o nombres que presenten esa regla backend como si fuera el filtro UI.

## Limpieza de codigo

Eliminar o consolidar:

- `view_my_capabilities_action` en `features/capability_board/view.gleam`.
- `data-testid="capability-my-capabilities-action"` y tests asociados.
- Render duplicado de scope en `features/pool/control_bar.gleam`.
- Clases CSS solo necesarias para el boton antiguo si quedan sin uso.
- Textos i18n no usados tras la unificacion:
  - `MyCapabilitiesOn`;
  - `MyCapabilitiesOff`;
  - `MyCapabilitiesHint`;
  - revisar `MyCapabilitiesLabel`.

No eliminar en esta fase:

- `MySkills`;
- `MySkillsHelp`;
- estado o mensajes de edicion personal de capacidades.

La rama de edicion de capacidades personales sigue existiendo en `features/skills/update.gleam` y usa:

- `MemberToggleCapability`;
- `MemberSaveCapabilitiesClicked`;
- `MemberMyCapabilityIdsSaved`;
- `member_my_capability_ids_edit`;
- `member_my_capabilities_in_flight`;
- `member_my_capabilities_error`.

Esa limpieza queda como decision separada: solo eliminarla si una revision de rutas confirma que no hay UI viva que permita editar capacidades personales. Mientras tanto, mantener `member_my_capability_ids` como dato de lectura para filtrar y no romper el flujo de fetch/save existente.

### Limpieza API cliente

Existe duplicacion de wrappers API de capacidades de miembro:

- `api/projects.gleam` expone `get_member_capabilities` / `set_member_capabilities`;
- `api/tasks/capabilities.gleam` expone `get_member_capability_ids` / `put_member_capability_ids`;
- ambos llaman al mismo endpoint.

Propuesta para API cliente:

- crear o escoger un unico modulo canonico para capacidades de miembro;
- usarlo tanto en admin como en "mis capacidades";
- eliminar el modulo duplicado si queda sin referencias.

Condicion importante: los contratos actuales no son identicos. `api/projects.gleam` devuelve `MemberCapabilities`, mientras `api/tasks/capabilities.gleam` devuelve `List(Int)`. La unificacion debe decidir el contrato canonico antes de eliminar codigo. Esta limpieza puede hacerse despues de la unificacion visual si amenaza con ampliar demasiado el refactor.

## Fases de implementacion

### Fase 1: componente comun y Pool

- Crear `features/work_filters_bar.gleam`.
- Migrar el render de busqueda, tipo, capacidad, scope y visibilidad desde `features/pool/control_bar.gleam`.
- Mantener `Lienzo / Lista` en `control_bar.gleam`, fuera del componente comun.
- Añadir tests de componente para `work_filters_bar`.

### Fase 2: Capacidades

- Eliminar `view_my_capabilities_action`.
- Insertar `view_refinement_controls` junto a tipo, capacidad, busqueda y cerradas.
- Actualizar tests de `capability_board_view_test.gleam`.

### Fase 3: Kanban y Plan Kanban

- Insertar filtros de trabajo en `plan/scope_bar.gleam` mediante `refinement_controls`.
- Verificar que Kanban de ejecucion y Plan Kanban muestran `Capacidades [Todas | Mias]`.
- Mantener Plan estructura sin scope de capacidades.

### Fase 4: limpieza

- Eliminar CSS, i18n y tests del boton antiguo.
- Consolidar test ids hacia `work-filter-*`.
- Registrar las metricas de calidad finales descritas en esta seccion.
- Ejecutar suite cliente y tests backend relevantes.

### Fase 5 opcional: API cliente

- Unificar wrappers API de capacidades de miembro solo si se puede escoger un contrato canonico sin ampliar el riesgo del cambio visual.
- Si no se hace en este refactor, dejar un follow-up explicito.

## Metricas de calidad esperadas

Estas metricas validan que la unificacion mejora la base de codigo, no solo cambia la UI.

No usar lineas netas eliminadas como criterio principal. Una reduccion de lineas es bienvenida, pero el objetivo real es reducir duplicacion, eliminar codigo obsoleto y concentrar comportamiento testeable.

### Duplicacion eliminada

Al terminar, debe existir una sola implementacion renderizada del control `Capacidades [Todas | Mias]`.

Validar con busqueda:

- `view_capability_scope_filter` ya no existe en `features/pool/control_bar.gleam`;
- `view_scope_button` ya no existe en `features/pool/control_bar.gleam`;
- `view_my_capabilities_action` ya no existe en `features/capability_board/view.gleam`;
- `capability-my-capabilities-action` ya no aparece en codigo ni tests;
- el render de `aria-pressed` para `AllCapabilities` / `MyCapabilities` vive en `work_filters_bar`.

### Codigo obsoleto eliminado

Validar con busqueda que no quedan referencias vivas a:

- `MyCapabilitiesOn`;
- `MyCapabilitiesOff`;
- `MyCapabilitiesHint`;
- clases CSS exclusivas del boton antiguo `Mis capacidades`.

`MyCapabilitiesLabel` solo puede quedar si tiene un uso vivo fuera del control segmentado. `MySkills` y `MySkillsHelp` no se eliminan en este refactor.

### Testeabilidad mejorada

El cambio debe mover cobertura desde fragmentos de vista hacia el componente comun:

- crear tests unitarios de `work_filters_bar`;
- cubrir `view_capability_scope_control` directamente;
- cubrir que `view_refinement_controls` genera controles insertables en `plan_scope_bar`;
- actualizar tests de Pool, Capacidades, Kanban y Plan Kanban para validar presencia del control comun por `work-filter-*`.

Balance minimo:

- tests nuevos de componente >= 1 archivo nuevo de test;
- tests nuevos o actualizados sobre `work-filter-*` >= tests eliminados que solo cubrian el boton antiguo;
- mantener tests de comportamiento de `work_filters.matches` sin duplicar esa logica en tests de vista.

### Estado y API de filtros

La unificacion no debe introducir estado local duplicado.

Validar con revision o busqueda:

- no aparecen nuevos campos de estado para `capability_scope`, `type_filter`, `capability_filter` o `search_query`;
- los callbacks siguen escribiendo en el estado existente de `member.pool`;
- no se duplica la logica de filtrado de `features/work_filters.gleam` dentro de componentes de vista.

### Medicion de diffs

Al cerrar la implementacion, registrar en la descripcion del cambio:

- funciones eliminadas;
- tests eliminados o renombrados;
- tests nuevos;
- i18n eliminado;
- CSS eliminado;
- si se hizo o no la limpieza API opcional;
- balance aproximado de lineas modificadas, solo como dato informativo.

## Tests

### Nuevos tests de componente

Crear tests para `work_filters_bar`:

- renderiza `Capacidades`, `Todas` y `Mias`;
- marca la opcion activa con `aria-pressed`;
- genera `data-testid` estables;
- permite emitir `all` y `mine`;
- no renderiza controles desactivados por configuracion;
- puede renderizar controles sueltos/grupo de refinamiento para `plan_scope_bar`.

### Tests de vistas

Actualizar o añadir:

- Pool renderiza el scope desde el componente comun.
- Capacidades ya no renderiza `capability-my-capabilities-action`.
- Capacidades muestra `Todas` y `Mias` en filtros.
- Kanban muestra `Todas` y `Mias`.
- Plan Kanban muestra `Todas` y `Mias`.
- Plan estructura no muestra el scope de capacidades.
- Kanban y Plan Kanban no pueden aplicar `scope=mine` sin mostrar `data-testid` del control reversible.

### Tests de URL y navegacion

Agregar o actualizar cobertura para este flujo:

- abrir una URL member con `scope=mine`;
- navegar entre Pool, Capacidades, Kanban y Plan Kanban;
- confirmar que cada vista que aplica `scope=mine` muestra `work-filter-capability-scope-mine` activo;
- confirmar que Plan estructura no muestra `work-filter-capability-scope` y no aplica `capability_scope`.

### Tests de comportamiento

Mantener:

- `work_filters` filtra por `my_capability_ids` cuando el scope es `MyCapabilities`.
- Pool filtra tareas disponibles por `MyCapabilities`.
- Capacidades filtra por `MyCapabilities`.
- Kanban filtra por `MyCapabilities`.
- Plan Kanban filtra por `MyCapabilities`.

### Tests backend

Mantener la cobertura que garantiza que un miembro solo recibe tareas visibles segun capacidades asignadas.

Renombrar o ajustar descripcion si induce a confundir esta regla con el filtro visual del frontend.

## Criterios de finalizacion

- No existe ningun boton unidireccional "Mis capacidades".
- Toda vista que consume `capability_scope` muestra un control reversible `Todas / Mias`.
- Ninguna vista que no consume `capability_scope` muestra ese control.
- El componente comun cubre Pool, Capacidades y Kanban/Plan Kanban segun corresponda.
- `plan_scope_bar` sigue representando scope estructural; los filtros de trabajo se insertan como refinamientos.
- Navegar con `scope=mine` entre Pool, Capacidades, Kanban y Plan Kanban nunca deja al usuario en una vista filtrada sin control reversible visible.
- No quedan tests del boton antiguo.
- No quedan textos i18n sin uso derivados del boton antiguo.
- Se cumplen y quedan registradas las metricas de calidad esperadas: duplicacion eliminada, codigo obsoleto retirado, cobertura nueva del componente comun y ausencia de estado local duplicado.
- La duplicacion API queda eliminada solo si se decide y migra un contrato canonico sin ampliar el refactor de forma riesgosa; si no, queda registrada como follow-up explicito.
- La suite de cliente pasa.
- Los tests backend relevantes de visibilidad por capacidades siguen pasando.
- Validacion visual con agent-browser en:
  - `/app/pool?...&view=pool`;
  - `/app/pool?...&view=capabilities`;
  - `/app/pool?...&view=cards&mode=kanban` o ruta equivalente del Plan Kanban;
  - vista Kanban.

## Evidencias de ejecucion

Estado registrado tras la implementacion:

- componente comun creado: `apps/client/src/scrumbringer_client/features/work_filters_bar.gleam`;
- tests de componente creados: `apps/client/test/work_filters_bar_test.gleam`;
- vistas migradas al namespace `work-filter-*`: Pool, Capacidades, Kanban y Plan Kanban;
- Plan estructura mantiene ausencia explicita de `work-filter-capability-scope`;
- `member_refresh_filters` distingue `PlanStructureRefresh` de `PlanKanbanRefresh` con tipos;
- la navegacion preserva filtros de trabajo en superficies que los muestran y limpia `scope/type/cap` al volver a Plan estructura;
- i18n obsoleto del boton antiguo eliminado: `MyCapabilitiesOn`, `MyCapabilitiesOff`, `MyCapabilitiesHint`, `MyCapabilitiesLabel`;
- no se migro una API cliente canonica de capacidades de miembro; queda fuera del alcance porque no reduce riesgo del refactor visual.

Metricas reales del diff:

- funciones/render locales retirados de Pool: busqueda, tipo, capacidad, scope, botones de scope, visibilidad y conversion local de opcion;
- render local retirado de Capacidades: boton unidireccional "Mis capacidades" y controles sueltos de tipo/capacidad/busqueda;
- codigo obsoleto buscado sin resultados en `apps/client/src apps/client/test`: `capability-my-capabilities-action`, `view_my_capabilities_action`, `view_capability_scope_filter`, `view_scope_button`, `pool-filter-capability-scope`, `MyCapabilitiesOn`, `MyCapabilitiesOff`, `MyCapabilitiesHint`, `MyCapabilitiesLabel`;
- tests nuevos o ampliados: `work_filters_bar_test`, `member_refresh_filters_test`, `pool_view_mode_update_test`, y aserciones `work-filter-*` en Pool, Capacidades, Kanban y Plan Kanban;
- balance aproximado de implementacion cliente sin docs: 405 inserciones y 309 eliminaciones en archivos existentes, mas 500 lineas nuevas entre componente y test de componente.

Validaciones ejecutadas:

- `cd apps/client && gleam format --check src test`;
- `cd apps/client && gleam check`;
- `cd apps/client && gleam test --target javascript`: 1856 tests pasan;
- `cd apps/server && gleam format --check src test`;
- `cd apps/server && gleam check`;
- `git diff --check`.

Validaciones no completadas por entorno:

- `cd apps/server && gleam test` no pudo completarse porque falta `DATABASE_URL`;
- `cd apps/client && gleam test --target erlang` no aplica al cliente porque el paquete usa target JavaScript y FFI DOM/JS sin implementacion Erlang;
- la validacion visual con agent-browser requiere runtime autenticado y backend con base de datos; queda pendiente de un entorno con `DATABASE_URL` y servidor levantado.
