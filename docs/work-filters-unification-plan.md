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

### Plan Kanban

Revisar si debe heredar el filtro de capacidades.

Decision preferente:

- si Plan Kanban mantiene `capability_scope`, debe mostrar el mismo control;
- si el filtro no encaja con el objetivo de Plan Kanban, dejar de aplicarlo ahi.

No debe quedar en un estado intermedio donde el filtro afecta pero no se ve.

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
  - revisar `MySkills` y `MySkillsHelp`.
- Duplicacion de wrappers API de capacidades de miembro:
  - `api/projects.gleam` expone `get_member_capabilities` / `set_member_capabilities`;
  - `api/tasks/capabilities.gleam` expone `get_member_capability_ids` / `put_member_capability_ids`;
  - ambos llaman al mismo endpoint.

Propuesta para API cliente:

- crear o escoger un unico modulo canonico para capacidades de miembro;
- usarlo tanto en admin como en "mis capacidades";
- eliminar el modulo duplicado si queda sin referencias.

Revisar si sigue existiendo una vista viva para editar "mis capacidades" personales:

- `MemberToggleCapability`;
- `MemberSaveCapabilitiesClicked`;
- `MemberMyCapabilityIdsSaved`;
- `member_my_capability_ids_edit`;
- `member_my_capabilities_in_flight`;
- `member_my_capabilities_error`.

Si no hay UI viva que use esa edicion personal, eliminar esa rama y mantener solo `member_my_capability_ids` como dato de lectura necesario para filtrar.

## Tests

### Nuevos tests de componente

Crear tests para `work_filters_bar`:

- renderiza `Capacidades`, `Todas` y `Mias`;
- marca la opcion activa con `aria-pressed`;
- genera `data-testid` estables;
- permite emitir `all` y `mine`;
- no renderiza controles desactivados por configuracion.

### Tests de vistas

Actualizar o añadir:

- Pool renderiza el scope desde el componente comun.
- Capacidades ya no renderiza `capability-my-capabilities-action`.
- Capacidades muestra `Todas` y `Mias` en filtros.
- Kanban muestra `Todas` y `Mias` si consume `capability_scope`.
- Plan Kanban muestra `Todas` y `Mias` solo si mantiene el filtrado por capacidades.
- Plan estructura no muestra el scope de capacidades.

### Tests de comportamiento

Mantener:

- `work_filters` filtra por `my_capability_ids` cuando el scope es `MyCapabilities`.
- Pool filtra tareas disponibles por `MyCapabilities`.
- Capacidades filtra por `MyCapabilities`.
- Kanban filtra por `MyCapabilities` si conserva ese comportamiento.

### Tests backend

Mantener la cobertura que garantiza que un miembro solo recibe tareas visibles segun capacidades asignadas.

Renombrar o ajustar descripcion si induce a confundir esta regla con el filtro visual del frontend.

## Criterios de finalizacion

- No existe ningun boton unidireccional "Mis capacidades".
- Toda vista que consume `capability_scope` muestra un control reversible `Todas / Mias`.
- Ninguna vista que no consume `capability_scope` muestra ese control.
- El componente comun cubre Pool, Capacidades y Kanban/Plan Kanban segun corresponda.
- No quedan tests del boton antiguo.
- No quedan textos i18n ni wrappers API duplicados sin uso.
- La suite de cliente pasa.
- Los tests backend relevantes de visibilidad por capacidades siguen pasando.
- Validacion visual con agent-browser en:
  - `/app/pool?...&view=pool`;
  - `/app/pool?...&view=capabilities`;
  - `/app/pool?...&view=cards&mode=kanban` o ruta equivalente del Plan Kanban;
  - vista Kanban.
