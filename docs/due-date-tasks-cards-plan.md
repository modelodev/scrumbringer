# Due Date Tasks And Cards Plan

Fecha: 2026-06-18

Este documento registra la propuesta para anadir fecha de vencimiento a tasks y
cards. El objetivo es que el campo encaje con el modelo pull-flow de
ScrumBringer, con la interfaz operacional existente y con las fronteras de
codigo actuales.

## Objetivo

Anadir un campo opcional de vencimiento que ayude a detectar urgencia y riesgo
sin convertir ScrumBringer en un calendario ni introducir asignaciones rigidas.

La propuesta recomendada es:

- `tasks.due_date`: fecha de vencimiento propia de una task.
- `cards.due_date`: fecha de vencimiento del paquete o compromiso que agrupa
  trabajo.
- `task.card_due_date`: campo derivado en respuestas de task para mostrar el
  contexto de la card padre sin copiarlo en la task.

Las fechas deben ser `DATE` en base de datos, `YYYY-MM-DD` en API y
`Option(due_date.DueDate)` dentro del dominio compartido. No deben usar
timestamps ni zonas horarias.

## Contexto De Producto

ScrumBringer esta orientado a flujo pull, bloqueo, foco, grooming y visibilidad
de estado. La fecha de vencimiento debe funcionar como senal de salud del flujo:
una task o card puede tener una fecha objetivo, pero esa fecha no debe cambiar
automaticamente su owner, su estado ni su prioridad.

La semantica propuesta es:

- Task due date: compromiso o expectativa especifica de una pieza de trabajo.
- Card due date: compromiso de entrega o paquete.
- Task sin due date con card due date: mostrar contexto heredado, sin persistir
  copia en la task.
- Task con due date propia: prevalece en la lectura de la task.
- Done, closed o done: la fecha deja de tener severidad visual fuerte y se
  muestra como informacion historica.

## Hallazgos De Interfaz

La revision con `agent-browser` cubrio pool, detalle de task, creacion de task,
detalle de card, administracion de cards, creacion de card y vista movil.

Hallazgos principales:

- El pool es denso y orientado a scanning. No conviene anadir texto permanente
  a todas las cards; solo debe aparecer una senal compacta cuando hay riesgo.
- El detalle de task ya tiene una seccion de planificacion con tipo, prioridad,
  estado y columnas. El vencimiento encaja ahi mejor que en metadatos
  secundarios.
- El formulario de creacion de task agrupa identidad, prioridad, tipo y
  ubicacion. El campo opcional `Vencimiento` debe aparecer despues de `Tipo` y
  antes de `Tarjeta` o hito.
- El hover de task tiene espacio para una fila adicional de vencimiento antes de
  la antiguedad.
- El detalle de card ya muestra estado, progreso, owner y orden. Un badge de
  vencimiento junto a estado/progreso refuerza el compromiso de paquete sin
  competir con el contenido.
- La tabla de administracion de cards puede aceptar una columna corta `VENCE`.
  En esta superficie el valor debe ser escaneable, no descriptivo.
- En movil hay poco espacio. La fecha solo debe competir con antiguedad cuando
  sea urgente o vencida.

## Estudio De Codigo

Las zonas relevantes del codigo estan bien separadas entre dominio compartido,
persistencia, HTTP, cliente API, estado de formularios y vistas Lustre.

### Dominio Y Codecs Compartidos

- `shared/src/domain/task.gleam`
- `shared/src/domain/card.gleam`
- `shared/src/domain/task/codec.gleam`
- `shared/src/domain/card/codec.gleam`

Aqui deben declararse los nuevos campos opcionales y sus codecs JSON. La fecha
debe viajar como string `YYYY-MM-DD` para mantener el contrato simple, pero el
codigo interno debe usar un tipo dedicado:

- Crear `shared/src/domain/due_date.gleam`.
- Exponer un tipo opaco `DueDate`.
- Exponer `parse(String) -> Result(DueDate, DueDateError)`.
- Exponer `to_string(DueDate) -> String`.
- Exponer helpers puros para comparar fechas y calcular distancia por dias.

Este tipo evita que cualquier string arbitrario se convierta en vencimiento una
vez dentro del dominio. Los formularios pueden seguir usando strings mientras el
usuario edita, pero los payloads, codecs, mappers y presenters deben cruzar la
frontera con `DueDate` validado.

### Persistencia Y SQL

- `apps/server/src/scrumbringer_server/sql/tasks_list.sql`
- `apps/server/src/scrumbringer_server/sql/tasks_create.sql`
- `apps/server/src/scrumbringer_server/sql/tasks_update.sql`
- `apps/server/src/scrumbringer_server/sql/tasks_get_for_user.sql`
- `apps/server/src/scrumbringer_server/sql/tasks_claim.sql`
- `apps/server/src/scrumbringer_server/sql/tasks_release.sql`
- `apps/server/src/scrumbringer_server/sql/tasks_complete.sql`
- `apps/server/src/scrumbringer_server/sql/cards_list.sql`
- `apps/server/src/scrumbringer_server/sql/cards_get.sql`
- `apps/server/src/scrumbringer_server/sql/cards_create.sql`
- `apps/server/src/scrumbringer_server/sql/cards_update.sql`
- `apps/server/src/scrumbringer_server/persistence/tasks/mappers.gleam`
- `apps/server/src/scrumbringer_server/persistence/tasks/queries.gleam`
- `apps/server/src/scrumbringer_server/services/cards_db.gleam`

La migracion debe anadir columnas nullable y actualizar select, insert, update y
mappers. Para tasks, los listados que ya unen card pueden exponer tambien
`card_due_date` como contexto derivado.

No basta con actualizar create/update/list: todas las queries que devuelven un
`Task` pasan por los mismos mappers y deben devolver `due_date` y
`card_due_date`. Esto incluye claim, release, complete, get y list-by-card.

Las updates de task ya usan `field_update.FieldUpdate`; por tanto `due_date`
debe agregarse a `TaskUpdates` como
`FieldUpdate(Option(due_date.DueDate))`. En SQL se necesita una semantica de
tres estados: unchanged, clear y set. Para evitar ambiguedad, usar una sentinela
string separada para unchanged, por ejemplo `__unset_date__`, y
`nullif($n, '')::date` para clear/set.

### HTTP

- `apps/server/src/scrumbringer_server/http/tasks/payloads.gleam`
- `apps/server/src/scrumbringer_server/http/tasks/presenters.gleam`
- `apps/server/src/scrumbringer_server/http/cards/payloads.gleam`
- `apps/server/src/scrumbringer_server/http/cards/presenters.gleam`
- `apps/server/src/scrumbringer_server/services/workflows/types.gleam`
- `apps/server/src/scrumbringer_server/services/workflows/validation.gleam`
- `apps/server/src/scrumbringer_server/services/workflows/validation_core.gleam`

Los payloads deben aceptar `due_date` ausente o `null`, validar formato
`YYYY-MM-DD` y rechazar fechas invalidas. Los presenters deben devolver
`due_date: null` cuando no exista.

La validacion no debe duplicarse en cada payload. La regla de formato y fecha
real debe vivir en `domain/due_date.gleam`; la capa workflow puede envolverla en
`validation_core` para mantener la forma actual de errores.

### Cliente API Y Estado

- `apps/client/src/scrumbringer_client/api/tasks/operations.gleam`
- `apps/client/src/scrumbringer_client/api/cards.gleam`
- `apps/client/src/scrumbringer_client/client_state/member/pool.gleam`
- `apps/client/src/scrumbringer_client/features/tasks/create_form.gleam`
- `apps/client/src/scrumbringer_client/features/tasks/create_update.gleam`
- `apps/client/src/scrumbringer_client/features/tasks/detail_editor.gleam`
- `apps/client/src/scrumbringer_client/features/tasks/detail_edit_form.gleam`
- `apps/client/src/scrumbringer_client/features/tasks/detail_state.gleam`
- `apps/client/src/scrumbringer_client/components/card_crud_dialog.gleam`
- `apps/client/src/scrumbringer_client/i18n/text.gleam`
- `apps/client/src/scrumbringer_client/i18n/en.gleam`
- `apps/client/src/scrumbringer_client/i18n/es.gleam`

Los formularios deben tratar el campo como opcional. El estado interno puede
mantener una cadena vacia mientras el usuario edita, pero las llamadas API deben
normalizar a `None` cuando el valor este vacio.

El helper API completo debe recibir `due_date`; los helpers simples deben
delegar con `None` para evitar duplicar payloads. En task detail, el
`TaskUpdatePayload` debe incluir `due_date: Option(due_date.DueDate)` y
serializarlo como string o `null`.

Los mensajes Lustre nuevos deben seguir el estilo de eventos observado en el
codigo: `CreateDueDateChanged`, `EditDueDateChanged` o equivalente contextual,
no nombres imperativos. En componentes web con eventos custom, la serializacion
JSON debe incluir tambien `due_date`; `card_crud_dialog.gleam` emite cards a su
padre y debe conservar ese campo en `card_to_json`.

### Superficies Visuales

- `apps/client/src/scrumbringer_client/features/pool/task_detail_summary.gleam`
- `apps/client/src/scrumbringer_client/features/pool/task_hover.gleam`
- `apps/client/src/scrumbringer_client/ui/task_hover_popup.gleam`
- `apps/client/src/scrumbringer_client/features/pool/task_card.gleam`
- `apps/client/src/scrumbringer_client/features/pool/task_row.gleam`
- `apps/client/src/scrumbringer_client/features/my_bar/view.gleam`
- `apps/client/src/scrumbringer_client/features/cards/list_view.gleam`
- `apps/client/src/scrumbringer_client/components/card_detail_modal.gleam`
- `apps/client/src/scrumbringer_client/ui/card_detail_host.gleam`
- `apps/client/src/scrumbringer_client/features/admin/cards_view.gleam`
- `apps/client/src/scrumbringer_client/utils/format_date.gleam`
- `apps/client/src/scrumbringer_client/styles/ux.gleam`
- `apps/client/src/scrumbringer_client/styles/pool.gleam`

Conviene crear un helper dedicado, por ejemplo
`apps/client/src/scrumbringer_client/ui/due_date.gleam`, para centralizar
etiquetas, severidad y clases CSS. Asi se evita duplicar logica en pool, cards,
hover y modales.

`components/card_detail_modal.gleam` contiene un decoder local de `Task` para la
propiedad `tasks`; debe actualizarse o, mejor, sustituirse por el decoder
compartido para no dejar una segunda forma de `Task` sin due date.

El helper de vencimiento no debe reutilizar directamente `utils/format_date`
para calculo relativo: ese modulo esta orientado a timestamps ISO. Para due
dates se necesita un calculo puro basado en `YYYY-MM-DD`. Puede reutilizar solo
el formato de mes (`21 jun`) si se extrae o replica como helper puro.

## Modelo De Datos Y Contrato

### Base De Datos

Anadir:

```sql
ALTER TABLE tasks ADD COLUMN due_date DATE NULL;
ALTER TABLE cards ADD COLUMN due_date DATE NULL;
```

Indices recomendados:

```sql
CREATE INDEX tasks_due_date_idx
ON tasks (due_date)
WHERE due_date IS NOT NULL;

CREATE INDEX cards_due_date_idx
ON cards (due_date)
WHERE due_date IS NOT NULL;
```

Si los listados filtran por tenant/org en columnas existentes, el indice final
debe seguir el patron real de esas consultas, por ejemplo `(org_id, due_date)`
si esa es la dimension de acceso dominante.

### API

Tasks:

```json
{
  "due_date": "2026-06-21",
  "card_due_date": "2026-06-30"
}
```

Cards:

```json
{
  "due_date": "2026-06-30"
}
```

Reglas:

- `due_date` puede omitirse en payloads existentes.
- `due_date: null` borra el vencimiento.
- String vacio desde UI se normaliza a `null`, no llega al backend como fecha.
- Fechas invalidas deben devolver error de validacion.
- No se aceptan timestamps ISO completos.
- En codigo compartido, `due_date` y `card_due_date` se representan como
  `Option(due_date.DueDate)`, no como `Option(String)`.
- La respuesta de task debe incluir siempre ambas claves: `due_date` y
  `card_due_date`, con `null` cuando no apliquen.

## Comportamiento Visual

Estados recomendados:

- Sin fecha: no mostrar chip en superficies compactas; mostrar `Sin
  vencimiento` con estilo muted en detalle.
- Futuro lejano: neutral.
- Proximos 7 dias: warning suave.
- Hoy: warning fuerte.
- Vencida y no finalizada: danger.
- Finalizada o cerrada: neutral/muted, incluso si la fecha ya paso.

Textos sugeridos:

- `Vence 21 jun`
- `Vence hoy`
- `Vencio ayer`
- `Vencida 3 d`
- `Sin vencimiento`
- `Vence con tarjeta 30 jun`

La interfaz debe evitar anadir chips permanentes a todas las tasks del pool. La
senal aparece solo cuando aporta decision: vencida, hoy o pronto. En detalle y
formularios, el campo siempre esta disponible.

Colocacion por vista:

- Crear task: anadir un input nativo `type="date"` despues de `Tipo` y antes de
  `Tarjeta` o hito. Es opcional y no debe ocupar copy auxiliar salvo error.
- Editar task: anadir `Vencimiento` en `Planificacion` como tercer campo de la
  grid, dejando `Tipo de tarea` y `Prioridad` en la primera fila.
- Summary de task: anadir `Vencimiento` despues de `Prioridad`; mostrar `Sin
  vencimiento` muted, `Vence con tarjeta 30 jun` si solo existe
  `card_due_date`, y la fecha propia cuando exista.
- Hover de task: anadir fila de vencimiento antes de `Antiguedad`.
- Task card desktop: mostrar chip solo si la fecha efectiva esta vencida, es hoy
  o vence en los proximos 7 dias. La fecha efectiva es `due_date` si existe, si
  no `card_due_date`.
- Task card desktop tambien debe reutilizar el vocabulario de movimiento del
  pool cuando la fecha efectiva se acerque. No debe sumar dos animaciones: se
  calcula la severidad maxima entre envejecimiento de pool y vencimiento, y se
  aplica una sola clase visual.
- Task card mobile: reemplazar la metadata de edad por vencimiento solo en esos
  mismos estados urgentes; no anadir otra linea al contexto movil.
- Card detail: anadir chip en la cabecera junto a estado y progreso, no dentro
  de la lista de tasks.
- Lista de cards de miembro: anadir chip compacto en `.ficha-meta`, junto al
  progreso.
- Admin cards: anadir columna `VENCE` entre `ESTADO` y `TAREAS`. No anadir
  filtro de vencimiento en el primer slice.
- Cards vencidas y no cerradas: mostrar el texto de fecha con color danger y
  peso semibold/bold. No animar cards por vencimiento.

Accesibilidad:

- Los chips no deben depender solo del color; el texto debe incluir la semantica
  (`Vencida`, `Vence hoy`, `Vence 21 jun`).
- Los inputs `type="date"` deben tener label visible `Vencimiento`.
- Las etiquetas compactas deben tener `title` o texto completo cuando se abrevie
  en superficies pequenas.

Movimiento por vencimiento en tasks:

- Mas de 7 dias: sin movimiento por due date.
- De 7 a 4 dias: `decay-shake-low` si no hay una severidad mayor por edad.
- De 3 a 1 dias: `decay-shake-medium` si no hay una severidad mayor por edad.
- Hoy o vencida: `decay-shake-high` si la task no esta completada.
- Task completada: sin movimiento por due date, aunque la fecha haya pasado.

Esta regla aprovecha una senal ya aprendida por el usuario en el pool, pero no
convierte el tablero en una superficie constantemente animada. La animacion
queda cubierta por la regla global `prefers-reduced-motion` existente.

## Plan Por Slices

### Slice 1: Dominio, DB Y API

Producto:

- Introducir la semantica de vencimiento opcional en tasks y cards.
- Mantener compatibilidad con datos y payloads existentes.

Codigo:

- Crear `domain/due_date.gleam` con tipo opaco y parse/format/comparacion.
- Crear migracion con `due_date DATE NULL` en `tasks` y `cards`.
- Actualizar SQL, mappers y servicios de tasks/cards, incluyendo todas las
  queries que devuelven `Task` o `Card`.
- Actualizar tipos compartidos y codecs.
- Actualizar payloads y presenters HTTP.
- Extender `TaskUpdates` con `FieldUpdate(Option(DueDate))`.
- Exponer `card_due_date` en respuestas de task cuando haya card asociada.
- Regenerar `sql.gleam` con `make squirrel`.

Tests:

- Tests de `domain/due_date.gleam`: formato, fecha real, bisiestos,
  comparacion y distancia por dias.
- Payloads aceptan ausente, `null` y fecha valida.
- Payloads rechazan fecha invalida y timestamp.
- HTTP create/update/list preserva y borra `due_date`.
- Task list devuelve `card_due_date` cuando aplica.
- Claim, release, complete, get y list-by-card conservan los campos nuevos.

### Slice 2: Formularios Y Detalle De Task

Producto:

- Permitir crear y editar vencimiento sin alterar prioridad, owner ni estado.
- Mostrar contexto de card cuando la task no tenga fecha propia.

Codigo:

- Anadir campo `Vencimiento` al formulario de creacion despues de `Tipo` y
  antes de ubicacion (`Tarjeta` o hito).
- Anadir campo al editor de detalle en la seccion de planificacion como tercer
  elemento de la grid.
- Normalizar cadena vacia a `None` en operaciones de cliente.
- Mostrar `Vencimiento` en summary y hover.
- Anadir claves i18n para `Vencimiento`, `Sin vencimiento`,
  `Fecha invalida`, `Vence hoy`, `Vencida`, `Vence con tarjeta`.

Tests:

- Estado de formulario inicializa sin fecha.
- Create/update envia `due_date` cuando se informa y `null` cuando se borra.
- Vistas renderizan fecha propia, fecha de card heredada y estado sin fecha.
- `tasks_detail_edit_form_test` cubre dirty-state cuando solo cambia due date.

### Slice 3: Cards

Producto:

- Tratar la fecha de card como compromiso de paquete.
- Hacerla visible en detalle y administracion sin sobrecargar listados.

Codigo:

- Anadir `due_date` al dialogo CRUD de cards.
- Mostrar badge en modal/detalle de card.
- Mostrar valor compacto en lista de cards de miembro.
- Anadir columna `VENCE` en administracion de cards.
- Incluir `due_date` en `card_to_json` del web component para que create/edit
  refresquen estado padre sin perder el campo.

Tests:

- Dialogo de card crea, edita y borra due date.
- Lista y detalle muestran severidad correcta.
- Tabla de admin mantiene layout y muestra `Sin vencimiento` o valor compacto.
- Eventos `card-created` y `card-updated` conservan `due_date`.

### Slice 4: Pool, My Bar Y Senales De Urgencia

Producto:

- Usar el vencimiento como senal de atencion, no como ruido visual.
- Priorizar vencidas y proximas cuando el usuario escanea trabajo.

Codigo:

- Crear helper `ui/due_date.gleam` con severidad, etiqueta y formato compacto.
- Integrar chip de vencimiento en cards de pool solo para fechas urgentes.
- Integrar la severidad de vencimiento en la clase de movimiento de task cards,
  reutilizando `decay-shake-low`, `decay-shake-medium` y `decay-shake-high`.
- Integrar senal en mobile metadata cuando sea vencida, hoy o pronto.
- Evaluar si `my_bar` necesita mostrar la misma senal en tareas activas.
- Sustituir o actualizar el decoder local de `Task` en `card_detail_modal.gleam`.

Tests:

- Helper clasifica futuro, pronto, hoy, vencida y finalizada.
- Helper combina severidad de envejecimiento y vencimiento sin generar clases
  duplicadas.
- Pool desktop no renderiza chip para fechas lejanas.
- Pool mobile no rompe layout con etiquetas largas.
- `card_detail_modal_test` cubre tasks con due date dentro de la card.

### Slice 5: Verificacion Y Rollout

Producto:

- Confirmar que el flujo principal sigue siendo crear, tomar, mover y cerrar
  trabajo sin depender del vencimiento.

Codigo:

- Revisar estilos en desktop y mobile con `agent-browser`.
- Ejecutar `make squirrel` si las queries SQL lo requieren.
- Ejecutar formatter y suite de tests.

Comandos esperados:

```sh
make squirrel
gleam format
make test
```

## Criterios De Aceptacion

- Se puede crear una task con o sin vencimiento.
- Se puede editar y borrar el vencimiento de una task.
- Se puede crear, editar y borrar el vencimiento de una card.
- La API conserva compatibilidad con clientes que no manden `due_date`.
- Una task asociada a una card muestra `card_due_date` sin copiarlo en
  `task.due_date`.
- Las fechas se guardan como `DATE` y se exponen como `YYYY-MM-DD`.
- En dominio compartido las fechas se manejan como `DueDate` validado.
- Fechas invalidas no entran al sistema.
- En pool desktop no aparece ruido visual para tasks sin fecha o con fecha
  lejana.
- En detalle, hover, card detail y admin cards el vencimiento es visible y
  consistente.
- Los estados finalizados no se marcan como vencidos con severidad de error.

## Fuera De Alcance Inicial

- Recordatorios, notificaciones o emails.
- Recurrencias.
- Calendario.
- Orden automatico por due date.
- Filtro de due date en pool o administracion.
- Cambios automaticos de prioridad o estado.
- Copiar automaticamente `card.due_date` a `task.due_date`.
- SLA por tipo de task.

## Decisiones Closeds

- La columna `VENCE` en administracion de cards entra en el primer slice visual,
  pero el filtro de vencimiento queda fuera del alcance inicial.
- El pool no recibe filtro `vencidas/proximas` en el primer slice; solo senal
  visual para mantener el scanning ligero.
- El texto de producto usa `Vencimiento` en formularios y detalle, `Vence` en
  chips compactos y `due_date` solo en codigo/API.
- La fecha efectiva de una task para visualizacion es `task.due_date` si existe;
  si no, `task.card_due_date`. Esta fecha efectiva no se persiste como copia.
- Las tasks pueden usar el mismo movimiento progresivo que el envejecimiento del
  pool, pero siempre como una unica severidad combinada.
- Las cards vencidas usan rojo y peso fuerte solo en el valor de vencimiento; no
  reciben shake ni tratamiento de fila completa.
- Los calculos de severidad usan fecha local de UI para "hoy", pero solo contra
  valores `YYYY-MM-DD`; no se convierten a timestamps con hora.
