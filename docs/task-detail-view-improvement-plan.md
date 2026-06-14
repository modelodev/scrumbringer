# Task Detail View Improvement Plan

Fecha: 2026-06-14

Plan para mejorar la vista de una tarea abierta en ScrumBringer. El objetivo no
es hacer un modal mas vistoso, sino convertirlo en una superficie operativa
coherente con el producto: entender una tarea, decidir la siguiente accion,
editar lo corregible y ver bloqueos sin perder contexto.

## Contexto de producto

ScrumBringer favorece el trabajo pull-based: las tareas disponibles deben poder
ser entendidas y reclamadas con confianza; las tareas reclamadas deben hacer
visible propiedad, estado y siguiente accion; los cambios de definicion no
deben mezclarse con acciones de ciclo de vida como reclamar, liberar o
completar.

La vista actual cumple funcionalmente, pero tiene problemas de jerarquia:

- El modo edicion deja visible el footer de ciclo de vida (`Cerrar`,
  `Liberar`, `Completar`) y desplaza las acciones reales de edicion
  (`Cancelar`, `Guardar`) dentro del body.
- La cabecera ocupa demasiado espacio y alinea mal el titulo.
- La primera pestana se llama `Tareas`, aunque el usuario ya esta dentro de una
  tarea; debe leerse como `Detalles`.
- El detalle de lectura muestra poca informacion operativa.
- En mobile hay doble scroll y el footer compite con el formulario.
- El dialogo necesita una pasada de accesibilidad: cierre localizado, foco,
  fondo no navegable y salida consistente.

## Estudio de la base de codigo

La vista esta bien separada en modulos, lo que permite una mejora incremental
sin reescribir el flujo:

| Area | Modulo actual | Responsabilidad actual |
| --- | --- | --- |
| Shell del modal | `apps/client/src/scrumbringer_client/features/pool/dialogs.gleam` | Compone backdrop, header, tabs, body y footer. |
| Configuracion desde estado | `apps/client/src/scrumbringer_client/features/pool/task_details_dialog_config.gleam` | Mapea `pool`, `notes`, `dependencies`, usuario y callbacks a `TaskDetailsConfig`. |
| Cabecera | `apps/client/src/scrumbringer_client/features/pool/task_detail_header.gleam` | Renderiza titulo, tipo, prioridad, estado y asignacion. |
| Tabs | `apps/client/src/scrumbringer_client/features/pool/task_detail_tabs.gleam` | Envuelve `ui/task_tabs` y calcula contador de notas. |
| Footer | `apps/client/src/scrumbringer_client/features/pool/task_detail_footer.gleam` | Renderiza `Cerrar` y acciones de ciclo de vida segun estado de trabajo. |
| Detalles | `apps/client/src/scrumbringer_client/features/pool/task_detail_details.gleam` | Conecta la tarea con `features/tasks/detail_editor`. |
| Editor | `apps/client/src/scrumbringer_client/features/tasks/detail_editor.gleam` | Permisos, dirty check, formulario y vista de campos actuales. |
| Dependencias | `apps/client/src/scrumbringer_client/features/pool/task_dependencies.gleam` | Lista, empty state y dialogo de alta de dependencias. |
| Estilos | `apps/client/src/scrumbringer_client/styles/ux.gleam` | CSS del shell, header, tabs, body, editor y footer. |

Componentes compartidos que deben reutilizarse:

- `ui/button.gleam` para botones semanticos con intent, scope, disabled,
  title y aria-label.
- `ui/form_field.gleam` para labels, errores e hints.
- `ui/detail_tabs.gleam` y `ui/task_tabs.gleam` para la barra de tabs.
- `ui/modal_header.gleam` solo si sigue ayudando; si su configuracion fuerza una
  cabecera rara para task detail, crear una vista especifica en
  `task_detail_header.gleam` es mejor que forzar el componente generico.
- `ui/icons.gleam` para iconos Heroicons.
- `ui/card_section_header.gleam` y `ui/empty_state`/patrones de empty state ya
  usados por dependencias.

Tests existentes a ampliar, no duplicar:

- `apps/client/test/pool_task_detail_footer_test.gleam`
- `apps/client/test/pool_task_detail_header_test.gleam`
- `apps/client/test/pool_task_detail_tabs_test.gleam`
- `apps/client/test/pool_task_detail_details_test.gleam`
- `apps/client/test/task_detail_editor_view_test.gleam`
- `apps/client/test/task_detail_update_test.gleam`
- `apps/client/test/tasks_detail_state_test.gleam`
- `apps/client/test/tasks_detail_update_test.gleam`
- `apps/client/test/task_metrics_view_test.gleam`

## Principios de implementacion

1. **Una sola fuente para cada decision.** La regla de si una tarea puede
   editarse vive en `detail_editor.can_edit_task`; la regla de dirty state vive
   en `detail_editor.is_dirty`; el footer debe consumir esas decisiones, no
   replicarlas.
2. **Un modo, una accion primaria.** En lectura, la accion primaria es de ciclo
   de vida (`Reclamar` o `Completar`). En edicion, la accion primaria es
   `Guardar`.
3. **DRY por extraccion con valor real.** Extraer helpers solo cuando eviten
   duplicacion visible en 2+ sitios o eliminen estados invalidos. No crear
   capas `manager`/`facade`.
4. **View functions antes que componentes con estado.** El estado ya esta en el
   modelo Lustre; la mejora debe seguir el patron de view functions.
5. **Contratos tipados.** Si el footer necesita distinguir modos, usar un ADT
   pequeno como `FooterMode(msg)` o campos explicitos en `Config`; evitar flags
   sueltos que puedan combinarse de forma invalida.
6. **CSS acotado.** No tocar tablas, cards ni otros modales salvo que se extraiga
   un patron compartido ya probado.

## Plan por slices

### Slice 1: Footer contextual

#### Producto

Separar acciones de definicion de acciones de flujo. Mientras se edita una
tarea, no debe ser posible completar/liberar/reclamar desde el mismo footer.

#### UI/UX

- Modo lectura:
  - Disponible: `Cerrar` + `Reclamar`.
  - Reclamada propia: `Cerrar` + `Liberar` + `Completar`.
  - Reclamada por otro: `Cerrar`.
  - Completada: `Cerrar`.
- Modo edicion:
  - `Cancelar` + `Guardar`.
  - `Guardar` disabled si no hay cambios o hay request en vuelo.
  - `Guardar` con estado loading si `edit_in_flight`.

#### Codigo

Cambios previstos:

- Ampliar `task_detail_footer.Config` con informacion de edicion:
  - `editing: Bool`
  - `edit_in_flight: Bool`
  - `edit_dirty: Bool`
  - `on_edit_cancelled: msg`
  - `on_edit_submitted: msg`
- Calcular `edit_dirty` en `dialogs.gleam` usando
  `detail_editor.is_dirty(detail_editor_config, task)` o un helper intermedio.
- Eliminar `task-detail-edit-actions` del formulario o dejarlo solo como fallback
  oculto si fuera necesario para submit por Enter. El footer sera la unica
  superficie visual de acciones de edicion.
- Mantener `event.on_submit` en el form para `Ctrl/Cmd+Enter` y submit
  programatico, pero el boton visible `Guardar` vivira en el footer con
  `form="task-detail-edit-form"` si se conserva `type="submit"`.

#### DRY

No duplicar botones `Cancelar`/`Guardar` entre editor y footer. Si se necesita
un helper, que viva en `task_detail_footer.gleam` como funciones privadas
`edit_actions` y `lifecycle_actions`.

#### Tests

- Footer renderiza `Cancelar`/`Guardar` en modo edicion.
- Footer no renderiza `Liberar`/`Completar` en modo edicion.
- `Guardar` disabled si `edit_dirty = False`.
- `Guardar` loading/disabled si `edit_in_flight = True`.
- Vista integrada de task detail no contiene dos botones `Guardar`.

### Slice 2: Cabecera compacta y localizada

#### Producto

La cabecera debe hacer visible identidad y estado sin empujar el contenido
operativo fuera de la primera pantalla.

#### UI/UX

- Primera linea: titulo a la izquierda, boton cerrar a la derecha.
- Segunda linea: chips compactos de tipo, prioridad, estado y propiedad.
- Reducir padding vertical en desktop y mobile.
- El cierre debe anunciarse como `Cerrar` en castellano, `Close` en ingles.
- Titulo largo debe envolver en 2 lineas maximas antes de romper layout.

#### Codigo

Opciones:

1. Mantener `modal_header.view_extended` si con CSS basta.
2. Si el layout sigue forzado, renderizar markup especifico en
   `task_detail_header.gleam` usando `modal_close_button` o `ui/button`.

La opcion preferente es primero intentar CSS + configuracion. Si el componente
generico obliga a una estructura mala, se justifica una vista especifica porque
task detail tiene requisitos distintos a CRUD dialogs.

#### DRY

Conservar `task_meta` como helper privado y no duplicar chips en otra parte.
Si los chips se hacen reutilizables, extraer solo cuando card/milestone detail
necesiten el mismo patron.

#### Tests

- Header sigue mostrando titulo, tipo, prioridad, estado y propiedad.
- Close button usa label localizado.
- Loading state sigue renderizando titulo de carga.

### Slice 3: Pestana principal como `Detalles`

#### Producto

Dentro de una tarea, la pestana debe representar el contenido, no otra entidad.
`Detalles` reduce ambiguedad con Pool, Mis tareas y tareas de card.

#### UI/UX

- Cambiar label visible de `TabTasks` a `Detalles` para task detail.
- Mantener `Notas` y `Metricas`.
- No cambiar el tipo interno `task_tabs.TasksTab` en esta slice para evitar un
  refactor de bajo valor en estado y tests.

#### Codigo

- En `task_detail_tabs.gleam`, usar `i18n_text.TabDetails` para `tasks`.
- Ajustar tests que esperan `Tasks`/`Tareas`.

#### DRY

No crear una segunda estructura de tabs. Seguir usando `ui/detail_tabs.gleam`.

#### Tests

- `pool_task_detail_tabs_test` espera `Details` en ingles y `Detalles` mediante
  test de i18n si aplica.
- El contrato ARIA de paneles no cambia.

### Slice 4: Resumen operativo de lectura

#### Producto

El detalle debe contestar rapido:

- Que estado tiene?
- Que prioridad/tipo tiene?
- Esta en card o hito?
- Quien la reclamo?
- Esta bloqueada por dependencias?
- Que debo hacer ahora?

#### UI/UX

Introducir un resumen compacto al inicio de `Detalles`, antes de la descripcion:

- Estado
- Prioridad
- Tipo
- Card
- Hito
- Propiedad
- Bloqueos/dependencias activas

La descripcion debe ser un bloque de lectura separado, con ancho de texto
controlado. Si esta vacia, mostrar un empty state discreto, no solo `-`.

#### Codigo

- Crear `features/pool/task_detail_summary.gleam` si el resumen supera 2-3
  helpers privados.
- Entrada recomendada:
  - `locale`
  - `task`
  - `parent_card_title`
  - `dependencies`
  - `current_user_id`
- Reutilizar:
  - `task_state.label`
  - `blocking.incomplete_dependency_count`
  - `detail_editor.parent_card_label` si se hace publico de forma justificada,
    o mover ese helper al nuevo summary para no exponer internals del editor.
- No duplicar estado ya disponible en la cabecera; la cabecera da identidad, el
  resumen da contexto operativo.

#### DRY

Si `parent_card_label`, `task_type_id` o formateo de prioridad se usan tanto en
lectura como edicion, moverlos a un modulo pequeno de presentacion:

`features/tasks/task_detail_presenters.gleam`

Solo hacerlo si evita duplicacion real. Mantener funciones privadas si se usan
una sola vez.

#### Tests

- Summary renderiza card/hito vacios con copy clara.
- Summary muestra count de bloqueos cuando hay dependencias incompletas.
- Summary no rompe cuando `dependencies` esta `Loading`/`Failed`.
- Description vacia renderiza estado discreto.

### Slice 5: Formulario de edicion por secciones

#### Producto

Editar una tarea no es rellenar un formulario administrativo; es corregir los
metadatos que permiten al equipo trabajar. La estructura debe seguir esa logica.

#### UI/UX

Dividir en secciones:

- `Identidad`: titulo y descripcion.
- `Planificacion`: tipo y prioridad.
- `Ubicacion`: card e hito.

Cambios concretos:

- Cambiar prioridad de `input type="number"` a control segmentado `P1`-`P5`.
- Cambiar label visible `Hitos` por `Hito` en este contexto.
- Si hay card seleccionada, mostrar hint `Hito heredado de la tarjeta` junto al
  campo hito deshabilitado.
- El hint de teclado (`Ctrl/Cmd+Enter...`) debe quedar al final de la edicion,
  menos prominente que los campos.

#### Codigo

- Mantener `detail_editor.Config` y handlers actuales.
- Sustituir `view_priority_field` por `view_priority_segmented`.
- Anadir helpers privados:
  - `view_edit_section(title, children)`
  - `priority_option`
  - `milestone_hint`
- Reutilizar `form_field.view`/`with_hint`.
- Si se necesita un segmented control reutilizable en mas pantallas, crearlo en
  `ui/segmented_control.gleam`; si solo se usa aqui, dejarlo local en
  `detail_editor.gleam`.

#### DRY

No introducir un componente generico prematuro. El control de prioridad solo
debe extraerse a `ui/` si aparece otro uso cercano (`create task`, filtros,
admin de tareas). Como minimo, evitar repetir cinco botones con markup
ad-hoc usando `priority_options |> list.map(priority_button)`.

#### Tests

- Se renderizan `P1`..`P5`.
- Seleccion de prioridad emite `on_priority_changed`.
- El valor actual aparece seleccionado.
- Hito queda deshabilitado y con hint cuando hay card.
- Formulario sigue marcando dirty state al cambiar prioridad/card/hito.

### Slice 6: Scroll, dependencias y espacio inferior

#### Producto

Las dependencias determinan si una tarea esta bloqueada y si puede reclamarse.
No pueden quedar tapadas por el footer.

#### UI/UX

- Body del modal con padding inferior suficiente para el footer.
- Un unico scroll interno en `.task-detail-body`.
- Dependencias despues del resumen/descripcion, con cabecera visible y empty
  state compacto.
- El boton `Añadir dependencia` debe mantenerse en la seccion, no en el footer.

#### Codigo

- Ajustar CSS en `ux.gleam`:
  - `.task-detail-body { padding-bottom: ... }`
  - evitar `height` o `overflow` duplicado en paneles internos.
- Revisar `.detail-tabpanel`, `.task-detail-grid`,
  `.task-dependencies-section`.

#### DRY

No crear estilos duplicados para desktop/mobile si una regla estructural resuelve
ambos. Mobile solo debe ajustar layout, no redefinir toda la UI.

#### Tests

La verificacion principal sera visual con agent-browser. Los tests unitarios no
capturan solapes de CSS.

### Slice 7: Mobile como sheet/fullscreen operativo

#### Producto

Una tarea abierta en movil debe permitir revisar/editar sin perder acciones ni
contexto. La app ya tiene una filosofia de uso operativo; mobile no debe sentirse
como una ventana desktop encajada.

#### UI/UX

En `max-width: 640px`:

- Modal casi fullscreen (`inset: 8px` o `width: calc(100% - 16px)` y
  `height: calc(100dvh - 16px)`).
- Cabecera compacta sticky.
- Tabs sticky si el contenido es largo.
- Footer sticky contextual.
- Edicion: footer `Cancelar`/`Guardar` siempre visible.
- Evitar doble scroll entre page y modal.

#### Codigo

- CSS acotado a `.task-detail-modal`.
- No introducir un componente mobile separado.
- Usar `dvh` con fallback razonable si ya existe patron en CSS.

#### DRY

Mismo markup para desktop/mobile. Solo cambia CSS.

#### Tests

- Agent-browser viewport desktop y mobile.
- Capturas de lectura y edicion.
- Comprobar que `Guardar` es visible en mobile sin scroll adicional.

### Slice 8: Accesibilidad y foco

#### Producto

Una tarea abierta es un estado modal de trabajo. El usuario no debe navegar
accidentalmente por el fondo ni perder el foco al editar.

#### UI/UX

- Cierre localizado.
- Escape:
  - en lectura: cerrar modal.
  - en edicion: cancelar edicion primero.
- Foco inicial:
  - lectura: titulo/modal.
  - edicion: campo titulo.
- Fondo no accesible mientras dialogo esta abierto.
- Focus visible en tabs, footer y botones.

#### Codigo

- Revisar `ui/modal_close_button.gleam` para localizacion o permitir label desde
  `task_detail_header`.
- Si el shell general no soporta inert/aria-hidden, documentar limitacion y
  resolver en el punto de render donde se monta el modal.
- Mantener handlers de teclado existentes en `detail_editor.gleam`.

#### DRY

Si la mejora de close label aplica a mas modales, arreglarla en
`ui/modal_close_button.gleam`. Si solo se requiere para task detail, pasar label
custom desde `task_detail_header`.

#### Tests

- Snapshot HTML contiene aria-label localizado.
- Tabpanel mantiene role/aria-labelledby.
- No se rompe autofocus del titulo en edicion.

## Refactorizacion y limpieza final

Al terminar los slices, hacer una pasada de refactor con este orden:

1. **Inventario de cambios.**
   - Listar archivos tocados.
   - Marcar funciones nuevas publicas.
   - Justificar cada nuevo modulo.
2. **Reducir superficie publica.**
   - Helpers de presentacion deben ser privados salvo que los usen tests o
     modulos distintos con valor claro.
   - Evitar exportar `parent_card_label`, `priority_label`, etc. si no hace
     falta.
3. **Eliminar duplicacion.**
   - Un solo lugar visual para acciones de edicion.
   - Un solo helper para botones del footer.
   - Un solo mapeo de prioridad `1..5 -> P1..P5`.
   - Un solo helper para label de card/hito si aparece en summary y editor.
4. **Eliminar obsolescencias.**
   - Borrar CSS `.task-detail-edit-actions` si ya no se usa.
   - Borrar clases o tests que sigan esperando `Tasks` como label visible si el
     producto ya usa `Details`.
   - Buscar restos con:
     - `rg "task-detail-edit-actions|TabTasks|Tasks|Tareas|Milestones|Hitos" apps/client/src apps/client/test`
     - Revisar resultados para distinguir otros contextos legitimos.
5. **Mantener arquitectura.**
   - `dialogs.gleam` compone; no debe convertirse en modulo de logica.
   - `task_detail_footer.gleam` decide acciones visibles de footer.
   - `detail_editor.gleam` conserva permisos, dirty state y campos de edicion.
   - Un posible `task_detail_summary.gleam` solo presenta lectura operativa.
6. **No sobreingenieria.**
   - No crear `TaskDetailManager`.
   - No crear ADTs si campos explicitos bastan.
   - No crear componentes Lustre con estado interno.
   - No extraer segmented control a `ui/` salvo que haya segundo uso real.

## Verificacion

### Tests automaticos

Ejecutar desde `apps/client`:

```sh
gleam format --check
gleam check
gleam test --target javascript
gleam run -m lustre/dev build
```

Si se toca codigo compartido o contratos de dominio, ejecutar tambien la suite
global que corresponda.

### Browser/UI

Con agent-browser:

1. Desktop, tarea disponible:
   - cabecera compacta;
   - tab `Detalles`;
   - footer `Cerrar` + `Reclamar`;
   - blocked/dependencies visibles.
2. Desktop, tarea reclamada propia:
   - footer `Cerrar` + `Liberar` + `Completar`;
   - boton `Editar tarea` visible.
3. Desktop, modo edicion:
   - footer `Cancelar` + `Guardar`;
   - no aparecen `Liberar`/`Completar`;
   - secciones del formulario visibles y ordenadas.
4. Mobile, modo lectura:
   - modal/sheet sin doble scroll evidente;
   - titulo y chips no solapan;
   - footer visible.
5. Mobile, modo edicion:
   - `Guardar` visible en footer;
   - tabs/header no consumen demasiado alto;
   - formulario no queda tapado.
6. Notas y metricas:
   - tabs siguen funcionando;
   - contador de notas sigue visible.

### Impeccable pass

Al final, ejecutar detector y revision visual:

```sh
node .agents/skills/impeccable/scripts/detect.mjs --json \
  apps/client/src/scrumbringer_client/features/pool/dialogs.gleam \
  apps/client/src/scrumbringer_client/features/pool/task_detail_header.gleam \
  apps/client/src/scrumbringer_client/features/pool/task_detail_footer.gleam \
  apps/client/src/scrumbringer_client/features/tasks/detail_editor.gleam \
  apps/client/src/scrumbringer_client/styles/ux.gleam
```

Los falsos positivos deben documentarse; los problemas reales de solape,
contraste, texto cortado o patrones prohibidos deben corregirse antes de cerrar.

## Orden recomendado de commits

Si el cambio se implementa en una sola rama, mantener commits pequenos:

1. `Improve task detail footer modes`
2. `Compact task detail header and tabs`
3. `Add task operational summary`
4. `Restructure task detail edit form`
5. `Polish task detail responsive layout`
6. `Clean task detail refactor leftovers`

Cada commit debe pasar tests relevantes antes del siguiente.

## Criterio de aceptacion

La mejora se considera terminada cuando:

- En lectura, la accion primaria del footer corresponde al estado de la tarea.
- En edicion, el footer solo muestra acciones de edicion.
- La pestana visible se llama `Detalles`.
- El resumen operativo permite entender estado, prioridad, tipo, ubicacion y
  bloqueos sin abrir otra vista.
- En mobile no hay doble scroll perceptible ni acciones principales tapadas.
- No quedan helpers o CSS obsoletos del flujo anterior.
- Las pruebas automaticas pasan.
- La pasada visual con agent-browser no muestra solapes ni texto cortado.
