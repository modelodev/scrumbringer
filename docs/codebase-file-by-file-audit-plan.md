# Plan de auditoria fichero a fichero de la base de codigo

Fecha: 2026-06-27

## Objetivo

Este documento define una auditoria completa de la base de codigo para generar,
como resultado final, un documento de auditoria accionable.

La auditoria debe repasar todos y cada uno de los ficheros versionados que
forman parte del producto, tanto backend como frontend, shared, tests,
configuracion y scripts de soporte. Primero debe construir un inventario
exhaustivo. Solo despues debe auditar ese inventario para descubrir:

- endpoints usados y no usados;
- componentes usados, duplicados o demasiado cercanos;
- modulos usados, demasiado publicos o con responsabilidades compartidas;
- tests existentes, duplicados, fragiles o ausentes;
- oportunidades de unificacion que reduzcan codigo y mejoren mantenibilidad;
- codigo que pueda retirarse de forma segura tras una unificacion.

El objetivo no es crear abstracciones por simetria. El objetivo es reducir la
base de codigo cuando haya evidencia de duplicacion real, fronteras publicas
accidentales, responsabilidades mal ubicadas o tests que obliguen a mantener
fragmentos de codigo sueltos.

## Resultado final esperado

La ejecucion de este plan debe producir:

```txt
docs/audits/codebase-file-by-file-audit.md
docs/audits/codebase-inventory.yml
docs/audits/endpoint-map.md
docs/audits/component-map.md
docs/audits/module-map.md
docs/audits/test-coverage-map.md
docs/audits/refactor-candidates.md
docs/audits/refactor-work-packages.md
```

El documento principal, `codebase-file-by-file-audit.md`, sera la sintesis
ejecutiva. Los ficheros auxiliares seran la evidencia trazable.

## Alcance

La auditoria cubre todos los ficheros versionados bajo estas areas:

- `apps/client/src`
- `apps/client/test`
- `apps/server/src`
- `apps/server/test`
- `shared/src`
- `shared/test`
- `docs/architecture`
- `docs/*.md` cuando describan arquitectura, contratos, UI o planes vivos
- `gleam.toml`, `manifest.toml` y configuracion relevante por paquete
- scripts versionados que ejecuten validacion, smoke tests, seeds o migraciones

La auditoria debe excluir artefactos generados o dependencias vendorizadas salvo
que esten versionados y formen parte explicita del comportamiento del producto:

- `build/`
- `dist/`
- `.lustre/build/`
- paquetes descargados;
- caches locales;
- artefactos temporales.

Cada exclusion debe quedar documentada con el motivo. Si un fichero versionado
parece generado, no se excluye automaticamente: se clasifica como
`generated_versioned` y se decide explicitamente si debe auditarse o
reconstruirse.

## Principios de la auditoria

1. Inventariar antes de opinar.
2. Auditar por evidencia, no por impresion de tamano.
3. Trazar cada endpoint desde router hasta tests y UI.
4. Trazar cada componente desde consumidor hasta tests y estilos.
5. Trazar cada modulo desde su API publica hasta sus consumidores reales.
6. Mantener ownership de producto: servidor para autorizacion/persistencia,
   cliente para estado de UI, shared para contratos canonicos.
7. No promover nada a shared sin al menos dos consumidores reales o un contrato
   full-stack claro.
8. No crear componentes o helpers genericos si no eliminan decisiones duplicadas.
9. Preferir tipos de dominio existentes antes de crear DTOs o tipos UI
   equivalentes.
10. Cada refactor candidato debe explicar que codigo borra, que frontera
    estrecha o que estado invalido impide.

## Fase 0: baseline

Antes de inventariar se debe registrar el estado de la rama.

Comandos sugeridos:

```sh
git status --short
git rev-parse HEAD
git ls-files > /tmp/scrumbringer-tracked-files.txt
```

Validaciones base, si el entorno lo permite:

```sh
cd shared && gleam format --check src test && gleam test
cd apps/server && gleam format --check src test && gleam test
cd apps/client && gleam format --check src test && gleam test
```

Si algun comando falla antes de empezar, el fallo se registra como baseline. La
auditoria puede continuar, pero ningun refactor posterior se considera validado
hasta recuperar un estado verde o explicar la excepcion.

## Fase 1: inventario completo

Esta fase no decide mejoras. Solo construye evidencia.

### 1.1 Inventario de ficheros

El inventario debe partir de `git ls-files`, no de `find`, para evitar caches y
artefactos locales.

Campos obligatorios por fichero:

```yaml
- path:
  package: client | server | shared | root | docs | script | unknown
  layer: frontend | backend | shared_domain | test | config | docs | script
  kind:
    - route
    - endpoint_handler
    - api_client
    - lustre_component
    - lustre_route
    - lustre_update
    - lustre_view
    - domain_model
    - contract
    - repository
    - use_case
    - sql
    - ffi
    - style
    - test
    - fixture
    - helper
    - generated_versioned
    - docs
    - config
  domain:
  public_symbols:
  imports:
  imported_by:
  endpoints_declared:
  endpoints_called:
  components_declared:
  components_used:
  tests_declared:
  tests_covering:
  side_effects:
  notes:
```

Regla: ningun fichero auditado puede quedar con `kind: unknown` al final de la
fase. Si no encaja, se crea una categoria explicita y se documenta.

### 1.2 Inventario de modulos Gleam

Por cada modulo `.gleam`:

```yaml
module:
path:
package:
is_test:
public_types:
public_functions:
public_consts:
private_major_functions:
imports:
consumers:
domain_concepts:
owns_state:
owns_effects:
owns_http_boundary:
owns_persistence_boundary:
owns_ui_boundary:
uses_dynamic:
uses_ffi:
uses_json:
uses_sql:
test_files:
```

Comandos de apoyo:

```sh
rg -n "^pub (type|opaque type|fn|const)" apps shared
rg -n "^import " apps shared
rg -n "@external|Dynamic|decode\\.dynamic|gleam/dynamic" apps shared
```

La revision manual debe completar lo que los comandos no pueden saber:
responsabilidad real, ownership, side effects y razon de existencia.

### 1.3 Inventario de endpoints

Por cada endpoint backend:

```yaml
method:
path:
router_match:
handler:
auth_required:
authorization_rule:
parse_phase:
process_phase:
present_phase:
request_contract:
response_contract:
shared_contract:
use_case:
repository:
sql_or_storage:
client_api_callers:
frontend_routes:
frontend_components:
server_tests:
client_tests:
contract_tests:
status_codes:
error_mapping:
```

Comandos de apoyo:

```sh
rg -n "\"api\"|\"v1\"|wisp.path_segments|require_method|method_not_allowed" apps/server/src apps/server/test
rg -n "/api/v1|core\\.request|request\\(" apps/client/src apps/client/test shared/src shared/test
```

Cada endpoint debe quedar clasificado en una de estas categorias:

- `live_full_stack`: servidor, cliente y tests lo usan.
- `live_server_only`: existe y esta probado, pero no hay cliente interno.
- `live_client_only`: el cliente llama a una ruta no encontrada en router.
- `test_only`: solo aparece en tests.
- `dead_or_legacy`: no tiene consumidor ni contrato vigente.
- `unknown`: categoria temporal prohibida al cerrar la fase.

### 1.4 Inventario de componentes frontend

Por cada componente o vista Lustre:

```yaml
component:
path:
kind: stateless_view | stateful_component | route_view | helper_view | web_component
domain:
public_api:
props:
messages:
state_owned:
effects:
children:
parents:
css_classes:
icons:
tooltips:
aria:
keyboard_support:
dynamic_lists_keyed:
tests:
browser_coverage:
adjacent_components_initial_notes:
```

Comandos de apoyo:

```sh
rg -n "pub fn view|fn view|lustre\\.component|element\\.map|effect\\.map" apps/client/src apps/client/test
rg -n "html\\.button|html\\.dialog|attribute\\.role|aria_|keyed\\.element" apps/client/src apps/client/test
rg -n "class\\(\"|class\\(" apps/client/src apps/client/test
```

La auditoria debe comprobar especificamente:

- si el componente encapsula estado o solo duplica markup;
- si el nombre expresa un concepto de producto o una abstraccion generica;
- si las listas dinamicas usan rendering keyed cuando corresponde;
- si hay accesibilidad y soporte de teclado para controles interactivos;
- si el componente tiene tests de render/update o solo tests indirectos.

### 1.5 Inventario de tests

Por cada fichero de test:

```yaml
test_file:
package:
target: erlang | javascript | both | unknown
test_type:
  - unit
  - integration
  - endpoint
  - contract
  - mapper
  - lustre_update
  - lustre_view
  - browser
  - fixture
subjects_under_test:
endpoints_covered:
components_covered:
modules_covered:
fixtures_used:
helpers_used:
uses_public_behavior:
tests_private_helpers:
duplicates:
missing_matrix:
snapshot_status:
```

Reglas:

- Los tests nuevos o refactorizados deben usar `let assert`, no `should`.
- Los tests de endpoints deben cubrir metodo permitido, metodo no permitido,
  payload valido, payload invalido, auth/autorizacion cuando aplique y errores
  de dominio relevantes.
- Los tests frontend deben cubrir transiciones de estado, render observable y
  flujos de usuario relevantes.
- Los snapshots Birdie, si aparecen, requieren revision humana; no se
  autoaceptan.

## Fase 2: auditoria del inventario

Esta fase empieza solo cuando el inventario no tenga ficheros `unknown`.

### 2.1 Deteccion de adyacencias

Dos endpoints, componentes o modulos son adyacentes cuando comparten demasiadas
decisiones para mantenerse separados sin coste.

Puntuacion por candidato:

| Dimension | Puntos | Pregunta |
| --- | ---: | --- |
| Dominio | 0-3 | Representan el mismo concepto de producto? |
| Contrato | 0-3 | Comparten payload, respuesta, tipo o decoder? |
| Politica | 0-3 | Comparten auth, permisos, lifecycle o reglas? |
| Estado | 0-3 | Modelan el mismo estado con nombres distintos? |
| Presentacion | 0-3 | Renderizan la misma informacion o lenguaje visual? |
| Efectos | 0-3 | Ejecutan las mismas llamadas, queries o comandos? |
| Tests | 0-3 | Repiten fixtures, matrices o expectativas? |
| Churn | 0-3 | Cambian juntos o se rompen por las mismas razones? |

Interpretacion:

- `0-6`: no unificar.
- `7-10`: revisar extraccion parcial.
- `11-15`: candidato fuerte.
- `16+`: prioridad alta.

La puntuacion no sustituye el juicio tecnico. Un candidato con puntuacion alta
puede rechazarse si la unificacion crea una abstraccion mas grande que el
problema.

### 2.2 Responsabilidades compartidas

Se deben marcar como hallazgo los casos donde:

- un modulo de UI conoce reglas de persistencia o autorizacion;
- un endpoint repite parse/present ya existente en otro endpoint;
- un caso de uso mezcla validacion HTTP, dominio y SQL;
- `shared` contiene tipos que solo usa un lado;
- `client_state` o routes raiz acumulan estado que pertenece a una feature;
- un test obliga a mantener `pub fn` que produccion no necesita;
- un helper existe solo para satisfacer un test o gate de forma;
- un componente `components/` es realmente una pantalla de producto;
- un modulo feature-local esta duplicado en otra feature con otro nombre.

### 2.3 Deteccion de codigo retirable

Por cada candidato se debe identificar codigo que podria borrarse:

```yaml
candidate:
obsolete_files:
obsolete_public_symbols:
obsolete_tests:
obsolete_fixtures:
obsolete_css:
obsolete_docs:
obsolete_routes:
guardrail_rg:
replacement_owner:
```

No se acepta una propuesta de unificacion sin una estimacion concreta de que se
elimina o que API publica se estrecha.

### 2.4 Clasificacion de hallazgos

Cada hallazgo debe usar una severidad operativa:

- `P0`: codigo muerto, endpoint roto, cliente llama ruta inexistente, test falso
  o frontera que permite estado invalido critico.
- `P1`: duplicacion clara entre endpoints/componentes/modulos con beneficio
  alto de unificacion.
- `P2`: API publica accidental, tests demasiado acoplados, helpers duplicados o
  ownership confuso.
- `P3`: mejora local de legibilidad o organizacion con impacto bajo.
- `Rejected`: similitud superficial que no conviene unificar.

## Fase 3: mapas de trazabilidad

La auditoria debe producir mapas bidireccionales.

### Endpoint map

Formato minimo:

```txt
METHOD /api/v1/example
  router:
  handler:
  parse:
  process:
  present:
  shared contract:
  client API:
  frontend consumers:
  tests:
  adjacent endpoints:
  decision:
```

### Component map

Formato minimo:

```txt
ComponentName
  path:
  owner:
  parents:
  children:
  state:
  messages:
  styles:
  tests:
  adjacent components:
  decision:
```

### Module map

Formato minimo:

```txt
module/name
  path:
  public API:
  consumers:
  tests:
  side effects:
  ownership:
  adjacent modules:
  decision:
```

### Test coverage map

Formato minimo:

```txt
Behavior: claim task
  endpoints:
  modules:
  components:
  tests:
  missing cases:
  duplicate tests:
  refactor impact:
```

## Fase 4: candidatos de mejora

Los candidatos deben ordenarse por impacto real sobre la base de codigo.

Orden recomendado:

1. Endpoints muertos, desalineados o sin consumidor valido.
2. Cliente API duplicado o que reimplementa contratos.
3. Tipos/contratos duplicados entre server, client y shared.
4. Componentes visuales que expresan el mismo lenguaje con markup distinto.
5. Routes/update roots que conocen demasiados subflujos.
6. Tests duplicados, de compatibilidad interna o acoplados a privados.
7. Helpers publicos accidentales.
8. CSS/clases obsoletas tras consolidar componentes.
9. Documentacion viva que contradice el modelo final.

Cada candidato debe incluir:

```yaml
id:
title:
priority:
scope:
evidence:
current_owners:
target_owner:
files_to_change:
files_to_delete:
public_api_to_remove:
tests_to_add:
tests_to_rewrite:
tests_to_delete:
risks:
acceptance_criteria:
validation_commands:
```

## Fase 5: paquetes de trabajo posteriores

La auditoria no ejecuta los refactors. Los disena.

Cada paquete de trabajo debe ser ejecutable de forma independiente y debe
seguir esta plantilla:

```md
## WP-N: titulo

### Problema

Descripcion breve de la duplicidad, responsabilidad compartida o deuda.

### Evidencia del inventario

- Ficheros:
- Endpoints:
- Componentes:
- Modulos:
- Tests:

### Decision de diseno

Owner final y razon. Alternativas rechazadas.

### Cambios previstos

- Codigo que se mueve:
- Codigo que se reescribe:
- Codigo que se elimina:
- Tests que se crean:
- Tests que se reescriben:
- Tests que se eliminan:

### Guardarrails

Comandos `rg`, tests o checks que deben fallar si reaparece el patron antiguo.

### Criterios de aceptacion

- Se reduce duplicacion real.
- Se elimina o estrecha API publica accidental.
- El comportamiento queda cubierto por tests de entrada publica.
- No se crea una abstraccion generica sin consumidores reales.
- No queda codigo obsoleto referenciado.
```

## Criterios de aceptacion de la auditoria

La auditoria se considera completa solo si cumple todo esto:

1. Todos los ficheros versionados dentro del alcance estan inventariados.
2. No queda ningun fichero con `kind: unknown`.
3. Todos los modulos Gleam tienen API publica, imports y consumidores
   identificados.
4. Todos los endpoints backend estan trazados hasta cliente/test o marcados como
   server-only con justificacion.
5. Todas las llamadas API frontend apuntan a un endpoint existente o quedan
   marcadas como fallo.
6. Todos los componentes frontend tienen consumidores y tests identificados, o
   quedan marcados como no cubiertos.
7. Todos los tests tienen subjects bajo prueba identificados.
8. Cada candidato de unificacion tiene evidencia y puntuacion de adyacencia.
9. Cada propuesta de mejora identifica codigo a borrar o API publica a cerrar.
10. Cada rechazo de unificacion relevante explica por que seria
    sobreingenieria.
11. El informe final incluye prioridades, riesgos y paquetes de trabajo
    ejecutables.
12. El informe final separa hechos del inventario, conclusiones de auditoria y
    recomendaciones de refactor.

## Validacion recomendada tras ejecutar la auditoria

La auditoria no modifica codigo productivo, pero debe poder comprobar que sus
mapas no son inconsistentes.

Comandos minimos:

```sh
git ls-files > /tmp/scrumbringer-tracked-files.txt
rg -n "^pub (type|opaque type|fn|const)" apps shared
rg -n "^import " apps shared
rg -n "/api/v1|wisp.path_segments|core\\.request|request\\(" apps shared
```

Si durante la auditoria se crean scripts de apoyo, deben ser deterministas,
versionables y no sustituir la revision manual. El script puede proponer
clasificaciones; la auditoria debe confirmarlas.

## Riesgos del proceso

### Riesgo: inventario incompleto

Mitigacion: partir de `git ls-files`, exigir 100% de clasificacion y documentar
exclusiones.

### Riesgo: sobreingenieria

Mitigacion: no aceptar unificaciones sin codigo eliminable, API cerrada o
invariante fortalecida.

### Riesgo: tests que fijan implementacion

Mitigacion: marcar tests que llaman helpers privados o fuerzan `pub fn`; cada
paquete de refactor debe migrarlos a entradas de produccion.

### Riesgo: mover duplicacion en vez de borrarla

Mitigacion: cada paquete debe declarar `files_to_delete`,
`public_api_to_remove` o `guardrail_rg`.

### Riesgo: shared como cajon comun

Mitigacion: shared solo acepta contratos full-stack, tipos de dominio canonicos
o helpers con consumidores reales en mas de una frontera.

## Primer corte recomendado

La primera ejecucion de la auditoria deberia limitarse a producir estos cuatro
artefactos. El inventario bruto se genera en disco para revision local, pero no
debe versionarse porque es derivado, muy voluminoso y queda obsoleto en cuanto
cambia la rama:

1. `docs/audits/codebase-inventory.yml` local/regenerable
2. `docs/audits/endpoint-map.md`
3. `docs/audits/component-map.md`
4. `docs/audits/test-coverage-map.md`

No se debe empezar a refactorizar hasta que esos cuatro documentos existan y no
contengan categorias `unknown`. El primer paquete de mejora debe salir de la
matriz de adyacencia, no de una intuicion local sobre un fichero grande.
