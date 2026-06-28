# Plan de reduccion mantenible de 20k lineas

Fecha: 2026-06-28

## Objetivo

Reducir aproximadamente 20.000 lineas netas de la base de codigo sin introducir
sobreingenieria. La reduccion debe venir de eliminar duplicacion, codigo muerto,
API publica accidental, fixtures repetidas, estados redundantes, queries SQL
obsoletas y responsabilidades mezcladas. No cuenta como exito mover lineas a
otro modulo si no desaparece una decision duplicada o una frontera publica
innecesaria.

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

- Objetivo principal: `-20.000` lineas netas entre codigo mantenido y generado
  derivado.
- Subobjetivo minimo mantenido: al menos `-12.000` lineas deben venir de codigo
  mantenido no generado.
- Subobjetivo generado: hasta `-8.000` lineas pueden venir de `sql.gleam` si el
  diff se explica por cambios en SQL fuente real.
- Tramo aspiracional: `-30.000` lineas solo si los paquetes anteriores quedan
  verdes y el analisis V/C/R mantiene riesgo bajo o medio. No es criterio base.

## Baseline actual

Medicion ejecutada sobre `f1df9c16 Execute remaining refactor work packages`.

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

Modulos de mayor peso que condicionan el plan:

| Modulo | Lineas | Lectura |
| --- | ---: | --- |
| `apps/server/src/scrumbringer_server/sql.gleam` | 9.576 | Generado; no editar manualmente. |
| `apps/server/test/tasks_http_test.gleam` | 3.853 | Alto potencial de fixture/DSL compartida. |
| `apps/client/src/scrumbringer_client/client_update.gleam` | 2.461 | Root de orquestacion; reducir solo por owners reales. |
| `apps/client/src/scrumbringer_client/client_view.gleam` | 2.169 | App shell; extraer composicion repetida, no crear framework. |
| `apps/server/test/notes_and_positions_http_test.gleam` | 2.165 | Tests largos con helpers duplicados. |
| `apps/server/src/scrumbringer_server/seed_db.gleam` | 1.782 | Orquestacion de seeds; dividir por escenarios. |
| `apps/client/src/scrumbringer_client/features/projects/update.gleam` | 1.608 | Settings/hierarchy/onboarding mezclados. |
| `apps/client/src/scrumbringer_client/features/plan/structure_view.gleam` | 1.595 | Selectores, politicas y DOM juntos. |
| `apps/client/src/scrumbringer_client/features/cards/show.gleam` | 1.486 | Ya mejorado; quedan paneles/work/actions. |
| `apps/client/src/scrumbringer_client/features/people/view.gleam` | 1.346 | Vista + agrupacion + acciones. |
| `apps/client/src/scrumbringer_client/features/capability_board/view.gleam` | 1.335 | Vista + breakdown + acciones. |
| `apps/client/src/scrumbringer_client/features/automations/rule_list.gleam` | 1.273 | UI de reglas con logica de frase/acciones. |

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
derivado.

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

El tramo de `-30.000` solo se considera si el total real de Fase 1+2 queda por
encima del rango alto sin aumentar riesgo, o si aparecen superficies claramente
obsoletas no detectadas en esta auditoria. No se acepta perseguirlo mediante
edicion manual de generado, perdida de cobertura o abstracciones universales.

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

Evidencia actual:

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
- `apps/server/test/fixtures.gleam` expone `new_app` y `reset_database` para
  tests que necesitan arrancar antes del registro inicial sin reintroducir FFI
  local ni truncates divergentes. Tambien expone `default_project_id` para
  retirar queries repetidas sobre el proyecto creado por bootstrap.
- Codigo eliminado:
  - bootstrap local,
  - login local,
  - cookie parsing local,
  - reset DB local,
  - invite-link insert local,
  - query helpers locales,
  - FFI local de `os.getenv`.
- Delta por archivo:
  - `org_invites_http_test.gleam`: `-193` lineas netas;
  - `org_invite_links_http_test.gleam`: `-246` lineas netas;
  - `password_resets_http_test.gleam`: `-84` lineas netas;
  - `auth_http_test.gleam`: `-105` lineas netas;
  - `capabilities_http_test.gleam`: `-252` lineas netas;
  - `fixtures.gleam`: `+13` lineas netas;
  - total parcial WP-01: `-867` lineas netas mantenidas.
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

Evidencia actual:

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
- Delta inicial:
  - SQL fuente: `-87` lineas;
  - generado derivado: `-309` lineas;
  - total paquete: `-396` lineas.
- Verificacion:
  - `DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable make squirrel`;
  - `cd apps/server && gleam build`;
  - `cd apps/server && DATABASE_URL=postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable SB_DB_POOL_SIZE=2 gleam test` (`560 passed`);
  - `rg "sql\\.(cards_task_count|ping|tasks_list_by_card|task_templates_list_for_org)\\b" apps/server/src apps/server/test`.

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
18. Gate final: objetivo `-20k`, refactor final y validacion agent-browser.

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
- Los tests HTTP y render helpers tienen duplicacion suficiente para empezar
  por ahi con bajo riesgo.
- La entrada Squirrel suma 114 SQL fuente y 3.037 lineas; las queries sin uso
  directo por nombre generado son `cards_task_count`, `ping`,
  `tasks_list_by_card` y `task_templates_list_for_org`.
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

El objetivo completo se considera listo solo si:

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

## Primeros candidatos concretos

| Candidato | Motivo | Guardarrail inicial |
| --- | --- | --- |
| Server HTTP test helpers | Duplicacion visible de login/cookies/fixtures. | `rg "fn login_as|fn find_cookie_value|fn create_project|fn create_task_type|fn create_task\\(" apps/server/test` |
| Client render assertions | Decenas de `assert_contains` repetidos. | `rg "fn assert_contains|fn assert_not_contains" apps/client/test` |
| Public API accidental | 3.384 simbolos publicos en src. | `rg "^pub fn|^pub type|^pub const" apps/client/src apps/server/src shared/src` |
| SQL fuente Squirrel obsoleto | 4 queries fuente sin uso directo por nombre generado. | Buscar `sql.<basename>` excluyendo `sql.gleam` y `sql/*.sql`. |
| Card/task/work selectors | Plan/People/Capability/Card Show repiten estado visual. | `rg "blocked_count|available_count|claimed_count|ongoing|closed_count" apps/client/src/scrumbringer_client/features` |
| Styles dead classes | 2.031 lineas de estilos y redisenos acumulados. | Comparar clases usadas en views contra `styles/*`. |
