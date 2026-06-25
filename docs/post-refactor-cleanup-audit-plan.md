# Post-refactor cleanup audit plan

Fecha: 2026-06-25

## Objetivo

Este documento registra el plan final de limpieza posterior al refactor. Integra
la auditoria previa, el plan contrastado con una nueva lectura del codigo, y los
hallazgos adicionales detectados durante la revision.

El objetivo no es partir archivos por tamano ni crear capas nuevas por simetria.
El objetivo es mover la base de codigo al modelo final, eliminar trazas del
modelo anterior, borrar marcadores sin comportamiento, y conservar solamente la
ruta de migracion necesaria desde el commit que esta en produccion.

## Principios

1. No mantener modulos marcador. Un modulo existe porque posee comportamiento,
   tipos, frontera, tests o integracion real.
2. No crear abstracciones genericas para resolver un problema local de producto.
3. No mantener legacy ni compatibilidad interna. La unica compatibilidad de
   produccion a considerar es migrar correctamente desde el servicio desplegado
   en `686908bfb7b2774a8c3949c0a4b07c1715b80e21`.
4. Sustituir gates de forma por tests de comportamiento.
5. Hacer primero los cortes que quitan falsos positivos y tests ficticios, luego
   los cambios de naming y ownership mas amplios.
6. Cada corte debe dejar un guardarrail repetible con `rg`, test o ambos.

## Baseline de produccion y criterio anti-legacy

Solo existe un servicio en produccion y esta desplegado en:

```txt
686908bfb7b2774a8c3949c0a4b07c1715b80e21
```

Por tanto, el plan no debe conservar compatibilidad con estados intermedios de
la rama actual ni con migraciones locales no desplegadas. Todo lo posterior al
commit de produccion puede ser reconstruido, squasheado o eliminado si el
resultado final cumple estas condiciones:

1. una instalacion en el commit de produccion puede migrar al modelo final;
2. los datos reales necesarios se preservan o se transforman explicitamente;
3. no quedan valores, rutas, modulos ni tests de compatibilidad interna;
4. los nombres canonicos finales son los que emite el codigo nuevo.

Esto habilita una limpieza agresiva de:

- migraciones reparadoras o intermedias no desplegadas;
- constraints y backfills que solo corregian estados de la rama;
- adapters de compatibilidad entre nombres antiguos y nuevos dentro de la rama;
- tests que verifican compatibilidad con modelos no desplegados;
- scripts HT12 que validan hitos intermedios en lugar del estado final.

La excepcion son migraciones historicas anteriores o iguales al commit de
produccion, que deben tratarse como punto de partida operativo y no borrarse sin
reconstruir una ruta de upgrade equivalente.

## Objetivo cuantitativo de limpieza

El plan no se considera satisfactorio si no reduce al menos 8.000 lineas netas
no-doc respecto al baseline registrado antes del primer cambio de limpieza,
salvo justificacion tecnica explicita y aceptada antes de cerrar el goal.

Objetivo preferente: reducir entre 12.000 y 16.000 lineas netas no-doc y
eliminar entre 75 y 125 archivos, priorizando codigo obsoleto, stubs,
compatibilidad interna, tests duplicados, seeds repetidas, migraciones no
desplegadas squasheables y superficies que conserven trazas del modelo anterior.

Objetivo stretch: reducir entre 16.000 y 20.000 lineas netas no-doc si la
reconstruccion de migraciones no desplegadas, schema generado, scripts HT12 y
seeds de escenarios permite hacerlo sin perder comportamiento ni cobertura
necesaria.

La metrica debe calcularse contra el commit/HEAD inmediatamente anterior al
inicio de este plan, no contra `3511cf309cb45015109f81ab78733e6db34ca1a0`.

Las reducciones en codigo generado, schema reconstruido o migraciones
squasheadas deben reportarse separadas de la reduccion en codigo fuente y tests,
para no ocultar el impacto real sobre mantenibilidad.

Despues de cada fase se debe registrar:

```sh
git diff <baseline-del-goal> --shortstat -- ':!docs/'
git diff <baseline-del-goal> --name-status -- ':!docs/' | awk '{count[$1]++} END {for (s in count) print s, count[s]}'
```

Si una fase aumenta lineas, debe justificar por que y compensarlo en una fase
posterior. No se permite compensar borrando cobertura util, contratos vivos o
tests de comportamiento sin sustitucion equivalente.

## Revision final de ambicion

La revision contra el plan anterior `docs/codebase_refactor_cleanup_plan.md` y
contra la estructura actual endurece el alcance. El plan anterior identificaba
capas correctas, pero aceptaba demasiado trabajo como "pendiente sano" o
"compatibilidad externa". Con un unico servicio desplegado en
`686908bfb7b2774a8c3949c0a4b07c1715b80e21`, esa tolerancia ya no es necesaria.

Medicion de referencia observada durante esta revision:

```txt
git diff 686908bfb7b2774a8c3949c0a4b07c1715b80e21 --numstat -- ':!docs/'
910 files, 75.844 additions, 38.293 deletions, +37.551 netas
```

Bloques de crecimiento que deben atacarse de forma explicita:

| Bloque | Neto observado desde produccion | Decision agresiva |
| --- | ---: | --- |
| DB/schema/migrations | +5.719 | Reconstruir ruta desde produccion y borrar migraciones intermedias no desplegadas |
| Scripts HT12/smoke | +1.654 | Eliminar scripts que validan hitos intermedios y sustituir por tests/gates finales |
| Tests cliente | +3.692 | Consolidar matrices duplicadas y borrar tests de compat interna |
| Tests servidor | +6.230 | Sustituir marker/smoke/tests duplicados por comportamiento agrupado |
| Tests shared | +2.007 | Borrar compat tests de estados no canonicos y mantener codecs finales |
| Client source | +7.334 | Reducir ownership duplicado en Pool/Show/Plan/Admin/Automations |
| Server source | +7.947 | Eliminar stubs, compactar use cases de transicion y cerrar naming legacy |
| Shared source | +2.940 | Reducir modelos duplicados y codecs de compat no desplegada |

Presupuesto de reduccion esperado por bloque:

| Bloque | Reduccion minima | Reduccion objetivo |
| --- | ---: | ---: |
| Migraciones/schema no desplegado | 2.500 | 4.500 |
| Scripts/gates HT12 | 1.000 | 1.600 |
| Stubs, aliases y marker tests | 800 | 1.200 |
| Lifecycle `completed`/`task_completed` | 1.000 | 2.000 |
| Tests duplicados o de compat interna | 2.500 | 4.000 |
| Seeds y escenarios repetidos | 1.500 | 2.500 |
| Pool/Card Show/Task Show ownership duplicado | 1.000 | 2.000 |
| Admin/automation/workflow naming y wrappers | 1.000 | 2.000 |
| API publica accidental y helpers obsoletos | 700 | 1.500 |

Regla nueva: una fase de movimiento de archivos no cuenta como avance suficiente
si no reduce lineas, archivos, superficie publica o terminos legacy. Si una fase
solo mueve codigo, debe cerrarse con una fase inmediata de poda.

## Diagnostico ejecutivo

| Prioridad | Area | Diagnostico | Decision |
| --- | --- | --- | --- |
| P0 | Modulos marcador | Hay ficheros creados para satisfacer gates, no para mover logica | Eliminar o convertir en owners reales |
| P0 | HT-12 final cleanup | Valida strings y presencia de ficheros, no calidad ni atomicidad | Reemplazar por tests de comportamiento y gates negativos |
| P0 | Legacy activo `card-tree` | Quedan clases, tests y textos activos no detectados por el gate actual | Renombrar o eliminar segun modelo actual |
| P1 | Rutas legacy | `external_route_aliases` mantiene URLs antiguas vivas | Eliminar salvo contrato externo explicito |
| P1 | Lifecycle `complete/completed` | `closed` es el modelo final, pero `completed` sigue en dominio/API/DB/UI | Migrar a `closed`/`task_closed` o aislar frontera externa |
| P1 | Card Show | Superficie de producto vive en `components/` y concentra estado, update y view | Mover a `features/cards/show/` y partir localmente |
| P1 | Task Show | El estado del show sigue dentro de Pool | Mover ownership a `features/tasks/show/` |
| P1 | Plan | `structure_view` concentra scope, filtros, rollups, acciones, move model y DOM | Partir por responsabilidades locales |
| P1 | Scripts y smoke HT12 | Scripts shell validan hitos intermedios y strings antiguos | Sustituir por checks finales o tests reales |
| P1 | Seeds de escenarios | `seed_*` suma miles de lineas y mezcla QA con fixtures | Consolidar escenarios finales y borrar seed data intermedia |
| P1 | Admin/automation | Conviven `admin/workflows`, `automations/*`, templates y metrics | Consolidar naming y borrar wrappers obsoletos |
| P2 | API publica accidental | Muchos modulos internos exponen helpers `pub` por tests o composicion antigua | Privatizar y cubrir por entradas reales |
| P2 | Tests/seeds/docs | Tests y seeds crecieron con duplicacion; docs mezclan estado vivo e historico | Limpiar despues de preservar cobertura |

## Evidencia principal

### Modulos marcador

Estos ficheros no tienen comportamiento real y solo aparecen como soporte de
gates:

- `apps/client/src/scrumbringer_client/api_response_model.gleam`
- `apps/server/src/scrumbringer_server/repository/audit_events.gleam`
- `apps/server/src/scrumbringer_server/use_case/card_activate.gleam`
- `apps/server/src/scrumbringer_server/use_case/card_close.gleam`
- `apps/server/src/scrumbringer_server/use_case/task_claim.gleam`
- `apps/server/src/scrumbringer_server/use_case/task_complete.gleam`
- `apps/server/src/scrumbringer_server/use_case/task_release.gleam`

El owner real de audit hoy es
`apps/server/src/scrumbringer_server/use_case/audit_events_db.gleam`. No se debe
crear un repository stub si no va a poseer persistencia, transacciones o un
contrato real.

Decision: eliminar los marcadores. Si se decide extraer casos de uso, hacerlo
por comportamiento probado, no por satisfacer nombres de fichero.

### HT-12 final cleanup

`apps/server/test/final_cleanup_ht12_ffi.erl` valida forma:

- presencia de modulos;
- strings como `transaction` y `audit`;
- strings como `ApiReturned`, `from_api_response` y `replace_from_response`;
- ausencia parcial de terminos legacy.

Esto no prueba atomicidad, rollback, audit correcto, ni ownership. Debe
reemplazarse por:

- tests de transicion exitosa que validen estado persistido y audit event;
- tests de conflicto que validen ausencia de audit event;
- test de rollback si falla la parte audit/persistencia, cuando sea viable sin
  acoplarse demasiado al motor SQL;
- gates negativos de ausencia de stubs y terminos legacy activos.

### Card Show

`apps/client/src/scrumbringer_client/components/card_show.gleam` es una
superficie de producto completa: estado, mensajes, tabs, notas, actividad,
acciones, task list y politicas. No es un componente generico.

Decision: mover a `apps/client/src/scrumbringer_client/features/cards/show/`.
Primer corte: mover sin cambiar comportamiento. Segundo corte: partir en
modulos locales.

Propuesta de modulos:

- `model.gleam` o `state.gleam`
- `update.gleam`
- `view.gleam`
- `summary.gleam`
- `work.gleam`
- `notes.gleam`
- `activity.gleam`
- `actions.gleam`
- `policy.gleam`

### Plan

`apps/client/src/scrumbringer_client/features/plan/structure_view.gleam`
concentra responsabilidades distintas:

- controles de scope y filtros;
- busqueda de destino y opciones de movimiento;
- render tabla y render mobile;
- calculo de rows, rollups y resumen;
- politica de acciones;
- drag/drop y move model;
- empty states y detalle.

Decision: partir dentro de `features/plan/`, sin crear una abstraccion generica
de tabla, arbol o move framework.

Propuesta de modulos:

- `structure_controls.gleam`
- `structure_rows.gleam`
- `structure_rollups.gleam`
- `structure_policy.gleam`
- `structure_move.gleam`
- `structure_table.gleam`
- `structure_detail.gleam`
- `structure_empty.gleam`

### Task Show y Pool

`apps/client/src/scrumbringer_client/client_state/member/pool.gleam` conserva
campos `member_task_show_*`. Al mismo tiempo existen
`features/tasks/show_state.gleam` y `features/tasks/show_update.gleam`, pero
siguen mutando Pool como storage.

Decision: `features/tasks/show/` debe poseer su propio estado. Pool debe quedar
como origen de navegacion, lista, filtros y contexto de trabajo, no como owner
del detalle.

### Rutas legacy

`apps/client/src/scrumbringer_client/external_route_aliases.gleam` conserva
aliases como `templates`, `rule-metrics` y `assignments`. El router los consume.

Decision: eliminar el modulo y sus tests si el producto ya no quiere legacy. Si
alguna URL antigua debe sobrevivir, moverla a un adapter de frontera externa con
owner, comentario de expiracion y test especifico.

### Lifecycle `completed`

El modelo final de ejecucion es `closed`, pero sobreviven valores antiguos:

- `shared/src/domain/task_status.gleam` parsea y emite `completed`.
- `shared/src/domain/automation.gleam` emite `task_completed` y `completed`.
- `db/schema.sql` conserva constraints con `task_completed`.
- APIs cliente, admin workflows, tests y migraciones usan esos valores.

Decision fuerte: migrar hacia `closed` y `task_closed`. Como la unica
compatibilidad de produccion es migrar desde
`686908bfb7b2774a8c3949c0a4b07c1715b80e21`, no se debe conservar compatibilidad
con valores intermedios no desplegados.

Secuencia recomendada:

1. Renombrar owners internos `complete` a `close` cuando no sean contrato
   externo.
2. Renombrar SQL/source query de `tasks_complete` a `tasks_close` y actualizar
   callers generados.
3. Introducir rutas/API canonicas `close` si aun no existen.
4. Migrar `task_completed` a `task_closed` en rules, automation y DB
   constraints.
5. Migrar `completed` a `closed` en filtros y payloads publicos si no hay
   contrato externo que lo impida.
6. Durante la migracion desde produccion, transformar valores antiguos al modelo
   final. No permitir que el dominio ni la API nueva emitan valores legacy.

### Workflow y automation

El producto usa `Automations`, pero dominio/API/DB siguen usando `workflow`,
`task_templates` y `rule_metrics`. Tambien existe ya lenguaje de `engine` en
eventos de configuracion.

Decision pendiente:

- Opcion recomendada para modelo final: `AutomationEngine` como entidad interna
  y de producto.
- `TaskTemplate` puede mantenerse solo si se usa fuera de automations. Si no,
  migrar a `AutomationTaskTemplate`.
- `RuleMetrics` debe aclararse como metricas de ejecucion de automation/rule.

La migracion de tabla/rutas puede ir despues del dominio si el riesgo es alto,
pero el plan debe definir el destino para evitar convivencia indefinida.

La revision final anade un criterio mas agresivo: no basta con renombrar. Deben
desaparecer wrappers y superficies duplicadas entre `features/admin/*` y
`features/automations/*` cuando solo existen por la transicion. `admin/workflows`,
`admin/task_templates` y `admin/rule_metrics` no pueden sobrevivir como
conceptos paralelos si el producto final se llama Automations.

### Card tree activo

Quedan trazas activas `card-tree-*` en:

- `apps/client/src/scrumbringer_client/features/hierarchy/scope_view.gleam`
- `apps/client/src/scrumbringer_client/styles/layout.gleam`
- `apps/client/test/hierarchy_scopes_ht09_test.gleam`
- comentarios como `loaded card tree`

Decision: renombrar a la nomenclatura canonica actual o eliminar si la UI ya no
debe exponer ese concepto. Actualizar el gate para detectar `card-tree`,
`card_tree`, `Card tree` y variantes relevantes.

### Tests, seeds y docs

Hay archivos grandes que hoy mezclan matrices de comportamiento:

- `apps/server/src/scrumbringer_server/seed_db.gleam`
- `apps/server/src/scrumbringer_server/seed_builder.gleam`
- `apps/server/src/scrumbringer_server/seed_plan_scenarios.gleam`
- `apps/server/src/scrumbringer_server/seed_root_card_scenarios.gleam`
- `apps/server/src/scrumbringer_server/seed_people_scenarios.gleam`
- `apps/server/src/scrumbringer_server/seed_task_scenarios.gleam`
- `apps/server/test/tasks_http_test.gleam`
- `apps/server/test/rules_engine_test.gleam`
- `apps/server/test/projects_http_test.gleam`

Decision: partir por matriz de comportamiento, no por numero de lineas. Pero la
revision final endurece esto: no se trata solo de partir, sino de borrar
escenarios que validan estados intermedios, duplican fixtures o existen solo
para HT12. El seed final debe ser una matriz minima de producto, no un registro
de todas las iteraciones del refactor.

Docs: los documentos historicos pueden conservar nombres antiguos, pero el
indice y las docs vivas no deben presentar terminos legacy como modelo actual.

### Superficie publica accidental

La revision final detecta modulos internos con una API publica demasiado amplia,
incluyendo `shared/src/domain/automation.gleam`, `url_state.gleam`,
`seed_db.gleam`, `projects_db.gleam`, `api_tokens.gleam`,
`crud_dialog_base.gleam`, helpers UI y multiples updates de feature.

Decision: anadir una poda explicita de `pub fn`, `pub type` y `pub const`. Los
tests deben entrar por mensajes, rutas, HTTP, codecs o helpers puros realmente
compartidos. No debe mantenerse API publica solo porque un test antiguo llama a
un handler interno.

Guardarrail inicial:

```sh
rg -n "^pub (fn|type|const)" apps/client/src apps/server/src shared/src --glob "*.gleam"
```

Cada simbolo publico restante debe clasificarse como contrato de modulo,
frontera externa, helper compartido estable o residuo a privatizar.

### Migraciones no desplegadas

El estado de produccion permite tratar las migraciones posteriores al commit
`686908bfb7b2774a8c3949c0a4b07c1715b80e21` como material reconstruible. Por
tanto, la limpieza debe revisar especialmente:

- migraciones de repair/backfill creadas para estados intermedios;
- migraciones que introducen un nombre y otra posterior lo corrige;
- constraints que aceptan valores legacy solo por compatibilidad interna;
- schema generado que conserva tablas, columnas o checks obsoletos;
- tests que validan la existencia de esas migraciones intermedias.

La salida deseada es una ruta clara desde produccion hasta el modelo final, con
el menor numero de migraciones activas posible y sin compatibilidad con estados
que nunca llegaron a produccion.

## Plan de ejecucion

### Fase 0: preparar guardarrails

Objetivo: evitar que el plan se ejecute sobre una base equivocada.

1. Registrar branch, `HEAD`, estado dirty y base de comparacion.
2. Registrar el baseline de limpieza para metrica cuantitativa.
3. Verificar que el unico commit desplegado a considerar es
   `686908bfb7b2774a8c3949c0a4b07c1715b80e21`.
4. Ejecutar formatos y tests actuales de shared, client y server.
5. Guardar barridos `rg` iniciales para:
   - modulos marcador;
   - `card-tree`, `card_tree`, `Card tree`;
   - `complete`, `completed`, `task_completed`;
   - `workflow`, `workflows`, `rule_metrics`, `task_templates`;
   - `external_route_aliases`;
   - imports de `components/card_show`.

Salida esperada: baseline reproducible antes de tocar codigo.

### Fase 1: eliminar stubs, gates falsos y scripts HT12

Objetivo: quitar los artefactos que hacen parecer limpia la base sin demostrar
comportamiento.

1. Borrar o convertir los modulos marcador.
2. Reemplazar `final_cleanup_ht12_ffi.erl` por tests reales.
3. Eliminar `api_response_model.gleam` si solo existe para el gate.
4. Agregar tests de UI/update que demuestren que la respuesta API sustituye el
   estado local donde corresponda.
5. Convertir el gate final en:
   - tests de comportamiento;
   - barridos negativos contra stubs y legacy activo;
   - lista documentada de falsos positivos permitidos.
6. Eliminar scripts HT12 que validan hitos intermedios, strings antiguos o
   presencia de ficheros.
7. Actualizar `Makefile` y `dev-hot` para invocar solo checks finales.

Presupuesto de reduccion: 1.800-2.800 lineas netas.

Validacion minima:

```sh
rg -n "transactional_audit_marker|repository_ready|api_response_model|from_api_response" apps shared
rg -n "ht12|HT12|final_cleanup_ht12" scripts apps shared
```

El resultado debe estar vacio o limitado a tests reales que no exijan modulos
marcador.

### Fase 2: limpiar legacy activo de rutas y jerarquia

Objetivo: eliminar compatibilidad viva que no sea contrato externo defendible.

1. Eliminar `external_route_aliases.gleam`.
2. Quitar ramas del router que dependan de esos aliases.
3. Actualizar tests de routing para el contrato canonico.
4. Renombrar o eliminar `card-tree-*` activo en UI, estilos y tests.
5. Ampliar guardarrails para evitar regresion.

Presupuesto de reduccion: 300-800 lineas netas.

Validacion minima:

```sh
rg -n "external_route_aliases|card-tree|card_tree|Card tree" apps shared docs
```

Los matches en docs historicas deben estar justificados o movidos a seccion
historica.

### Fase 3: squashear migraciones no desplegadas y cerrar schema

Objetivo: eliminar migraciones intermedias y compatibilidad de rama que no
llegaron a produccion.

1. Listar migraciones presentes en produccion segun el commit
   `686908bfb7b2774a8c3949c0a4b07c1715b80e21`.
2. Clasificar migraciones posteriores como:
   - necesarias para migrar datos reales;
   - reparadoras de estados intermedios no desplegados;
   - naming/constraint cleanup que puede fusionarse;
   - obsoletas por el modelo final.
3. Reconstruir una ruta de migracion desde produccion al modelo final.
4. Regenerar schema final.
5. Eliminar constraints y backfills que acepten legacy interno.
6. Reportar reduccion de migraciones/schema separada del codigo fuente/test.

Presupuesto de reduccion: 2.500-4.500 lineas netas.

Validacion minima:

```sh
git diff <baseline-del-goal> --shortstat -- db ':!docs/'
rg -n "task_completed|completed|card_tree|workflow" db
```

Cada match restante debe ser punto de partida historico de produccion o nombre
final aceptado. No debe quedar compatibilidad con estados no desplegados.

### Fase 4: cerrar lifecycle task/card

Objetivo: que `closed` sea el modelo final y no una capa encima de
`completed`.

1. Renombrar internamente `complete` a `close` donde no sea contrato externo.
2. Cambiar source SQL y repository callers a nombres `close`.
3. Migrar automation triggers de `task_completed` a `task_closed`.
4. Migrar payloads/filtros de `completed` a `closed` si no existe contrato
   externo obligatorio.
5. Actualizar constraints y migraciones de datos.
6. Transformar valores antiguos durante la migracion desde produccion, no en
   runtime ordinario.

Presupuesto de reduccion: 1.000-2.000 lineas netas.

Validacion minima:

```sh
rg -n "task_completed|completed|/complete|tasks_complete|complete_task" apps shared db
```

Cada match restante debe ser una migracion historica anterior al baseline de
produccion o una referencia documentada como punto de partida. No debe haber
compatibilidad runtime con esos valores.

### Fase 5: mover ownership de Card Show

Objetivo: convertir Card Show en feature de producto.

1. Crear `features/cards/show/`.
2. Mover el modulo actual sin cambio semantico.
3. Actualizar imports de `features/cards/view.gleam` y `show_entry.gleam`.
4. Partir estado/update/view en cortes pequenos.
5. Extraer paneles locales: summary, work, notes, activity, actions, policy.
6. Eliminar el modulo antiguo de `components`.
7. Borrar tests de compat con `card_detail_modal`/nombres anteriores que no
   cubran comportamiento final.

Presupuesto de reduccion: 500-1.200 lineas netas. El move puro no cuenta si no
va seguido de poda.

Validacion minima:

```sh
rg -n "components/card_show|scrumbringer_client/components/card_show" apps/client/src apps/client/test
```

Debe quedar vacio.

### Fase 6: mover ownership de Task Show

Objetivo: Pool deja de ser storage del detalle de tarea.

1. Crear estado propio en `features/tasks/show/`.
2. Migrar campos `member_task_show_*` fuera de `member_pool.Model`.
3. Dejar Pool como origen de lista, scope, filtros y navegacion.
4. Ajustar `features/pool/task_route.gleam` para mapear eventos, no poseer
   estado del show.
5. Cubrir open, close, refresh, notes, dependencies y lifecycle desde mensajes
   reales.
6. Borrar wrappers `features/pool/task_show*` cuando la feature nueva posea el
   show completo.

Presupuesto de reduccion: 700-1.500 lineas netas.

Validacion minima:

```sh
rg -n "member_task_show_|task_show_model|task_show_update.Model" apps/client/src/scrumbringer_client/client_state apps/client/src/scrumbringer_client/features
```

Los matches restantes deben vivir en `features/tasks/show/` o en adapters de
ruta muy pequenos.

### Fase 7: partir Plan localmente

Objetivo: reducir el monolito sin crear framework.

1. Extraer controles y filtros.
2. Extraer rows, selectors y rollups.
3. Extraer action policy.
4. Extraer move model y drag/drop decoders.
5. Extraer tabla y mobile row.
6. Extraer detalle y empty states.
7. Borrar helpers locales que solo duplicaban calculos despues de extraer
   selectors y policy.

Presupuesto de reduccion: 500-1.200 lineas netas. Partir sin reducir no cierra
la fase.

Validacion minima:

- tests actuales de `plan_structure_view_test.gleam`;
- barrido de imports para asegurar que los modulos nuevos son locales a
  `features/plan/`;
- sin componentes genericos nuevos salvo que tres features los necesiten.

### Fase 8: alinear automation/workflow

Objetivo: decidir y ejecutar la nomenclatura final, borrando superficies
duplicadas de transicion.

1. Elegir destino: recomendado `AutomationEngine`.
2. Renombrar shared domain y cliente hacia ese destino.
3. Migrar DB/rutas si no aumenta el riesgo de upgrade desde produccion; si se
   aplaza, dejar un adapter estrecho y fechado, no una capa paralela.
4. Renombrar templates y metrics si solo pertenecen a automations.
5. Eliminar wrappers admin obsoletos: `admin/workflows`, `admin/task_templates`,
   `admin/rule_metrics` como conceptos paralelos.
6. Consolidar rule list, template library, execution history y engine list si
   hay config/state duplicado.
7. Actualizar docs, API contract y tests.

Presupuesto de reduccion: 1.000-2.000 lineas netas.

Validacion minima:

```sh
rg -n "workflow|workflows|task_templates|rule_metrics" apps shared db docs
```

Cada match restante debe estar clasificado como:

- nombre final aceptado;
- adapter temporal estrictamente necesario para migrar desde produccion;
- migracion historica;
- doc historica.

### Fase 9: consolidar seeds y escenarios

Objetivo: convertir seeds en una matriz minima de producto y borrar escenarios
de hitos intermedios.

1. Clasificar cada `seed_*` como producto final, fixture comun, validacion
   browser o residuo HT12.
2. Fusionar seeds redundantes de Plan/root card/people/task/card cuando
   describan el mismo workspace.
3. Borrar seeds de automation diagnostics/executions si solo duplican tests HTTP
   o scripts HT12.
4. Mantener IDs deterministas solo donde los tests o validaciones los requieran.
5. Dividir `seed_db.gleam` por familias finales o reducirlo a helper estrecho de
   persistencia.

Presupuesto de reduccion: 1.500-2.500 lineas netas.

Validacion minima:

- los escenarios finales cubren Pool, Plan, Cards, Tasks, Automations,
  Permissions y Activity sin duplicar workspaces;
- ningun seed existe solo porque un script HT12 lo esperaba;
- browser/API validations actualizadas a la matriz final.

### Fase 10: limpiar tests duplicados

Objetivo: bajar coste de mantenimiento despues de preservar comportamiento.

1. Partir `tasks_http_test.gleam` por matrices: lifecycle, audit, dependencies,
   metrics, auth, pool inclusion, work sessions.
2. Partir `rules_engine_test.gleam` por trigger matching, actions, persistence,
   idempotency, interpolation y project scoping.
3. Partir `projects_http_test.gleam` por settings, hierarchy, members,
   permissions y switching.
4. Borrar tests que solo prueban compatibilidad con rutas, valores o modulos no
   desplegados.
5. Reemplazar tests de handlers internos por tests de ruta, HTTP, mensaje real,
   codec o helper puro compartido.

Presupuesto de reduccion: 2.500-4.000 lineas netas.

Validacion minima:

- la suite conserva o mejora cobertura;
- ningun helper nuevo actua como framework generico;
- los tests eliminados tienen reemplazo o justifican que cubrian solo legacy.

### Fase 11: podar API publica accidental y helpers obsoletos

Objetivo: cerrar APIs internas abiertas durante el refactor anterior.

1. Generar inventario de `pub fn`, `pub type` y `pub const`.
2. Privatizar handlers internos llamados solo por tests.
3. Borrar helpers UI/feature que solo envolvian una llamada o conservaban copy
   antigua.
4. Reducir `shared/src/domain/automation.gleam` moviendo codecs/string mapping a
   frontera si ya no son dominio.
5. Reducir `url_state.gleam` y route helpers a contrato canonico, sin aliases.
6. Borrar componentes CRUD genericos si tras mover Card/Task/Admin ya no
   reducen duplicacion real.

Presupuesto de reduccion: 700-1.500 lineas netas.

Validacion minima:

```sh
rg -n "^pub (fn|type|const)" apps/client/src apps/server/src shared/src --glob "*.gleam"
```

Cada simbolo publico restante debe tener consumidor productivo o frontera
documentada.

### Fase 12: docs vivas y cierre anti-overengineering

Objetivo: cerrar el plan sin dejar documentacion viva contradiciendo el modelo
final.

1. Marcar historicas las docs que mencionen modelos antiguos.
2. Actualizar arquitectura, API contract, data model, no-legacy rules e indice.
3. Borrar docs de validacion HT12 que ya no correspondan a checks finales.
4. Ejecutar barridos finales y registrar reduccion cuantitativa.

Presupuesto de reduccion no-doc: 0. Esta fase no compensa objetivos de codigo.

## Orden recomendado

| Orden | Fase | Motivo |
| --- | --- | --- |
| 1 | Guardarrails | Evita ejecutar sobre supuestos obsoletos |
| 2 | Stubs, HT-12 y scripts | Quita falsos positivos y validaciones de hitos intermedios |
| 3 | Rutas y `card-tree` | Limpieza acotada, alto valor, bajo acoplamiento |
| 4 | Migraciones/schema no desplegado | Alto impacto de lineas y elimina compat interna antes de dominio |
| 5 | Lifecycle `closed` | Alto valor, alto riesgo; requiere tests ya fortalecidos |
| 6 | Card Show | Corrige ownership visible de producto |
| 7 | Task Show | Reduce acoplamiento de Pool |
| 8 | Plan | Refactor local grande, mejor despues de estabilizar shows |
| 9 | Automation/workflow/admin | Naming estrategico y borrado de wrappers paralelos |
| 10 | Seeds | Alto volumen y mucha deuda de escenarios intermedios |
| 11 | Tests | Consolidacion despues de preservar comportamiento final |
| 12 | API publica accidental | Cierra superficie abierta por tests/refactor anterior |
| 13 | Docs vivas | Cierre documental, sin contar como reduccion no-doc |

## Criterio de finalizacion

El plan se considera completo cuando:

1. No quedan modulos marcador ni gates que validen solo strings positivos.
2. No quedan rutas legacy vivas ni adapters internos de compatibilidad.
3. `closed` y `task_closed` son los valores canonicos del modelo final.
4. Card Show y Task Show viven bajo `features/*/show/`.
5. Pool no posee estado interno del detalle de tarea.
6. Plan esta partido por responsabilidades locales.
7. Workflow/automation tiene una semantica unica documentada y no conserva
   wrappers admin paralelos.
8. Tests y seeds estan organizados por matrices de comportamiento final, sin
   escenarios de compat interna.
9. Scripts HT12 o smoke de hitos intermedios han sido eliminados o sustituidos
   por checks finales.
10. La ruta de migracion desde `686908bfb7b2774a8c3949c0a4b07c1715b80e21`
    hasta el modelo final esta probada.
11. La superficie publica interna fue auditada y los handlers/helpers
    accidentales se privatizaron o justificaron.
12. Docs vivas no presentan nombres historicos como arquitectura actual.
13. La reduccion neta no-doc es >= 8.000 lineas o existe una justificacion
    tecnica explicita.
14. El objetivo preferente de 12.000-16.000 lineas netas se ha intentado
    atacando stubs, legacy, scripts, tests, seeds, migraciones no desplegadas,
    API publica accidental y duplicacion real.

## Riesgos principales

| Riesgo | Mitigacion |
| --- | --- |
| Romper migracion desde produccion al migrar `completed` | Probar upgrade desde `686908bfb7b2774a8c3949c0a4b07c1715b80e21` al schema final |
| Perder cobertura al borrar HT-12 | Reemplazar primero por tests de comportamiento, despues borrar gate antiguo |
| Convertir Card/Task Show en demasiados modulos | Mover primero, partir despues solo por responsabilidades existentes |
| Crear framework de Plan | Mantener todos los modulos bajo `features/plan/` y prohibir helpers genericos prematuros |
| Naming workflow/automation demasiado grande | Separar decision semantica, dominio, API y DB en cortes verificables |
| Borrar una migracion necesaria para datos reales | Clasificar cada migracion posterior a produccion y conservar la transformacion necesaria en la ruta final |
| Cumplir metricas borrando tests utiles | Cada test eliminado debe cubrir legacy interno, duplicacion real o tener reemplazo por comportamiento final |
| Fases que solo mueven archivos | Cada fase con moves debe cerrar con poda cuantitativa o reduccion de API publica |

## Comandos de auditoria recurrentes

```sh
rg -n "transactional_audit_marker|repository_ready|api_response_model|from_api_response" apps shared
rg -n "external_route_aliases|card-tree|card_tree|Card tree" apps shared docs
rg -n "task_completed|completed|/complete|tasks_complete|complete_task" apps shared db
rg -n "components/card_show|scrumbringer_client/components/card_show" apps/client/src apps/client/test
rg -n "member_task_show_|task_show_model|task_show_update.Model" apps/client/src/scrumbringer_client/client_state apps/client/src/scrumbringer_client/features
rg -n "workflow|workflows|task_templates|rule_metrics" apps shared db docs
rg -n "^pub (fn|type|const)" apps/client/src apps/server/src shared/src --glob "*.gleam"
find apps/server/src/scrumbringer_server -maxdepth 1 -name "seed*.gleam" -printf "%p\n" | sort | xargs wc -l
```

Estos comandos no son criterio unico de calidad. Son guardarrails para detectar
regresiones y para obligar a clasificar cada resto como modelo final, adapter
temporal, migracion historica o documentacion historica.

## Registro de ejecucion

Baseline de ejecucion:

```txt
b4f7fdbb31e996ddf2a6fa6476a2a9908c8c2ab1
```

Produccion usada como unico punto de compatibilidad:

```txt
686908bfb7b2774a8c3949c0a4b07c1715b80e21
```

Resultado no-doc contra el baseline de ejecucion:

```txt
git diff b4f7fdbb31e996ddf2a6fa6476a2a9908c8c2ab1 --shortstat -- ':!docs/'
148 files changed, 2608 insertions(+), 11147 deletions(-)
```

Reduccion neta no-doc: `-8.539` lineas.

Distribucion de cambios no-doc:

```txt
A 1
R099 1
R100 1
D 47
M 98
```

La ejecucion supera el objetivo minimo de `-8.000` lineas netas. No alcanza el
objetivo preferente de `-12.000` a `-16.000` porque los siguientes bloques
siguen conteniendo cobertura o comportamiento vivo y no se han borrado solo para
mejorar la metrica:

- `apps/server/test/tasks_http_test.gleam`
- `apps/server/test/notes_and_positions_http_test.gleam`
- `apps/server/test/projects_http_test.gleam`
- `apps/server/test/rules_engine_test.gleam`
- `apps/client/src/scrumbringer_client/features/plan/structure_view.gleam`
- `apps/client/src/scrumbringer_client/client_state/member/pool.gleam`
- `apps/server/src/scrumbringer_server/seed_db.gleam`

Limpieza ejecutada:

- eliminados modulos marcador sin comportamiento;
- eliminados gates y scripts HT12 de hito intermedio;
- eliminadas rutas legacy externas y tests de aliases;
- consolidada la ruta de migracion posterior a produccion en una migracion
  final desde `686908bfb7b2774a8c3949c0a4b07c1715b80e21`;
- eliminado `db/schema.sql`, tratado como dump local;
- eliminadas migraciones reparadoras no desplegadas;
- eliminados bloques `migrate:down`, porque no se conserva rollback legacy;
- migrado lifecycle publico de `complete/completed/task_completed` a
  `close/closed/task_closed`;
- movido Card Show de `components/` a `features/cards/show.gleam`;
- eliminados tests/seeds duplicados o de compatibilidad interna;
- eliminado el reporte transitorio `card_tree_migration_report` y las trazas
  activas `card_tree`;
- renombradas metricas de estado de card modal de `tasks_completed` a
  `tasks_closed`.

Barridos finales relevantes:

```sh
rg -n "tasks_completed|task_completed|TaskCompleted|status=completed|#\(\"completed\"|/complete|complete_task|tasks_complete|handle_complete|invalid_migrated_rule|card_tree|card-tree|external_route_aliases|final_cleanup_ht12|api_response_model" apps shared db scripts Makefile --glob '!**/build/**' --glob '!apps/client/dist/**'
```

Resultado: sin coincidencias.

Validacion ejecutada:

```txt
shared: gleam format --check src test && gleam test
270 passed, no failures

apps/client: gleam format --check src test && gleam test --target javascript
1781 passed, no failures

apps/server: gleam format --check src test && gleam build
build correcto

git diff --check -- ':!docs/'
sin errores
```

Validacion DB/server reabierta tras confirmar PostgreSQL local en `5433`:

```txt
pg_isready -p 5433
/var/run/postgresql:5433 - aceptando conexiones
```

Los tests HTTP/integracion de server y la prueba real de migracion con dbmate
deben ejecutarse contra este puerto antes de cerrar el goal.

### Fase 6 ejecutada: Task Show fuera de Pool

Cambio ejecutado:

- creado `features/tasks/show/model.gleam` como estado local del detalle de
  tarea;
- movidos los presenters `task_show*` desde `features/pool/` a
  `features/tasks/show/`;
- actualizado `member_pool.Model` para conservar solo un submodelo
  `task_show`, eliminando los campos `member_task_show_*`;
- actualizados update/state/config/tests para acceder al estado desde la
  feature de Task Show;
- renombrados tests `pool_task_show_*` a `tasks_show_*`;
- actualizados comentarios y nombres de tests que conservaban ownership antiguo.

Metrica no-doc contra el baseline de ejecucion tras esta fase:

```txt
git diff b4f7fdbb31e996ddf2a6fa6476a2a9908c8c2ab1 --shortstat -- ':!docs/'
173 files changed, 2991 insertions(+), 11424 deletions(-)
```

Reduccion neta no-doc acumulada: `-8.433` lineas.

Nota: antes de commitear, el movimiento de ficheros aparecia como borrado
masivo porque los destinos aun no estaban trackeados. La metrica oficial del
plan se calcula con `git diff` contra el baseline y detecta renames; por tanto,
esta fase cuenta como reduccion de ownership/superficie legacy, no como gran
reduccion neta de lineas.

Distribucion acumulada de cambios no-doc:

```txt
A 2
R098 6
R099 1
R100 4
D 47
R093 1
R096 1
M 111
```

Guardarrails ejecutados:

```sh
rg -n "features/pool/task_show|pool/task_show|member_task_show_|import scrumbringer_client/features/pool/task_show|pool_task_show" apps/client/src apps/client/test --glob '!**/build/**' --glob '!apps/client/dist/**'
```

Resultado: sin coincidencias.

Validacion ejecutada:

```txt
apps/client: gleam format src test && gleam test --target javascript
1781 passed, no failures
```

### Validacion DB/server ejecutada en PostgreSQL 5433

Hallazgo:

- `dbmate` exige que toda migracion tenga bloque `-- migrate:down`;
- la migracion final se mantiene irreversible, pero incluye el separador
  requerido por la herramienta para poder ejecutar `migrate`.

Validacion de upgrade desde produccion:

```txt
DB: scrumbringer_test en localhost:5433
produccion: 686908bfb7b2774a8c3949c0a4b07c1715b80e21
production_migrations=35
current final migration applied: 20260626000000_post_production_final_model.sql
schema_migrations_count=36
```

Secuencia ejecutada:

```sh
git archive 686908bfb7b2774a8c3949c0a4b07c1715b80e21 db/migrations | tar -x -C "$TMPDIR"
dbmate --url "$DATABASE_URL" --migrations-dir "$TMPDIR/db/migrations" migrate
dbmate --url "$DATABASE_URL" --migrations-dir db/migrations migrate
```

Validacion server:

```txt
DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_test?sslmode=disable
apps/server: gleam format src test && gleam test
564 passed, no failures
```
