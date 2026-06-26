# Card Target Field Plan

Fecha: 2026-06-26

## Objetivo

Unificar la seleccion de tarjetas cuando una pantalla necesita elegir una card
como destino operativo o scope de trabajo, empezando por el bug actual:

- al crear una task desde el boton global, la UI exige una card activa pero no
  permite elegirla;
- al crear un tipo de task, el dialogo de nueva task puede quedar leyendo datos
  de otro cache si no se refresca la pantalla;
- ya existe logica reutilizable en `features/plan/card_picker.gleam`, pero esta
  ubicada en Plan aunque su responsabilidad real es construir opciones de card.

La solucion no debe ser un selector generico sin semantica. El patron final debe
ser un `CardTargetField`: un campo reutilizable para elegir una card como
destino, con wrappers especificos por caso de uso.

## Principios UI/UX

- El usuario no "elige una tarjeta" en abstracto: elige donde vive una task,
  que rama inspecciona, o donde mover una card.
- El lenguaje debe cambiar segun intencion:
  - crear task: `Tarjeta activa`;
  - editar task: `Tarjeta`;
  - scope de Plan/Kanban/Capacidades: `Tarjeta`;
  - mover card: `Destino`.
- La seleccion debe mostrar suficiente contexto para evitar ambiguedad:
  titulo, ruta jerarquica, nivel y `#id`.
- En creacion de task no se deben mostrar destinos invalidos si el usuario no
  puede actuar sobre ellos. Es mejor ocultarlos y explicar el estado vacio.
- En movimiento de card si conviene mostrar opciones deshabilitadas con razon,
  porque la razon ensena la regla estructural.
- El componente no debe hacer fetch propio. Las cards son recurso del proyecto y
  deben venir del estado/carga compartida.
- La UI no debe prometer una accion que no puede resolverse en el mismo flujo.

## Diseno Propuesto

### 1. Nucleo De Opciones

Crear `apps/client/src/scrumbringer_client/features/cards/card_target.gleam`.

Responsabilidades:

- construir `CardTargetOption` desde `List(Card)`;
- calcular ruta visible usando `utils/card_queries`;
- calcular nivel usando `features/hierarchy/scope_view.DepthName`;
- filtrar por titulo, ruta, label, `#id` e id numerico;
- representar validez como `disabled_reason: Option(String)`;
- exponer constructores por intencion:
  - `active_task_targets`;
  - `plan_scope_targets`;
  - `move_destination_targets`;
  - `selected_label`;
  - `search_value_to_card_id`.

No responsabilidades:

- renderizar markup;
- conocer mensajes de padres;
- disparar HTTP;
- leer directamente `member.pool` o `admin.cards`.

### 2. Campo Visual

Crear `apps/client/src/scrumbringer_client/features/cards/card_target_field.gleam`.

Responsabilidades:

- renderizar label, input de busqueda y listbox;
- soportar estados `Loading`, `Failed`, vacio y cargado;
- recibir copy contextual:
  - label;
  - placeholder;
  - empty title/body;
  - aria label;
  - test id prefix;
- emitir mensajes por callbacks:
  - `on_query_changed: fn(String) -> msg`;
  - `on_selected: fn(String) -> msg`;
  - opcionalmente `on_retry: Option(msg)`;
- mantener el lenguaje visual de Plan:
  - densidad compacta;
  - border-first;
  - hover/focus teal;
  - title + meta en dos lineas;
  - truncado estable.

No responsabilidades:

- decidir si una card es valida;
- mutar estado;
- mezclar reglas de mover card con reglas de crear task.

### 3. Wrappers Semanticos

Crear wrappers pequenos, no una mega-configuracion generica:

- `features/tasks/task_create_card_field.gleam`
  - label: `Tarjeta activa`;
  - solo cards activas que aceptan tasks;
  - empty: `No hay tarjetas activas que puedan recibir tareas`;
  - no ofrece "Sin tarjeta".

- `features/tasks/task_edit_card_field.gleam`
  - label: `Tarjeta`;
  - mismas reglas de destino valido que crear task;
  - mantiene la seleccion actual si sigue siendo valida;
  - no ofrece "Sin tarjeta" si el modelo final exige task con card.

- `features/plan/scope_card_field.gleam`
  - label: `Tarjeta`;
  - uso de inspeccion, no de destino operativo;
  - puede usar solo activas si ese sigue siendo el criterio actual de scope;
  - conserva copy de `PlanScopeSelectCard`.

- `features/plan/move_destination_field.gleam`
  - label: `Destino`;
  - permite opciones deshabilitadas con razon;
  - conserva opcion de mover a raiz si la politica lo permite.

## Recursos Compartidos

El bug de `QA` apunta a una separacion pobre entre caches:

- Configuracion de tipos usa `admin.task_types`.
- Nueva task usa `member.pool.member_task_types`.
- Tras crear/editar/borrar un tipo, no debe quedar un formulario leyendo un
  cache obsoleto.

Plan recomendado:

- mantener una fuente de verdad de recursos de proyecto consumibles por
  formularios, o sincronizar explicitamente los caches existentes como paso
  conservador;
- al crear/actualizar/borrar task type:
  - actualizar la lista visible de admin;
  - invalidar o refrescar `member_task_types` del proyecto seleccionado;
  - garantizar que el dialogo global de crear task ve el nuevo tipo sin recarga;
- al crear/actualizar/borrar/activar/cerrar card:
  - actualizar o invalidar el store de cards de proyecto;
  - garantizar que los campos `CardTargetField` no muestran destinos obsoletos.

No introducir un framework global de recursos si no hace falta. Si el estado
actual se puede normalizar con helpers pequenos de sincronizacion por proyecto,
esa es la primera opcion.

## Usos Iniciales

### Obligatorios En Esta Mejora

- `features/pool/create_dialog.gleam`
  - sustituir el hint muerto por campo `Tarjeta activa`;
  - anadir estado de query y seleccion de card;
  - bloquear submit con empty state accionable si no hay destino valido.

- `features/tasks/show_editor.gleam`
  - sustituir el `<select>` plano de `ParentCardLabel`;
  - eliminar opcion `NoCard` si el modelo final no permite tasks sin card;
  - mostrar ruta/nivel para evitar titulos ambiguos.

- `features/plan/scope_bar.gleam`
  - dejar de importar `features/plan/card_picker`;
  - consumir el nucleo comun de cards.

- `features/plan/structure_move.gleam` y `structure_view.gleam`
  - consumir el nucleo comun para opciones;
  - conservar wrapper especifico de movimiento y razones de bloqueo.

### No Incluir En Esta Fase

- `features/admin/cards_view.gleam`
  - es lista/gestion de cards, no selector de destino.

- `features/cards/list_view.gleam` y `features/cards/view.gleam`
  - son navegacion y Card Show, no seleccion.

- `features/automations/rule_list.gleam`
  - actualmente el scope de card es por nivel/profundidad, no card concreta.
  - solo se migraria si el producto decide reglas sobre una card especifica.

- `components/card_crud_dialog.gleam`
  - crea hijas por contexto `parent-card-id`.
  - no necesita picker salvo que el modal permita elegir padre manualmente.

## Fases De Ejecucion

### Fase 1. Tests Rojos

- Test de vista: crear task sin `card_id` renderiza campo `Tarjeta activa` y
  opciones cuando hay cards activas.
- Test de vista: crear task sin cards validas muestra empty state accionable.
- Test de update: seleccionar card actualiza `member_create_card_id`.
- Test de vista: Task Show editor usa labels con ruta/nivel, no select plano.
- Test de sincronizacion: tras `TaskTypeCrudCreated(QA)`, el formulario de
  nueva task puede renderizar `QA` sin recarga completa.
- Test de nucleo: `CardTargetOption` filtra por titulo, ruta, `#id` e id.
- Test de nucleo: move destinations preservan `disabled_reason`.

### Fase 2. Nucleo Y Campo Comun

- Mover la logica reusable de `features/plan/card_picker.gleam` a
  `features/cards/card_target.gleam`.
- Crear `features/cards/card_target_field.gleam`.
- Migrar tests `plan_card_picker_test.gleam` a tests de `card_target`.
- Mantener clases CSS compatibles inicialmente para reducir riesgo visual.

### Fase 3. Crear Task

- Anadir mensajes:
  - `MemberCreateCardChanged(String)`;
  - `MemberCreateCardSearchChanged(String)`.
- Anadir estado:
  - `member_create_card_query: String`.
- Cambiar `create_state.open` para no depender de contexto externo cuando se
  abre desde boton global.
- Usar `task_create_card_field` en `create_dialog.gleam`.
- El submit debe quedar bloqueado solo por regla real, no por ausencia de UI.
- Si las cards no estan cargadas, mostrar loading del campo y disparar/asegurar
  carga de cards de proyecto al abrir el dialogo.

### Fase 4. Editar Task

- Sustituir el select de `show_editor.gleam`.
- Ajustar `show_edit_form.gleam` para no aceptar `None` como destino valido si
  el modelo final exige card.
- Mapear errores backend de card no valida a copy claro y refresco de cards si
  aplica.

### Fase 5. Plan, Kanban Y Capacidades

- Migrar `scope_bar.gleam` al wrapper de scope comun.
- Migrar `structure_move.gleam` y `structure_view.gleam` al wrapper de destino.
- Verificar que Kanban y Capacidades quedan cubiertos al consumir `scope_bar`.
- Mantener textos especificos de Plan para no contaminar crear/editar task.

### Fase 6. Sincronizacion De Recursos

- Al crear/editar/borrar task type, sincronizar o invalidar el cache usado por
  formularios de task.
- Al mutar cards, sincronizar o invalidar el store de cards del proyecto.
- Evitar fetch duplicado si `member_cards_store` ya tiene datos listos del
  proyecto.
- Mantener `project_cards(model)` como helper de lectura, pero revisar si debe
  pasar a un modulo de recursos compartidos.

### Fase 7. Validacion Browser

Validar con `agent-browser`:

- `http://192.168.1.120:8443/config/task-types?project=3`
  - crear/confirmar tipo `QA`;
  - abrir `Nueva tarea`;
  - comprobar que `QA` aparece;
  - buscar y seleccionar una card activa;
  - comprobar que `Crear` se habilita con titulo, tipo y card.

- `http://192.168.1.120:8443/app/pool?project=3&view=cards`
  - abrir una card activa;
  - crear task desde contexto;
  - comprobar preseleccion de card.

- Task Show
  - editar una task;
  - cambiar de card con el nuevo campo;
  - comprobar copy, foco y truncado.

- Plan/Kanban/Capacidades
  - usar scope por card;
  - buscar por titulo, ruta e `#id`;
  - comprobar que no se rompe el layout compacto.

## Matriz De Tests

### Unitarios De Nucleo

- `active_task_targets` solo devuelve cards activas validas para recibir tasks.
- `plan_scope_targets` conserva el comportamiento actual de scope.
- `move_destination_targets` incluye opciones invalidas con `disabled_reason`.
- `filter_options` busca por titulo.
- `filter_options` busca por ruta.
- `filter_options` busca por `#id`.
- `selected_label` devuelve label con ruta/nivel.
- `search_value_to_card_id` resuelve labels exactos e ids.

### Vista Frontend

- Crear task muestra `Tarjeta activa`.
- Crear task muestra opciones con titulo, ruta, nivel e id.
- Crear task sin cards validas muestra empty state y no submit.
- Crear task con card seleccionada muestra label seleccionado.
- Task Show editor no renderiza `NoCard` si no se permiten tasks sin card.
- Task Show editor muestra cards con contexto jerarquico.
- Scope de Plan mantiene buscador y resultados.
- Move destination mantiene razones de bloqueo.

### Update Frontend

- Abrir create dialog dispara carga de task types si faltan.
- Abrir create dialog dispara/asegura carga de cards si faltan.
- Cambiar busqueda de card actualiza query.
- Seleccionar card actualiza `member_create_card_id` y limpia query.
- Cerrar dialogo resetea card/query.
- Crear task resetea card/query.
- `TaskTypeCrudCreated` sincroniza/refresca el cache de tipos usado por create.

### Integracion / Browser

- Desde config de tipos, crear/confirmar `QA` y verlo en nueva task sin recarga.
- Desde nueva task global, seleccionar una card activa y crear task.
- Desde Card Show, crear task conserva card contextual.
- Desde Task Show, cambiar card muestra resultado persistido.
- Scope por card sigue funcionando en Plan/Kanban/Capacidades.

## Limpieza Y Refactorizacion Final

Esta fase es obligatoria antes de cerrar el plan.

- Eliminar `features/plan/card_picker.gleam` o dejarlo reducido a wrapper minimo
  si todavia aporta semantica de Plan. No debe contener logica reusable de cards.
- Eliminar tests `plan_card_picker_test.gleam` si solo prueban el modulo viejo;
  migrarlos a `card_target_test.gleam`.
- Eliminar el test que fija el comportamiento legacy:
  `create_dialog_renders_contextual_form_without_location_selector_test`.
- Eliminar el hint como mecanismo principal de seleccion:
  `task-create-context-hint` no debe ser el unico feedback para elegir card.
- Eliminar opcion/copy `NoCard` de edicion de task si el modelo final exige
  card.
- Eliminar CSS duplicado `plan-card-picker-*` si pasa a clases comunes
  `card-target-*`, o dejar alias temporal solo si se borra en la misma fase.
- Revisar imports de `features/plan/card_picker` con `rg` y dejarlos en cero.
- Revisar mensajes y estado de create task para no dejar campos sin uso:
  `member_create_card_query`, callbacks, i18n y CSS.
- Revisar i18n para borrar textos obsoletos que describan root/no-card task
  creation como flujo normal.
- Revisar snapshots/tests de Pool, Plan, Kanban, Capacidades y Task Show para
  que no validen selects legacy ni ausencia de selector de ubicacion.
- Ejecutar formato y suite cliente relevante antes de cerrar.

## Criterios De Finalizacion

- Nueva task global permite elegir una card activa.
- El tipo `QA` recien creado en proyecto 3 aparece en nueva task sin depender de
  recarga manual.
- Task Show editor usa el mismo lenguaje visual para elegir card.
- Plan/Kanban/Capacidades mantienen scope por card tras la extraccion.
- No quedan imports de `features/plan/card_picker` como modulo de logica comun.
- Los tests cubren nucleo, vista, update y flujo browser.
- La limpieza final elimina selectores/copy/tests legacy ligados a "sin selector
  de ubicacion" o "sin card" cuando no son parte del modelo final.
