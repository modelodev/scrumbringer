# Plan de reduccion mantenible de 20k lineas + tramo 30k

Fecha: 2026-06-28

## Objetivo

Reducir aproximadamente 20.000 lineas netas como objetivo base y dejar un tramo
condicionado hasta 30.000 lineas si la evidencia de la ejecucion lo permite sin
introducir sobreingenieria. La reduccion debe venir de eliminar duplicacion,
codigo muerto, API publica accidental, fixtures repetidas, estados redundantes,
queries SQL obsoletas y responsabilidades mezcladas. No cuenta como exito mover
lineas a otro modulo si no desaparece una decision duplicada o una frontera
publica innecesaria.

El objetivo principal acepta dos contabilidades separadas:

- Incluye `apps/client/src`, `apps/client/test`, `apps/server/src`,
  `apps/server/test`, `shared/src` y `shared/test`.
- Excluye `build/` y dependencias.
- `apps/server/src/scrumbringer_server/sql.gleam` se trata como generado: no se
  edita a mano. Su reduccion cuenta solo si es consecuencia verificable de
  borrar, fusionar o simplificar SQL fuente mantenido.
- Las entradas mantenidas de Squirrel si se auditan: ficheros `.sql` bajo
  `apps/server/src/scrumbringer_server/sql/`, repositorios que los consumen,
  migraciones que definen el esquema introspectado y `db/schema.sql` como
  contrato de validacion.
- Documentacion y migraciones se auditan, pero no se usan para demostrar las
  20k lineas salvo que se borre documentacion obsoleta claramente reemplazada.

Meta de cierre:

- Objetivo base: `-20.000` lineas netas entre codigo mantenido y generado
  derivado.
- Subobjetivo base mantenido: al menos `-12.000` lineas deben venir de codigo
  mantenido no generado.
- Subobjetivo generado base: hasta `-8.000` lineas pueden venir de `sql.gleam`
  si el diff se explica por cambios en SQL fuente real.
- Tramo de extension: `-30.000` lineas solo si los paquetes anteriores quedan
  verdes, el analisis V/C/R mantiene riesgo bajo o medio y se alcanzan al menos
  `-22.000` lineas mantenidas no generadas. El generado derivado puede ayudar,
  pero no puede ser la mayor parte del exito.
- Mas de `-30.000` no se fija como objetivo de este plan. Solo se decidiria tras
  una nueva auditoria posterior a los 30k, porque a partir de ahi aumenta mucho
  la probabilidad de borrar cobertura util o introducir abstracciones debiles.

## Baseline actual

Medicion original ejecutada sobre `f1df9c16 Execute remaining refactor work
packages`.

| Area | Lineas Gleam |
| --- | ---: |
| Cliente produccion | 89.349 |
| Servidor produccion | 43.537 |
| Shared produccion | 7.255 |
| Cliente tests | 43.216 |
| Servidor tests | 27.222 |
| Shared tests | 3.435 |
| Total Gleam | 214.014 |
| Produccion sin `sql.gleam` generado | 130.565 |

Baseline SQL/Squirrel mantenido:

| Area | Lineas / conteo | Lectura |
| --- | ---: | --- |
| SQL fuente Squirrel | 3.037 lineas en 114 ficheros | Entrada mantenida; si se borra una query obsoleta, se regenera `sql.gleam`. |
| `sql.gleam` generado | 9.576 lineas | Cuenta solo como delta derivado de cambios SQL fuente; nunca se edita a mano. |
| `-- name:` divergente del fichero | 69 ficheros | Squirrel 4.6.0 genera la funcion por nombre de fichero; estos comentarios inducen auditorias falsas. |
| SQL fuente sin uso directo por funcion generada | 4 ficheros | Candidatos: `cards_task_count`, `ping`, `tasks_list_by_card`, `task_templates_list_for_org`. |
| DB schema/migrations | 6.420 lineas | Contrato e historia; auditar validez, no recortar por metrica. |

Medicion actual tras `b23225cb Consolidate HTTP payload decoding`:

| Area | Lineas Gleam |
| --- | ---: |
| Cliente produccion | 87.799 |
| Servidor produccion | 42.246 |
| Shared produccion | 7.150 |
| Cliente tests | 42.858 |
| Servidor tests | 22.255 |
| Shared tests | 3.435 |
| Total Gleam | 205.743 |
| Produccion sin `sql.gleam` generado | 128.021 |

SQL/Squirrel actual:

| Area | Lineas / conteo | Lectura |
| --- | ---: | --- |
| SQL fuente Squirrel | 2.838 lineas en 109 ficheros | No quedan ficheros `.sql` sin consumidor directo por nombre de funcion generada. |
| `sql.gleam` generado | 9.174 lineas | Sigue siendo generado; cuenta solo como delta derivado de SQL fuente. |

Modulos de mayor peso que condicionan el plan:

| Modulo | Lineas | Lectura |
| --- | ---: | --- |
| `apps/server/src/scrumbringer_server/sql.gleam` | 9.174 | Generado; no editar manualmente. |
| `apps/server/test/tasks_http_test.gleam` | 2.747 | Alto potencial de fixture/DSL compartida restante. |
| `apps/client/src/scrumbringer_client/client_update.gleam` | 2.461 | Root de orquestacion; reducir solo por owners reales. |
| `apps/client/src/scrumbringer_client/client_view.gleam` | 2.155 | App shell; extraer composicion repetida, no crear framework. |
| `apps/server/test/rules_engine_test.gleam` | 1.728 | Test de reglas grande; consolidar fixtures sin perder escenarios. |
| `apps/server/test/fixtures.gleam` | 1.563 | Helper compartido ya creado; vigilar que no se convierta en DSL generico. |
| `apps/client/src/scrumbringer_client/features/projects/update.gleam` | 1.608 | Settings/hierarchy/onboarding mezclados. |
| `apps/client/src/scrumbringer_client/features/plan/structure_view.gleam` | 1.595 | Selectores, politicas y DOM juntos. |
| `apps/client/src/scrumbringer_client/features/cards/show.gleam` | 1.486 | Ya mejorado; quedan paneles/work/actions. |
| `apps/client/src/scrumbringer_client/features/people/view.gleam` | 1.346 | Vista + agrupacion + acciones. |
| `apps/server/test/notes_and_positions_http_test.gleam` | 1.339 | Tests largos con helpers duplicados restantes. |
| `apps/client/src/scrumbringer_client/features/capability_board/view.gleam` | 1.335 | Vista + breakdown + acciones. |
| `apps/client/src/scrumbringer_client/features/automations/rule_list.gleam` | 1.273 | UI de reglas con logica de frase/acciones. |
| `apps/server/src/scrumbringer_server/seed_db.gleam` | 1.025 | Orquestacion de seeds ya reducida; auditar solo escenarios con valor QA. |

## Principios de diseno

1. Primero borrar duplicacion exacta o casi exacta; despues partir modulos.
2. Preferir funciones de vista Lustre con `Config` tipada frente a componentes
   con estado propio, salvo que haya ciclo de vida interno real.
3. Usar ADTs para eliminar estados invalidos o ramas repetidas, no por estilo.
4. Mantener efectos en bordes: API, DB, browser interop y timers.
5. Reducir `pub` a contratos de produccion. Tests deben entrar por rutas,
   `try_update`, vistas publicas o helpers puros intencionalmente compartidos.
6. No crear `manager`, `service`, `facade` o CRUD universal si solo ahorra
   imports o renombra codigo.
7. Cada paquete debe dejar una prueba o barrido `rg` que detecte la regresion.
8. En Squirrel, la unidad mantenida es el fichero `.sql`: el nombre del fichero
   define la funcion generada en `sql.gleam`. Los comentarios `-- name:` solo
   son documentacion local en este repo y no deben usarse para auditar usos.

## Criterios tecnicos Gleam, tipos y Lustre

Estos criterios son parte del plan, no recomendaciones opcionales. Un paquete
que reduzca lineas pero viole estas reglas no debe aceptarse.

### Tipos y dominio

| Regla | Aplicacion en este plan | Rechazo explicito |
| --- | --- | --- |
| ADTs para estados de negocio | Usar ADTs cuando eliminan flags/string states o hacen exhaustivo un flujo real. | No crear ADTs solo para embellecer un `case` local. |
| `Result` para fallos esperados | Mantener errores de validacion, autorizacion y persistencia tipados en use cases o payloads. | No convertir errores de dominio en strings hasta presenter/JSON. |
| Opaque types solo con invariantes | Usarlos para tokens, IDs validados, fechas o permisos si impiden construir valores invalidos. | No envolver cada `Int` como ID si no hay bug de mezcla o frontera publica clara. |
| Pattern matching exhaustivo | Preferir variantes concretas y reducir `_` cuando oculte estados de negocio. | No perseguir cero `_` en fronteras externas o fallback defensivo documentado. |
| Genericos con consumidores reales | Introducir funciones genericas solo si dos o mas dominios las usan con la misma semantica. | No crear utils universales para ahorrar tres lineas locales. |

### Lustre/frontend

| Regla | Aplicacion en este plan | Rechazo explicito |
| --- | --- | --- |
| Reusar tipos de dominio | View models derivan de `shared/domain` o selectors existentes antes de crear tipos UI paralelos. | No duplicar `Task`, `Card`, `Status` o permisos en frontend. |
| Mensajes como eventos | Nuevos `Msg` deben describir lo ocurrido (`UserClicked...`, `ApiReturned...`, `ParentSet...`). | No introducir comandos vagos tipo `Save`, `Toggle`, `Load`. |
| Efectos en bordes | API, browser interop, timers y storage se quedan en routes/update owners; vistas son puras. | No meter efectos en helpers UI o componentes visuales. |
| Listas dinamicas keyed | Superficies con drag, reordenacion o listas mutables deben usar keys estables. | No aceptar indices como identidad si hay movimientos o filtros. |
| Accesibilidad integrada | Icon-only, menus, tabs, dialogs y botones deben mantener `aria-label`, `title`, roles o keyboard behavior. | No reducir lineas quitando labels accesibles o estados disabled/loading. |
| View functions por defecto | Preferir funciones puras con `Config` frente a componentes con estado. | No crear web components o estado interno si el padre ya controla el flujo. |

### Testing

| Regla | Aplicacion en este plan | Rechazo explicito |
| --- | --- | --- |
| `let assert`, no `should` | Mantener el patron actual y bloquear regresiones con barridos. | No introducir dependencias deprecated para snapshots/asserts. |
| Tests por contrato publico | Endpoint HTTP, `try_update`, vista publica o helper puro intencional. | No mantener `pub fn` solo porque un test llama un handler interno. |
| Fixtures con tipos reales | Builders de test deben usar constructores y tipos de dominio existentes. | No crear records semanticos duplicados solo para tests. |
| Matriz por riesgo | Shared/client/server completos para paquetes transversales; suite local solo en cambios pequenos y luego cierre global. | No declarar avance global con un test estrecho. |
| Snapshots con revision humana | Birdie solo si aporta valor y queda pendiente de revision humana. | No autoaceptar snapshots ni usar snapshots masivos para esconder ruido. |

## Protocolo de implementacion por paquete

Cada paquete se ejecuta como una refactorizacion guiada por comportamiento. La
reduccion de lineas es una consecuencia aceptada solo si el comportamiento queda
caracterizado y las fronteras mejoran.

1. Resolver baseline y alcance:
   - `git status --short`;
   - `git log -1 --oneline`;
   - si aplica a una rama de trabajo, resolver parent con `@{upstream}`,
     `main` o `master` y listar `git diff --name-only <parent>...HEAD`.
2. Inventariar el area:
   - entradas publicas: rutas HTTP, mensajes Lustre, views, API client, SQL
     fuente, seeds y tests;
   - funciones `pub` afectadas;
   - efectos: DB, HTTP, browser FFI, timers, storage y Squirrel;
   - tipos compartidos ya disponibles antes de crear nuevos.
3. Caracterizar antes de refactorizar:
   - si cambia comportamiento publico, escribir o ajustar test primero;
   - si el cambio es de estructura pura, registrar test existente que cubre el
     contrato y anadir uno solo si hay hueco real;
   - evitar snapshots salvo que el HTML/JSON sea demasiado verboso y requiera
     revision humana.
4. Refactorizar por capas, en este orden:
   - dominio/tipos;
   - transformaciones puras/selectores;
   - mappers, decoders y presenters;
   - orquestacion `update`/handlers/use cases;
   - infraestructura: DB, SQL, browser FFI, seeds;
   - tests y helpers.
5. Cerrar el paquete:
   - formato y tests del area afectada;
   - delta de lineas mantenidas;
   - barridos `rg` definidos por el paquete;
   - lista de codigo eliminado;
   - V/C/R de las mejoras aplicadas;
   - mejoras rechazadas por sobreingenieria.

### Gates por tipo de cambio

| Tipo de cambio | Gate obligatorio | Evidencia esperada |
| --- | --- | --- |
| Lustre view/update | Mensajes nombrados como eventos, effects mapeados, listas dinamicas keyed, ARIA/keyboard en controles interactivos. | Tests de `try_update` o render y barrido de `Msg` nuevo. |
| Componente UI reutilizable | Funcion pura con `Config` por defecto; componente con estado solo si hay ciclo interno real. | Dos consumidores reales o justificacion explicita. |
| Dominio/tipos | ADT/opaco solo si elimina estado invalido, string/flag repetido o frontera insegura. | Tests de variantes y errores con pattern matching especifico. |
| HTTP/backend | Auth y autorizacion visibles; errores de dominio siguen tipados hasta presenter. | Endpoint tests publicos y tests de payload/presenter si el JSON es no trivial. |
| Squirrel/SQL | Auditar por nombre de fichero `.sql`, no por `-- name:`; regenerar `sql.gleam`. | `make squirrel`, build server y diff generado explicado. |
| Tests/fixtures | Helpers finos, fixtures con tipos de produccion, sin `should`. | Barrido `rg "should\\." apps shared` y tests deterministas. |
| Browser/FFI | Dynamic/JS confinado al borde y decodificado antes de `update`. | Wrapper tipado y test del mensaje o flujo consumidor. |

## Meta de reduccion

Objetivo base: `-20.000` lineas netas, separando codigo mantenido y generado
derivado. Objetivo extendido: `-30.000` lineas solo si los paquetes reales
entregan ahorro mantenible con gates verdes.

La Fase 1 debe alcanzar una reduccion limpia similar al plan original. La Fase
2 solo empieza cuando la Fase 1 tiene tests verdes, agent-browser sin fallos
bloqueantes y una lista clara de deficiencias restantes.

| Bloque | Fase | Rango mantenido | Rango generado derivado | Riesgo | Fuente principal |
| --- | --- | ---: | ---: | --- | --- |
| A. Infraestructura de tests y fixtures | 1 | -3.000 a -4.200 | 0 | Bajo/medio | Tests HTTP, asserts render, builders repetidos. |
| B. Roots y superficies Lustre | 1 | -1.800 a -2.800 | 0 | Medio | `client_update`, `client_view`, Pool, Plan, People, Capability. |
| C. UI/design system y dialogos | 1 | -1.200 a -2.000 | 0 | Medio | CRUD dialogs, botones locales, estilos muertos. |
| D. Backend HTTP/use cases | 1 | -1.400 a -2.200 | 0 a -600 | Medio/alto | Payloads, presenters, auth/project lookup, workflows/cards/projects. |
| E. Entrada Squirrel y SQL obsoleto | 1 | -100 a -400 | -300 a -800 | Bajo/medio | Queries fuente sin uso, nombres/comentarios divergentes, contrato SQL. |
| F. Seeds y escenarios QA | 1 | -800 a -1.400 | 0 | Medio | `seed_db`, builders y escenarios duplicados. |
| G. API publica accidental y codigo obsoleto | 1 | -600 a -1.000 | 0 | Bajo | `pub` solo-test, compat/deprecated/legacy real. |
| H. i18n/copy obsoleta | 1 | -200 a -600 | 0 | Bajo | Keys no usadas y terminos legacy. |
| I. Consolidacion profunda de tests HTTP/client | 2 | -3.000 a -5.000 | 0 | Medio | Segundo pase en tests grandes, fixtures DB, builders de dominio. |
| J. Consolidacion de task/card SQL projections | 2 | -800 a -1.800 | -1.800 a -4.500 | Medio/alto | Queries `tasks_*`, mappers repetidos, proyecciones JSON duplicadas. |
| K. Use cases y presenters de segundo pase | 2 | -1.500 a -3.000 | -300 a -1.000 | Medio/alto | Cards/projects/workflows/rules despues de caracterizacion. |
| L. Estilos/i18n/seeds segundo pase | 2 | -800 a -1.800 | 0 | Medio | Clases legacy, copy obsoleta, escenarios QA redundantes. |
| Total Fase 1 | 1 | -9.100 a -14.600 | -300 a -1.400 | Medio | Debe dejar la base lista para Fase 2. |
| Total Fase 1+2 | 1+2 | -15.200 a -26.200 | -2.400 a -6.900 | Medio/alto | Ejecutar Fase 2 hasta superar -20k sin forzar recortes. |

La reduccion debe ejecutarse por paquetes. Si un paquete no consigue borrar
codigo neto o solo mueve lineas, se detiene y se reevalua.

El rango bajo de Fase 1+2 no garantiza `-20k`; por eso el gate final exige
medicion real. Si tras WP-12 a WP-15 no se alcanza el umbral, no se inventan
recortes: se documenta el deficit y se decide si activar el tramo aspiracional
con nuevos candidatos de bajo riesgo.

El tramo de `-30.000` se activa solo con estas condiciones:

- Reduccion acumulada real de al menos `-18.000` lineas antes de abrir paquetes
  nuevos de mayor riesgo, con tests completos verdes.
- Al menos `-14.000` lineas reales ya vienen de codigo mantenido no generado en
  ese punto.
- Existe una lista concreta de candidatos adicionales con guardarrail propio,
  no una bolsa generica de "modulos grandes".
- Cada candidato adicional mantiene V/C/R bajo o medio. Si el riesgo sube a
  alto, requiere caracterizacion previa y debe justificar por que reduce
  complejidad, no solo lineas.

Para cerrar `-30.000`:

- Minimo `-22.000` lineas deben venir de codigo mantenido no generado.
- Maximo `-8.000` lineas pueden venir de `sql.gleam` generado, y solo como
  efecto de `make squirrel` tras cambios en SQL fuente mantenido.
- No se puede contar migraciones historicas, documentacion viva ni cobertura
  funcional eliminada como ahorro de mantenimiento.
- No se puede introducir una abstraccion nueva sin dos consumidores reales y una
  reduccion neta del paquete completo.

Mas alla de `-30.000` no se planifica ahora. Solo se permitiria despues de una
segunda auditoria post-30k que demuestre codigo claramente obsoleto o
duplicacion estructural no cubierta por este plan.

## Paquetes de trabajo

### WP-00. Medicion y guardarrails

Objetivo: fijar medicion repetible antes de tocar codigo.

Pasos:

1. Registrar `git status --short`, `git log -1 --oneline` y upstream.
2. Medir lineas con y sin generado:
   - `find apps shared -path '*/build' -prune -o -name '*.gleam' -print | xargs wc -l`
   - `find apps/client/src apps/server/src shared/src -name '*.gleam' ! -path '*/sql.gleam' -print | xargs wc -l`
   - `wc -l apps/server/src/scrumbringer_server/sql.gleam`
   - `find apps/server/src/scrumbringer_server/sql -name '*.sql' -print | xargs wc -l`
3. Ejecutar baseline de tests:
   - `cd shared && gleam format --check src test && gleam test`
   - `cd apps/client && gleam format --check src test && gleam test`
   - `cd apps/server && DATABASE_URL=... gleam format --check src test && DATABASE_URL=... gleam test`
4. Guardar una tabla de delta por paquete: lineas antes, lineas despues, tests.

Criterios de aceptacion:

- Hay baseline reproducible.
- La reduccion se mide como neta, no solo borrados brutos.
- `sql.gleam` queda etiquetado como generado.

### WP-01. Consolidar infraestructura de tests HTTP

Objetivo: reducir duplicacion en tests de servidor conservando cobertura por
contrato publico.

Evidencia inicial:

- `apps/server/test/tasks_http_test.gleam`: 3.853 lineas.
- `apps/server/test/notes_and_positions_http_test.gleam`: 2.165 lineas.
- `projects_http_test`, `rules_http_test`, `task_templates_http_test`,
  `workflows_http_test`, `org_users_http_test` repiten `login_as`,
  `find_cookie_value`, `create_project`, `create_task_type`, `create_task`.
- Ya existe `apps/server/test/fixtures.gleam`, pero muchos tests mantienen
  helpers locales.

Diseno:

- Crear o ampliar helpers estrechos en `apps/server/test/support/http.gleam` y
  `apps/server/test/support/builders.gleam`.
- No crear un DSL generico de negocio. Helpers permitidos:
  - login y cookies,
  - request autenticada con CSRF,
  - bootstrap de proyecto/tipo/card/task,
  - asserts de envelope/status.
- Migrar archivo a archivo, empezando por tests con mayor repeticion.

Codigo a eliminar:

- `login_as`, `find_cookie_value`, `create_project`, `create_task_type`,
  `create_task`, `create_card` duplicados en tests HTTP.
- Bloques grandes de setup que solo varian por nombres.

Estimacion:

- `-1.800` a `-2.800` lineas en server tests.

Tests:

- Suite server completa despues de cada migracion de archivo grande.
- Ningun test nuevo debe llamar handlers internos si existe ruta HTTP publica.

Criterios de aceptacion:

- `rg "fn login_as|fn find_cookie_value|fn create_project|fn create_task_type|fn create_task\\(" apps/server/test` solo devuelve helpers compartidos o falsos positivos justificados.
- Tests HTTP siguen leyendo como contratos de endpoint.

Estado de ejecucion:

- Parcialmente ejecutado en rama `refactor-cleanup`.
- `apps/server/test/org_invites_http_test.gleam` migrado a `fixtures.bootstrap`,
  `fixtures.login`, `fixtures.create_member_user`, `fixtures.with_auth`,
  `fixtures.query_string` y `fixtures.query_int`.
- `apps/server/test/org_invite_links_http_test.gleam` migrado al mismo patron
  compartido, manteniendo los casos de CSRF sin helper de auth para conservar
  la intencion del contrato.
- `apps/server/test/password_resets_http_test.gleam` migrado a
  `fixtures.bootstrap` y `fixtures.query_int`; el reset compartido ahora incluye
  `password_resets`, retirando aislamiento local duplicado.
- `apps/server/test/auth_http_test.gleam` migrado a `fixtures.new_app`,
  `fixtures.reset_database`, `fixtures.bootstrap`, `fixtures.login`,
  `fixtures.with_auth`, `fixtures.query_string` y `fixtures.query_int`.
  Mantiene helpers locales para los estados especificos de invite links
  porque forman parte del contrato que prueba el modulo.
- `apps/server/test/capabilities_http_test.gleam` migrado a
  `fixtures.bootstrap`, `fixtures.login`, `fixtures.create_member_user`,
  `fixtures.add_member`, `fixtures.with_auth`, `fixtures.query_int` y
  `fixtures.default_project_id`; conserva helpers locales para payloads y
  decoders de capacidades porque son especificos del contrato del endpoint.
- `apps/server/test/org_users_http_test.gleam` migrado a `fixtures.bootstrap`,
  `fixtures.login`, `fixtures.with_auth`, `fixtures.query_int` y
  `fixtures.user_id_by_email`; conserva inserts locales de organizaciones,
  proyectos e invite links con `org_id` variable porque son setup especifico
  de los contratos multi-org.
- `apps/server/test/task_templates_http_test.gleam` migrado a
  `fixtures.bootstrap`, `fixtures.create_project`, `fixtures.create_task_type`,
  `fixtures.create_template`, `fixtures.create_template_full`,
  `fixtures.create_workflow`, `fixtures.create_member_user`,
  `fixtures.add_member`, `fixtures.with_auth`, `fixtures.query_int` y
  `fixtures.default_project_id`; conserva helpers especificos para reglas,
  ejecuciones historicas y decoders de templates.
- `apps/server/test/workflows_http_test.gleam` migrado a `fixtures.bootstrap`,
  `fixtures.create_project`, `fixtures.create_workflow`,
  `fixtures.create_member_user`, `fixtures.add_member`, `fixtures.login`,
  `fixtures.with_auth`, `fixtures.query_int` y `fixtures.default_project_id`;
  conserva solo inserts SQL especificos para reglas, historial y tareas
  generadas por automatizaciones.
- `apps/server/test/rules_http_test.gleam` migrado a `fixtures.bootstrap`,
  `fixtures.create_project`, `fixtures.create_task_type`,
  `fixtures.create_workflow`, `fixtures.create_template`,
  `fixtures.create_task_rule_with_trigger`, `fixtures.create_member_user`,
  `fixtures.add_member`, `fixtures.login`, `fixtures.with_auth`,
  `fixtures.query_int` y `fixtures.query_bool`; conserva payloads, decoders de
  reglas e inserts SQL especificos para historial/origen de automatizaciones.
- `apps/server/test/projects_http_test.gleam` migrado a `fixtures.bootstrap`,
  `fixtures.create_project`, `fixtures.create_member_user`,
  `fixtures.add_member`, `fixtures.login`, `fixtures.with_auth`,
  `fixtures.query_int` y `fixtures.query_string`; elimina bootstrap/login/cookie
  parsing/FFI locales y usa IDs devueltos por la API para proyectos creados en
  setup, conservando solo inserts SQL especificos de otros orgs, cards,
  workflows, templates y reglas de profundidad.
- `apps/server/test/tasks_http_test.gleam` primera pasada: helpers locales de
  proyecto, cards, miembros, usuarios invitados y queries escalares delegan en
  `fixtures.create_project`, `fixtures.create_card`, `fixtures.add_member`,
  `fixtures.create_member_user`, `fixtures.query_int` y `fixtures.with_auth`.
  `bootstrap_app` delega en `fixtures.bootstrap`, eliminando `new_app`, reset DB
  y FFI de entorno locales. Se conservan firmas locales para evitar una
  migracion masiva de escenarios en el mismo paquete y quedan pendientes los
  requests directos del propio test.
- `apps/server/test/notes_and_positions_http_test.gleam` primera pasada:
  helpers locales de proyecto, tipos, activacion de cards, miembros, usuarios
  invitados y queries escalares delegan en `fixtures.create_project`,
  `fixtures.create_task_type`, `fixtures.activate_card`, `fixtures.add_member`,
  `fixtures.create_member_user`, `fixtures.query_int` y `fixtures.with_auth`.
  `bootstrap_app` delega en `fixtures.bootstrap`, eliminando `new_app`, reset DB
  y FFI de entorno locales. Se conservan `create_card` y
  `create_task_with_card` porque sus payloads difieren de los helpers
  compartidos actuales.
- `apps/server/test/cards_http_test.gleam` reutiliza
  `fixtures.create_child_card` para setup jerarquico de cards, retirando el
  helper local duplicado y manteniendo explicitos los nombres que cada escenario
  necesita para el contrato.
- Micro-pase de acciones HTTP de card: `fixtures.gleam` expone
  `activate_card_response` y `close_card_response`, y `cards_http_test`,
  `activity_http_test` y `integration/rules_trigger_on_close_test` dejan de
  construir localmente los mismos requests de activacion/cierre. La reduccion
  neta es pequena por el coste del helper compartido, pero concentra el contrato
  HTTP reutilizable y evita drift entre tests.
- Micro-pase de acciones HTTP de task: `fixtures.gleam` expone
  `claim_task_response`, `release_task_response` y `close_task_response` sobre
  un helper privado versionado. `cards_http_test`, `activity_http_test`,
  `work_sessions_http_test`, `unit/http/task_conflict_handlers_test` y
  `tasks_http_test` dejan de duplicar los requests de `claim`, `release` y
  `close`; `tasks_http_test` conserva wrappers locales de status porque reducen
  ruido en el test grande sin reabrir la duplicacion HTTP.
- `apps/server/test/fixtures.gleam` expone `new_app` y `reset_database` para
  tests que necesitan arrancar antes del registro inicial sin reintroducir FFI
  local ni truncates divergentes. Tambien expone `default_project_id` para
  retirar queries repetidas sobre el proyecto creado por bootstrap y
  `user_id_by_email` para retirar queries repetidas de usuario, y `query_bool`
  como equivalente tipado de `query_int` para asserts de persistencia booleanos.
- Codigo eliminado:
  - bootstrap local,
  - login local,
  - cookie parsing local,
  - reset DB local,
  - invite-link insert local,
  - query helpers locales,
  - helper local de child card,
  - requests locales repetidos de activar/cerrar card,
  - requests locales repetidos de claim/release/close de task,
  - FFI local de `os.getenv`.
- Delta por archivo:
  - `org_invites_http_test.gleam`: `-193` lineas netas;
  - `org_invite_links_http_test.gleam`: `-246` lineas netas;
  - `password_resets_http_test.gleam`: `-84` lineas netas;
  - `auth_http_test.gleam`: `-105` lineas netas;
  - `capabilities_http_test.gleam`: `-252` lineas netas;
  - `org_users_http_test.gleam`: `-249` lineas netas;
  - `task_templates_http_test.gleam`: `-458` lineas netas;
  - `workflows_http_test.gleam`: `-426` lineas netas;
  - `rules_http_test.gleam`: `-535` lineas netas;
  - `projects_http_test.gleam`: `-436` lineas netas;
  - `tasks_http_test.gleam` primera pasada: `-186` lineas netas;
  - `notes_and_positions_http_test.gleam` primera pasada: `-147` lineas netas;
  - `cards_http_test.gleam` pase child-card fixture: `-18` lineas netas;
  - acciones HTTP compartidas de card en tests: `-13` lineas netas;
  - acciones HTTP compartidas de task en tests: `-74` lineas netas;
  - `fixtures.gleam` en migraciones base: `+45` lineas netas; los incrementos
    posteriores quedan incluidos en los micro-pases compartidos;
  - total parcial WP-01: `-3.377` lineas netas mantenidas.
- Verificacion:
  - `cd apps/server && gleam format src test`;
  - `cd apps/server && DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable SB_DB_POOL_SIZE=2 gleam test` (`560 passed`).

### WP-02. Consolidar helpers de render/assert en cliente

Objetivo: reducir repeticion en tests de vista Lustre sin ocultar expectativas.

Evidencia actual:

- Decenas de tests definen `assert_contains` y `assert_not_contains`.
- Muchos tests crean fixtures locales con los mismos records parciales.
- `apps/client/test/people_view_test.gleam` tiene 1.250 lineas.

Diseno:

- Crear `apps/client/test/support/render_assertions.gleam` con:
  - `contains`,
  - `not_contains`,
  - `html` para `element.to_document_string`.
- Crear builders solo donde haya repeticion real de tipos de dominio:
  `task`, `card`, `project`, `user`, `remote`.
- Mantener assertions explicitas en cada test; no snapshots masivos.

Codigo a eliminar:

- Helpers `assert_contains`/`assert_not_contains` repetidos.
- Fixtures locales que duplican constructores de dominio sin variacion.

Estimacion:

- `-700` a `-1.200` lineas en client tests.

Tests:

- Suite client completa.

Criterios de aceptacion:

- `rg "fn assert_contains|fn assert_not_contains" apps/client/test` queda
  reducido a soporte compartido y casos con motivo especial.
- Los tests siguen expresando el comportamiento, no la implementacion interna.

Estado de ejecucion:

- Completado para la consolidacion de asserts de render en rama
  `refactor-cleanup`.
- Creado `apps/client/test/support/render_assertions.gleam` con `contains`,
  `not_contains` y `html`.
- Migrados `plan_kanban_view_test.gleam`, `pool_task_card_test.gleam`,
  `styles_btn_loading_test.gleam`, `people_view_test.gleam` y el resto de tests
  de vista/render que repetian helpers locales `assert_contains` o
  `assert_not_contains`.
- Segundo pase amplio sobre render HTML: 85 tests que ya importaban
  `support/render_assertions` dejan de importar `lustre/element` solo para
  llamar a `element.to_document_string`; ahora usan `render_assertions.html`.
  Se excluyen los tests que usan `element.to_string`, `element.none` u otras
  primitivas reales de Lustre.
- Tercer pase focalizado: `responsive_drawer_test`, `three_panel_layout_test`,
  `ui_badge_test` y `ui_skeleton_test` usan helpers locales o
  `render_assertions.view_contains` para evitar serializacion repetida sin
  ocultar las expectativas de HTML que valida cada caso.
- Cuarto pase focalizado: `ui_misc_test`, `task_create_feedback_test` y tests
  de assignments usan `render_assertions.html`/`fragment_html`; los usos
  directos de `element.to_document_string` en tests cliente bajan de 65 a 49.
- Quinto pase focalizado: `note_content_test`, `pool_view_error_test`,
  `card_show_test` y `member_mobile_shell_test` retiran serializacion directa
  donde solo se validaban fragmentos HTML; los usos directos bajan de 49 a 41.
- Sexto pase focalizado: `automation_console_test`,
  `automation_rule_list_test`, `client_view_guard_test`,
  `crud_dialog_base_test` y `plan_scope_bar_test` sustituyen las ultimas
  serializaciones directas de vistas por `render_assertions.html`; queda un
  unico `element.to_document_string`, el del helper compartido.
- Delta WP-02 hasta este punto: `-491` lineas netas mantenidas (`-17` del pase
  inicial, `-312` del pase amplio de asserts y `-86` del pase de
  `render_assertions.html`, `-67` del tercer pase focalizado y `-3` del cuarto
  pase focalizado, `-6` del quinto pase focalizado y `0` del cierre de
  serializacion directa). La reduccion queda por debajo de la estimacion porque
  esta iteracion no introdujo builders de dominio agresivos: se priorizo retirar
  duplicacion exacta sin esconder expectativas.
- Verificacion:
  - `cd apps/client && gleam format src test`;
  - `cd apps/client && gleam test` (`1873 passed`);
  - `cd apps/client && gleam format src test && gleam test` (`1859 passed`)
    tras el tercer, cuarto, quinto y sexto pase focalizado.

### WP-03. Reducir roots Lustre por owners reales

Objetivo: bajar complejidad de roots sin crear un framework de rutas.

Evidencia actual:

- `client_update.gleam`: 2.461 lineas.
- `client_view.gleam`: 2.169 lineas.
- `features/pool/update.gleam`: 1.194 lineas.
- `features/projects/update.gleam`: 1.608 lineas.

Diseno:

- Extraer solo familias ya nombradas y repetidas:
  - show routing,
  - hydration/resource refresh,
  - admin/member feature routing,
  - project settings/hierarchy wizard,
  - pool drag/task mutation/card show routes.
- Cada owner nuevo debe tener:
  - `Config` o input record estrecho,
  - `Msg`/callbacks de frontera,
  - tests por `try_update` o vista publica.
- Evitar un router generico de features.

Codigo a eliminar:

- Ramas `case` que solo delegan con apply/auth/feedback repetido.
- Helpers privados del root que pasan a un owner y dejan de conocer el root.
- Tests que llaman handlers internos del root.

Estimacion:

- `-900` a `-1.500` lineas netas en roots y tests asociados.

Tests:

- Client suite completa.
- Barridos `rg` de imports para comprobar que el root no conoce subowners.

Criterios de aceptacion:

- Cada extraccion reduce imports y ramas del root.
- No aumenta la superficie publica accidental.

### WP-04. Plan, People y Capability: selectores y view models compartidos

Objetivo: eliminar calculos duplicados de estado de task/card usados por varias
superficies.

Evidencia actual:

- `features/plan/structure_view.gleam`: 1.595 lineas.
- `features/people/view.gleam`: 1.346 lineas.
- `features/capability_board/view.gleam`: 1.335 lineas.
- Todas representan agrupaciones, conteos, acciones y labels de work state.

Diseno:

- Crear selectores puros de producto cuando el mismo concepto aparece en al
  menos dos superficies:
  - `WorkItemView`,
  - metricas/rollups,
  - accionabilidad de task,
  - agrupacion por card/capability/person.
- Mantener layout local. No crear un board/list universal.

Codigo a eliminar:

- Conteos locales de available/claimed/ongoing/blocked/closed.
- Labels y classnames derivados de estado repetidos.
- Branches de accionabilidad duplicadas.

Estimacion:

- `-800` a `-1.300` lineas netas.

Tests:

- Unit tests de selectores puros.
- Tests existentes de vistas ajustados a render publico.

Criterios de aceptacion:

- Las vistas consumen view models o selectors, no reimplementan reglas.
- Los selectores viven cerca del dominio de UI, no en `ui/` si contienen
  decisiones de producto.

Estado de ejecucion:

- Primer pase de rollups de task:
  - creado `features/tasks/rollup` como selector puro compartido para
    `total`, `available`, `claimed`, `ongoing`, `closed` y `blocked`;
  - `plan/structure_rollups`, `views/kanban_board` y
    `capability_board/view` dejan de mantener predicados locales duplicados
    para estados `Available`, `Claimed(Taken)`, `Claimed(Ongoing)` y
    `Closed`;
  - añadido `task_rollup_test` para validar el contrato del selector con
    tareas reales de dominio;
  - verificacion: `cd apps/client && gleam format --check src test &&
    gleam build && gleam test` (`1873 passed`);
  - delta neto: `+10` lineas mantenidas, aceptado por mejora de DRY,
    frontera de tipos y testeabilidad.
- Segundo pase de rollups de task:
  - `features/tasks/blocking_status` delega en `features/tasks/rollup` para
    el predicado canonico de bloqueo;
  - `cards/show` deja de mantener un wrapper local `is_blocked` y consume el
    selector compartido;
  - verificacion: `cd apps/client && gleam format --check src test &&
    gleam test` (`1873 passed`);
  - delta neto adicional: `-5` lineas mantenidas.

### WP-05. Dialogos CRUD y controles UI sin abstraccion universal

Objetivo: reducir dialogos y controles repetidos usando primitivas existentes.

Evidencia actual:

- `components/card_crud_dialog.gleam`: 1.031 lineas.
- `components/task_type_crud_dialog.gleam`: 924 lineas.
- `components/crud_dialog_base.gleam`: 442 lineas.
- Aun hay botones raw en features y componentes, aunque muchos son controles
  legitimos de seleccion, expansion o UI atomica.

Diseno:

- No crear un CRUD universal.
- Extraer solo piezas repetidas:
  - footer submit/cancel,
  - field group con error/help,
  - icon/color picker section,
  - blocked/loading action.
- Migrar botones raw solo si representan comandos simples; mantener raw buttons
  en `ui/` atomico, tabs, pickers, drag/selection controls.

Codigo a eliminar:

- Markup repetido en `card_crud_dialog` y `task_type_crud_dialog`.
- Clases/attrs repetidas de acciones.
- Tests duplicados que verifican markup identico por dialogo.

Estimacion:

- `-700` a `-1.100` lineas netas.

Tests:

- Tests de componente compartido.
- Tests de dialogos por comportamiento especifico.

Criterios de aceptacion:

- No existe `crud_manager` ni componente CRUD unico.
- Cada helper compartido elimina uso en al menos dos sitios.

### WP-06. Backend HTTP: payload, presenter y error mapping

Objetivo: eliminar repeticion en handlers sin esconder autorizacion ni reglas
de negocio.

Evidencia actual:

- `http/rules.gleam`: 791 lineas.
- `http/projects.gleam`: 758 lineas.
- `http/cards.gleam`: 711 lineas.
- `http/rule_metrics.gleam`: 648 lineas.
- `http/org_users.gleam`: 645 lineas.
- Hay precedentes buenos: `http/resource_views.gleam`,
  `http/*/payloads.gleam`, `http/*/presenters.gleam`.

Diseno:

- Reusar patrones estrechos:
  - parse JSON -> payload tipado,
  - auth/project membership,
  - service error -> API error,
  - presenter JSON.
- No crear un handler generico REST.
- Separar boundary HTTP de use case cuando el handler mezcla parse, auth,
  decision de producto y presenter.

Codigo a eliminar:

- Mapeos de error/status duplicados.
- Decoders/payloads repetidos por endpoint.
- Presenters con la misma forma envelope/list/item.

Estimacion:

- `-700` a `-1.200` lineas netas.

Tests:

- Endpoint tests publicos.
- Tests unitarios de payload/presenter solo si el contrato JSON es no trivial.

Criterios de aceptacion:

- Cada handler conserva autorizacion explicita.
- El helper compartido no conoce recursos concretos salvo por callbacks
  tipados.

### WP-07. Backend use cases: cards, projects y workflows

Objetivo: reducir use cases grandes eliminando responsabilidades compartidas,
no solo partiendo ficheros.

Evidencia actual:

- `use_case/cards_db.gleam`: 1.168 lineas.
- `use_case/projects_db.gleam`: 1.105 lineas.
- `use_case/workflows/handlers.gleam`: 1.121 lineas.
- `use_case/rules_engine.gleam`: 970 lineas.

Diseno:

- Cards: separar lifecycle, hierarchy moves, closure/activation validation y
  persistence mapping si cada owner borra branches repetidas.
- Projects: separar members/roles, hierarchy depth policy y project CRUD.
- Workflows: separar trigger matching, action execution, outcome/audit y
  suppression policy.
- Usar ADTs solo para estados de negocio que hoy se repiten como strings/flags.

Codigo a eliminar:

- Validaciones duplicadas entre handlers/use cases.
- Strings/flags internos reemplazados por ADTs canonicos.
- Helpers privados que solo existen para sostener un modulo demasiado amplio.

Estimacion:

- `-700` a `-1.000` lineas netas.

Tests:

- Characterization tests antes de tocar lifecycle/workflows.
- Tests unitarios de politicas puras.
- Endpoint/integration tests despues.

Criterios de aceptacion:

- Cada modulo nuevo tiene un owner de producto claro.
- Los DB strings quedan confinados a mappers/persistence.

### WP-08. Entrada Squirrel y SQL obsoleto

Objetivo: limpiar la entrada mantenida de Squirrel sin editar a mano el
artefacto generado.

Evidencia inicial:

- Squirrel esta bloqueado en `apps/server/manifest.toml` a `4.6.0`.
- `make squirrel` ejecuta `cd apps/server && DATABASE_URL=... gleam run -m
  squirrel`.
- Squirrel genera funciones en `sql.gleam` a partir del nombre de fichero
  `.sql`; en este repo los comentarios `-- name:` no son la identidad usada
  por el codigo generado.
- Hay 114 ficheros SQL fuente y 3.037 lineas mantenidas.
- 69 ficheros declaran un `-- name:` distinto del fichero, lo que puede hacer
  que una auditoria marque como muertas queries que si se usan por nombre de
  fichero.
- Candidatos sin uso directo por funcion generada:
  - `cards_task_count.sql`,
  - `ping.sql`,
  - `tasks_list_by_card.sql`,
  - `task_templates_list_for_org.sql`.

Diseno:

- Auditar siempre por nombre de fichero:
  - `basename apps/server/src/scrumbringer_server/sql/*.sql .sql`,
  - busqueda de `sql.<basename>` en `apps/server/src` y `apps/server/test`,
  - exclusion explicita de `sql.gleam` y de los propios `.sql`.
- Para cada candidato sin uso:
  - confirmar que no hay endpoint, repositorio, test o cliente que dependa del
    contrato,
  - borrar el `.sql` fuente,
  - regenerar `sql.gleam` con `make squirrel`,
  - compilar servidor para detectar llamadas residuales.
- Normalizar o borrar comentarios `-- name:` divergentes. Si se mantienen,
  deben coincidir con el nombre de fichero para que documenten la funcion real.
- Revisar `db/schema.sql` y migraciones solo como contrato de introspeccion:
  - el schema final debe reflejar el modelo canonico,
  - las migraciones historicas no se reescriben por reduccion de lineas,
  - residuos legacy solo son problema si aparecen en schema final, runtime o
    queries fuente activas.

Codigo a eliminar:

- Queries fuente sin consumidores reales.
- Funciones generadas derivadas de esas queries, mediante regeneracion.
- Comentarios `-- name:` que contradicen el nombre real de la funcion generada.
- Documentacion que cite como activa una query ya eliminada.

Estimacion:

- `-100` a `-400` lineas mantenidas entre SQL fuente, llamadas residuales y
  docs obsoletas.
- El delta en `sql.gleam` generado cuenta para el objetivo de 20k solo como
  ahorro derivado y debe reportarse separado del mantenido.

Tests:

- `make squirrel` con `DATABASE_URL` valido.
- `cd apps/server && gleam build`.
- Tests de endpoints afectados si se elimina una query usada indirectamente.
- Barrido de rutas/cliente si la query corresponde a un endpoint retirado.

Criterios de aceptacion:

- `rg "sql\\.(cards_task_count|ping|tasks_list_by_card|task_templates_list_for_org)\\b" apps/server/src apps/server/test` queda vacio antes y despues de borrar.
- No queda ningun `.sql` sin consumidor salvo que este documentado como query
  deliberadamente reservada para generacion/smoke.
- `sql.gleam` solo cambia como resultado de regeneracion.
- No se reescriben migraciones historicas para obtener ahorro cosmetico.

Estado de ejecucion:

- Ejecutado en rama `refactor-cleanup`.
- Borradas queries fuente sin consumidor:
  - `cards_task_count.sql`,
  - `ping.sql`,
  - `tasks_list_by_card.sql`,
  - `task_templates_list_for_org.sql`.
- Regenerado `sql.gleam` con `make squirrel`.
- Retirados los 110 comentarios `-- name:` restantes de SQL fuente. En esta
  version de Squirrel del proyecto, la funcion generada viene del nombre del
  fichero `.sql`; conservar un segundo nombre en comentario duplicaba identidad
  y ya habia provocado auditorias falsas por divergencia.
- Delta inicial:
  - SQL fuente: `-87` lineas;
  - generado derivado: `-309` lineas;
  - total paquete: `-396` lineas.
- Delta adicional:
  - SQL fuente mantenido: `-110` lineas;
  - generado derivado: `-54` lineas tras regeneracion reproducible de
    `sql.gleam`, que sustituye los `/// name:` divergentes por referencias al
    fichero `.sql` real y elimina los comentarios `-- name:` embebidos en las
    cadenas SQL.
- Tercer pase:
  - detectada `project_member_capabilities_delete.sql` como query fuente sin
    consumidor real por nombre de funcion generada;
  - se conserva `project_member_capabilities_delete_all.sql`, que es la query
    usada por el flujo actual de reemplazo completo de capacidades de miembro;
  - SQL fuente mantenido: `-3` lineas;
  - generado derivado: `-39` lineas tras `make squirrel`.
- Verificacion:
  - `DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable make squirrel`;
  - `cd apps/server && gleam build`;
  - `cd apps/server && DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable SB_DB_POOL_SIZE=2 gleam test` (`560 passed`);
  - `rg "sql\\.(cards_task_count|ping|tasks_list_by_card|task_templates_list_for_org)\\b" apps/server/src apps/server/test`.
  - `rg "^-- name:" apps/server/src/scrumbringer_server/sql` sin resultados.
  - Barrido de todos los ficheros `.sql` por basename frente a consumidores
    `sql.<basename>` en `apps/server/src` y `apps/server/test`, excluyendo
    `sql.gleam` y `sql/*.sql`, sin resultados pendientes.

### WP-09. Seeds y escenarios QA

Objetivo: reducir seed orchestration y hacer que cada escenario tenga owner.

Evidencia actual:

- `seed_db.gleam`: 1.782 lineas.
- Existen varios `seed_*_scenarios.gleam`, pero el orquestador conserva mucho
  conocimiento de casos.

Diseno:

- Dividir en paquetes de escenario:
  - pool/work sessions,
  - cards hierarchy,
  - capability board,
  - automations,
  - people/workload.
- Crear helpers de seed finos para entidades basicas y relaciones.
- Mapear escenario -> validacion smoke/browser.

Codigo a eliminar:

- Setup repetido de org/project/users/task types/cards/tasks.
- Branches de seed que duplican builder existente.

Estimacion:

- `-800` a `-1.400` lineas netas.

Tests:

- Smoke/seed command si existe.
- Tests de builders solo para invariantes no obvias.

Criterios de aceptacion:

- Cada escenario puede borrarse o ajustarse sin tocar el orquestador global.
- No se pierden datos necesarios para QA visual.

Estado de ejecucion:

- Primer pase ejecutado en rama `refactor-cleanup`.
- Auditoria de `seed_db.gleam`: el modulo es una capa atomica de operaciones
  SQL y no un orquestador de escenarios; no se fuerza su particion para ganar
  lineas porque ya separa efectos de escenarios.
- Centralizados en `seed_pools.gleam` los helpers puros repetidos por escenarios
  (`days_ago_timestamp` y `list_at`), eliminando copias en
  `seed_task_scenarios.gleam`, `seed_card_scenarios.gleam`,
  `seed_capability_scenarios.gleam` y `seed_workspace_scenarios.gleam`.
- Segundo pase en `seed_db.gleam`: retiradas operaciones atomicas sin
  consumidores de escenarios ni tests (`insert_root_card`,
  `assign_cards_to_parent_card`, workflows/rules/templates legacy, notes,
  task positions, rule executions diagnosticos, `query_int` y
  `reset_workflow_tables`) junto con sus option records. Se mantienen las
  operaciones usadas por escenarios vivos y fixtures (`insert_task`,
  `insert_card`, `insert_work_session`, `insert_audit_event_simple`, etc.).
- Retirados `visual_qa_config`, `automation_engine_names` y los campos de
  workflow de `SeedConfig`; no tenian consumidor ni efecto desde que el builder
  dejo de generar workflows.
- Delta parcial WP-09: `-808` lineas netas mantenidas (`-27` del primer pase,
  `-757` del pase de operaciones seed sin consumidores, `-24` del pase de
  configuracion seed sin efecto).
- Verificacion:
  - `cd apps/server && gleam format src test`;
  - `cd apps/server && gleam build`;
  - `cd apps/server && DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable SB_DB_POOL_SIZE=2 gleam test` (`560 passed`).

### WP-10. API publica accidental y codigo obsoleto

Objetivo: eliminar exports que existen solo por tests o por historia.

Evidencia actual:

- Auditorias previas ya detectaron y redujeron parte de esta deuda.
- Todavia hay 3.384 simbolos publicos (`pub fn`, `pub type`, `pub const`) en
  `src`.
- Los tests con senales de helper privado deben revisarse por comportamiento
  publico.

Diseno:

- Barrido por familias:
  - `handle_`, `apply_`, `success_effect`, `error_feedback`,
  - view helpers publicos no consumidos,
  - payload/presenter publicos usados solo por tests.
- Mantener publicos los helpers puros intencionalmente compartidos y los
  contratos de modulo.

Codigo a eliminar:

- Exports accidentales.
- Tests de implementacion que fuerzan `pub`.
- Wrappers de compatibilidad sin consumidores.

Estimacion:

- `-600` a `-1.000` lineas netas.

Tests:

- Reescribir tests hacia rutas, `try_update`, vistas publicas o helpers puros.
- `rg` por simbolo retirado debe quedar vacio.

Criterios de aceptacion:

- Cada `pub` nuevo o mantenido tiene consumidor de produccion o justificacion.
- No se reduce cobertura funcional.

Estado de ejecucion:

- Pase aplicado en `apps/server/test/fixtures.gleam` para estrechar la API
  publica accidental del fixture compartido. Se retiraron helpers sin
  consumidores externos:
  - `task_ongoing`;
  - `required_cookie_value`;
  - `create_template_with_priority`;
  - `decode_entity_names`;
  - `insert_note_db`;
  - `insert_task_type_db`;
  - `insert_project_db`;
  - `insert_member_db`.
- Se mantuvieron helpers publicos con consumidores reales o uso interno
  justificado, como `insert_user_db`; los wrappers usados solo dentro del
  modulo quedan privados o se eliminan en micro-pases posteriores.
- Delta del pase: `-108` lineas mantenidas.
- Verificacion:
  - `rg` de los simbolos retirados en `apps/server/test`, `apps/server/src`,
    `shared`, `apps/client/src` y `apps/client/test` sin consumidores reales;
  - `cd apps/server && gleam format test && gleam build`;
  - `cd apps/server && DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable SB_DB_POOL_SIZE=2 gleam test` (`560 passed`).
- Pase de modulos cliente sin importadores:
  - retirado `apps/client/src/scrumbringer_client/features/work_scope/queries.gleam`,
    reemplazado por queries/filtros vivos de cards y plan;
  - retirado `apps/client/src/scrumbringer_client/ui/move_menu.gleam`,
    reemplazado por `ui/action_menu`.
- Delta adicional del pase: `-100` lineas mantenidas.
- Verificacion:
  - `rg` de los modulos retirados sin consumidores;
  - `cd apps/client && gleam format --check src test && gleam build`;
  - `cd apps/client && gleam test` (`1912 passed`).
- Pase de simbolos publicos sin consumidor:
  - retirado el modulo plantilla `shared/src/shared.gleam`, sin importadores
    reales;
  - retirados helpers publicos de API cliente, routing, UI, estado y backend
    que tenian una sola aparicion global y no formaban parte de ningun flujo
    activo;
  - eliminados codecs compartidos que existian solo como API publica
    accidental; los tests usan los decoders publicos de contrato
    (`decode_card_create`, `decode_card_move`, `decode_card_close`, etc.);
  - retirados imports residuales detectados por el compilador.
- Delta adicional del pase: `-526` lineas mantenidas.
- Delta acumulado WP-10: `-734` lineas mantenidas.
- Verificacion:
  - `cd shared && gleam format --check src test && gleam test` (`277 passed`);
  - `cd apps/client && gleam format --check src test && gleam test`
    (`1912 passed`);
  - `cd apps/server && gleam format --check src test && DATABASE_URL=... SB_DB_POOL_SIZE=2 gleam test`
    (`560 passed`);
  - `rg` exacto de los simbolos retirados sin consumidores;
  - `git diff --check`;
  - `rg "should\\." apps/client/src apps/client/test apps/server/src apps/server/test shared/src shared/test` sin resultados.
- Micro-pase adicional UI:
  - retirados `add_button_with_size`, `no_cards`, `no_results`, `all_done` y
    `empty_inbox`, todos sin consumidores reales tras el pase de helpers
    publicos;
  - delta adicional: `-27` lineas mantenidas.
- Micro-pase final UI:
  - retirado `add_button_with_size_and_testid`, ultimo helper publico de UI con
    una sola aparicion global;
  - delta adicional: `-16` lineas mantenidas.
- Micro-pase de tipos huerfanos:
  - retirados `ToastMsg`, `ConsumeError`, `TaskCreationSource` y
    `RuleTriggerSource`; no tenian constructores ni firmas consumidoras;
  - delta adicional: `-19` lineas mantenidas.
- Micro-pase adicional de fixtures server:
  - `extract_session` pasa a ser privado porque solo se consume dentro de
    `fixtures.gleam`;
  - eliminados `task_trigger_state_with_card` y `card_trigger_state_full`, dos
    wrappers publicos sin consumidores externos y con un unico consumidor
    interno;
  - delta adicional: `-46` lineas mantenidas.
- Micro-pase adicional de API publica compartida/cliente:
  - eliminado `people/state.badge_variant`, helper publico sin consumidores;
  - `people_workload_codec.person_to_json` pasa a ser privado porque solo es
    callback interno de `people_to_json`;
  - delta adicional: `-10` lineas mantenidas.
- Micro-pase adicional de modulo cliente huerfano:
  - retirado `apps/client/src/scrumbringer_client/workspace_state.gleam`; no
    tenia importadores en `apps/client/src` y solo lo cubria
    `workspace_state_test.gleam`;
  - retirado `apps/client/test/workspace_state_test.gleam`, que verificaba la
    API interna del modulo huerfano y no un contrato de producto o flujo
    visible;
  - delta adicional: `-487` lineas mantenidas.
- Micro-pase adicional de builder URL sin consumidores:
  - retirado `url_state.without_project`, sin llamadas en produccion ni tests
    de contrato;
  - retirado su test unitario directo en `url_state_test.gleam`;
  - delta adicional: `-14` lineas mantenidas.
- Micro-pase adicional de accessor URL accidental:
  - retirado `url_state.assignments_view`, sin consumidores de produccion y
    usado solo por un test unitario directo;
  - el test pasa a verificar el contrato real de parseo con
    `assignments_view_param`, conservando la cobertura del parametro
    `view=users`;
  - delta adicional: `-17` lineas mantenidas.
- Micro-pase adicional de accessors URL de show:
  - retirados `url_state.card_show` y `url_state.task_show`, sin consumidores
    de produccion;
  - los tests pasan a verificar el ADT publico `ShowParam` mediante
    `url_state.show`, que es el contrato que consume `client_update`;
  - delta adicional: `-20` lineas mantenidas.
- Micro-pase adicional de helper visual `for_test`:
  - retirado `task_type_crud_dialog.view_icon_picker_trigger_for_test`, helper
    publico creado solo para un test;
  - el test comprueba el mismo contrato visual desde
    `view_create_dialog_for_test`, evitando exponer una pieza interna del icon
    picker;
  - delta adicional: `-17` lineas mantenidas.
- Micro-pase adicional de API publica cliente accidental:
  - retirado `crud_dialog_base.decode_optional_int_attribute`, helper publico
    sin consumidores;
  - `auth/helpers.clear_drag_state`, `auth/view.view_forgot_password`,
    `rule_sentence.trigger_sentence` y
    `action_buttons.delete_button_with_size` pasan a ser privados porque solo
    tienen consumidores dentro del propio modulo;
  - delta adicional: `-13` lineas mantenidas y cuatro exports menos.
- Micro-pase adicional de wrappers API cliente sin consumidores:
  - retirados `cards.create_card_note_with_url` y
    `tasks/notes.add_task_note_with_url`, wrappers publicos sin consumidores
    externos;
  - `api_tokens.integration_users_payload_decoder`,
    `api_tokens.tokens_payload_decoder`, `api_tokens.token_payload_decoder` y
    `api_tokens.created_token_payload_decoder` pasan a privados porque solo son
    callbacks internos del modulo;
  - delta adicional: `-22` lineas mantenidas y cuatro exports menos.
- Micro-pase adicional de superficie publica accidental cliente:
  - retirados wrappers triviales sin consumidor externo:
    `api_tokens.default_scopes`, `theme.encode_storage` y
    `plan/structure_move.move_query`;
  - pasan a privados helpers usados solo dentro de su modulo:
    `rule_metrics.project_rule_executions_response_decoder`,
    `selectors.now_working_active_session`, `urgency.age_severity`,
    `urgency.max_severity`, `structure_filters.card_state_rank`,
    `mutation_state.restore_snapshot`, `show_editor.permission_hint`,
    `show_editor.view_intro`, `cards/policy.move_destinations_with_tasks`,
    `locale.detect` y `router.format_team`;
  - delta adicional: `-15` lineas mantenidas y once exports menos.
- Micro-pase adicional de helpers internos app-specific:
  - pasan a privados `api/core.decode_success`,
    `api/core.decode_failure`, `app/effects.toast_effect`,
    `three_panel_layout.render_with_labels`,
    `plan_move_update.clear_drag`, `modal_header.view_extended_with_close_label`,
    `http/api.session_cookie_attributes`, `http/api.csrf_cookie_attributes`,
    `http/auth.auth_required_response` y `cards/presenters.card_metrics`;
  - delta adicional: `0` lineas mantenidas y diez exports menos.
- Micro-pase adicional de empty state de Pool sin consumidor:
  - retirado `pool/chrome.tasks_onboarding`, componente publico sin llamadas
    desde produccion y cubierto solo por un test directo de implementacion;
  - retiradas sus aserciones de `pool_chrome_test`, conservando la cobertura de
    estados vivos de carga y filtros sin resultados;
  - delta adicional WP-10: `-18` lineas mantenidas.
- Micro-pase adicional de helpers de paginacion de actividad sin consumidores:
  - retirados `api/activity.has_more` y `api/activity.next_offset`; no habia
    llamadas desde produccion y el unico uso era un test directo del modulo;
  - `api_activity_url_test` mantiene el contrato de URLs y decoder de
    paginacion, sin proteger helpers muertos;
  - delta adicional WP-10: `-14` lineas mantenidas.
- Micro-pase adicional de helper de opciones sin consumidor:
  - retirado `helpers/options.empty_to_opt`; el modulo conserva los helpers
    vivos `search_to_opt` y `empty_to_int_opt`, usados por filtros del Pool;
  - retirado el test directo del helper muerto en `update_helpers_test`;
  - delta adicional WP-10: `-12` lineas mantenidas.
- Micro-pase adicional de accessors de badge:
  - retirados `ui/badge.get_text` y `ui/badge.get_variant`; exponian la
    estructura opaca del componente solo para tests;
  - `ui_badge_test` valida ahora el resultado renderizado de
    `new_truncated`, reforzando el contrato visual publico;
  - delta adicional WP-10: `-15` lineas mantenidas.
- Micro-pase adicional de API preventiva de button:
  - retirados `ui/button.with_autofocus` y `ui/button.with_stop_propagation`,
    sin consumidores de produccion;
  - retirados los campos internos `autofocus` y `stop_propagation` del
    `Config` del boton; el autofocus vivo continua en
    `crud_dialog_base.with_autofocus_when` para campos de formulario, y otros
    usos de `stop_propagation` siguen como atributos Lustre locales;
  - retirados tests directos de API preventiva en `ui_button_test`;
  - delta adicional WP-10: `-64` lineas mantenidas.
- Micro-pase adicional de primitivas UI preventivas:
  - retirados `data_table.sortable_column`, `filter_bar.checkbox_chip`,
    `skeleton.skeleton_card`, `layout.theme_switch` y `layout.locale_switch`,
    sin consumidores de produccion y cubiertos solo por tests directos;
  - simplificado `data_table.Column` retirando el campo `on_sort` y la rama
    de header sortable, ya que ningun flujo activo ordena desde esa primitiva;
  - retirados tests de implementacion asociados, conservando tests de los
    contratos UI vivos de tabla, filtros, skeleton line/list/table y layout
    section/empty;
  - delta adicional WP-10: `-212` lineas mantenidas.
- Micro-pase adicional de abstraccion CSS no adoptada:
  - retirado `ui/css_class`, wrapper publico de clases CSS usado solo por
    `empty_state`, `info_callout` y tests directos del propio wrapper;
  - `empty_state` e `info_callout` declaran sus clases visuales de forma
    explicita, manteniendo el contrato renderizado y evitando una capa publica
    que no reducia duplicacion real;
  - retirados tests de implementacion de `css_class`, conservando los tests de
    iconos, section header y componentes UI consumidores;
  - delta adicional WP-10: `-322` lineas mantenidas.
- Micro-pase adicional de layout UI huerfano:
  - retirado `ui/layout`, modulo publico sin consumidores tras haber eliminado
    los switchers preventivos de tema/idioma;
  - sus helpers restantes (`empty` y `section`) duplicaban primitivas Lustre
    locales y no aportaban contrato visual compartido;
  - delta adicional WP-10: `-41` lineas mantenidas.
- Micro-pase adicional de tooltips UI huerfanos:
  - retirados `ui/tooltips/author_tooltip`, `notes_preview_tooltip`,
    `progress_tooltip` y `tab_badge`, componentes sin consumidores de
    produccion y cubiertos solo por tests directos del propio componente;
  - `ui/tooltips/types` conserva solo `DeleteNoteContext`, que sigue siendo
    contrato vivo de `notes_list`;
  - retirados los tests directos de componentes muertos, manteniendo la
    cobertura de `notes_list` para el contexto de borrado;
  - delta adicional WP-10: `-407` lineas mantenidas.
- Micro-pase adicional de icon picker preventivo:
  - retirado `ui/icon_picker`, modulo publico sin consumidores de produccion;
  - el picker real de tipos de tarea sigue viviendo en
    `components/task_type_crud_dialog`, que es el flujo actualmente conectado;
  - retirado su test directo, que cubria una API no integrada;
  - delta adicional WP-10: `-233` lineas mantenidas.
- Micro-pase adicional de categoria legacy en icon catalog:
  - retirado `IconCategory`, `categories`, `category_label`, `by_category` y
    el campo `CatalogIcon.category`, ya sin consumidores tras sustituir el
    picker por la lista real conectada en `task_type_crud_dialog`;
  - retirado el estado `task_types_create_icon_category`, su mensaje admin y
    las aserciones que solo protegian ese estado sin salida visual;
  - delta adicional WP-10: `-67` lineas mantenidas.
- Micro-pase adicional de busqueda legacy en icon catalog:
  - retirado `task_types_create_icon_search`, su mensaje admin, handler y
    aserciones asociadas, ya que el picker conectado no expone busqueda;
  - retirado `icon_catalog.search` y su dependencia de `gleam/string`, al no
    tener consumidores tras retirar el picker preventivo;
  - delta adicional WP-10: `-47` lineas mantenidas.
- Micro-pase adicional de fuente unica para iconos de task type:
  - retirado el `const task_type_icons` local de
    `task_type_crud_dialog.gleam`;
  - el picker conectado renderiza directamente desde `icon_catalog.catalog()`,
    eliminando duplicacion entre catalogo, labels y render;
  - delta adicional WP-10: `-7` lineas mantenidas.
- Micro-pase adicional de API preventiva en `signal_chip`:
  - retirados `signal_chip.with_extra_class` y `signal_chip.with_title`, sin
    consumidores de produccion;
  - retirados los campos internos `extra_class` y `title`, simplificando el
    contrato renderizado de la primitiva a clase base, tono, partes y
    `data-testid`;
  - `ui_signal_chip_test` conserva la cobertura de las capacidades usadas por
    producto y deja de proteger una API preventiva;
  - delta adicional WP-10: `-24` lineas mantenidas y dos exports menos.
- Micro-pase adicional de wrappers internos de `action_buttons`:
  - `delete_button_with_disabled_and_testid` y
    `delete_button_blocked_with_testid` pasan a privados porque solo son ramas
    internas de `delete_button_with_availability_and_testid`;
  - `ui_action_buttons_test` concentra la cobertura en el wrapper publico de
    disponibilidad, incluyendo disabled, blocked, tooltip, clase bloqueada y
    `data-testid`;
  - delta adicional WP-10: `-31` lineas mantenidas y dos exports menos.
- Micro-pase adicional de helpers internos de tabs/iconos:
  - `detail_tabs.tab_id`, `detail_tabs.tabpanel_id`,
    `icons.heroicon_outline_url`, `icons.view_heroicon_inline` e
    `icons.icon_size_px` pasan a privados porque solo se consumen dentro de su
    modulo;
  - no cambia el contrato renderizado ni se retira cobertura funcional;
  - delta adicional WP-10: `-4` lineas mantenidas y cinco exports menos.
- Micro-pase adicional de API muerta en `crud_dialog_base`:
  - retirados `OptionalIntParseError`, `optional_text_input_value`,
    `prepend_fields`, `parse_optional_int` y `optional_int_or_none`, sin
    consumidores de produccion;
  - `view_dialog_error` y `view_danger_button` pasan a privados porque son
    detalles internos de `view_dialog_shell` y `view_delete_dialog_shell`;
  - la cobertura se desplaza de helpers directos muertos al shell publico de
    borrado, manteniendo validacion de error, boton danger, loading y copy;
  - delta adicional WP-10: `-74` lineas mantenidas y siete exports menos.
- Micro-pase adicional de helpers UI preventivos:
  - retirado el builder preventivo de `info_callout`
    (`InfoCalloutConfig`, `new`, `with_title`, `view`), ya que producto solo
    consume `simple` y `view_with_content`;
  - retirados `form_field.none` y `event_decoders.mouse_offset`, sin
    consumidores reales;
  - delta adicional WP-10: `-36` lineas mantenidas y seis exports menos.
- Micro-pase adicional de API preventiva en `modal_header`:
  - retiradas las APIs genericas sin consumidores de produccion:
    `Config`, `ExtendedConfig`, `TitleElement`, `ClosePosition`,
    `DetailConfig`, `view`, `view_simple`, `view_extended`, `extend`,
    `view_dialog`, `view_dialog_with_icon`, `view_detail` y
    `view_detail_with_close_label`;
  - el modulo conserva solo los dos contratos vivos usados por CRUD dialogs:
    `view_dialog_with_close_label` y `view_dialog_with_icon_and_close_label`;
  - `modal_header_test` pasa de proteger API preventiva a cubrir solo los
    headers vivos, incluyendo titulo, icono, rol, clases y label localizado;
  - delta adicional WP-10: `-808` lineas mantenidas y trece exports menos.
- Micro-pase adicional de headers/chips UI preventivos:
  - retirados `card_section_header.ExtendedConfig` y
    `card_section_header.view_extended`, ya que producto solo consume
    `view`/`view_with_class` y el test existente preservaba una variante sin
    consumidor real;
  - simplificado el render interno de `card_section_header` eliminando el
    override preventivo de clase de boton;
  - retirado `task_metric_chip.full`, redundante con
    `task_metric_chip.view(Config(..., variant: Full, ...))`, que ya es la
    entrada canónica cubierta por tests;
  - delta adicional WP-10: `-78` lineas mantenidas y tres exports menos.
- Micro-pase adicional de `action_menu` textual preventivo:
  - retirado `action_menu.view`, wrapper textual sin consumidores de producto;
  - retirados los constructores `TextTrigger` e `IconTextTrigger`; el contrato
    vivo queda alineado con `inspector_actions`, que usa `IconTrigger`;
  - el test de links/menu se mantiene sobre `view_with_trigger`, cubriendo la
    ruta viva de popover, roles y enlaces;
  - delta adicional WP-10: `-36` lineas mantenidas y tres entradas publicas
    menos.
- Micro-pase adicional de encapsulacion de `toast`:
  - retirado `toast.show`, wrapper sin consumidores; el flujo real usa
    `toast.show_with_action`;
  - `Toast` y `ToastState` pasan a `pub opaque`, de modo que el resto de la app
    depende de operaciones publicas y no de constructores internos;
  - delta adicional WP-10: `-12` lineas mantenidas, una funcion publica menos
    y dos constructores publicos menos.
- Micro-pase adicional de variante textual obsoleta en metricas de tareas:
  - retirados `task_metric_chip.Full`, `task_metric_chip.Compact` y el campo
    `variant` de `task_metric_chip.Config`; el componente vivo queda fijado a
    icono+numero con `title` y `aria-label`;
  - eliminados estilos `.task-metric-chip.is-full` y
    `.task-metric-chip-label`, sin consumidores de producto tras la
    unificacion visual;
  - los tests cubren ahora el contrato accesible del chip compacto y la
    ausencia de label textual visible;
  - delta adicional WP-10: `-55` lineas mantenidas y dos constructores
    publicos menos.
- Micro-pase adicional de API preventiva en `signal_chip`:
  - retirados `signal_chip.metric_int` y `signal_chip.metric_if_positive`,
    helpers publicos sin consumidores de producto;
  - el test de clase/partes personalizadas usa ahora `signal_chip.metric`, que
    es la entrada real consumida por `work_surface`;
  - delta adicional WP-10: `-37` lineas mantenidas y dos funciones publicas
    menos.
- Micro-pase adicional de helper de igualdad de `ToastId`:
  - retirado `ids.toast_id_eq`, wrapper publico con un unico consumidor;
  - `toast.dismiss` compara mediante `toast_id_to_int`, accessor que ya era
    necesario para renderizar identificadores de toast;
  - delta adicional WP-10: `-11` lineas mantenidas y una funcion publica
    menos.
- Micro-pase adicional de helpers internos de `ui/dialog`:
  - privatizados `escape_close_attributes` y `panel_base_attributes`; sus
    consumidores son internos del modulo y las APIs publicas vivas siguen
    siendo `panel_attributes` y `passive_panel_attributes`;
  - delta adicional WP-10: `-2` lineas mantenidas y dos funciones publicas
    menos.
- Verificacion de micro-pases:
  - `cd shared && gleam format --check src test && gleam test` (`277 passed`);
  - `cd apps/client && gleam format --check src test && gleam test`
    (`1912 passed`; `1888 passed` tras retirar `workspace_state_test.gleam`;
    `1887 passed` tras retirar `url_state.without_project`;
    `1887 passed` tras retirar `url_state.assignments_view`;
    `1887 passed` tras retirar `url_state.card_show` y
    `url_state.task_show`;
    `1887 passed` tras retirar
    `task_type_crud_dialog.view_icon_picker_trigger_for_test`;
    `1887 passed` tras retirar `decode_optional_int_attribute` y privatizar
    helpers cliente sin consumidores externos;
    `1887 passed` tras retirar wrappers de notas con URL y privatizar decoders
    de `api_tokens`;
    `1887 passed` tras retirar wrappers triviales y privatizar helpers cliente
    sin consumidores externos;
    `1887 passed` tras privatizar helpers app-specific sin consumidores
    externos;
    `1887 passed` tras retirar `pool/chrome.tasks_onboarding`;
    `1887 passed` tras retirar helpers muertos de `api/activity`;
    `1886 passed` tras retirar `helpers/options.empty_to_opt`;
    `1886 passed` tras retirar accessors de `ui/badge`;
    `1884 passed` tras retirar API preventiva de `ui/button`;
    `1879 passed` tras retirar primitivas UI preventivas sin consumidores;
    `1871 passed` tras retirar `ui/css_class`;
    `1871 passed` tras retirar `ui/layout`;
    `1864 passed` tras retirar tooltips UI huerfanos;
    `1859 passed` tras retirar `ui/icon_picker`;
    `1859 passed` tras retirar categoria legacy del icon catalog;
    `1859 passed` tras retirar busqueda legacy del icon catalog;
    `1859 passed` tras conectar el picker a `icon_catalog.catalog`;
    `1859 passed` tras retirar API preventiva de `signal_chip`;
    `1857 passed` tras privatizar wrappers internos de `action_buttons`;
    `1857 passed` tras privatizar helpers internos de tabs/iconos;
    `1849 passed` tras retirar API muerta de `crud_dialog_base`;
    `1849 passed` tras retirar helpers UI preventivos;
    `1822 passed` tras retirar API preventiva de `modal_header`;
    `1821 passed` tras retirar API preventiva de headers/chips UI;
    `1821 passed` tras retirar API textual preventiva de `action_menu`;
    `1821 passed` tras encapsular `toast`;
    `1820 passed` tras retirar la variante textual de `task_metric_chip`;
    `1819 passed` tras retirar helpers preventivos de `signal_chip`;
    `1819 passed` tras retirar `ids.toast_id_eq`;
    `1819 passed` tras privatizar helpers internos de `ui/dialog`);
  - `cd apps/server && gleam format --check src test && DATABASE_URL=... SB_DB_POOL_SIZE=2 gleam test`
    (`560 passed`; `gleam build` tras privatizar helpers app-specific).
- Delta acumulado WP-10 tras micro-pases: `-4.124` lineas mantenidas.

### WP-11. i18n, estilos y clases muertas

Objetivo: borrar claves, copy y estilos que ya no tienen consumidores.

Evidencia actual:

- `i18n/text.gleam`: 1.173 lineas.
- `i18n/en.gleam`: 1.409 lineas.
- `i18n/es.gleam`: 1.444 lineas.
- `styles/*`: 2.031 lineas.

Diseno:

- Para i18n:
  - detectar keys sin uso,
  - borrar terminos legacy reales,
  - mantener cobertura exhaustiva por ADT.
- Para estilos:
  - extraer lista de clases desde views,
  - comparar con estilos,
  - borrar compat classes sin uso real.
- No convertir i18n a strings libres para ahorrar lineas.

Codigo a eliminar:

- Keys no usadas y translations correspondientes.
- Clases CSS sin consumidores.
- Compat styles de redisenos antiguos.

Estimacion:

- `-500` a `-1.200` lineas netas.

Tests:

- Tests i18n existentes.
- Tests de estilos si se borran reglas cubiertas.
- Revisión visual/browser para superficies afectadas.

Criterios de aceptacion:

- No quedan referencias rotas.
- No se debilita el modelo tipado de i18n.

Estado de ejecucion:

- Primer pase ejecutado en rama `refactor-cleanup`.
- Barrido estatico de clases CSS definidas en `styles/*.gleam` frente a
  consumidores en `apps/client/src` y `apps/client/test`.
- Eliminado el bloque legacy `ficha-detail-*`, `ficha-task-*` y
  `ficha-add-task-*` de `styles/ux.gleam`; esas clases no tenian consumidores y
  fueron sustituidas por las superficies actuales `card-show`/`detail-*`.
- Segundo pase i18n: eliminadas 190 variantes `Text` sin consumidor en
  produccion, sus ramas de traduccion `en/es` y aserciones de tests que solo
  protegian copy muerta. El barrido excluyo `i18n/text.gleam`, `i18n/en.gleam`
  e `i18n/es.gleam` para no contar las propias definiciones como uso real.
- Tercer pase de estilos: retirado bloque legacy `hierarchies-*` /
  `hierarchy-*` del antiguo modulo plural de jerarquias, preservando las clases
  vivas `hierarchy-scope-*`, `card-surface` y `kanban-card`.
- Cuarto pase de estilos: retiradas clases legacy sin consumidores de
  formularios antiguos, settings menu, confirm modal, priority dots, hamburger
  admin y restos de card/task dialogs ya reemplazados por los componentes
  actuales.
- Quinto pase de estilos: tras retirar el modulo muerto `ui/move_menu`,
  eliminadas reglas `move-menu`, `move-menu-trigger`, `move-menu-actions` y
  `move-menu-option` de `styles/layout.gleam`.
- Sexto pase de estilos: eliminados restos sin consumidores de topbar legacy,
  filtros antiguos, previews de icono, badges preview de task, skills legacy,
  reglas de tablas/radio obsoletas y remates mobile asociados.
- Septimo pase de estilos: eliminadas variantes legacy sin consumidores en
  `styles/ux.gleam` para admin/sidebar antiguos, acciones de error/banner,
  acciones de tabla, skeleton subvariantes, detail/modal antiguo, contexto
  padre de task, grids de task show, metricas workflow y `form-input`.
- Octavo pase de estilos: retirados selectores legacy sin consumidores en
  `styles/layout.gleam`, `styles/tables.gleam`, `styles/dialogs.gleam` y
  `styles/components.gleam` para plantillas antiguas, mobile header obsoleto,
  rollups previos de plan, decoracion kanban/footer retirada, jerarquias
  antiguas y selectores compuestos ya sin markup.
- Noveno pase i18n: retirada la clave `CreateFirstTaskToStartUsingPool` de
  `Text`, `en` y `es` tras eliminar el unico componente que la consumia.
- Decimo pase de estilos: retiradas reglas del antiguo `ui/icon_picker`
  preventivo (`icon-picker-search`, tabs, item/label/empty states) tras borrar
  el modulo sin consumidores; se preservan las clases usadas por el picker real
  conectado en `task_type_crud_dialog`.
- Undecimo pase de estilos: retiradas reglas legacy sin consumidores de
  navegacion antigua (`nav-item`, `nav-item-icon`), texto auxiliar de
  `error-banner`, sorting visual de `DataTable` aun no implementado en markup,
  badges legacy de decay y restos de progreso duplicados en `styles/ux.gleam`.
  Se conserva la regla responsive viva de `.nav` y `.pool-right` sin
  reintroducir el selector obsoleto `.nav-item`.
- Duodecimo pase de estilos: retiradas reglas sin consumidores
  (`admin-card`, `admin-card-header`, `info-callout-link`,
  `task-blocked-card`, `btn-action-primary`, `theme-switch`, `btn-active`).
  Se conserva `highlight-success` porque `styles_accessibility_test` protege el
  contrato de utilidades `highlight-*` aunque no haya consumidor actual.
- Decimotercer pase i18n: retiradas las claves `LanguageEs` y `LanguageEn` de
  `Text`, `en` y `es`; el selector de idioma usa literales deliberados
  (`Español`, `English`) y no consumia esas claves.
- Delta parcial WP-11: `-913` lineas netas mantenidas (`-20` estilos iniciales,
  `-700` i18n/tests, `-139` estilos legacy de jerarquias, `-54` estilos legacy
  adicionales). Delta adicional del quinto pase: `-8` lineas mantenidas.
  Delta adicional del sexto pase: `-53` lineas mantenidas. Delta adicional del
  septimo pase: `-47` lineas mantenidas. Delta adicional del octavo pase:
  `-28` lineas mantenidas. Delta adicional del noveno pase: `-5` lineas
  mantenidas. Delta adicional del decimo pase: `-12` lineas mantenidas. Delta
  adicional del undecimo pase: `-30` lineas mantenidas. Delta adicional del
  duodecimo pase: `-9` lineas mantenidas. Total parcial WP-11: `-922` lineas
  mantenidas. Delta adicional del decimotercer pase: `-6` lineas mantenidas.
  Total parcial WP-11 tras pase i18n: `-928` lineas mantenidas.
- Verificacion:
  - `cd apps/client && gleam format src test`;
  - `cd apps/client && gleam build`;
  - `cd apps/client && gleam test` (`1912 passed`; `1859 passed` tras los
    pases posteriores de componentes y estilos);
  - `rg "ficha-detail|ficha-task|ficha-add-task" apps/client/src apps/client/test`.
  - `rg "i18n_text\\.<clave>|text\\.<clave>" apps/client/src --glob '!**/i18n/text.gleam' --glob '!**/i18n/en.gleam' --glob '!**/i18n/es.gleam'` para las claves retiradas.
  - `rg "hierarchies-|hierarchy-" apps/client/src/scrumbringer_client/styles/layout.gleam apps/client/src/scrumbringer_client/styles/ux.gleam` solo muestra `hierarchy-scope-*`.
  - Barrido de selectores legacy retirados contra `apps/client/src` y
    `apps/client/test`, excluyendo `styles/*.gleam`; solo queda una asercion
    negativa de `card-empty-work-decision`.
  - `rg "move-menu" apps/client/src apps/client/test` sin consumidores.
  - `rg -n "\\b(nav-item|nav-item-icon|error-banner-text|sortable|table-sort-button|sort-icon|decay-badge|progress-bar-fill)\\b" apps/client/src apps/client/test -g '*.gleam' --glob '!**/styles/*.gleam'` sin consumidores.
  - `rg -n "\\b(admin-card|admin-card-header|btn-action-primary|btn-active|info-callout-link|task-blocked-card|theme-switch)\\b" apps/client/src/scrumbringer_client -g '*.gleam'` sin consumidores.
  - `rg -n "\\b(LanguageEs|LanguageEn)\\b" apps/client/src apps/client/test -g '*.gleam'` sin consumidores.
  - Barrido de selectores retirados del sexto pase contra `apps/client/src` y
    `apps/client/test` sin consumidores.
  - Barrido de selectores retirados del septimo pase contra `apps/client/src`
    y `apps/client/test` sin consumidores.
  - Barrido exacto de clases retiradas del octavo pase dentro de
    `attribute.class(...)` contra `apps/client/src` y `apps/client/test`,
    excluyendo `styles/*.gleam`, sin consumidores.
  - `cd apps/client && gleam format --check src test && gleam test`
    (`1859 passed`) tras retirar estilos muertos del icon picker preventivo.

### WP-12. Fase 2: consolidacion profunda de tests

Objetivo: alcanzar reduccion adicional sin borrar escenarios, convirtiendo
tests grandes en contratos legibles apoyados por helpers finos.

Condicion de entrada:

- WP-01 y WP-02 estan completos.
- Las suites server/client pasan.
- El informe de Fase 1 identifica duplicacion restante concreta en tests.

Diseno:

- Reabrir los tests de mayor tamano despues de migrar helpers iniciales:
  `tasks_http_test`, `notes_and_positions_http_test`, `projects_http_test`,
  `rules_http_test`, `people_view_test` y tests de views grandes.
- Extraer solo patrones con tres o mas consumidores:
  - bootstrap DB/HTTP;
  - builders de `Project`, `Card`, `Task`, `TaskType`, `Capability`;
  - asserts de contratos JSON;
  - asserts de render para metricas, empty states y menus.
- Mantener los nombres de test como documentacion de comportamiento.

Codigo a eliminar:

- Setup repetido que ya no aporta intencion.
- Helpers locales equivalentes a helpers compartidos.
- Fixtures que duplican records de dominio.

Estimacion:

- `-3.000` a `-5.000` lineas mantenidas.

Criterios de aceptacion:

- No baja el numero de comportamientos cubiertos; si se eliminan tests
  redundantes, se documenta por que otro test cubre el mismo contrato.
- No aparece `should`.
- Los helpers compartidos siguen siendo estrechos y faciles de leer.

Estado de ejecucion:

- Segundo pase iniciado en rama `refactor-cleanup`.
- `apps/server/test/fixtures.gleam` incorpora:
  - `create_task_with_card_full`, para compartir el POST tipado de tasks sin
    perder `description`, `priority`, `type_id` ni `card_id`;
  - `required_cookie_value`, para retirar parsers locales de `set-cookie`.
  - `with_session_cookies`, para compartir cookies de sesion sin anadir
    `X-CSRF`; se mantiene separado de `with_auth` porque varios tests validan
    precisamente la ausencia de ese header.
- Migrados `tasks_http_test.gleam` y `notes_and_positions_http_test.gleam` para
  delegar esos helpers y sustituir el patron repetido `login_as` +
  extraccion de cookies por `login_session`, y los pares repetidos
  `sb_session`/`sb_csrf` por `with_session_cookies`; cuando el header
  `X-CSRF` ya estaba presente se reutiliza `fixtures.with_auth`. Se mantienen
  intactos los escenarios y los casos sin CSRF.
- Los wrappers locales `create_project` devuelven el ID que ya proporciona el
  fixture HTTP compartido, retirando consultas SQL posteriores por nombre de
  proyecto en `tasks_http_test.gleam` y `notes_and_positions_http_test.gleam`.
- Los wrappers locales `create_task_type` devuelven el ID que ya proporciona
  el fixture HTTP compartido, retirando consultas SQL posteriores por nombre de
  tipo de tarea en `tasks_http_test.gleam` y
  `notes_and_positions_http_test.gleam`.
- Los wrappers locales `create_member_user` conservan el ID devuelto por el
  fixture compartido, retirando consultas SQL posteriores por email para los
  usuarios creados en `tasks_http_test.gleam` y
  `notes_and_positions_http_test.gleam`. Las consultas al admin creado por
  bootstrap quedan fuera de este pase.
- `notes_and_positions_http_test.gleam` reutiliza `fixtures.create_card` y
  elimina el POST/decoder local de card ID.
- `projects_http_test.gleam` conserva los IDs devueltos por
  `fixtures.create_member_user`, retirando consultas SQL posteriores por email
  para miembros, candidatos y managers creados por invite.
- `modal_metrics_http_test.gleam` conserva el ID del miembro creado por
  `fixtures.create_member_user` y elimina la consulta SQL posterior por email.
- `tasks_http_test.gleam` y `notes_and_positions_http_test.gleam` sustituyen
  el FFI local `integer_to_binary` por `gleam/int.to_string`.
- `notes_and_positions_http_test.gleam` deja de convertir `fixtures.Session`
  a tuplas `#(session, csrf)` para reconstruirlas despues. Los helpers locales
  de creacion y las requests directas reciben ahora el tipo compartido
  `fixtures.Session`; se elimina `fixture_session`, el campo `csrf` duplicado
  de `ResourceViewFixture` y los parametros `csrf` paralelos en helpers de
  proyecto, task type, card, task, member y posiciones.
- `tasks_http_test.gleam` aplica el mismo contrato tipado: `login_session`
  devuelve `fixtures.Session`, los helpers de task lifecycle, dependencias,
  work sessions, proyectos, cards, miembros y listados reciben la sesion
  compartida.
- `fixtures.with_session_cookies` acepta ahora `fixtures.Session`; se eliminan
  los wrappers locales duplicados de `tasks_http_test.gleam` y
  `notes_and_positions_http_test.gleam` sin perder los tests que validan
  ausencia de header `X-CSRF`.
- `rules_http_test.gleam` deja de usar el helper local `int_to_string` y llama
  directamente a `gleam/int.to_string`, igual que el pase previo aplicado en
  `tasks_http_test.gleam` y `notes_and_positions_http_test.gleam`.
- Retirados `support/test_db.gleam` y `support/test_helpers.gleam`, modulos de
  soporte de tests sin importadores reales; solo se referenciaban en sus
  propios comentarios de ejemplo.
- `fixtures.gleam` incorpora helpers `require_*` estrechos para setup HTTP que
  falla el test via `expect.ok`; `tasks_http_test.gleam` y
  `notes_and_positions_http_test.gleam` retiran wrappers locales equivalentes y
  usan alias `fx` solo en esos tests densos para evitar wrapping repetitivo.
- `projects_http_test.gleam` adopta el alias local `fx` para el fixture denso y
  elimina el wrapper local `single_int` en favor de
  `fixtures.require_query_int`.
- `fixtures.gleam` concentra decoders estrechos para contratos HTTP de test:
  `data.<entity>.id`, `data.<collection>[].<field>` y listas directas de ints.
  `activity`, `api_tokens`, `capabilities`, `notes_and_positions`,
  `org_users`, `rules`, `task_templates` y `workflows` eliminan decoders
  locales repetidos sin cambiar escenarios ni rutas verificadas.
- `fixtures.require_data_list` se expone como helper de envelope HTTP para
  mantener decoders de item especificos de cada escenario y retirar solo el
  parseo repetido `data.<collection>`. `tasks_http_test.gleam` lo aplica en
  contratos de lista, metricas de proyecto, metricas de usuarios y titulos de
  tasks.
- `fixtures.require_data` centraliza el parseo del envelope `data` para
  payloads no-lista. Se aplica en templates, rules, notes/positions, projects
  y tasks manteniendo decoders de item/payload especificos en cada test.
- `fixtures.gleam` anade `require_query_string` y `require_query_bool` para
  completar la familia de helpers `require_query_*`. Se retiran pipelines
  directos `query_* |> expect.ok` en auth, capabilities, invite links,
  invites, org users, password resets, projects, rules, templates y workflows.
- `apps/client/test/support/assertions.gleam` centraliza aserciones triviales
  de tests de cliente (`assert_equal`, `assert_not_equal`, `assert_none`,
  `assert_true`, `assert_error`). Se retiran helpers locales equivalentes en
  23 tests de cliente.
- `assert_non_blank` completa las aserciones compartidas de cliente sin perder
  semantica: los tests de i18n siguen comprobando texto no-blanco tras `trim`,
  mientras `ui_loading_test.gleam` reutiliza `assert_non_empty` para HTML no
  vacio.
- `apps/client/test/support/domain_fixtures.gleam` centraliza fixtures de
  dominio para tests de cliente (`Card`, `Task`, `TaskDependency` y extractor
  `card_id`). Se retiran builders locales repetidos en tests de store,
  cache de cards, feedback de task creada y highlights de bloqueo, manteniendo
  overrides explicitos para los campos relevantes de cada escenario.
- Segundo pase de fixtures de dominio aplicado a tests de pool available,
  right panel y blocking status. Los tests conservan como overrides visibles
  los metadatos que forman parte del escenario (`state`, `blocked_count`,
  icono/tipo, `created_by` y fechas).
- Tercer pase de fixtures de dominio aplicado a tests de dependencias de tasks
  (`dependency_state`, `dependency_update` y `dependency_list`). Se retiran
  constructores completos repetidos manteniendo explicitos los campos de
  dependencia, versionado y contadores bloqueados que gobiernan cada caso.
- Cuarto pase de fixtures de dominio aplicado a tests de `tasks/show`
  (`actions`, `permissions` y `show_state`). Se conserva la intencion de cada
  escenario mediante overrides de estado, version, ids de card, permisos y
  valores de formulario.
- Quinto pase de fixtures de dominio aplicado a tests de refresh/routing del
  pool (`pool_refresh_update`, `pool_project_refresh` y `pool_task_route`). Se
  retiran constructores completos manteniendo overrides para icono/tipo,
  descripcion vacia, prioridad y datos de refresh usados por cada escenario.
- Sexto pase de fixtures de dominio aplicado a tests de posicionamiento de
  pool y actualizacion/listado de tasks (`pool_positions_route`,
  `tasks_task_list`, `tasks_show_update` y `tasks_show_feedback_update`). Los
  tests pasan a declarar solo los campos observables del caso: descripcion,
  prioridad, fecha de creacion, version y card asociada.
- Septimo pase de fixtures de dominio aplicado a tests de logica pura de task
  (`tasks_claimability`, `tasks_dependency_list` y `task_blocking_status`). Se
  retiran constructores e imports locales donde el escenario solo depende de
  `state`, `blocked_count` o dependencia abierta/cerrada.
- Octavo pase de fixtures de dominio aplicado a tests de `tasks/show`
  (`tasks_show_lifecycle_update`, `tasks_show_details`,
  `tasks_show_edit_form` y `task_show_editor_view`). Se conservan solo
  overrides de descripcion, prioridad, version, fecha de creacion, estado
  reclamado y card asociada cuando forman parte del caso.
- Noveno pase de fixtures de dominio aplicado a tests de UI de pool/mobile
  (`pool_task_row`, `pool_task_hover`, `pool_my_tasks_dropzone` y
  `now_working_mobile_view`). Se preservan explicitamente los datos visuales
  del caso: tipo/icono cuando afecta al componente, card, color, bloqueadores,
  estado reclamado y metadatos de automatizacion.
- Decimo pase de fixtures de dominio aplicado a tests de barra personal,
  lista agrupada, right panel y sesiones de trabajo (`my_bar_task_row_view`,
  `grouped_list_task_item`, `right_panel_tasks` y `work_sessions_state`). Se
  conservan como overrides los datos que gobiernan el comportamiento visible:
  estado reclamado/ongoing, prioridad, version, card asociada y color.
- Undecimo pase de fixtures de dominio aplicado a tests de lookup, mutaciones,
  drag y creacion de tasks (`update_helpers`, `tasks_mutation_state`,
  `pool_drag_update` y `tasks_create_update`). Se retiran constructores
  completos y se mantienen visibles estado, dependencia, descripcion,
  prioridad, fecha, version, autor y estado de card cuando son parte del caso.
- Duodecimo pase de fixtures de dominio aplicado a tests de cabecera, titular
  y resumen de task show (`tasks_show_header`, `tasks_show_headline` y
  `tasks_show_summary`). Se preservan explicitamente tipo/icono, prioridad,
  autor, fechas, version, card y dependencias que alimentan textos y estados
  visuales del inspector.
- Decimotercer pase de fixtures de dominio aplicado a `task_show_update`. Se
  sustituye el constructor manual completo por `domain_fixtures.task`,
  manteniendo el estado reclamado, descripcion, prioridad, fechas y version que
  gobiernan el comportamiento de apertura, edicion y render.
- Decimocuarto pase de fixtures de dominio aplicado a
  `capability_board_view`. Se retiran constructores completos de card y task
  manteniendo tipo/icono, estado, card, color y descripcion visibles en el
  agrupado por capacidad.
- Decimoquinto pase de fixtures de dominio aplicado a `kanban_task_item`. Se
  reemplazan builders manuales de card y task por fixtures compartidas sin
  ocultar los campos de contrato del kanban: estado, prioridad, version,
  pertenencia a card, color y conteo de tareas.
- Decimosexto pase de fixtures de dominio aplicado a `people_view`. Se retiran
  constructores completos de task/card manteniendo explicitos los datos que
  alimentan el workload: owner, estado, card, color, tipo y titulo.
- Decimoseptimo pase de fixtures de dominio aplicado a
  `plan_structure_view`. Se reemplazan builders completos por fixtures
  compartidas manteniendo jerarquia, estado, card asociada, tipo visible y
  bloqueo.
- Decimoctavo pase de fixtures de dominio aplicado a
  `tasks_mutation_update`. Se reduce `sample_task` a fixture compartida y se
  conservan descripcion, prioridad, fecha, version y estado para los contratos
  de optimistic update y rollback.
- Decimonoveno pase de fixtures de dominio aplicado a `plan_kanban_view`.
  Se reemplazan cards y task manuales por fixtures compartidas manteniendo
  estado de card, conteo, color, version y pertenencia visible de la task.
- Vigesimo pase de fixtures de dominio aplicado a `pool_task_card`. Se recorta
  el helper base de task conservando icono, prioridad, autor/fecha y card
  asociada, que son los datos visuales que gobiernan esos casos.
- Vigesimoprimer pase de fixtures de dominio aplicado a `admin_cards_view`.
  `sample_card` reutiliza la fixture compartida y conserva solo `task_count`
  como dato especifico de los contratos de borrado y detalle.
- Vigesimosegundo pase de fixtures de dominio aplicado a helpers pequenos de
  card (`card_scoped_navigation`, `cards_list_view` y `card_show_summary`).
  Se conservan solo los campos observables: scope/id, descripcion, metricas,
  estado y fecha cuando el render o la URL los usan.
- Vigesimotercer pase de fixtures de dominio aplicado a builders pequenos de
  card (`card_due_date_ht11`, `plan_scope_bar` y `plan_move_update`). Se
  conserva la intencion visible de cada escenario: vencimiento, scope,
  jerarquia y estado de destino.
- Vigesimocuarto pase de fixtures de dominio aplicado a helpers base de card
  en `pool_create_dialog`, `admin_cards_update` y `card_show`. Se mantienen
  color, descripcion, metricas, fechas y estados que los tests observan.
- Vigesimoquinto pase de fixtures de dominio aplicado a `card_show_entry` y
  `card_show_actions_ht10`. Se retiran constructores completos de card/task
  manteniendo path, estado, task_count, tipo/icono, owner y bloqueos visibles.
- Vigesimosexto pase de fixtures de dominio aplicado a `pool_view_composition`
  y `helpers_dicts`. Se retiran defaults completos de task manteniendo icono,
  prioridad, owner, fecha y card cuando el render los usa.
- Vigesimoseptimo pase de fixtures de dominio aplicado a helpers de estado de
  task (`tasks_claimability`, `tasks_show_actions`, `tasks_task_list` y
  `work_sessions_state`). Se conservan solo id/titulo, estado, bloqueo y
  version cuando el contrato los observa.
- Vigesimoctavo pase de fixtures de dominio aplicado a helpers de lookup,
  refresh y dependencias (`update_helpers`, `pool_project_refresh`,
  `tasks_dependency_list` y `tasks_dependency_state`). Se retiran descripcion,
  prioridad y fechas que no participan en la igualdad ni en las transiciones.
- Vigesimonoveno pase de fixtures de dominio aplicado a rutas/helpers de pool
  (`pool_blocking`, `pool_positions_route`, `pool_refresh_update` y
  `pool_task_dependencies`). Se sustituyen builders completos por fixtures
  conservando solo dependencias, posiciones e ids/estado observados.
- Trigesimo pase de fixtures de dominio aplicado a tests de task show
  (`tasks_show_header`, `tasks_show_headline`, `tasks_show_permissions` y
  `tasks_show_summary`). Se retiran tipo/card/fechas/version cuando el HTML o
  la regla solo observan estado, usuario y titulo; se conserva `Feature/P2`
  donde el resumen lo verifica.
- Trigesimoprimer pase de fixtures de dominio aplicado a editor/form/update de
  task show (`task_show_editor_view`, `tasks_show_edit_form`,
  `task_show_update` y `tasks_show_feedback_update`). Se eliminan fechas y
  versiones no observadas conservando descripcion, prioridad y version donde
  gobiernan dirty-check o concurrencia.
- Trigesimosegundo pase de fixtures de dominio aplicado a vistas laterales y
  moviles de tareas (`my_bar_task_row_view`, `pool_my_tasks_dropzone`,
  `now_working_mobile_view` y `right_panel_tasks`). Se retiran descripcion,
  fechas y campos de card no observados, conservando estado, version,
  prioridad o card metadata cuando el render/callback los usa.
- Trigesimotercer pase de fixtures de dominio aplicado a vistas de lista,
  kanban y pool (`grouped_list_task_item`, `kanban_task_item`,
  `pool_task_row` y `pool_task_hover`). Se sustituyen constructores completos
  por fixtures de dominio y se conservan solo task type, card color, prioridad
  o `blocked_count` cuando gobiernan iconos, orden visual o accionabilidad.
- Trigesimocuarto pase de fixtures de dominio aplicado a vistas de jerarquia y
  card show (`hierarchy_scopes_ht09`, `card_scoped_navigation`,
  `card_show_headline` y `card_show_summary`). Se eliminan constructores
  completos de card/task conservando solo jerarquia, estado, contadores y due
  date cuando el render o la URL los observan.
- Trigesimoquinto pase de fixtures de dominio aplicado a pool/plan
  (`plan_kanban_view` y `pool_task_card`). Se retiran descripcion, version,
  prioridad y contexto de card cuando el componente recibe esos datos por
  `Config` o solo necesita asociacion a card.
- Trigesimosexto pase de fixtures de dominio aplicado a tipos de tarea y
  capacidades (`pool_create_dialog`, `task_types_view`, `task_types_update`,
  `pool_available_tasks`, `center_panel_data`, `pool_control_bar`,
  `work_filters_bar` y `capabilities_view`). Se retiran constructores locales
  repetidos usando `domain_fixtures.task_type` y
  `domain_fixtures.capability`, conservando overrides de icono,
  `capability_id` y `tasks_count` donde gobiernan el contrato.
- Trigesimoseptimo pase de fixtures de dominio aplicado a usuarios,
  proyectos y miembros (`org_user`, `project`, `project_member`) en rutas y
  vistas de administracion, asignaciones, proyectos y capacidades. Se eliminan
  constructores locales repetidos y se conservan overrides explicitos de rol,
  `members_count` o `claimed_count` cuando esos campos son parte del contrato
  del test.
- Trigesimoctavo pase de fixtures de dominio aplicado a usuario autenticado
  (`domain_fixtures.user`) en guards, auth helpers, org settings, member
  refresh, pool/right panel y task show. Se conserva override de `org_role`
  solo cuando el test valida permisos o comportamiento de administrador.
- Trigesimonoveno pase de fixtures de dominio aplicado a
  `assignments_view_test`. Se retiran constructores completos de proyecto,
  usuario de organizacion, usuario autenticado y miembro de proyecto, dejando
  visibles solo `members_count: 0`, rol `Admin` y rol `Manager` cuando
  gobiernan el contrato visual.
- Cuadragesimo pase de fixtures de dominio aplicado a
  `capability_board_view_test`. Los tipos de tarea del tablero reutilizan
  `domain_fixtures.task_type` manteniendo explicitos icono, capacidad y
  contador; capacidades y usuario admin reutilizan fixtures compartidas.
- Cuadragesimoprimer pase de fixtures de dominio aplicado a
  `admin_task_types_view_test`. Se retiran constructores completos de
  `TaskType` usando `domain_fixtures.task_type` y se mantienen visibles icono,
  capacidad asociada y contador de tareas cuando gobiernan el render.
- Cuadragesimosegundo pase de fixtures de dominio aplicado a
  `admin_task_types_route_test`. El helper local de `TaskType` reutiliza
  `domain_fixtures.task_type` y conserva solo el override de icono usado por
  ese contrato.
- Cuadragesimotercer pase de fixtures de dominio aplicado a
  `helpers_selection_test` y `permissions_test`. Se retiran constructores
  completos de `Project` usando `domain_fixtures.project`, conservando
  overrides de rol, `members_count` y `healthy_pool_limit` cuando gobiernan
  los contratos de permisos o seleccion.
- Cuadragesimocuarto pase de fixtures HTTP aplicado a
  `tasks_http_test` y `notes_and_positions_http_test`. Se extrae
  `fixtures.require_task` para crear una task completa en una card activa,
  retirando wrappers locales equivalentes y el helper de activacion que quedo
  sin uso; los tests siguen expresando titulo, descripcion, prioridad y tipo
  en cada escenario.
- Cuadragesimoquinto pase de fixtures HTTP aplicado a `tasks_http_test`.
  El helper local `create_task_type(..., capability_id: Int)` desaparece:
  las tareas sin capacidad usan `fixtures.require_task_type` y los escenarios
  con capacidad usan `fixtures.require_task_type_with_capability`, eliminando
  el sentinel `0` del test. La construccion opcional del payload queda privada
  dentro de `fixtures.gleam` para no ampliar API publica accidental.
- Delta parcial WP-12: `-4.011` lineas netas mantenidas (`-44` del primer pase
  de helpers de task/cookie, `-257` del pase de login/session y `-96` del pase
  de cookies de sesion, `-63` del pase de cookies+CSRF a `with_auth`, `-169`
  del pase de IDs de proyecto desde fixtures, `-240` del pase de IDs de tipos
  de tarea desde fixtures, `-122` del pase de IDs de usuarios miembro desde
  fixtures, `-32` del pase de creacion de cards desde fixtures, `-40` del pase
  de IDs de usuarios en proyectos desde fixtures, `-6` del pase de ID de
  usuario en metricas modales, `-12` del pase de conversion Int->String con
  API estandar, `-213` del pase de `fixtures.Session` tipado en
  `notes_and_positions_http_test.gleam`, `-300` del pase de
  `fixtures.Session` tipado en `tasks_http_test.gleam`, `-18` del pase de
  `with_session_cookies` tipado en `fixtures.gleam`, `-4` del pase de
  `int.to_string` en `rules_http_test.gleam`, `-141` del pase de modulos
  `support` huerfanos, `-26` del pase de wrappers `require_*` compartidos,
  `+13` del pase de task types con capacidad tipada en fixtures,
  `-9` del pase de `projects_http_test.gleam`, `-202` del pase de decoders de
  envelope HTTP en tests, `-74` del pase de `require_data_list` en
  `tasks_http_test.gleam`, `-141` del pase de `require_data` para payloads
  HTTP no-lista, `-3` del pase de helpers `require_query_string/bool`, `-56`
  del pase de aserciones compartidas en tests de cliente, `-8` del pase de
  aserciones de strings compartidas en tests de cliente, `-85` del pase de
  fixtures de dominio compartidas en tests de cliente, `-74` del segundo pase
  de fixtures de dominio compartidas en tests de cliente, `-67` del tercer
  pase de fixtures de dominio compartidas en tests de cliente, `-43` del
  cuarto pase de fixtures de dominio compartidas en tests de cliente, `-56` del
  quinto pase de fixtures de dominio compartidas en tests de cliente, `-72` del
  sexto pase de fixtures de dominio compartidas en tests de cliente, `-28` del
  septimo pase de fixtures de dominio compartidas en tests de cliente, `-63`
  del octavo pase de fixtures de dominio compartidas en tests de cliente, `-50`
  del noveno pase de fixtures de dominio compartidas en tests de cliente, `-75`
  del decimo pase de fixtures de dominio compartidas en tests de cliente, `-96`
  del undecimo pase de fixtures de dominio compartidas en tests de cliente,
  `-53` del duodecimo pase de fixtures de dominio compartidas en tests de
  cliente, `-14` del decimotercer pase de fixtures de dominio compartidas en
  tests de cliente, `-21` del decimocuarto pase de fixtures de dominio
  compartidas en tests de cliente, `-44` del decimoquinto pase de fixtures de
  dominio compartidas en tests de cliente, `-30` del decimosexto pase de
  fixtures de dominio compartidas en tests de cliente, `-24` del decimoseptimo
  pase de fixtures de dominio compartidas en tests de cliente, `-15` del
  decimoctavo pase de fixtures de dominio compartidas en tests de cliente,
  `-45` del decimonoveno pase de fixtures de dominio compartidas en tests de
  cliente, `-11` del vigesimo pase de fixtures de dominio compartidas en tests
  de cliente, `-13` del vigesimoprimer pase de fixtures de dominio compartidas
  en tests de cliente, `-22` del vigesimosegundo pase de fixtures de dominio
  compartidas en tests de cliente, `-28` del vigesimotercer pase de fixtures
  de dominio compartidas en tests de cliente, `-26` del vigesimocuarto pase de
  fixtures de dominio compartidas en tests de cliente, `-55` del
  vigesimoquinto pase de fixtures de dominio compartidas en tests de cliente,
  `-37` del vigesimosexto pase de fixtures de dominio compartidas en tests de
  cliente, `-19` del vigesimoseptimo pase de fixtures de dominio compartidas
  en tests de cliente, `-11` del vigesimoctavo pase de fixtures de dominio
  compartidas en tests de cliente, `-41` del vigesimonoveno pase de fixtures
  de dominio compartidas en tests de cliente, `-30` del trigesimo pase de
  fixtures de dominio compartidas en tests de cliente, `-6` del
  trigesimoprimer pase de fixtures de dominio compartidas en tests de cliente,
  `-13` del trigesimosegundo pase de fixtures de dominio compartidas en tests
  de cliente, `-35` del trigesimotercer pase de fixtures de dominio
  compartidas en tests de cliente, `-46` del trigesimocuarto pase de fixtures
  de dominio compartidas en tests de cliente, `-15` del trigesimoquinto pase
  de fixtures de dominio compartidas en tests de cliente, `-26` del
  trigesimosexto pase de fixtures de dominio compartidas en tests de cliente,
  `-155` del trigesimoseptimo pase de fixtures de dominio compartidas en tests
  de cliente, `-70` del trigesimoctavo pase de fixtures de dominio compartidas
  en tests de cliente, `-73` del trigesimonoveno pase de fixtures de dominio
  compartidas en tests de cliente, `-7` del cuadragesimo pase de fixtures de
  dominio compartidas en tests de cliente, `-9` del cuadragesimoprimer pase
  de fixtures de dominio compartidas en tests de cliente, `-5` del
  cuadragesimosegundo pase de fixtures de dominio compartidas en tests de
  cliente, `-35` del cuadragesimotercer pase de fixtures de dominio
  compartidas en tests de cliente, `-5` del cuadragesimocuarto pase de
  fixtures HTTP compartidas en tests de servidor).
- Verificacion:
  - `cd apps/server && gleam format src test`;
  - `cd apps/server && gleam build`;
  - `cd apps/server && DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_test?sslmode=disable SB_DB_POOL_SIZE=2 gleam test` (`560 passed`).
  - `cd apps/client && gleam format --check src test && gleam build`;
  - `cd apps/client && gleam test` (`1887 passed`).

### WP-13. Fase 2: consolidar proyecciones SQL task/card

Objetivo: reducir duplicacion entre queries `tasks_*`, mappers y projections
generadas sin ocultar reglas de negocio en SQL opaco.

Condicion de entrada:

- WP-08 completo.
- `make squirrel` y build server verdes.
- Caracterizacion de endpoints de task/card disponible.

Diseno:

- Auditar queries grandes con proyecciones repetidas:
  - `tasks_list`,
  - `tasks_claim`,
  - `tasks_close`,
  - `tasks_get_for_user`,
  - `tasks_update`,
  - `tasks_release`,
  - `tasks_create`.
- Identificar campos repetidos de row/projection y decidir entre:
  - mantener duplicacion si Squirrel requiere query completa para type safety;
  - mover transformacion a mapper Gleam si reduce SQL y generated code sin
    perder indices ni semantica DB;
  - fusionar query solo si dos endpoints tienen mismo contrato real.
- No crear una query universal de tasks si obliga a parametros sentinela o
  condicionales opacos.

Codigo a eliminar:

- SQL fuente de queries obsoletas o equivalentes.
- Proyecciones duplicadas que puedan reconstruirse tipadamente en Gleam.
- Mappers repetidos por rows identicas.
- Generado derivado en `sql.gleam`.

Estimacion:

- `-800` a `-1.800` lineas mantenidas.
- `-1.800` a `-4.500` lineas generadas derivadas.

Criterios de aceptacion:

- Cada query resultante tiene consumidor claro.
- El delta de `sql.gleam` se explica por cambios en SQL fuente.
- Tests HTTP/task/card cubren claim, release, close, update, blocked deps,
  created-from-rule y reload de cliente.

Estado de ejecucion:

- Primer pase de auditoria ejecutado en rama `refactor-cleanup`.
- Revisadas `tasks_list`, `tasks_claim`, `tasks_close`,
  `tasks_get_for_user`, `tasks_update`, `tasks_release` y `tasks_create`
  junto a sus consumidores en `repository/tasks/queries.gleam` y mappers.
- Hallazgo: `tasks_claim`, `tasks_release`, `tasks_close` y `tasks_update`
  repiten una proyeccion grande de task enriquecida, pero esa duplicacion esta
  acoplada al tipo generado por Squirrel y al contrato HTTP que devuelve la
  task completa tras cada mutacion.
- Decision: no se consolida en este pase. Las alternativas disponibles
  aumentaban riesgo o complejidad:
  - una query universal de task con parametros sentinela, descartada por el
    propio plan;
  - mutaciones que devuelven solo ID y hacen una segunda query para reconstruir
    la task, descartadas por anadir roundtrip y cambiar atomicidad/transaccion;
  - mover la proyeccion a una abstraccion SQL no soportada directamente por el
    flujo actual de Squirrel.
- WP-13 queda documentado como auditado y parcialmente descartado hasta que
  exista una mejora de Squirrel/SQL que permita compartir proyecciones sin
  perder type safety ni claridad de contrato.

### WP-14. Fase 2: use cases y presenters de segundo pase

Objetivo: reducir coordinacion duplicada en backend una vez estabilizados tests
y SQL.

Condicion de entrada:

- WP-06, WP-07 y WP-13 completos o descartados con justificacion.
- Hay tests de caracterizacion para cards/projects/workflows/rules.

Diseno:

- Reauditar:
  - `cards_db.gleam`;
  - `projects_db.gleam`;
  - `workflows/handlers.gleam`;
  - `rules_engine.gleam`;
  - presenters/payloads que repiten envelopes o error mapping.
- Mover politicas puras a funciones testeables cuando tengan dos o mas
  consumidores o reduzcan branches repetidas.
- Usar ADTs para lifecycle/outcomes solo si eliminan strings/flags repetidos.

Codigo a eliminar:

- Branches duplicadas entre handler/use case/presenter.
- Error mapping duplicado.
- Wrappers de compatibilidad que ya no tienen cliente.

Estimacion:

- `-1.500` a `-3.000` lineas mantenidas.
- `-300` a `-1.000` generadas si desaparecen queries asociadas.

Criterios de aceptacion:

- Auth/autorizacion no queda escondida en helpers genericos.
- Errores esperados siguen como `Result`.
- Presenters no filtran strings internos de DB/dominio.

Estado de ejecucion:

- Primer pase ejecutado en rama `refactor-cleanup`.
- Extraido `http/payload_decode.gleam` como helper estrecho para ejecutar
  decoders de payload y mapear errores de JSON a `Nil` o a un error de payload
  explicito, sin tocar handlers ni autorizacion.
- Migrados payload decoders de `api_tokens`, `auth`, `capabilities`,
  `integration_users`, `notes`, `org_invite_links`, `org_invites`,
  `org_users`, `password_resets`, `projects`, `rules`, `task_positions`,
  `task_templates`, `tasks`, `work_sessions` y `workflows`.
- Se descarto consolidar wrappers HTTP de `projects`, `workflows` y `rules`
  porque el formateo de llamadas largas aumentaba lineas y no mejoraba la
  frontera de responsabilidades.
- Delta del pase: `-20` lineas mantenidas netas.
- Verificacion:
  - `cd apps/server && gleam format src test`;
  - `cd apps/server && gleam build`;
  - `cd apps/server && DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable SB_DB_POOL_SIZE=2 gleam test` (`560 passed`);
  - barrido de `decode.run(data, decoder)` y `result.map_error(fn(_) { Nil | InvalidJson })` en payloads HTTP para confirmar que solo quedan casos locales no equivalentes.

### WP-15. Fase 2: estilos, i18n y seeds de segundo pase

Objetivo: borrar residuos que solo aparecen despues de consolidar UI, tests y
seeds principales.

Condicion de entrada:

- WP-05, WP-09 y WP-11 completos.
- agent-browser AU-01 a AU-12 ejecutado al menos una vez tras Fase 1.

Diseno:

- Reextraer clases reales desde views y comparar con `styles/*`.
- Revisar i18n por constructores/textos sin uso tras refactors.
- Revisar seeds que ya no aportan cobertura browser ni test.
- Consolidar escenarios solo si se mantiene trazabilidad escenario -> caso AU.

Codigo a eliminar:

- Clases legacy de redisenos ya sustituidos.
- Traducciones sin constructor o constructor sin uso.
- Seeds duplicadas de estados ya cubiertos por otro escenario.

Estimacion:

- `-800` a `-1.800` lineas mantenidas.

Criterios de aceptacion:

- El modelo i18n sigue exhaustivo.
- Los casos AU siguen teniendo datos representativos.
- No se elimina seed que cubre un permiso, estado o empty state unico.

Estado de ejecucion:

- Segundo pase auditado en rama `refactor-cleanup`.
- Clases CSS: barrido exacto de clases definidas en `styles/*.gleam` frente a
  `apps/client/src` y `apps/client/test`, excluyendo estilos. Las unicas clases
  sin literal directo son variantes dinamicas de `CardColor`
  (`card-border-*` y `card-initials-*`) generadas por `color_picker` y
  `task_color`; no se eliminan porque cubren colores validos del ADT aunque los
  fixtures actuales no usen todos.
- i18n: los 866 constructores de `Text` tienen consumidor real fuera de
  `i18n/text.gleam`, `i18n/en.gleam` e `i18n/es.gleam`; no hay traducciones
  muertas sin degradar exhaustividad.
- SQL fuente/seeds: los 109 ficheros `.sql` tienen consumidor por basename y
  las APIs publicas de seed conservan consumidores entre modulos de seed; no se
  elimina escenario visual sin ejecutar antes AU-01 a AU-12.
- Decision: WP-15 queda auditado sin cambios adicionales de codigo; perseguir
  reduccion aqui sin evidencia implicaria borrar cobertura visual o estados de
  dominio validos.

### WP-16. Tramo 30k: auditoria de extension condicionada

Objetivo: decidir y ejecutar solo los paquetes adicionales necesarios para
pasar de `-20k` a `-30k` sin degradar cobertura, UX ni claridad arquitectonica.

Condicion de entrada:

- WP-00 a WP-15 ejecutados, descartados o cerrados con justificacion.
- Reduccion acumulada real de al menos `-18k`.
- Suites `shared`, `client` y `server` verdes.
- AU-01 a AU-12 ejecutados con agent-browser tras el ultimo cambio visible.
- Informe de deficiencias actualizado con V/C/R.

Diseno:

- Recalcular inventario despues de WP-15:
  - top 50 modulos por lineas;
  - top 30 tests por lineas;
  - top 30 ficheros SQL fuente por lineas y funciones generadas;
  - `pub` sin consumidores;
  - clases/i18n/seeds sin consumidores;
  - handlers/use cases con mappers/presenters repetidos.
- Abrir solo paquetes con una de estas senales:
  - tres o mas consumidores con duplicacion real;
  - query SQL fuente que permite borrar una funcion generada completa;
  - test largo donde se elimina setup repetido sin borrar casos;
  - componente UI duplicado con contrato de accesibilidad compartible;
  - use case con politica pura repetida que puede testearse directamente.
- Ejecutar paquetes de menor riesgo primero:
  1. tests y fixtures restantes;
  2. `pub` accidental y codigo obsoleto;
  3. estilos/i18n/seeds residuales;
  4. componentes UI duplicados;
  5. SQL/use cases solo con caracterizacion previa.

Codigo a eliminar:

- Helpers locales equivalentes a helpers compartidos.
- Tests repetidos que solo verifican setup identico.
- SQL fuente con consumidor inexistente o reemplazado por query mas clara.
- Funciones `pub` mantenidas solo por tests de implementacion.
- Componentes visuales duplicados despues de que exista una primitiva testeada.
- Seeds o escenarios visuales sin caso AU asociado.

Estimacion:

- `-4.000` a `-8.000` lineas mantenidas adicionales si WP-12 a WP-15 quedan en
  rango medio.
- `0` a `-1.500` lineas generadas adicionales si aparece consolidacion SQL real
  no detectada en WP-13.
- Si WP-12 a WP-15 ya alcanzan el rango alto, WP-16 puede limitarse a medicion,
  refactor final y validacion.

Criterios de aceptacion:

- La reduccion acumulada supera `-30k`.
- Al menos `-22k` vienen de codigo mantenido no generado.
- Cada paquete extendido tiene guardarrail `rg`, test o AU asociado.
- Ningun paquete extendido introduce abstracciones de un solo consumidor.
- Las deficiencias detectadas por agent-browser o revision manual se corrigen o
  quedan documentadas como preexistentes con owner claro.
- Si no aparecen candidatos de bajo/medio riesgo suficientes, se cierra el plan
  en `-20k` y se documenta por que perseguir `-30k` seria sobreingenieria.

Estado de ejecucion:

- Primer pase iniciado con el paquete de menor riesgo del diseno:
  `pub` accidental y helpers internos de codecs/presenters.
- Privatizados helpers sin consumidor externo:
  - `metrics_codec.window_days_decoder`, `sampled_metric_decoder`,
    `org_metrics_bucket_decoder` y `org_metrics_project_overview_decoder`;
  - `automation_codec.scope_decoder` y `scope_to_json`;
  - `tasks/presenters.task_type_json`, `dependency_json` y
    `task_metrics_json`.
- Las APIs publicas vivas siguen siendo los decoders/responses de contrato
  (`my_metrics_decoder`, `org_metrics_overview_decoder`,
  `task_types_response`, `dependency_response`, `task_metrics_response`, etc.).
- Delta del pase: `-13` lineas mantenidas y nueve funciones publicas menos.
- Verificacion:
  - `cd shared && gleam format src test && gleam test` (`277 passed`);
  - `cd apps/server && gleam format src test && gleam build`;
  - `cd apps/server && DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_test?sslmode=disable SB_DB_POOL_SIZE=2 gleam test`
    (`560 passed`);
  - `cd apps/client && gleam format src test && gleam test` (`1819 passed`);
  - barrido de referencias externas de los nueve helpers privatizados sin
    consumidores.
- Segundo pase de encapsulacion HTTP server:
  - privatizados `tasks/filters.parse_int_filter`, `parse_string_filter` y
    `single_query_value`; el contrato publico queda en `parse_task_filters` y
    el comportamiento de duplicados ya esta cubierto por
    `parse_filters_rejects_duplicate_q_values_test` y por
    `http/query.single_value`;
  - privatizados `projects/presenters.role_update_result` y
    `org_users/presenters.project_role_update`, manteniendo como API publica
    las respuestas envelope `role_update_response` y
    `project_role_update_response`;
  - eliminado el test de implementacion del wrapper duplicado
    `single_query_value_public_wrapper_rejects_duplicates_test`;
  - delta adicional: `-34` lineas mantenidas y cinco funciones publicas menos;
  - verificacion: `cd apps/server && gleam format src test && gleam build &&
    DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_test?sslmode=disable SB_DB_POOL_SIZE=2 gleam test`
    (`559 passed`).

## Orden recomendado de ejecucion

1. WP-00 baseline.
2. WP-01 server test fixtures.
3. WP-02 client test helpers.
4. WP-10 public API accidental.
5. WP-03 roots Lustre.
6. WP-04 selectors compartidos de work/card/task.
7. WP-05 dialogos UI.
8. WP-06 backend HTTP.
9. WP-07 backend use cases.
10. WP-08 entrada Squirrel y SQL obsoleto.
11. WP-09 seeds.
12. WP-11 i18n/styles.
13. Gate Fase 1: tests completos, agent-browser AU-01 a AU-12 y medicion real.
14. WP-12 consolidacion profunda de tests.
15. WP-13 proyecciones SQL task/card.
16. WP-14 use cases y presenters de segundo pase.
17. WP-15 estilos, i18n y seeds de segundo pase.
18. Gate base: objetivo `-20k`, refactor final y validacion agent-browser.
19. WP-16 tramo `-30k` si cumple condiciones de entrada.
20. Gate extendido: objetivo `-30k`, refactor final y validacion agent-browser
    completa.

La razon del orden: primero se reducen tests y API accidental para que los
refactors grandes no arrastren acoplamientos falsos. Despues se atacan roots y
superficies con mejor red de seguridad.

## Matriz backend/frontend por paquete

| WP | Frontend | Backend | Shared | Tests | Riesgo dominante |
| --- | --- | --- | --- | --- | --- |
| WP-00 | Medicion client/src y client/test | Medicion server/src, server/test y generado | Medicion shared | Baseline completo | Ninguno; es observabilidad. |
| WP-01 | No aplica | Helpers HTTP compartidos para tests | No aplica | Server tests | Borrar setup que tambien valida auth por accidente. |
| WP-02 | Helpers render y builders de dominio | No aplica | Reuso de tipos compartidos | Client tests | Ocultar expectativas con helpers demasiado opacos. |
| WP-03 | Roots Lustre y routes feature-owned | No aplica | Reuso de dominio en selectors | Client tests | Crear router/framework innecesario. |
| WP-04 | Plan/People/Capability/Card/Task selectors | No aplica | Task/Card states canonicos | Client tests | Mover reglas de producto a `ui/`. |
| WP-05 | Dialogos, botones, UI atoms | No aplica | No aplica | Client component tests | Crear CRUD universal. |
| WP-06 | Cliente API afectado solo si cambia contrato | Handlers, payloads, presenters | Contratos si el payload es compartido | Server + contract tests | Esconder autorizacion en helper generico. |
| WP-07 | Cliente solo si cambia presenter/API | Use cases cards/projects/workflows | ADTs o contratos canonicos | Unit + endpoint + integration | Romper reglas de negocio no caracterizadas. |
| WP-08 | Cliente/API solo si habia contrato retirado | SQL fuente, repositorios, schema de introspeccion | Contratos si cambia payload | Squirrel + server build + endpoints afectados | Auditar por `-- name:` en lugar del nombre de fichero. |
| WP-09 | Seeds usados por validacion visual | Seeds y builders server | Dominio compartido para entidades | Smoke/seed/browser | Perder escenarios QA. |
| WP-10 | `pub` accidental en features/api/ui | `pub` accidental en handlers/use cases | `pub` compartido justificado | Tests migrados a entrada publica | Privatizar helper puro realmente compartido. |
| WP-11 | i18n/styles/classes | No aplica salvo payload copy | ADT i18n/copy si aplica | i18n/style/render/browser | Borrar clase usada dinamicamente. |
| WP-12 | Tests de views y helpers render | Tests HTTP/DB grandes | Builders con dominio real | Server/client full | Reducir escenarios en vez de setup. |
| WP-13 | Cliente solo si cambia contrato task/card | SQL task/card, mappers, repositorios | Task/Card contracts | Squirrel + HTTP + AU Pool/Card/Task | Query universal opaca o sentinels nuevos. |
| WP-14 | Cliente si cambia presenter/API | Use cases, presenters, payloads | ADTs/outcomes compartidos si procede | Unit + endpoint + integration | Esconder reglas/autorizacion. |
| WP-15 | Estilos, i18n, seeds visibles | Seeds server | i18n/domain si aplica | i18n + seed + browser | Perder datos QA o coverage visual. |

## Validacion final con agent-browser

La validacion navegada no sustituye tests unitarios/integracion; cubre riesgos
de composicion, accesibilidad basica, menus, modales, drag, responsive y
contratos API reales desde el cliente.

### Preparacion

1. Cargar DB dev con seeds representativas:
   - `cd apps/server && DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable gleam run -m scrumbringer_server/seed`
   - Si se usa otra URL, registrarla en el informe.
2. Levantar app:
   - preferente: `DATABASE_URL=... scripts/dev-hot.sh`;
   - alternativa ya validada: server/API y cliente segun scripts locales.
3. Login base:
   - usuario: `admin@example.com`;
   - password: `passwordpassword`.
4. agent-browser:
   - usar una session nombrada, por ejemplo `--session scrumbringer-refactor`;
   - tomar `snapshot -i` antes de interactuar y despues de cada navegacion;
   - refrescar refs tras cada click que cambie DOM/ruta;
   - capturar screenshots desktop `1440x1000`, tablet `900x900` y mobile
     `390x844` para las superficies UI tocadas;
   - registrar `network requests --type xhr,fetch --status 400-599` al final.

### Casos de uso obligatorios

| Caso | Ruta/superficie | Flujo | Debe verificar |
| --- | --- | --- | --- |
| AU-01 Login y shell | Login -> app principal | Abrir app, login, esperar dashboard/shell, cambiar de proyecto si hay selector. | No hay errores 4xx/5xx, nav principal visible, layout sin solapes en desktop/mobile. |
| AU-02 Pool pull flow | Pool | Filtrar/visualizar disponibles, reclamar una task, liberarla o cerrarla segun seed, verificar contadores. | Task no salta de posicion de forma erratica, contadores iconificados coherentes, acciones disabled/loading accesibles. |
| AU-03 Drag en Pool | Pool | Arrastrar una task dentro del pool y repetir sobre otra columna/seccion si existe. | Solo se mueve la task arrastrada, orden estable tras refresh/snapshot, no hay glitches visuales ni requests fallidas. |
| AU-04 Card show | Plan/Pool -> abrir card | Abrir card, cambiar tabs principales, abrir/cerrar menu de acciones y panel secundario. | Un solo overlay/menu abierto, acciones no quedan cortadas por modal, escape/click fuera cierra, summary/work mantienen contenido esperado. |
| AU-05 Task show | Pool/People/Kanban -> abrir task | Abrir task, inspeccionar resumen/trabajo/notas/actividad, abrir acciones y cerrar. | Lenguaje visual de metricas unificado, icon-only con label/tooltip accesible, notas/actividad visibles sin solape. |
| AU-06 Plan estructura | Plan | Navegar jerarquia, expandir/contraer, abrir card/task desde estructura. | Listas keyed estables, seleccion no se pierde, badges/metricas consistentes, no hay texto legacy. |
| AU-07 Capability board | Capacidades | Usar filtro "mis capacidades", revisar bloques con tasks de varias cards, abrir task/card. | Filtro coincide con semantica unificada, bloques explican estado sin barra/artefacto confuso, metricas usan componentes compartidos. |
| AU-08 People/workload | Personas | Abrir People, filtrar por estado/capacidad si aplica, abrir trabajo asignado. | Agrupaciones y contadores coherentes con Pool, personas sin trabajo/overloaded renderizan estados correctos. |
| AU-09 Automations | Automations reglas/templates/executions | Navegar reglas, templates, historial, filtros y empty/error states. | No se rompen workflows tras refactor backend, estados activos/inactivos y ejecuciones se muestran sin copy obsoleto. |
| AU-10 CRUD admin/settings | Projects/task types/capabilities si estan disponibles | Crear/editar/cancelar entidad no destructiva o usar dialogos en modo cancel. | Dialogos reutilizados conservan validacion, foco, escape, disabled/loading y mensajes i18n. |
| AU-11 Responsive smoke | Pool, Card show, Task show, Plan | Repetir snapshot/screenshot en tablet y mobile. | Sin texto cortado, menus visibles, modal no corta acciones, targets tactiles razonables. |
| AU-12 Reload/consistencia | Rutas modificadas | Recargar browser en rutas profundas y volver a abrir vistas clave. | Estado inicial recupera datos, no hay 404 cliente, API client no llama endpoints retirados. |

### Evidencia de cierre

El informe final debe incluir:

- URL local usada y `DATABASE_URL` usada para seed.
- Lista de casos AU ejecutados, estado `pass/fail`, y comentario de fallo si
  aplica.
- Capturas relevantes o ruta de screenshots.
- Resumen de requests 4xx/5xx; cualquier fallo debe mapearse a endpoint o
  modulo cliente.
- Confirmacion de que no hay overlays simultaneos ni solapes en Card/Task show.
- Confirmacion de que Pool drag conserva identidad de task y orden estable.
- Confirmacion de que las queries SQL eliminadas no se invocan desde cliente ni
  backend.

Un caso AU fallido bloquea el cierre del plan salvo que se documente como bug
preexistente fuera del alcance y se cree plan/issue separado.

## Evidencia inicial capturada

Comandos ejecutados durante el diseno del plan:

```sh
git status --short
git log -1 --oneline
find apps shared -path '*/build' -prune -o -name '*.gleam' -print | xargs wc -l | sort -nr | head -40
find apps/client/src apps/server/src shared/src -path '*/build' -prune -o -name '*.gleam' -print | xargs wc -l | sort -nr | head -60
find apps/client/test apps/server/test shared/test -path '*/build' -prune -o -name '*.gleam' -print | xargs wc -l | sort -nr | head -60
find apps/client/src -name '*.gleam' -print | xargs wc -l | tail -1
find apps/server/src -name '*.gleam' -print | xargs wc -l | tail -1
find shared/src -name '*.gleam' -print | xargs wc -l | tail -1
find apps/client/test -name '*.gleam' -print | xargs wc -l | tail -1
find apps/server/test -name '*.gleam' -print | xargs wc -l | tail -1
find shared/test -name '*.gleam' -print | xargs wc -l | tail -1
find apps/server/src/scrumbringer_server/sql -name '*.sql' -print | wc -l
find apps/server/src/scrumbringer_server/sql -name '*.sql' -print | xargs wc -l | tail -1
wc -l apps/server/src/scrumbringer_server/sql.gleam
for f in apps/server/src/scrumbringer_server/sql/*.sql; do b=$(basename "$f" .sql); rg -q "sql\\.${b}\\b" apps/server/src apps/server/test --glob '!**/sql.gleam' --glob '!**/sql/*.sql' || echo "$b"; done
rg "fn login_as|fn find_cookie_value|fn create_project|fn create_task_type|fn create_task\(" apps/server/test
rg "fn assert_contains|fn assert_not_contains" apps/client/test
rg "^pub fn|^pub type|^pub const" apps/client/src apps/server/src shared/src
```

Lectura de la evidencia:

- Hay 214.014 lineas Gleam totales, con 73.873 en tests.
- Produccion mantenida sin `sql.gleam` generado queda en 130.565 lineas.
- La reduccion base de 20k supone alrededor del 9,8% del codigo Gleam
  mantenido si se incluyen tests, y exige al menos 12k no generadas. Es
  ambiciosa pero plausible si se ejecuta en dos fases y se mide el generado
  solo como delta derivado.
- Tras los primeros paquetes ejecutados en `refactor-cleanup`, la medicion baja
  a 205.743 lineas Gleam totales, 128.021 lineas de produccion mantenida sin
  `sql.gleam`, 2.838 lineas SQL fuente y 9.174 lineas generadas por Squirrel.
- Con estas cifras, elevar el plan a `-30k` es posible solo como tramo
  condicionado: requiere apurar los rangos altos de tests, frontend y backend,
  mas una consolidacion SQL real. No es razonable prometer mas de `-30k` sin una
  nueva auditoria, porque `sql.gleam` completo solo suma 9.174 lineas y no puede
  usarse como bolsa libre.
- Los tests HTTP y render helpers tienen duplicacion suficiente para empezar
  por ahi con bajo riesgo.
- La entrada Squirrel inicial sumaba 114 SQL fuente y 3.037 lineas; las queries
  sin uso directo por nombre generado eran `cards_task_count`, `ping`,
  `tasks_list_by_card` y `task_templates_list_for_org`. Tras WP-08, quedan 109
  ficheros SQL fuente, 2.838 lineas y no hay candidatos sin consumidor directo.
- Los roots y use cases grandes deben tratarse despues de reducir acoplamiento
  de tests; partirlos primero aumentaria lineas y riesgo.

## Criterios globales de aceptacion

Cada paquete debe entregar:

- Delta de lineas antes/despues, separando produccion y tests.
- Lista de codigo eliminado, no solo codigo movido.
- Tests ejecutados y resultado.
- Barrido `rg` de guardarrail con resultado esperado.
- Justificacion V/C/R: valor, complejidad, riesgo.
- Rechazos explicitos de mejoras que serian sobreingenieria.

El objetivo base de `-20k` se considera listo solo si:

1. La reduccion neta acumulada supera 20.000 lineas entre codigo mantenido y
   generado derivado.
2. Al menos 12.000 lineas de reduccion vienen de codigo mantenido no generado.
3. Toda reduccion de `sql.gleam` viene de `make squirrel` tras borrar, fusionar
   o simplificar SQL fuente mantenido.
4. `shared`, `client` y `server` pasan formato y tests.
5. No se ha aumentado la API publica accidental.
6. Los modulos grandes restantes tienen owner claro o plan posterior.
7. No quedan abstracciones nuevas sin al menos dos consumidores reales.
8. La validacion agent-browser AU-01 a AU-12 pasa o deja fallo preexistente
   documentado con owner y plan separado.
9. El informe final incluye deficiencias encontradas por revision manual,
   tests automatizados y validacion navegada.

El tramo extendido de `-30k` se considera listo solo si, ademas de todo lo
anterior:

1. La reduccion neta acumulada supera 30.000 lineas.
2. Al menos 22.000 lineas vienen de codigo mantenido no generado.
3. El ahorro generado no supera 8.000 lineas y esta asociado a commits donde se
   borra, fusiona o simplifica SQL fuente mantenido.
4. No queda ningun paquete extendido sin V/C/R documentado y sin decision
   explicita sobre mejoras rechazadas por sobreingenieria.
5. Se repite la validacion agent-browser completa despues del ultimo paquete,
   no solo despues de Fase 1.

## Riesgos y limites

- La reduccion de tests no debe borrar escenarios de producto; debe borrar
  setup duplicado.
- Partir un modulo puede aumentar lineas temporalmente. Solo se acepta si el
  paquete elimina duplicacion neta en el mismo commit o en el paquete completo.
- `sql.gleam` cuenta como ahorro solo si es delta derivado de `make squirrel`.
  Debe reportarse separado del codigo mantenido.
- No se acepta editar `sql.gleam` a mano ni reordenarlo para inflar el delta.
- Si una reduccion SQL elimina cobertura funcional, debe revertirse aunque
  mejore la metrica.
- No perseguir cero botones raw: algunos son primitivas UI legitimas.
- No perseguir cero strings: SQL, JSON, DOM y DB son fronteras validas.

## Candidatos concretos y estado actual

| Candidato | Motivo | Estado / guardarrail |
| --- | --- | --- |
| Server HTTP test helpers | Duplicacion visible de login/cookies/fixtures. | Parcialmente ejecutado; `tasks_http_test` ya no mantiene helper local de task type; repetir `rg "fn login_as|fn find_cookie_value|fn create_project|fn create_task_type|fn create_task\\(" apps/server/test` antes de nuevos pases. |
| Client render assertions | Decenas de `assert_contains` repetidos. | Ejecutado para serializacion HTML directa; queda solo `support/render_assertions.html` como uso canonico de `element.to_document_string`. Los siguientes pases WP-02 deben centrarse en builders de dominio reales, no en sustituciones cosmeticas. |
| Public API accidental | Simbolos publicos en `src` sin consumidor claro. | Parcialmente ejecutado; tooltips UI, `ui/icon_picker`, categoria/busqueda legacy de `ui/icon_catalog` y lista local duplicada de iconos ya retirados. Repetir `rg "^pub fn|^pub type|^pub const" apps/client/src apps/server/src shared/src` y auditar consumidores. |
| SQL fuente Squirrel obsoleto | 4 queries iniciales sin uso directo por nombre generado. | Ejecutado; el barrido actual de `sql.<basename>` no devuelve pendientes. |
| Card/task/work selectors | Plan/People/Capability/Card Show repiten estado visual. | Parcialmente ejecutado; `features/tasks/rollup` unifica conteos de estado en Plan/Kanban/Capability y el predicado canonico de bloqueo usado por `blocking_status`/Card Show. Repetir `rg "blocked_count|available_count|claimed_count|ongoing|closed_count" apps/client/src/scrumbringer_client/features` para siguientes pases. |
| Styles dead classes | Estilos de redisenos acumulados. | Parcialmente ejecutado; retirados restos de `ui/icon_picker`, navegacion antigua, sorting visual no conectado, decay badge legacy y progreso duplicado, preservando reglas responsive vivas. Repetir comparacion de clases usadas en views contra `styles/*`. |
