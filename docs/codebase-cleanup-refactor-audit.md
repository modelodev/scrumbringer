# Informe de limpieza y refactorizacion de base de codigo

Fecha: 2026-06-15

## Objetivo

Este informe profundiza en los puntos detectados durante el repaso de la base de codigo y propone mejoras concretas para:

- Reducir duplicacion y fomentar DRY donde ya hay repeticion real.
- Mejorar el diseno de tipos, especialmente ADT y responsabilidad de cada record.
- Reorganizar modulos grandes sin introducir frameworks internos ni abstracciones prematuras.

La regla principal es conservar las fronteras actuales del producto: dominio compartido como contrato canonico, servidor como owner de persistencia/autorizacion, y cliente como owner de estado de UI.

## Principios de aplicacion

1. Consolidar primero los duplicados exactos o casi exactos.
2. Mantener tipos internos cuando contienen datos que solo tienen sentido en servidor, como `org_id` para autorizacion.
3. Usar ADT para estados de negocio, no para cada detalle accidental de formulario.
4. Mantener strings y sentinels solo en fronteras inevitables: SQL, JSON, DOM select values.
5. Extraer modulos por responsabilidad de producto, no por patrones genericos.
6. Anadir helpers compartidos solo cuando el mismo patron aparece en tres o mas sitios y la firma queda clara.

## Criterio de decision

Las mejoras se priorizan con tres variables:

- Valor: cuanto reduce duplicacion, fortalece invariantes o aclara ownership.
- Complejidad: cuantos modulos, tests y contratos hay que tocar.
- Riesgo: probabilidad de romper comportamiento observable o contratos HTTP.

Una mejora es preferente cuando tiene valor alto y complejidad/riesgo bajo. Si el valor es alto pero el riesgo tambien, debe ir despues de cambios pequenos que validen el patron. Por eso `Card` y `RuleTemplate` aparecen antes que `Task`, aunque `Task` sea mas importante para el modelo del producto.

La propuesta no busca maximizar abstraccion. Busca maximizar eliminacion de conceptos duplicados. Un helper nuevo solo es mejor que codigo local cuando borra ramas repetidas, hace imposible un estado invalido o reduce una frontera publica.

## Refuerzo definitivo de lectura

Este informe queda reforzado con una conclusion operativa: la mejor solucion no
es seguir refactorizando de forma abierta, sino aplicar cortes pequenos solo
cuando superen una prueba de ownership, frontera publica, tipo y test. La rama
ya contiene mejoras reales, pero el informe no debe convertir esas mejoras en
permiso para tocar todo lo que parezca grande.

La lectura canonica para decidir el siguiente paso es esta:

| Dimension | Decision actual | Accion correcta |
| --- | --- | --- |
| API publica de updates | Cerrar handlers internos detras de `try_update` cuando no hay consumidores externos legitimos | Continuar solo con barrido previo de `pub fn`/`pub type` y migracion de tests a mensajes reales |
| DRY | Extraer owners pequenos cuando eliminan contexto, auth, apply o convenciones repetidas | No crear helpers por similitud superficial de lineas |
| Tipos y ADT | Usar `shared/src/domain` para conceptos canonicos y ADT para estados de negocio | No mover records internos con autorizacion, persistencia, hash, bearer o auditoria |
| UI/UX compartida | Reutilizar primitivas cuando expresan comando, dialogo, intent o accesibilidad comun | No forzar toggles, drag handles, rows seleccionables o segmented controls a un boton generico |
| HTTP/payloads | Absorber sentinels y convenciones de transporte en parse/presenter/payload helper | No perseguir cero literales en SQL, JSON o DOM si siguen confinados en frontera |
| Documentacion | Mantener el informe como registro de decisiones y guardarrails repetibles | No aceptar conclusiones sin comando, test o falso positivo explicado |

### Regla reforzada de optimalidad

Una mejora es optima solo si cumple las cuatro condiciones siguientes:

1. Borra una decision duplicada o estrecha una API publica accidental.
2. Reutiliza un owner existente o crea uno estrecho con responsabilidad de
   producto, no un framework interno.
3. Mantiene o mejora el modelado de tipos sin mover datos internos a una
   frontera publica.
4. Tiene una prueba por la entrada que usa produccion y un barrido `rg`
   repetible que detectaria la regresion.

Si una de estas condiciones falla, la mejora puede documentarse como sospecha,
pero no debe ejecutarse todavia.

### Contrato de evidencia por corte

Cada nuevo corte debe dejar una ficha verificable:

| Campo | Evidencia minima |
| --- | --- |
| Parent scope | `origin/main` o parent resuelto explicitamente |
| Owner anterior y owner final | Modulo que deja de conocer el flujo y modulo que queda como owner |
| Public API retirada | Lista de simbolos que dejan de ser `pub`, o justificacion de cada simbolo que queda |
| Reuso | Que helper, route, ADT, presenter o payload existente se aprovecha |
| Tests | Test por `try_update`, route, payload o presenter, evitando handlers internos salvo helper puro |
| Guardarrail | Comando `rg` con resultado esperado, incluyendo falsos positivos admitidos |
| V/C/R | Valor, complejidad y riesgo comparados con la alternativa de no tocar |

Esta ficha evita dos errores simetricos: conservar cambios intermedios que no
cerraron nada, y borrar codigo solo porque aumento el numero de lineas de la
rama.

### Semaforo reforzado de lo que no debe tocarse ahora

| Area | Estado | Por que no tocar sin nueva evidencia |
| --- | --- | --- |
| `client_state/types.gleam` | Cerrado bajo vigilancia | Ya no actua como cajon de forms o dialog targets; solo debe cambiar si aparece un tipo transversal real |
| Aliases de slices admin/member | Residuo aceptable | No tienen callers externos y ayudan a leer el shell de estado; eliminarlos ahora seria churn |
| `card trees/update.gleam` shell | Residuo aceptado | Filtros, seleccion, refresh, dialogos, movimientos, expansion y create ya tienen owner; partir contratos sin owner nuevo solo mueve imports |
| `pool/update.gleam` shell | Parcial sano | Tareas, metricas, rule metrics, posiciones, skills y auth ya fueron extraidos; otro corte exige familia funcional nueva |
| CRUD/UI universal | Descartado | Los dialogos comparten piezas, no un contrato unico de producto |
| Wrappers opacos para todos los IDs | Descartado por ahora | Sin bug real de mezcla de IDs, el churn supera el valor |

### Prioridad reforzada pendiente

El siguiente trabajo, si se continua, debe ordenarse asi:

| Prioridad | Candidato | Condicion de entrada |
| --- | --- | --- |
| 1 | API publica accidental en updates restantes | `rg "^pub fn|^pub type"` muestra handlers operativos publicos y tests directos |
| 2 | Repeticion concreta de route/root | El root conserva contexto, auth, apply o feedback de una familia funcional ya nombrada |
| 3 | Convenciones de payload repetidas | Dos o mas endpoints repiten la misma traduccion de transporte |
| 4 | UI compartida | Tres acciones simples comparten intent, disabled/loading y accesibilidad |
| 5 | Tipos compartidos nuevos | Aparece un concepto canonico duplicado fuera de `shared/src/domain` |

Todo lo demas queda por debajo de la linea de ejecucion hasta que aparezca
evidencia nueva.

## Resumen canonico reforzado

Este documento debe leerse como una auditoria de ownership, no como un
inventario de archivos grandes. La pregunta correcta para cada cambio no es
"reduce lineas?", sino:

1. Que decision de producto o tecnica estaba duplicada?
2. Cual es el owner unico despues del cambio?
3. Que frontera publica se estrecha o que estado invalido desaparece?
4. Que test o barrido impide volver al estado anterior?

Si una propuesta no puede responder esas cuatro preguntas, no debe ejecutarse
todavia. Puede quedar como sospecha, pero no como plan de refactorizacion.

Lectura reforzada del estado actual:

| Clase | Significado estricto | Accion permitida |
| --- | --- | --- |
| Cerrado | Owner real, API publica minima, test cercano o barrido negativo | Mantener guardarrail; no tocar por tamano |
| Cerrado bajo vigilancia | El diseno es correcto, pero puede degradarse por nuevos callers o tipos publicos | Repetir barridos antes de tocar areas cercanas |
| Parcial sano | Queda residuo, pero esta justificado por frontera HTTP, SQL, DOM, UI gestual o shell de composicion | Clasificar nuevos matches; no exigir cero matches |
| Pendiente real | Hay handlers publicos accidentales, owners duplicados, sentinels cruzando a negocio o roots con contexto/apply/auth repetidos | Hacer un corte pequeno con tests por la entrada de produccion |
| Descartado | La solucion crea framework, facade o wrapper sin borrar una decision duplicada | No reabrir sin nueva evidencia |

El refuerzo cambia tambien el peso de la evidencia: un test que llama a un
handler interno no demuestra una buena frontera; puede demostrar lo contrario.
Para updates de cliente, el test preferente debe entrar por el mensaje real y
por `try_update`/route, salvo helpers puros compartidos o integraciones externas
explicitas.

### Corte ejecutado verificado

El barrido de superficie publica detecto una deuda concreta en
`features/task_types/update.gleam`: el route admin ya esta extraido y cerrado
como owner de integracion, pero el update de task types exponia handlers
internos y `Success` como API publica. Los tests tambien los llamaban de forma
directa.

Esto no invalidaba el corte de `features/admin/task_types_route.gleam`; lo
acotaba. El cierre ejecutado deja ambas capas con el contrato correcto:

| Capa | Estado | Evidencia | Decision |
| --- | --- | --- | --- |
| Route admin de task types | Cerrado | `task_types_route.gleam` contiene contexto, feedback, auth, apply y refresh policy | Mantener |
| Update de task types | Cerrado como API publica | Tests entran por `try_update`; `Success`, `success_effect` y handlers operativos son privados | Mantener guardarrail |

Guardarrail del candidato:

```sh
rg -n "task_types_update\.(handle_|success_effect)|^pub type Success|^pub fn handle_task_type|^pub fn success_effect" apps/client/src/scrumbringer_client/features/task_types/update.gleam apps/client/test/task_types_update_test.gleam apps/client/src/scrumbringer_client/features/admin/task_types_route.gleam
```

Resultado actual tras el corte: vacio. Si reaparece un match, debe existir una
integracion externa real que justifique mantener un simbolo publico; si no, los
tests deben cubrir el comportamiento por `try_update`.

V/C/R estimado:

| Valor | Complejidad | Riesgo | Motivo |
| --- | --- | --- | --- |
| Medio-alto | Media-baja | Bajo | Ejecutado; todos los handlers tenian mensajes `AdminMsg` equivalentes y produccion consume el update por `try_update` desde el route |

Este fue mejor candidato que seguir partiendo pool o card trees porque no crea
ningun owner nuevo: solo alinea una extraccion ya hecha con la frontera publica
correcta.

## Refuerzo ejecutivo 2026-06-15

El informe queda reforzado con una lectura mas estricta del estado actual: la
base de codigo no debe evaluarse por balance bruto de lineas anadidas/borradas,
sino por si cada cambio reduce una decision duplicada, mueve responsabilidad al
owner correcto o estrecha una frontera tecnica. Con ese criterio, el trabajo
ejecutado si mejora la base, pero no autoriza a declarar "todo limpio" sin
matices.

Estado ejecutivo:

| Area | Estado | Garantia fuerte | Limite vigente |
| --- | --- | --- | --- |
| Tasks update cliente | Cerrado | El orquestador antiguo desaparece y create/notes/mutation/detail tienen owners propios | No partir mas si no aparece una responsabilidad nueva |
| Lifecycle de task servidor | Cerrado | `task_json` deriva `status` y `work_state` desde `TaskState` | No eliminar campos redundantes del contrato compartido sin migracion coordinada |
| `ProjectGrant` | Cerrado | El ADT vive en `shared/src/domain/api_token.gleam` y seguridad runtime sigue en servidor | No mover bearer/hash/`VerifiedToken` a shared |
| `client_state/types.gleam` | Cerrado bajo vigilancia | Solo conserva tipos transversales reales | No aceptar nuevos forms/dialog targets/drag state globales |
| Admin routes | Cerrado para routes extraidos | El root delega en routes de area con tests directos | Nuevos cortes solo con evidencia de auth/context/apply repetidos |
| CRUD/UI helpers | Parcial sano | Las acciones simples migran a `ui/button`/`ui/dialog` y CRUD comparte helpers pequenos | No crear un componente CRUD universal |
| Project HTTP contract | Cerrado en frontera publica | El presenter ya no expone `org_id` de `ProjectRecord` ni `project_id` de `ProjectMemberRecord` | Los records internos siguen conservando esos campos para autorizacion/persistencia |
| Sentinels | Parcial sano | Los sentinels SQL/JSON quedan nombrados o confinados en frontera | No afirmar eliminacion total mientras existan queries que los necesitan |

### Refuerzo de suficiencia del informe

La conclusion reforzada es mas estricta que "se han limpiado cosas": los
cortes ejecutados son defendibles porque reducen owners duplicados, no porque
reduzcan lineas de forma uniforme. La base todavia tiene roots amplios, pero los
roots restantes tienen que evaluarse por conocimiento operacional, imports y
tests, no por `wc -l`.

Controles repetidos al reforzar el informe:

| Control | Resultado | Lectura |
| --- | --- | --- |
| `wc -l client_state.gleam client_state/types.gleam features/admin/update.gleam features/capabilities/update.gleam` | `399`, `14`, `346`, `288` | Los roots restantes son amplios, pero `types.gleam` ya no es cajon global y capabilities/admin actuan como dispatchers |
| `rg "pub type (Task|Card|Workflow|Rule|ApiToken|IntegrationUser|Project|ProjectMember) \{" apps/server/src shared/src` | Solo encuentra tipos canonicos en `shared/src/domain` | El servidor ya no publica entidades con el mismo nombre y significado que shared |
| `rg "features/tasks/update" apps/client/src apps/client/test` | Sin matches | El orquestador obsoleto de tasks no sigue siendo dependencia tecnica |
| Barrido global de botones raw | El uso cualificado `html.button` queda reducido a `ui/button.gleam` e `ui/icon_picker.gleam`; aun hay imports directos de `button` en features y helpers UI | La migracion de acciones simples ha avanzado, pero el estado correcto es parcial: cada `button` directo debe clasificarse como primitiva, helper UI, control de seleccion/expansion o deuda migrable |
| Barrido de `active` en handlers rules/workflows | Sin `normalize_active`, sin `active: Option(Int)` | El handler ya recibe `Option(Bool)` desde Parse |
| Barrido de `active` en APIs cliente | Sin `json.int(case active ...)` en workflows/rules | El cliente tambien concentra la convencion PATCH `active 0/1` en `api/payload_fields.gleam` |
| Barrido de task routing en pool | Sin imports de `task_create_update`, `task_mutation_update`, `task_detail_update`, `task_notes_update`, `dependency_update`, `detail_permissions` ni `helpers_lookup` en `features/pool/update.gleam` | El root de pool ya no conoce el orden interno de los subflujos de tarea |
| Barrido de campos internos en project presenters | Sin `org_id` ni `project_id` serializados | La frontera publica ya no filtra campos internos |

Con estos datos, la mejor lectura del estado es:

- Cerrado significa que existe owner claro, barrido repetible y prueba cercana o
  contrato verificable.
- Parcial sano significa que el residuo esta en una frontera tecnica y no cruza
  a dominio ni a reglas de producto.
- Pendiente real significa que todavia hay una decision duplicada o un root que
  conserva conocimiento operativo de un subflujo.
- Descartado significa que una abstraccion aumentaria superficie conceptual sin
  borrar una decision duplicada.

### Priorizacion reforzada por V/C/R

La siguiente tabla fija el orden optimo de actuacion si se continua la limpieza.
No ordena por tamano del archivo, sino por valor, complejidad y riesgo.

| Candidato | Valor | Complejidad | Riesgo | Decision |
| --- | --- | --- | --- | --- |
| Mantener vigilancia de tipos canonicos en shared | Alto | Baja | Bajo | Obligatorio como guardarrail; no requiere nuevo codigo si los barridos siguen limpios |
| Mantener `TaskState` como fuente de lifecycle | Alto | Baja | Medio | Cerrado ahora; solo ampliar si aparece otro presenter/handler con lifecycle paralelo |
| Normalizar convenciones JSON en payloads | Medio-alto | Baja | Bajo | Ejecutar solo cuando haya repeticion real como `active 0/1`; no crear framework de payloads |
| Sentinels SQL nombrados | Medio | Baja | Bajo | Mantener en frontera; no perseguir cero matches en SQL generado |
| Nuevos routes admin | Medio | Media | Medio | Solo si el root vuelve a mostrar context/apply/auth repetidos y tests migrables |
| Pool/card trees update | Medio | Media-alta | Medio | Pool ya tiene cortes por tareas, metricas operativas, metricas de reglas, posiciones, skills y auth comun; card trees ya separa filtros, seleccion, refresh, dialogos, movimientos, expansion y create; queda bajo vigilancia solo para contratos/feedback/root policy |
| CRUD universal | Bajo | Alta | Medio | Descartado; helpers pequenos sobre `crud_dialog_base` son suficientes |
| Wrappers opacos para todos los IDs | Medio | Alta | Alto | Descartado por ahora; solo ante bugs reales de mezcla de IDs |

Esta priorizacion tambien explica por que algunas areas deben dejar de tocarse:
si el siguiente cambio solo mueve funciones privadas o crea una capa con muchos
parametros, el valor baja y la complejidad sube. En ese caso la decision optima
es parar, documentar la frontera y protegerla con barridos.

### Refuerzo de optimo local

El plan queda reforzado con un criterio adicional: una mejora solo se considera
optima si mejora al menos una frontera real sin empeorar otra. En concreto:

| Frontera | Mejora valida | Senal de sobreingenieria | Control exigible |
| --- | --- | --- | --- |
| Dominio/shared | Un tipo compartido elimina un duplicado semantico o centraliza una invariante de producto | Mover records con datos internos de persistencia/autorizacion a shared | Barrido de `pub type` canonicos y tests de codec/presenter |
| Servidor/HTTP | Un payload o presenter absorbe convenciones de transporte antes de negocio | Crear wrappers genericos para todos los payloads aunque solo haya un caso | Test de payload/presenter cerca del endpoint |
| Cliente/update | Un route adapter elimina contexto, auth y apply repetidos del root | Crear un dispatcher generico que obliga a pasar muchos callbacks | Test de route con exito, auth/error y mensaje ignorado |
| UI | Un helper expresa semantica comun de comando, intent o accesibilidad | Forzar controles de seleccion, expansion o drag a una primitiva de boton | Barrido de `button` clasificado, no necesariamente vacio |
| Persistencia | Un sentinel queda nombrado o convertido en la frontera SQL/JSON | Perseguir cero literales en SQL generado o fixtures de compatibilidad | Barrido clasificado de sentinels y tests de parse/conversion |

Esta matriz evita dos extremos: dejar deuda porque "compila" y crear capas
porque "parece mas limpio". El cambio correcto es el que borra conocimiento
duplicado del owner equivocado y queda protegido por un control repetible.

### Pendientes reales tras el refuerzo

El informe no debe vender como deuda todo lo que aun se parece. Tras el nuevo
barrido, los pendientes reales son estos:

| Pendiente | Evidencia requerida antes de actuar | Solucion aceptable |
| --- | --- | --- |
| Card Trees como root amplio | Barrido de handlers que mezclen contexto, efectos y apply de subflujos ya nombrados | Extraer un owner existente por vez, con tests de update/view; filtros, seleccion, refresh, dialogos, movimientos, expansion y create ya tienen owner parcial |
| Pool como root todavia grande | Nueva evidencia de otra familia mezclada distinta de tareas, metricas operativas, metricas de reglas, posiciones, skills y auth | No cortar por longitud; repetir el patron de routes concretos solo si hay owner funcional claro |
| Helpers admin de listas remotas con scope | Ejecutado: el bloque duplicado desaparece de `features/admin/workflows.gleam` y `features/admin/task_templates.gleam` | Mantener `features/admin/scoped_remote_list.gleam` como owner puro de operaciones `Remote(List(_))` con scope org/proyecto |
| Nuevos formularios o estados en root cliente | `rg` debe detectar tipos especificos entrando en `client_state.gleam` o `client_state/types.gleam` | Mover al modulo de estado del feature y actualizar tests cercanos |
| Nuevos strings de negocio | Matches donde `"task"`, `"card"`, `"claimed"`, `"completed"` decidan comportamiento fuera de parse/present/form | Convertir a ADT en la frontera del submit, mapper o payload |
| Nuevas acciones raw de UI | `html.button` fuera de primitiva, controles seleccionables o drag | Migrar a `ui/button`, `ui/action_buttons` o `ui/dialog` segun semantica |
| Nuevos records servidor parecidos a shared | `pub type` con nombre canonico fuera de `shared/src/domain` | Usar shared si es contrato; renombrar como `Record`/`Projection` si contiene campos internos |

No hay evidencia suficiente ahora para introducir una capa comun mayor. La deuda
restante pide barridos dirigidos y cortes pequenos, no una reorganizacion
transversal.

### Contrato reforzado de conservacion o retirada

Un cambio intermedio se conserva solo si cumple al menos una de estas pruebas:

1. Reduce una decision duplicada observable.
2. Cambia el owner mental y tecnico del flujo.
3. Hace que un tipo canonico viva en `shared` o que una projection interna deje
   de competir por el mismo nombre.
4. Confina una convencion tecnica en SQL, JSON, DOM o FFI.
5. Anade un test cerca del modulo que decide el comportamiento.

Si no cumple ninguna, debe retirarse, inlinearse o reclasificarse como deuda.
Esto aplica incluso si compila. La limpieza no acepta codigo nuevo por
comodidad futura si no borra responsabilidad actual.

La consecuencia practica es esta:

- Un area cerrada solo debe tocarse si un barrido nuevo demuestra regresion o
  responsabilidad mezclada.
- Un area parcial no debe expandirse por intuicion: necesita una decision de
  contrato, un test cercano o un barrido que justifique el corte.
- Un cambio intermedio solo se conserva si tiene prueba, reduce imports del root
  o elimina un concepto duplicado. Si no cumple eso, debe retirarse.

### Garantias minimas por tipo de mejora

| Tipo de mejora | Garantia minima antes de marcar cerrado | Evidencia esperada |
| --- | --- | --- |
| Mover un tipo al dominio compartido | No queda un tipo publico equivalente en servidor/cliente operativo | Barrido de `pub type`, tests de codec/presenter o consumidores principales |
| Renombrar projection interna | El nuevo nombre explica por que no es contrato compartido | Callers actualizados y ausencia del nombre canonico fuera de `shared` |
| Extraer route/update | El root deja de conocer contexto, auth, feedback y apply del subflujo | Test de exito, test de auth/error y barrido de imports antiguos |
| Confinar sentinel | El literal no cruza a dominio, HTTP de negocio ni workflow handler | Constante/helper privado en frontera y test de parseo/conversion |
| Centralizar UI | El helper reutiliza primitiva existente y elimina repeticion real | Tres usos equivalentes o eliminacion de un estado invalido/atributo arbitrario |

Esta tabla debe usarse como freno de calidad. Si una mejora no alcanza la
garantia minima, no se borra del informe: se clasifica como parcial o se
descarta.

### Refuerzo de trazabilidad

Para que el informe sea accionable y no solo descriptivo, cada conclusion debe
poder rastrearse con esta cadena:

`hallazgo -> owner correcto -> cambio permitido -> garantia -> control de no regresion`

Si falta un eslabon, el punto no puede marcarse como cerrado. Esta regla evita
dos problemas que ya aparecieron durante la limpieza: conservar cambios
intermedios que solo movian codigo, y seguir extrayendo modulos cuando el
beneficio real ya no compensaba el coste.

| Hallazgo | Owner correcto | Cambio permitido | Garantia exigida | Control de no regresion |
| --- | --- | --- | --- | --- |
| Entidad canonica duplicada entre servidor y shared | `shared/src/domain/*` | Usar el tipo compartido o renombrar el servidor como `Record`/`Projection` | No hay `pub type` canonico fuera de shared | `rg "pub type (Task|Card|Workflow|Rule|ApiToken|IntegrationUser|Project|ProjectMember) \\{" apps/server/src shared/src` |
| Lifecycle de tarea calculado en mas de un sitio | `domain/task_state.gleam` y presenter como conversion JSON | Derivar `status`/`work_state` desde `TaskState` | Test con datos redundantes inconsistentes que demuestre que gana el ADT | Test de presenter y barrido de `task_state.to_status`/`to_work_state` |
| Root de cliente acumulando estado especifico | `client_state/<area>/*` | Mover forms, dialog targets, drag state o preview al owner de pantalla | `client_state/types.gleam` solo conserva tipos transversales | Barrido de nombres de forms/dialogs/drag en `client_state.gleam` y `types.gleam` |
| Root update adaptando subflujos | Route adapter concreto del area | Extraer context, auth y apply del submodelo | El root deja de importar subupdates y helpers operativos | Barrido de imports antiguos y tests del route |
| Repeticion UI de accion simple | `ui/button`, `ui/action_buttons`, `ui/dialog` o helper local estrecho | Sustituir botones raw solo cuando son comandos simples | El helper expresa intent/scope/loading/accessibility sin clase CSS completa | Barrido de `button(` y tests de vista para clases semanticas |
| Sentinel tecnico usado como regla | Frontera SQL/JSON/DOM | Nombrar constante o convertir en payload/mapper antes de negocio | El literal no decide reglas en dominio, handler o workflow | Barrido clasificado de `0`, `-1`, `""`, `"__unset__"` y strings de estado |

La lectura del control no es binaria en todos los casos. Un match puede ser
aceptable si esta en test de compatibilidad, documentacion, SQL generado,
formulario DOM o projection interna con nombre claro. Lo que no es aceptable es
un match que siga siendo el punto de decision de negocio.

### Matriz de cierre por capas

Esta matriz refuerza que las mejoras optimas no se miden por lineas sino por
responsabilidad cerrada. Un area queda cerrada solo si su capa queda con un
contrato claro y con al menos una prueba repetible.

| Capa | Estado esperado | Evidencia actual | Riesgo residual | Decision |
| --- | --- | --- | --- | --- |
| Dominio compartido | Tipos canonicos de producto viven en shared | `Task`, `Card`, `Workflow`, `Rule`, `Project`, `ProjectMember`, `ApiToken`, `IntegrationUser` aparecen como `pub type` canonicos en `shared/src/domain` | Que un servicio vuelva a publicar un tipo con el mismo nombre semantico | Cerrado bajo guardarrail de `rg` |
| Servidor/persistencia | Records internos se nombran como operativos y convierten en frontera | `ProjectRecord`, `ProjectMemberRecord`, `StoredProject`, `StoredProjectMember`, `WorkflowRecord`, `RuleRecord`, `ApiTokenRecord` | Confundir projection interna con contrato publico al presentar JSON | Cerrado si presenters no filtran campos internos |
| Payload/HTTP | Strings y enteros de transporte se convierten antes de Process | `payload_fields.gleam` en cliente y servidor concentra convenciones como `active 0/1` | Duplicar normalizaciones en handlers nuevos | Cerrado para casos ejecutados; vigilancia en endpoints nuevos |
| Estado cliente | Root contiene shell y tipos transversales, no modelos de pantalla | `client_state/types.gleam` queda reducido a `DialogState(form)` como primitiva generica | Reintroducir forms o targets especificos por comodidad | Cerrado bajo vigilancia |
| Updates de feature | Flujos con reglas propias tienen owner y tests cercanos | Tasks create/notes/mutation/detail, capabilities CRUD/assignments, admin routes, pool task route, pool rule metrics route | Cortes adicionales por longitud en vez de por owner | Parcial sano; actuar solo con evidencia |
| UI compartida | Acciones simples usan primitiva semantica; controles complejos pueden seguir raw | Migraciones a `ui/button`, `ui/dialog`, `ui/action_buttons`, `ui/task_actions`, `ui/modal_close_button` | Forzar controles segmentados, toggles o drag a botones genericos | Parcial sano; no crear CRUD universal |

### Criterio reforzado de optimalidad

Las mejoras indicadas son optimas bajo el estado actual si cumplen estas cuatro
condiciones a la vez:

1. Eliminan una decision duplicada, no solo una forma de escribir codigo.
2. Reutilizan un owner existente o crean uno con responsabilidad de producto
   clara.
3. Reducen conocimiento operativo en un root, presenter o servicio.
4. Pueden cerrarse con test cercano o barrido repetible.

Cuando dos soluciones compiten, se elige por V/C/R:

| Solucion candidata | Valor | Complejidad | Riesgo | Resultado |
| --- | --- | --- | --- | --- |
| Extraer route concreto con auth/context/apply repetidos | Alto | Media | Medio | Ejecutar si el root pierde imports y hay tests de route |
| Crear dispatcher generico para todos los routes | Medio | Alta | Medio-alto | Rechazar: aumenta framework interno y no borra mas decision |
| Mover ADT semantico a shared | Alto | Baja-media | Medio | Ejecutar si es contrato publico y no contiene datos internos |
| Mover records con `org_id`, hash o bearer a shared | Bajo | Media | Alto | Rechazar: mezcla contrato publico con seguridad/persistencia |
| Centralizar botones de acciones simples | Medio | Baja | Bajo | Ejecutar si reduce clases raw y mejora intent/accessibility |
| Centralizar todos los controles interactivos | Bajo | Alta | Medio | Rechazar: toggles, drag handles y segmented controls tienen semantica propia |
| Nombrar sentinels privados en persistencia | Medio | Baja | Bajo | Ejecutar: confina frontera tecnica |
| Eliminar todo sentinel de SQL aunque lo requiera la query | Bajo | Alta | Alto | Rechazar: perseguir cero matches no mejora el modelo |

Esta matriz tambien responde a la duda sobre las muchas adiciones acumuladas:
una adicion es aceptable si introduce tests, owner real o documentacion de
contrato; es sospechosa si introduce facade, helper con un solo uso o tipo sin
invariante nueva. Por eso el informe no debe usar el balance de lineas como
prueba principal. Debe usar imports eliminados, owners mas claros, tests
cercanos y barridos negativos.

### Clasificacion de residuos

Antes de pedir mas limpieza, cualquier residuo debe clasificarse en una de
estas categorias:

| Categoria | Se conserva? | Ejemplo aceptable | Ejemplo no aceptable |
| --- | --- | --- | --- |
| Compatibilidad publica | Si, si hay contrato externo vigente | JSON sigue exponiendo `status` aunque se derive de `TaskState` | Presenter decide `status` desde un campo obsoleto |
| Frontera tecnica | Si, si es privada y nombrada | Constante privada para `__unset__` o `0` de SQL | Literal usado en handler como regla de producto |
| Primitiva transversal | Si, si no conoce features | `DialogState(form)` generico | `TaskDialogMode` en `client_state/types.gleam` |
| Projection interna | Si, si el nombre explica que no es dominio | `ProjectRecord`, `StoredProject` | `Project` publico en servidor con `org_id` |
| Helper local | Si, si mejora legibilidad y tiene caller claro | Helper privado de vista con semantica local | Modulo facade con un caller y parametros genericos |
| Comentario/documentacion historica | Si, si esta en informe de migracion | Referencia a modulo eliminado en este documento | Comentario operativo apuntando al owner antiguo |

Todo lo que no encaje en una categoria aceptable debe retirarse o convertirse
en tarea concreta. Esta clasificacion es mas fuerte que "pasa los tests":
obliga a justificar por que un residuo sigue existiendo.

## Respuesta sobre optimalidad

Si se pregunta si estas son las mejoras optimas, la respuesta es: si, con el estado actual de la base de codigo, son el mejor orden conocido porque atacan duplicacion real y ownership borroso sin crear infraestructura especulativa.

La razon no es que sean las unicas mejoras posibles, sino que cumplen simultaneamente estas condiciones:

- Reducen conceptos duplicados ya observables en codigo.
- Aprovechan tipos y modulos existentes antes de anadir otros.
- Refuerzan invariantes del producto, especialmente alrededor de `Task`.
- Mantienen los strings y sentinels en fronteras tecnicas en vez de propagarlos.
- Permiten validacion incremental con tests existentes y barridos `rg`.
- Evitan cambios masivos donde el beneficio no compensa el riesgo.

El plan no considera optimo:

- partir archivos solo porque son largos;
- crear un framework interno de updates o CRUD;
- envolver todos los IDs con tipos opacos en un unico corte;
- mover al dominio compartido records que contienen datos internos de autorizacion;
- convertir cada string de formulario en un ADT global.

Esas alternativas pueden sonar mas limpias en abstracto, pero en este repositorio aumentarian superficie conceptual antes de eliminar duplicacion comprobada.

## Resumen ejecutivo

| Area | Mejora | Valor | Complejidad | Riesgo | Prioridad |
| --- | --- | --- | --- | --- | --- |
| `Card` | Usar `domain/card.Card` en servidor | Alto | Baja | Bajo | 1 |
| `RuleTemplate` | Usar `domain/workflow.RuleTemplate` en servidor | Medio | Baja | Bajo | 1 |
| SQL sentinels | Encapsular valores magicos en persistencia | Medio | Baja | Bajo | 1 |
| `Task` | Mapper servidor -> `domain/task.Task` | Muy alto | Media | Medio-alto | 2 |
| `TaskState` | Derivar status/work state desde estado canonico | Alto | Media | Medio | 2 |
| API tokens | Contrato compartido para metadata publica | Medio-alto | Media | Medio | 3 |
| `client_state/types` | Dividir por owners reales | Alto | Media-alta | Medio | 3 |
| `features/tasks/*_update` | Extraer create/detail/notes/mutation | Alto | Media | Medio | Ejecutado |
| `features/capabilities/update` | Separar CRUD y asignaciones | Medio-alto | Media | Medio | Ejecutado |
| `features/admin/update` | Extraer routes por area funcional | Medio-alto | Media-alta | Medio | 4 |
| CRUD UI | Helpers pequenos en `crud_dialog_base` | Medio | Baja-media | Bajo-medio | Ejecutado parcialmente |
| `Project`/`ProjectMember` | Renombrar projections internas, convertir en HTTP | Medio | Media | Medio | Ejecutado |

## Resumen reforzado de decision

El informe queda reforzado con una distincion operativa: no todo lo que queda "parecido" merece refactor. El siguiente trabajo solo debe ejecutarse si mejora al menos una de estas garantias:

- Un unico owner de producto para una regla.
- Un unico contrato canonico para una entidad compartida.
- Una frontera tecnica mas estrecha para SQL, JSON, DOM o FFI.
- Una prueba mas cercana al modulo que realmente decide el comportamiento.
- Menos conocimiento operacional en un root update.

Con ese criterio, el mejor siguiente esfuerzo no es partir mas archivos por inercia. Es cerrar deuda concreta que todavia tiene evidencia en codigo:

| Deuda real | Evidencia actual | Accion optima | Por que no hacer mas |
| --- | --- | --- | --- |
| Sentinels de tasks sin nombres semanticos | Ejecutado en `persistence/tasks/queries.gleam`: `0`, `-1`, `""` y `"__unset__"` quedan como constantes privadas de frontera | Mantener `FieldUpdate` como API tipada y no exponer valores SQL fuera de persistencia | No crear un DSL de updates SQL hasta ver repeticion identica en mas modulos |
| Sentinels de task templates y card trees | Ejecutado en `task_templates_db.gleam` y `card trees_db.gleam`: los valores de update/create quedan nombrados | Mantener el mismo patron que cards/workflows sin mover valores al dominio | No extraer helper comun si la semantica no es exactamente igual |
| Sentinels del rules engine | Ejecutado en `services/rules_engine.gleam`: `no_task_type_filter_value`, `no_card_id_create_value` y `no_task_parent_card_id` nombran los `0` tecnicos | Mantenerlos privados dentro del motor mientras sean parametros de query/creacion | No moverlos a dominio ni crear helper generico de ids ausentes |
| Duplicados parciales de `Workflow` y `Rule` | Ejecutado: servidor usa `WorkflowRecord` y `RuleRecord`; `Workflow`/`Rule` quedan reservados a shared | Mantener records de servidor cuando el shape sea parcial o de persistencia | No forzar shared si el servidor contiene shape parcial |
| Admin root aun concentra routing general | Ejecutado: `features/admin/update.gleam` queda en 346 lineas y delega la familia members/search en `members_route.gleam`; `route_support.gleam` elimina copias exactas de auth en routes admin | Mantener `members_route.gleam` como route de area y no fusionar los updates puros de miembros | No crear dispatcher generico ni routes vacios por simetria |
| CRUD visual aun puede divergir | Helpers opcionales, merge de payload fields, botones CRUD comunes y submit de `ui/dialog` ya centralizados sobre `ui/button` | Revisar nuevas piezas solo si aparecen en tres o mas dialogos | No introducir componente CRUD universal ni atributos arbitrarios |

Esta tabla reemplaza una lectura por "cantidad de lineas". Un modulo de 400 lineas puede ser aceptable si solo coordina rutas; un helper de 20 lineas puede ser deuda si es un facade que no elimina decisiones duplicadas.

Lectura de la tabla:

- Prioridad 1: cambios de saneamiento con bajo riesgo. Sirven para validar el enfoque.
- Prioridad 2: cambios de modelo central. Dan mas valor, pero requieren tests de contrato.
- Prioridad 3: limpieza de ownership en cliente y contratos de API.
- Prioridad 4: reduccion de complejidad en orquestadores.
- Prioridad 5: mejoras utiles, pero menos urgentes o mas dependientes de contexto.

## Estado de ejecucion del informe

Este informe no es solo una lista teorica. Varias recomendaciones ya han sido contrastadas contra la base de codigo y sirven como evidencia del criterio:

| Punto | Estado | Evidencia de codigo | Garantia principal |
| --- | --- | --- | --- |
| `Card` duplicado en servidor | Ejecutado | `cards_db.gleam` devuelve `domain/card.Card` | Un solo contrato publico de card |
| `RuleTemplate` duplicado en servidor | Ejecutado | `rules_db.gleam` devuelve `domain/workflow.RuleTemplate` | Menos drift entre reglas del dominio y servidor |
| `Workflow`/`Rule` duplicados en servidor | Ejecutado | `workflows_db.gleam` expone `WorkflowRecord`; `rules_db.gleam` expone `RuleRecord` sin templates cargadas | Los nombres canonicos quedan reservados al dominio compartido |
| Sentinels SQL | Ejecutado parcialmente | Sentinels nombrados en persistencia de cards/workflows/tasks/task_templates/card trees | Los valores magicos quedan en frontera SQL |
| `Task` duplicado en mapper | Ejecutado | Mapper de tareas devuelve `domain/task.Task` | La entidad central usa el contrato canonico |
| `status`/`work_state` de task | Ejecutado | `presenters.task_json` deriva `status` y `work_state` desde `TaskState`; `presenters_test.gleam` cubre drift entre campos redundantes y estado canonico | Menos estados paralelos en la frontera HTTP |
| Active flags de workflows/rules | Ejecutado | `http/payload_fields.gleam` decodifica `active` de PATCH `0/1` a `Option(Bool)`; los handlers de workflows/rules ya no normalizan enteros | La convencion HTTP queda en Parse y el Process recibe tipos de dominio |
| Active flags cliente workflows/rules | Ejecutado | `api/payload_fields.gleam` codifica `active` de PATCH como `0/1`; `api/workflows.gleam` y `api/workflows/rules.gleam` ya no reconstruyen el `case active` | La misma convencion de transporte tiene un owner en cliente y otro en servidor |
| API tokens en cliente | Ejecutado | Contrato en `shared/src/domain/api_token.gleam`; estado UI en `client_state/admin/api_tokens.gleam` | Separacion entre contrato HTTP y estado de pantalla |
| API tokens/integration users servidor | Ejecutado | `IntegrationUser`, `ApiToken` y `ProjectGrant` viven en `shared/src/domain/api_token.gleam`; el record operativo de tokens se llama `ApiTokenRecord` | El contrato publico y el ADT de grant quedan compartidos; seguridad/verificacion sigue en servidor |
| Assignments en cliente | Ejecutado | `AssignmentsModel` y `AssignmentsAddContext` viven en `client_state/admin/assignments.gleam` | El owner real de la pantalla contiene su estado |
| Release-all de members | Ejecutado | `ReleaseAllTarget` vive en `client_state/admin/members.gleam` | El dialogo no contamina tipos globales |
| Drag de pool | Ejecutado | `DragState`, `PoolDragState` y `Rect` viven en `client_state/member/pool.gleam` | El estado de interaccion queda junto al modelo que lo guarda |
| Dialog modes admin | Ejecutado | Dialog modes viven en `client_state/admin/{cards,workflows,rules,task_templates,task_types}.gleam` | Cada modal CRUD queda junto al estado que lo guarda |
| Formularios/search/icon state admin | Ejecutado | `InviteLinkForm`, `ProjectDialogForm`, `OrgUsersSearchState` e `IconPreview` viven en `client_state/admin/{invites,projects,members,task_types}.gleam` | Los estados especificos de pantalla salen del cajon global |
| Aliases especificos en `client_state.gleam` | Ejecutado | El root ya no reexporta dialog modes, forms, drag state, assignments ni `rect_contains_point`; los callers usan owners reales | El root queda como shell de `Model`/`Msg` y aliases transversales |
| Capabilities update | Ejecutado | `features/capabilities/update.gleam` delega en `crud_update.gleam` y `assignments_update.gleam`; los contratos compartidos viven en `features/capabilities/types.gleam` y el dispatcher ya no reexporta aliases ni wrappers de exito | CRUD y asignaciones tienen owners separados sin dispatcher generico ni facade de tipos |
| Task create update | Ejecutado | `features/tasks/create_update.gleam` contiene contrato, validacion, efectos y routing por `try_update`; los handlers de creacion son privados | El flujo de crear tarea sale del orquestador central, reutiliza `create_state`/`create_form` y evita API publica accidental |
| Task notes update | Ejecutado | `features/tasks/notes_update.gleam` contiene contrato, auth policy, efectos y routing por `try_update`; los handlers de notas son privados | El flujo de notas sale del orquestador central, reutiliza `note_state`/`note_form` y evita API publica accidental |
| Task mutation update | Ejecutado | `features/tasks/mutation_update.gleam` contiene contrato, efectos, claim/release/complete, optimistic update y rollback; los handlers de click/success/error son privados | La mutacion de tarea sale del orquestador central, reutiliza `mutation_state` y mantiene publica solo la integracion de drag y helpers puros testeados |
| Task detail update | Ejecutado | `features/tasks/detail_update.gleam` contiene contrato, apertura/cierre, tabs, metricas y edicion; los tests entran por `try_update` y los handlers internos ya no son publicos | El detalle de tarea sale del orquestador central, reutiliza `detail_state`/`detail_edit_form` y evita API publica accidental |
| Admin API tokens route | Ejecutado | `features/admin/api_tokens_route.gleam` contiene contexto, auth y apply del submodelo de tokens | `features/admin/update.gleam` deja de aplicar directamente ese area |
| Admin assignments route | Ejecutado | `features/admin/assignments_route.gleam` contiene contexto, auth timing, root policy y apply del submodelo de assignments | `features/admin/update.gleam` deja de mezclar assignments con el root admin |
| Admin capabilities route | Ejecutado | `features/admin/capabilities_route.gleam` contiene selected project, textos, feedback, auth y apply del submodelo de capabilities | `features/admin/update.gleam` deja de adaptar directamente capabilities |
| Admin projects route | Ejecutado | `features/admin/projects_route.gleam` contiene contexto, feedback, auth y sincronizacion explicita de `core.projects`/`selected_project_id` | `features/admin/update.gleam` deja de aplicar directamente projects |
| Admin invites route | Ejecutado | `features/admin/invites_route.gleam` contiene contexto, feedback, auth y apply del submodelo de invites | `features/admin/update.gleam` deja de aplicar directamente invites |
| Admin task types route | Ejecutado | `features/admin/task_types_route.gleam` contiene contexto, feedback, auth, apply del submodelo y refresh policy | `features/admin/update.gleam` deja de aplicar directamente task types |
| Admin org settings route | Ejecutado | `features/admin/org_settings_route.gleam` contiene contexto, feedback, auth, apply de members y politicas root de assignments/current user | `features/admin/update.gleam` deja de aplicar directamente org settings |
| Admin members route | Ejecutado | `features/admin/members_route.gleam` agrupa member list/add/remove/release-all/role/search; `admin_members_route_test.gleam` cubre exito, auth-before y mensaje ignorado | El root admin deja de conocer el orden interno de members/search |
| Admin route support | Ejecutado | `features/admin/route_support.gleam` centraliza `apply_auth_check_before` y `apply_auth_check_after`; los routes ya no definen copias privadas de esos helpers | La mecanica 401 queda en un unico helper sin imponer ADT global de auth |
| Admin scoped remote list | Ejecutado | `features/admin/scoped_remote_list.gleam` centraliza prepend por scope org/proyecto y replace/remove por id sobre `Remote(List(_))`; `workflows.gleam` y `task_templates.gleam` ya no mantienen el bloque privado duplicado | Reduce una decision duplicada concreta sin introducir motor CRUD admin |
| Pool route support | Ejecutado | `features/pool/route_support.gleam` centraliza `apply_auth_check_before` y `apply_auth_check_after`; `pool/update`, `pool/admin_route` y `pool/refresh_update` ya no importan `auth_helpers` directamente | La mecanica 401 queda compartida sin mover las `AuthPolicy` locales |
| Pool people update | Ejecutado | `features/people/update.gleam` expone solo `try_update`; los handlers de roster y expansion de fila son privados y los tests entran por mensajes `MemberPeople*` | La ruta de people mantiene un unico entrypoint igual que otros subflujos cerrados, sin crear un route generico |
| Pool metrics update | Ejecutado | `features/metrics/update.gleam` expone solo `AuthPolicy`, `Update` y `try_update`; los handlers de member/admin metrics son privados y los tests entran por mensajes `MemberMetrics*`/`AdminMetrics*` | Las metricas mantienen un contrato pequeno para el route y evitan que tests congelen handlers internos |
| Now working update | Ejecutado | `features/now_working/update.gleam` expone solo `Model`, `Context`, `AuthPolicy`, `Update` y `try_update`; start/pause/tick/sessions quedan privados | El flujo de timer y sesiones mantiene un unico entrypoint por mensajes sin mover logica de efectos a un dispatcher generico |
| Pool card detail update | Ejecutado | `features/pool/card_detail_update.gleam` expone solo `Model`, `Context` y `try_update`; apertura/cierre y respuestas de metricas son privadas y los tests entran por `OpenCardDetail`/`CloseCardDetail`/`CardMetricsFetched` | El detalle de card conserva un adapter effectful pequeno sin exponer pasos internos como contrato |
| Pool position update | Ejecutado | `features/pool/position_update.gleam` expone solo `Context`, `AuthPolicy`, `Update` y `try_update`; fetch/open/close/change/submit/save quedan privados y los tests entran por `MemberPosition*` | El adapter effectful de posiciones conserva un unico entrypoint sin convertir `position_edit.gleam` en API publica de route |
| Pool skills update | Ejecutado | `features/skills/update.gleam` expone solo `Context`, `AuthPolicy`, `Update` y `try_update`; fetch/toggle/save quedan privados y los tests entran por `Member*Capability*` | La seleccion de capacidades mantiene un contrato pequeno para `skills_route` y evita fijar handlers internos en tests |
| Pool task route | Ejecutado | `features/pool/task_route.gleam` agrupa dependencias, notas, creacion, mutacion y detalle de tarea; `pool/update.gleam` delega en `task_route.try_update`; `pool_task_route_test.gleam` cubre ruta positiva, auth-before y mensaje ignorado | El root de pool deja de conocer el orden interno de los subflujos de tarea y mantiene un fallback exhaustivo |
| Pool metrics route | Ejecutado | `features/pool/metrics_route.gleam` contiene auth policy y apply de `member.metrics`/`admin.metrics` para `features/metrics/update.gleam`; `pool/update.gleam` delega en el route y deja de importar el workflow de metricas o los submodelos de metricas | El root de pool deja de conocer apply dual member/admin de metricas sin mover la logica pura de metricas |
| Pool rule metrics route | Ejecutado | `features/pool/rule_metrics_route.gleam` contiene context callbacks, auth policy y apply de `admin.metrics` para `features/admin/rule_metrics.gleam`; `pool/update.gleam` delega en el route y deja de importar el workflow admin de metricas de reglas | El root de pool deja de conocer detalles operativos de metricas de reglas sin mover la logica de producto |
| Pool positions route | Ejecutado | `features/pool/positions_route.gleam` contiene contexto i18n/toasts, auth policy y apply de `member.positions` para `position_update.gleam`; `pool/update.gleam` delega en el route y deja de importar `position_update` o el submodelo de posiciones | El root de pool deja de conocer edicion, guardado y refetch de posiciones sin mover la logica pura de posiciones |
| Pool skills route | Ejecutado | `features/pool/skills_route.gleam` contiene contexto i18n/toasts, auth policy y apply de `member.skills` para `features/skills/update.gleam`; `pool/update.gleam` delega en el route y deja de importar el workflow de skills o el submodelo de skills | El root de pool deja de conocer seleccion, guardado y refetch de skills sin mover la logica pura de skills |
| Card Tree filters update | Ejecutado parcialmente | `features/card trees/filters.gleam` contiene ahora los filtros de lista y las transiciones de estado de filtros; `card trees_update.gleam` delega toggles/search; `card trees_filters_test.gleam` cubre las transiciones directas | Se empieza a reducir `card trees/update.gleam` por owner existente sin mezclar summary/card expansion con filtros |
| Card Tree selection update | Ejecutado parcialmente | `features/card trees/selection.gleam` contiene ahora la transicion `select_card tree`; `card trees_update.gleam` delega `MemberCard TreeDetailsClicked`; `card trees_selection_test.gleam` cubre seleccion y limpieza de flags de dialogo | La seleccion queda junto a `selected_progress` sin crear un route nuevo ni mezclar efectos |
| Card Tree refresh update | Ejecutado | `features/card trees/refresh.gleam` contiene el routing de fetch ok/error y las derivaciones privadas de refresh; `card trees_update.gleam` ya no aplica fetch ok/error directamente; `card tree_refresh_test.gleam` cubre el comportamiento por `try_update` y los helpers publicos usados por el root | El apply del refresh multi-proyecto queda junto a las derivaciones de refresh sin crear una capa nueva; la API publica queda en `try_update`, `mark_pending` y `loading_unless_loaded` |
| Card Tree dialog update | Ejecutado | `features/card trees/dialog_update.gleam` contiene apertura/cierre, cambios de campos, submits y respuestas de create/edit/delete/activate; `pool/card trees_route.gleam` compone primero este owner y luego `card trees/update.gleam`; `pool/shortcut_update.gleam` usa el cierre de dialogo para Escape; `card trees_update_test.gleam` prueba create/edit/delete por `try_update` | Los efectos API/focus y helpers de dialogo salen del workflow general, y la superficie publica queda reducida a `try_update` + cierre por Escape |
| Card Tree movement update | Ejecutado parcialmente | `features/card trees/movement_update.gleam` contiene drag start/end, drop, movimiento por click de cards/tasks, validacion de card trees `Ready`, lookup de card/task de origen, respuestas ok/error y `Context` propio para callbacks de card/task moved; su superficie publica queda en `Context` y `try_update`; `pool/card trees_route.gleam` lo compone despues de dialogos y antes del workflow general; `card trees_update_test.gleam` apunta los tests directos de movimiento al modulo nuevo | Las APIs de cards/tasks, sus callbacks y las reglas de movimiento salen del shell general sin crear un dispatcher generico |
| Card Tree expansion update | Ejecutado parcialmente | `features/card trees/expansion.gleam` contiene el toggle de summary y el toggle de cards expandidas; `card trees/update.gleam` delega `MemberCard TreeSummaryToggled` y `MemberCard TreeCardToggled`; `card trees_expansion_test.gleam` cubre expand/collapse y preservacion de otras cards | El estado visual local sale del shell general sin mezclarse con filtros ni crear un route root-aware innecesario |
| Card Tree create update | Ejecutado parcialmente | `features/card trees/create_update.gleam` contiene quick-create de task y card desde card tree; `pool/card trees_route.gleam` lo compone despues de movimiento y antes del workflow residual; `card trees_create_update_test.gleam` cubre apertura de task dialog, root policy de card dialog e ignorado de mensajes ajenos | `card trees/update.gleam` deja de importar `dialog_mode` y de conocer campos `member_create_*`; la politica root-aware sigue aplicada en `pool/card trees_route.gleam` |
| Project projections servidor | Ejecutado | `ProjectRecord`, `ProjectMemberRecord`, `StoredProject` y `StoredProjectMember` sustituyen los nombres internos ambiguos; el presenter publico no expone `org_id` ni `project_id` internos | Solo el dominio compartido conserva los nombres canonicos `Project`/`ProjectMember` |
| CRUD UI helpers | Ejecutado parcialmente | `crud_dialog_base.gleam` centraliza atributos opcionales de campos (`aria-label`, `placeholder`, `autofocus`), merge de payload fields y botones comunes mediante `ui/button`; los CRUD dialogs eliminan helpers locales duplicados | Reduce duplicacion concreta sin introducir motor CRUD |
| Dialog submit helpers | Ejecutado | `ui/dialog.gleam` distingue submit de formulario externo y accion por mensaje mediante `submit_button_with_locale_form` y `submit_button_with_locale_click`; ambos reutilizan `ui/button`; `ui/confirm_dialog.gleam` recibe `button.Intent` tipado y deriva `btn-loading` internamente | Los dialogs dejan de construir botones submit raw con atributos arbitrarios o deducir intencion desde strings CSS |
| Pool dialog submits | Ejecutado parcialmente | `features/pool/create_dialog.gleam`, `position_edit_dialog.gleam` y `task_dependencies.gleam` reutilizan los helpers tipados de `ui/dialog`; el retry de task types en `create_dialog.gleam` y las acciones de `task_detail_footer.gleam` pasan por `ui/button`, conservando `task-detail-save` como clase de compatibilidad | Se reduce duplicacion DOM sin perder comportamiento propio del detalle de tarea |
| UI shared buttons | Ejecutado parcialmente | `empty_state.gleam`, `card_section_header.gleam`, `copyable_input.gleam`, el dialogo de activacion de card trees, confirm dialogs, close buttons de modal, el retry de task type en pool, acciones simples de dialogs de capabilities, cabecera/dismiss de API tokens, delete de proyectos, drill de metricas, crear tarea desde My Bar, trigger de forgot password, acciones simples de members, claim primario de task card, acciones de perfil del right panel y botones de drawer del shell movil delegan en `ui/button`, `ui/action_buttons`, `ui/task_actions` o `ui/modal_close_button`; `ui/button.with_autofocus` conserva foco inicial sin volver a botones raw; `ui/button.with_attribute` cubre atributos ARIA puntuales sin escapar a `button` raw; `icon_picker.gleam` queda como excepcion por ser control de seleccion con estado propio | El contrato de botones semanticos se aplica en componentes reutilizables sin forzar controles que no son acciones simples |
| Capabilities dialog actions | Ejecutado | `features/admin/capabilities_view.gleam` ya no importa `button`; delete y save members usan `ui/button` con intent/scope semanticos y tests de vista | Las acciones de dialog dejan de reconstruir `btn-danger`/`btn-primary` manualmente |
| API token view actions | Ejecutado | `features/admin/api_tokens_view.gleam` ya no importa `button`; create token y dismiss del secreto usan `ui/button` con scopes global/entity y tests de vista | La pantalla conserva la separacion contrato/estado ya ejecutada y deja de reconstruir acciones simples en DOM raw |
| Project dialog actions | Ejecutado | `features/projects/view.gleam` ya no importa `button`; el submit destructivo del dialogo de borrado usa `ui/button` con intent `Danger`, disabled y copy de loading | La accion irreversible se expresa con el mismo contrato semantico que otros deletes |
| Assignments inline actions | Ejecutado | `features/assignments/components/{project_card,user_card}.gleam` usan `ui/button` para add, confirm remove, cancel y submit inline; `ui/button.with_accessible_label` conserva etiquetas contextuales | Las dos tarjetas simetricas dejan de reconstruir clases de botones y mantienen accesibilidad |
| My Bar card task action | Ejecutado | `features/my_bar/view.gleam` ya no importa `button` ni `event` para crear tarea desde una tarjeta; reutiliza `ui/action_buttons` con clase local de compatibilidad y test de vista | La accion usa el mismo helper de icon action que el resto de acciones de entidad sin perder la clase propia del layout |
| Metrics/detail feature actions | Ejecutado | `features/admin/rule_metrics_view.gleam` usa `ui/button` para ver detalle y paginar ejecuciones, y `ui/modal_close_button` para cerrar el drilldown; `features/metrics/view.gleam` usa `ui/button` para drill por proyecto; `features/tasks/detail_editor.gleam` usa `ui/button` para iniciar edicion | Acciones textuales simples y cierre de modal dejan de reconstruir clases raw y conservan labels accesibles localizados |
| Auth actions | Ejecutado | `features/auth/view.gleam` centraliza login, forgot password submit, accept invite y reset password en un helper privado sobre `ui/button.submit`; el trigger de forgot password usa `ui/button.text` con intent `Ghost` y clase local | Los formularios de auth dejan de repetir `type="submit"`, disabled y loading class en cada vista, y la accion secundaria ya no reconstruye un button raw |
| Admin member view actions | Ejecutado | `features/admin/views/members.gleam` reutiliza `ui/button` para `Select`/`Selected`, `Add member`/`Working`, confirmaciones remove/release mediante `confirm_dialog` tipado y save de capabilities; el modulo ya no importa `html.button` | La vista de miembros deja de reconstruir `btn-primary`/`btn-secondary`/`btn-danger`/`btn-loading` manualmente para acciones simples |
| Workflow rules actions | Ejecutado | `features/admin/workflow_rules_view.gleam` usa `ui/button` para volver y adjuntar plantilla; `ui/button.with_stop_propagation` cubre acciones dentro de filas clicables | Se elimina el legacy `btn btn-sm btn-primary` sin perder la proteccion contra bubbling |
| Org settings delete action | Ejecutado | `features/admin/org_settings_view.gleam` usa `action_buttons.delete_button_with_disabled_and_testid`, construido sobre `ui/button` | La pantalla deja de pasar una clase completa para expresar un delete icon semantico |
| Updates grandes restantes | Parcial | Admin queda en 346 lineas y conserva dispatch, routes de area y fallback exhaustivo | Nuevos cortes solo si el barrido demuestra responsabilidad mezclada |

Lectura del estado:

- "Ejecutado" significa que la responsabilidad principal ya se movio al owner correcto.
- "Ejecutado parcialmente" significa que el patron se aplico donde habia bajo riesgo, pero no conviene afirmar cobertura total sin otro barrido especifico.
- "Pendiente" significa que el valor de producto/codigo sigue existiendo, pero requiere otra iteracion con tests especificos.

El estado actual de `client_state/types.gleam` ya es una restriccion fuerte: solo debe contener tipos transversales reales. Si vuelve a recibir un formulario, target de dialogo, preview, modelo de pantalla o estado de interaccion, se estaria reintroduciendo la mezcla de responsabilidades que este informe busca eliminar.

## Evidencia actual del barrido

El informe queda reforzado con estas senales concretas del codigo actual:

- `client_state/types.gleam` ha quedado reducido a 14 lineas y `client_state.gleam` a unas 399 lineas. El root ya no reexporta tipos especificos de pantalla ni helpers de geometria que pertenecen a owners concretos.
- `features/capabilities/update.gleam` queda en 288 lineas y delega en `crud_update.gleam` y `assignments_update.gleam`; es el patron correcto de dispatcher fino mas owners reales. Los contratos compartidos se importan desde `features/capabilities/types.gleam`, no desde aliases del dispatcher.
- `features/tasks/create_update.gleam`, `features/tasks/notes_update.gleam`, `features/tasks/mutation_update.gleam` y `features/tasks/detail_update.gleam` ya existen como owners de flujo. El modulo obsoleto `features/tasks/update.gleam` se elimino.
- `features/admin/update.gleam` ya bajo a 346 lineas tras extraer `api_tokens_route`, `assignments_route`, `capabilities_route`, `projects_route`, `invites_route`, `task_types_route`, `org_settings_route` y `members_route`. Los siguientes cortes admin deben justificarse por barrido concreto, no por inercia.
- `features/admin/members_route.gleam` agrupa list/add/remove/release-all/role/search y evita que el root conozca el orden interno de la familia members/search.
- `features/admin/route_support.gleam` centraliza `apply_auth_check_before` y `apply_auth_check_after`; los routes admin conservan `auth_error` local porque traduce ADTs propias de cada feature.
- `apps/server/src/scrumbringer_server/http/tasks/presenters.gleam` ya no serializa `status`/`work_state` desde campos redundantes del record. Los deriva desde `TaskState`, igual que hace el mapper al reconstruir `domain/task.Task`.
- `apps/server/test/unit/presenters_test.gleam` incluye un caso con `TaskState.Claimed(... Ongoing)` y campos `status/work_state` obsoletos para verificar que JSON responde `"claimed"` y `"ongoing"` desde el ADT canonico.
- `shared/src/domain/field_update.gleam` ya existe como modelo tipado para updates parciales, pero el SQL generado aun contiene sentinels. La lectura correcta es "frontera tecnica contenida", no "sentinels completamente eliminados".
- `http/tasks/payloads.gleam` normaliza `card_id` y `parent_card_id` no positivos en create/update antes de construir mensajes de workflow. `services/workflows/handlers.gleam` ya no necesita interpretar `Some(0)` como ausencia.
- `http/workflows/payloads.gleam` y `http/rules/payloads.gleam` decodifican el `active` entero de PATCH como `Option(Bool)` mediante `http/payload_fields.gleam`; los handlers ya no contienen `normalize_active`.
- `services/rules_engine.gleam` nombra los `0` tecnicos usados para filtro de task type, card id de creacion y card tree ausente. Siguen siendo privados del motor y no suben a dominio.
- `projects_db.Project`/`ProjectMember` y `store_state.Project`/`ProjectMember` ya no existen como tipos publicos del servidor. Los records internos se llaman `ProjectRecord`, `ProjectMemberRecord`, `StoredProject` y `StoredProjectMember`, dejando `Project` y `ProjectMember` como nombres canonicos del dominio compartido. El presenter de proyectos ya no filtra `org_id` ni `project_id` a la respuesta publica.
- `crud_dialog_base.gleam` ya contiene helpers pequenos para atributos opcionales de campos (`with_optional_aria_label`, `with_optional_placeholder`, `with_autofocus_when`), para payload fields opcionales (`prepend_fields`) y para botones CRUD comunes delegando en `ui/button`. `card_crud_dialog`, `workflow_crud_dialog`, `task_template_crud_dialog`, `rule_crud_dialog` y `task_type_crud_dialog` ya no mantienen copias locales de esos helpers.
- `ui/dialog.gleam` ya no expone un submit con atributos arbitrarios. Distingue submit de formulario externo (`submit_button_with_locale_form`) y accion por mensaje (`submit_button_with_locale_click`), ambos reutilizando `ui/button`.
- `ui/confirm_dialog.gleam` ya no recibe `confirm_class: String` ni deduce la intencion buscando `"danger"` en CSS. Recibe `button.Intent`, deriva `btn-loading` internamente y queda cubierto por `ui_confirm_dialog_test.gleam`.
- `features/pool/create_dialog.gleam`, `features/pool/position_edit_dialog.gleam` y `features/pool/task_dependencies.gleam` ya no montan su submit principal a mano. `features/pool/task_detail_footer.gleam` tambien usa `ui/button` para acciones de lectura/edicion y conserva `task-detail-save` solo como clase de compatibilidad.
- `features/pool/create_dialog.gleam` tampoco monta ya el retry de carga de task types con `button` raw. La accion pasa por `ui/button.text` y `pool_create_dialog_test.gleam` verifica `btn-secondary` y `btn-entity-action`.
- `features/pool/task_card.gleam` ya no monta a mano la accion primaria de claim con `button`, `icons.HandRaised` y una clase raw completa. La accion pasa por `ui/task_actions.claim_icon`, conserva `task-card-primary-action` como clase de compatibilidad y `pool_task_card_test.gleam` protege `btn-entity-action`, `btn-icon` y que no reaparezca `class="task-card-primary-action"`. El drag handle queda fuera del refactor porque es una superficie gestual con decoder de coordenadas, no una accion simple.
- `features/admin/capabilities_view.gleam` ya no importa `button` desde Lustre. Las acciones simples de borrar capability y guardar miembros pasan por `ui/button.text`, conservan disabled/loading copy y quedan cubiertas por `capabilities_view_test.gleam`.
- `features/admin/api_tokens_view.gleam` ya no importa `button` desde Lustre. La accion primaria de crear token y el dismiss del secreto usan `ui/button`, con tests que protegen intent, scope y ausencia de clases raw completas.
- `features/projects/view.gleam` ya no importa `button` desde Lustre. El dialogo de borrado de proyecto usa `ui/button.text` con `Danger`, `EntityAction` y `with_disabled`, y queda cubierto por `projects_view_test.gleam`.
- `features/metrics/view.gleam` ya no importa `button` ni `event` para el drill por proyecto. La accion usa `ui/button.text` con tamano `ExtraSmall`, y `metrics_view_test.gleam` protege que no vuelva el `class="btn-xs"` raw.
- `features/my_bar/view.gleam` ya no importa `button` ni `event` para crear tarea dentro de una tarjeta. La accion pasa por `ui/action_buttons.add_icon_button_with_size_and_testid`, conserva `my-bar-add-task` como clase de compatibilidad y `my_bar_task_row_view_test.gleam` protege que no vuelva el `class="btn-icon btn-sm my-bar-add-task"` raw.
- `ui/button.gleam` ya diferencia el comportamiento nativo con `ButtonType` (`ClickButton`/`SubmitButton`), permite asociar un formulario con `with_form`, y acumula clases de compatibilidad sin sobrescribir las clases semanticas del sistema de botones.
- `ui/empty_state.gleam`, `ui/card_section_header.gleam` y `ui/copyable_input.gleam` ya no renderizan botones raw para acciones simples. `card_section_header.gleam` elimina el default legacy `"btn btn-sm btn-primary"` para no duplicar las clases generadas por `ui/button`.
- `ui/button.gleam` permite `with_accessible_label` para casos donde el texto visible debe ser corto pero `title`/`aria-label` necesitan contexto. Esto permite que las confirmaciones inline de assignments conserven `Remove: <entidad>` sin montar botones raw.
- `features/assignments/components/project_card.gleam` y `user_card.gleam` ya no construyen a mano los botones inline `btn-sm btn-secondary`, `btn-xs btn-danger`, `btn-xs btn-secondary` y `btn-xs btn-primary`; conservan solo los toggles de expansion como raw porque necesitan `aria-expanded` y contenido custom.
- `features/admin/rule_metrics_view.gleam` ya no monta a mano los `btn-xs btn-secondary` de `View Details` ni de paginacion. La paginacion usa `ui/button.with_accessible_label` con textos i18n (`FirstPage`, `PreviousPage`, `NextPage`, `LastPage`) para que los simbolos visibles no sean el unico nombre accesible. El cierre del drilldown reutiliza `ui/modal_close_button.view_with_label_and_class`, conservando `btn-close` por compatibilidad CSS.
- `features/tasks/detail_editor.gleam` ya no reconstruye `btn btn-sm btn-secondary task-detail-edit-toggle`; el toggle de entrar en edicion conserva la clase de compatibilidad y delega intent/scope/tamano en `ui/button`. Los botones de prioridad siguen raw porque son controles segmentados con `aria-pressed`, no acciones textuales simples.
- `features/auth/view.gleam` ya no define submits raw en cada formulario. Login, forgot password, accept invite y reset password comparten `submit_button`, que usa `ui/button.submit`, aplica disabled y conserva `btn-loading` como clase de compatibilidad encapsulada. El trigger de forgot password tambien pasa por `ui/button.text`, conserva `auth-forgot` y queda cubierto por `auth_view_error_test.gleam`.
- `features/admin/views/members.gleam` ya no importa `button` desde Lustre. `Select`/`Selected`, `Add member`/`Working`, confirmaciones remove/release y save de capabilities pasan por `ui/button` o `confirm_dialog` tipado, y `admin_member_add_flow_test.gleam` protege intent, scope, loading y ausencia de clases legacy completas.
- `features/layout/right_panel.gleam` ya no monta a mano las acciones de perfil para abrir preferencias, cerrar el popup y hacer logout. Comparten `profile_icon_button_config` sobre `ui/button.icon`, conservan `btn-icon-only`/`btn-logout` como clases de compatibilidad, y `ui/button.with_attribute` permite `aria-haspopup`/`aria-expanded` sin reconstruir el DOM raw. `right_panel_tasks_test.gleam` protege labels, test ids, clases semanticas y ausencia de `class="btn-icon-only"`/`class="btn-icon-only btn-logout"` raw.
- `features/layout/member_mobile_shell.gleam` ya no monta a mano los botones del topbar movil para abrir navegacion y actividad. Ambos pasan por `ui/button.icon`, conservan `mobile-menu-btn`/`mobile-user-btn` como clases y test ids de compatibilidad, y usan `ui/button.with_attribute` para `aria-expanded`. `ui/icons.gleam` incorpora `Menu` como `NavIcon` tipado para evitar volver a `view_heroicon_inline("bars-3", ...)`. `member_mobile_shell_test.gleam` protege labels, expanded state, clases semanticas y ausencia de `heroicon-inline` en esos controles.
- `ui/button.gleam` permite `with_stop_propagation` para botones que viven dentro de contenedores clicables. Esta opcion se usa en `features/admin/workflow_rules_view.gleam` para `Attach template`, sustituyendo el antiguo `event.on_click(...) |> event.stop_propagation` raw.
- `features/admin/workflow_rules_view.gleam` ya no contiene el back button raw ni `btn btn-sm btn-primary` en la expansion de templates; ambas acciones pasan por `ui/button`.
- `features/admin/org_settings_view.gleam` ya no llama a `task_icon_button_with_class` con `"btn-icon btn-xs btn-danger-icon"`; usa un helper semantico de delete con disabled/testid en `action_buttons.gleam`.
- El barrido de tipos publicos confirma que `Workflow`, `Rule`, `ApiToken` e `IntegrationUser` publicos solo quedan en `shared/src/domain`. En servidor, los shapes parciales u operativos se llaman `WorkflowRecord`, `RuleRecord` y `ApiTokenRecord`.
- `ProjectGrant` ya vive junto al contrato publico de API tokens en `shared/src/domain/api_token.gleam`; `VerifiedToken`, bearer, hash y auditoria siguen siendo responsabilidad exclusiva del servidor.
- El barrido de sentinels confirma que cards, workflows, tasks, task templates y card trees ya tienen valores de frontera nombrados en constantes privadas. El SQL generado puede seguir conteniendo esos valores porque es la frontera tecnica.

Estas senales confirman que el plan debe pasar de consolidar tipos globales a reducir orquestadores grandes y evitar que los nuevos subflujos vuelvan a depender de modulos antiguos.

## Mapa de deuda restante validada

Este mapa separa deuda confirmada de deuda descartada. Su objetivo es evitar dos errores: declarar limpio algo que solo compila, o seguir refactorizando areas que ya tienen owner suficiente.

| Area | Estado reforzado | Siguiente prueba antes de tocar codigo | Cambio permitido |
| --- | --- | --- | --- |
| `Task` dominio/mapper/presenter | Cerrado en contrato principal y frontera HTTP | `rg "pub type Task \\{" apps/server/src/scrumbringer_server` debe quedar vacio; `presenters.task_json` debe derivar lifecycle desde `TaskState` | Solo ajustes si aparece otro presenter, mapper o handler calculando lifecycle paralelo |
| `Task` SQL update boundary | Ejecutado en frontera Gleam | Revisar `persistence/tasks/queries.gleam` y `sql/tasks_update.sql` juntos cuando cambie el contrato | Mantener constantes privadas y documentar equivalencia SQL |
| `Project`/`ProjectMember` | Cerrado en frontera publica | Barrer que `project_presenters.project/member` no emitan campos internos | Mantener `ProjectRecord`/`ProjectMemberRecord` para autorizacion y persistencia |
| `Workflow`/`Rule` | Ejecutado como records internos | Barrer que `pub type Workflow`/`Rule` no reaparezcan en servidor | Mantener `WorkflowRecord`/`RuleRecord` mientras el servidor necesite shape parcial o `project_id` no opcional |
| API tokens/integration users | Ejecutado en frontera publica y ADT de grant | `rg "pub type (ApiToken|IntegrationUser|ProjectGrant) \\{" apps/server/src/scrumbringer_server shared/src` | Mantener `ApiTokenRecord`, `VerifiedToken` y seguridad en servidor; shared contiene contrato publico y `ProjectGrant` |
| `client_state/types.gleam`/`client_state.gleam` | Cerrado bajo vigilancia | Barrer nuevos tipos especificos de pantalla y reexports de compatibilidad | No anadir estado de feature ni aliases especificos al root |
| Admin routes | Cerrado para cortes ejecutados; members/search ya tienen route de area | Buscar helpers reales `*_context`, `apply_*`, `*_auth_error` en root y en adapters hermanos | Extraer solo el siguiente owner que reduzca root de verdad |
| CRUD dialogs | Parcial correcto | Buscar repeticion en tres o mas dialogos | Helpers concretos y testeados en `crud_dialog_base`; acciones comunes y submits compartidos deben pasar por `ui/button` |

Regla de salida: si un punto no tiene una prueba o barrido antes de tocar codigo, no debe ejecutarse en la siguiente iteracion. La limpieza debe seguir siendo guiada por evidencia.

## Refuerzo 2026-06-15: corte admin members/search ejecutado

El nuevo barrido confirmo que no habia que seguir extrayendo routes admin por simetria. Los routes grandes ya ejecutados (`projects`, `invites`, `capabilities`, `assignments`, `api_tokens`, `task_types`, `org_settings`) tenian owner claro. La deuda con evidencia real era mas especifica: la familia de miembros y busqueda de usuarios de organizacion.

Evidencia observada:

| Senal | Resultado | Lectura |
| --- | --- | --- |
| `features/admin/update.gleam` | 346 lineas; delega `members_route.try_update` y ya no importa `member_*_update`/`search_update` | El root deja de conocer el orden interno de la familia members/search |
| `member_add_update.gleam` y `member_remove_update.gleam` | 86 lineas cada uno, estructura casi identica de context, feedback, error feedback, refresh y auth | Hay duplicacion semantica, no solo visual |
| `members_route.gleam` | Agrupa list/add/remove/release-all/role/search como route de area | La familia queda en un unico owner de orquestacion |
| `member_root.gleam` | Centraliza `set_members`, `apply_members_result` y auth check para miembros | Es la base correcta; no hace falta inventar un framework |
| `route_support.gleam` | Centraliza `apply_auth_check_before` y `apply_auth_check_after` | La mecanica 401 se comparte sin mover las `AuthPolicy` locales |

Solucion ejecutada:

1. Se creo `features/admin/members_route.gleam` como route de area.
2. El root admin delega en ese route y deja de importar `member_list_update`, `member_add_update`, `member_remove_update`, `member_release_all_update`, `member_role_update` y `search_update`.
3. Los updates de negocio existentes (`member_add.gleam`, `member_remove.gleam`, `member_role.gleam`, etc.) se mantienen separados.
4. Se creo `features/admin/route_support.gleam` porque sustituye mas de tres copias equivalentes de auth en routes admin.
5. Se anadio `admin_members_route_test.gleam` para exito, auth-before y mensaje ignorado.

Por que esta es mejor que seguir el patron anterior:

- Reduce el conocimiento del root admin: `update.gleam` pasa de seis entradas de members/search a una unica entrada de area.
- Respeta la frontera de producto: miembros y busqueda de usuarios son una familia funcional de administracion, no seis features independientes para el usuario.
- Reutiliza `member_root.gleam` en vez de crear un dispatcher generico.
- Mantiene el comportamiento testeable por subflujo; no obliga a reescribir los updates puros existentes.
- Ataca duplicacion exacta de auth/apply/context donde ya se ha visto, no duplicacion estetica.

Lo que no debe hacerse:

- No crear una lista generica de handlers con funciones homogeneizadas solo para reducir la cadena de `case`.
- No fusionar `member_add.gleam`, `member_remove.gleam`, `member_role.gleam` y `search.gleam` en un unico modulo grande; esos modulos son owners de comportamiento distintos.
- No convertir todas las `AuthPolicy` locales en un ADT global. Cada feature puede mantener su ADT si expresa una politica propia; el soporte comun debe aceptar `Option(ApiError)`.
- No mover copy localizado a un modulo global de textos para "secar" parametros: el contexto localizado pertenece al adapter que conecta root y feature.

Definition of Done especifica para este corte:

| Garantia | Criterio |
| --- | --- |
| Root mas fino | Cumplido: el barrido `rg "member_(list|add|remove|release_all|role)_update|search_update|update_without_member_|update_without_org_users_search" features/admin/update.gleam` queda vacio |
| Menos cadena manual | Cumplido: solo queda `update_without_members` como frontera hacia otros routes |
| Soporte comun real | Cumplido: `route_support.gleam` sustituye copias privadas de `apply_auth_check_before/after` en routes admin |
| Tests cercanos | Cumplido: `admin_members_route_test.gleam` cubre exito, auth-before y mensaje ignorado |
| Sin sobreingenieria | No aparece un dispatcher generico para todos los admin routes ni un ADT global de auth |

Este corte tenia mejor relacion valor/complejidad/riesgo que seguir limpiando UI: valor medio-alto, complejidad media, riesgo bajo-medio al mantenerse como agregacion de area. Tambien era mejor que mezclar en la misma iteracion una deuda de `Task`, porque la entidad central requiere cambios pequenos, aislados y con pruebas cercanas.

## Refuerzo 2026-06-15: frontera HTTP de `TaskState` cerrada

El nuevo barrido sobre servidor mostro que el mapper de tareas ya hacia lo correcto: reconstruia `domain/task.Task` desde la DB y calculaba `status` y `work_state` a partir de `TaskState`. La deuda restante estaba en el presenter: aunque recibia la entidad canonica, todavia podia serializar `status` y `work_state` desde campos redundantes del record.

Solucion ejecutada:

1. `http/tasks/presenters.gleam` conserva `TaskState` como fuente de verdad para lifecycle.
2. `task_json` deriva `status` con `task_state.to_status(state)`.
3. `task_json` deriva `work_state` con `task_state.to_work_state(state)`.
4. Los campos redundantes `Task.status` y `Task.work_state` quedan ignorados en el presenter.
5. `unit/presenters_test.gleam` anade un test de regresion con un `Task` deliberadamente inconsistente: `TaskState.Claimed(... Ongoing)` junto a campos obsoletos `Available`/`WorkAvailable`. La respuesta JSON esperada sale del ADT: `status = "claimed"` y `work_state = "ongoing"`.

Por que esta es la mejor solucion ahora:

- Refuerza la entidad central del producto sin cambiar el contrato publico de `Task`.
- Aprovecha `TaskState`, `TaskStatus`, `WorkState`, `TaskTypeInline` y `OngoingBy` ya existentes.
- Evita introducir un constructor smart o un tipo opaco mientras el record compartido sigue siendo publico y usado por cliente/servidor.
- Reduce drift en la frontera HTTP, que es donde el usuario y el cliente consumen el estado de la tarea.
- Tiene una prueba cercana al modulo que decide el JSON, no una prueba indirecta de handler con DB.

Lo que no debe hacerse todavia:

- No eliminar `Task.status` y `Task.work_state` en este corte: son parte del contrato compartido y requeririan migrar decoders, cliente y tests de API.
- No introducir una segunda projection de tarea solo para ocultar campos redundantes en servidor.
- No mover conversiones de JSON al dominio compartido hasta que haya repeticion real entre cliente y servidor; ahora la conversion HTTP pertenece al presenter.

Definition of Done especifica para este corte:

| Garantia | Criterio |
| --- | --- |
| Lifecycle canonico | Cumplido: `task_json` deriva `status` y `work_state` desde `TaskState` |
| Drift cubierto | Cumplido: test con campos redundantes obsoletos verifica que gana el ADT |
| Sin sobreingenieria | Cumplido: no hay nuevo wrapper, projection ni constructor global |
| Frontera correcta | Cumplido: DB normaliza en mapper; HTTP serializa desde el mismo estado canonico |
| Validacion local | `gleam format --check src test` y `gleam check --target erlang` pasan para el corte; la suite completa queda cubierta en la auditoria de cierre con `DATABASE_URL` contra `localhost:5433` |

## Refuerzo 2026-06-15: `ProjectGrant` movido al dominio compartido

El barrido sobre API tokens mostro una separacion incompleta: `ApiToken` e `IntegrationUser` ya estaban en `shared/src/domain/api_token.gleam`, pero el ADT que expresa el alcance de proyecto de un token (`AllProjects | ProjectOnly`) seguia viviendo en `services/api_tokens.gleam`. Ese ADT no es una preocupacion de hash, bearer ni persistencia: decide el significado de `project_id = null` frente a `project_id = <id>`.

Solucion ejecutada:

1. `ProjectGrant` se movio a `shared/src/domain/api_token.gleam`.
2. Las conversiones `project_grant_from_option` y `project_grant_to_option` se movieron al mismo owner.
3. `services/api_tokens.gleam` conserva `ApiTokenRecord`, `CreatedToken`, `VerifiedToken`, hash, bearer y auditoria.
4. `http/auth/resource_access.gleam`, `http/projects.gleam` y `http/api_tokens/presenters.gleam` pattern-matchean o serializan usando el ADT compartido.
5. `shared/test/api_token_test.gleam` cubre los dos sentidos de conversion entre `Option(Int)` y `ProjectGrant`.

Por que esta es la mejor solucion ahora:

- El ADT modela semantica de producto, no detalle interno de seguridad.
- Reduce el ownership ambiguo sin cambiar el JSON publico, que sigue exponiendo `project_id`.
- Evita mover `VerifiedToken` al dominio compartido; ese record contiene datos de autorizacion runtime y debe seguir en servidor.
- Reutiliza el modulo compartido ya creado para API tokens en vez de introducir otro modulo o wrapper.

Lo que no debe hacerse:

- No mover bearer secrets, hashes, auditoria ni validacion criptografica a `shared`.
- No cambiar `ApiToken.project_id: Option(Int)` por `ProjectGrant` sin una migracion coordinada de decoders, views y contrato HTTP.
- No reexportar `ProjectGrant` desde `services/api_tokens.gleam`; los consumidores deben importar el owner real.

Definition of Done especifica para este corte:

| Garantia | Criterio |
| --- | --- |
| ADT en owner correcto | Cumplido: `ProjectGrant` vive en `shared/src/domain/api_token.gleam` |
| Seguridad confinada | Cumplido: `VerifiedToken`, bearer y hash siguen en servidor |
| Conversion centralizada | Cumplido: `Option(Int) <-> ProjectGrant` se prueba en `shared/test/api_token_test.gleam` |
| Sin cambio de contrato HTTP | Cumplido: el JSON sigue usando `project_id` |
| Validacion multi-target | Cumplido: `shared` pasa en Erlang y JavaScript; servidor y cliente compilan contra el nuevo owner |

## Refuerzo 2026-06-15: sentinels de create task confinados en payloads

El barrido de sentinels encontro un caso que cruzaba la frontera HTTP: `services/workflows/handlers.gleam` interpretaba `Some(0)` como ausencia de `card_id` al crear una tarea. Esa lectura pertenece al decoder del payload, no al workflow handler. El handler debe recibir `None` para ausencia y `Some(id)` para IDs de dominio.

Solucion ejecutada:

1. `decode_create_task` aplica `normalize_optional_id` a `card_id` y `parent_card_id`.
2. El helper ya existente de payloads mantiene el contrato usado en update: IDs no positivos representan ausencia.
3. `normalize_card_id` en `services/workflows/handlers.gleam` deja de conocer `Some(0)` y solo valida `None`, IDs positivos o error.
4. `tasks_payloads_test.gleam` cubre create con `card_id = 0` y `parent_card_id = -1`, verificando que ambos llegan como `None`.

Por que esta es la mejor solucion ahora:

- Mueve el valor tecnico a la frontera JSON, donde entra el dato.
- Reutiliza `normalize_optional_id` ya existente en el mismo modulo de payloads.
- Evita crear un helper global de sentinels para un caso local.
- Mantiene el workflow handler como capa de proceso: autorizacion, validacion de dominio y llamada a persistencia.

Lo que no debe hacerse:

- No llevar `0`/`-1` al dominio compartido como estado.
- No crear un DSL de IDs opcionales hasta ver la misma semantica repetida en mas fronteras.
- No eliminar la validacion positiva del workflow handler: sigue siendo una defensa de dominio para llamadas internas.

Definition of Done especifica para este corte:

| Garantia | Criterio |
| --- | --- |
| Sentinel en frontera HTTP | Cumplido: `decode_create_task` normaliza `card_id` y `parent_card_id` |
| Handler sin sentinel especifico | Cumplido: no queda `Some(0)` en `services/workflows/handlers.gleam` |
| Reuso local | Cumplido: se reutiliza `normalize_optional_id` en payloads |
| Test cercano | Cumplido: `decode_create_task_payload_normalizes_non_positive_optional_ids_test` cubre el contrato |

## Refuerzo 2026-06-15: active flags de workflows/rules confinados en payloads

El barrido posterior encontro otra repeticion de frontera HTTP: `rules.gleam` y
`workflows.gleam` tenian el mismo `normalize_active`, interpretando `0` como
`False` y `1` como `True` dentro del handler. Esa conversion no es proceso de
producto; es compatibilidad del payload PATCH actual, que el cliente envia como
entero para updates.

Solucion ejecutada:

1. Se creo `http/payload_fields.gleam` con
   `optional_active_flag_decoder() -> Decoder(Option(Bool))`.
2. `http/workflows/payloads.gleam` cambia `UpdatePayload.active` de
   `Option(Int)` a `Option(Bool)`.
3. `http/rules/payloads.gleam` aplica el mismo cambio.
4. `http/workflows.gleam` y `http/rules.gleam` eliminan sus funciones
   `normalize_active` duplicadas y pasan `payload.active` directamente a
   persistencia.
5. Los tests de payload cubren `1 -> Some(True)`, `0 -> Some(False)` y rechazo
   de valores desconocidos como `2`.

Por que esta es la mejor solucion ahora:

- Mantiene el contrato externo existente de PATCH (`0/1`) sin forzar una
  migracion del cliente.
- Mueve la convencion tecnica a Parse, siguiendo Parse -> Process -> Present.
- Elimina dos copias exactas de normalizacion sin crear un framework de
  payloads.
- Hace que los handlers trabajen con `Option(Bool)`, que es el tipo que ya
  esperan `workflows_db.set_active_cascade` y `rules_db.update_rule`.

Lo que no debe hacerse:

- No cambiar el contrato PATCH a booleano mientras el cliente y los tests HTTP
  sigan enviando `0/1`.
- No mover esta convencion al dominio compartido: `0/1` es transporte, no
  estado de negocio.
- No crear un modulo generico de todos los campos de payload si no hay mas
  convenciones repetidas con la misma semantica.

Definition of Done especifica para este corte:

| Garantia | Criterio |
| --- | --- |
| Handler sin sentinel de active | Cumplido: `rg "fn normalize_active|Some\\(0\\) -> Ok\\(Some\\(False\\)\\)" apps/server/src/scrumbringer_server/http/{rules.gleam,workflows.gleam}` queda vacio |
| Payload tipado | Cumplido: `UpdatePayload.active` es `Option(Bool)` en workflows y rules |
| Reuso de frontera | Cumplido: ambos payloads usan `payload_fields.optional_active_flag_decoder()` |
| Test cercano | Cumplido: `rules_payloads_test.gleam` y `workflows_payloads_test.gleam` cubren `0`, `1` y valor invalido |

## Snapshot verificable

El estado del informe se apoya en evidencia que puede repetirse desde el repositorio:

| Senal | Resultado observado | Lectura tecnica |
| --- | --- | --- |
| `wc -l apps/client/src/scrumbringer_client/client_state/types.gleam` | 14 lineas | El modulo global ya solo debe actuar como owner de tipos transversales. |
| `wc -l apps/client/src/scrumbringer_client/client_state.gleam` | 399 lineas | El root conserva `Model`, `Msg`, page/nav y aliases transversales; no debe volver a ser facade de tipos de feature. |
| `wc -l apps/client/src/scrumbringer_client/features/capabilities/update.gleam` | 288 lineas | La separacion CRUD/asignaciones ya deja un dispatcher fino. |
| `wc -l apps/client/src/scrumbringer_client/features/admin/update.gleam` | 346 lineas | Ya no contiene los adapters grandes de projects, invites, capabilities, assignments, API tokens, task types, org settings ni la cadena interna de members/search. |
| `rg "projects_workflow|invite_links_workflow" features/admin/update.gleam` | sin matches reales | Projects e invites ya no viven como adapters dentro del root admin. |
| `rg "features/tasks/update" apps/client/src apps/client/test` | no debe encontrar imports reales | El orquestador antiguo de tasks no debe volver como punto de entrada. |
| `rg "pub type Card \\{|pub type RuleTemplate \\{|pub type Task \\{" apps/server/src/scrumbringer_server` | debe revisarse por falso positivo y owner | Cada match debe ser contrato canonico, row/projection interna o deuda concreta. |
| `rg "status: _status|work_state: _work_state|task_state.to_status\\(state\\)|task_state.to_work_state\\(state\\)" apps/server/src/scrumbringer_server/http/tasks/presenters.gleam` | debe encontrar el presenter derivando desde `TaskState` e ignorando campos redundantes | La frontera HTTP no debe volver a serializar lifecycle paralelo desde `Task.status`/`Task.work_state`. |
| `rg "task_json_derives_status_and_work_state_from_task_state_test" apps/server/test/unit/presenters_test.gleam` | debe encontrar el test de drift del presenter | El contrato de JSON de tarea tiene una prueba local sin depender de DB. |
| `rg "pub type ProjectGrant" shared/src/domain/api_token.gleam apps/server/src/scrumbringer_server` | solo debe encontrar `shared/src/domain/api_token.gleam` | El ADT de grant no debe volver al servicio operativo de tokens. |
| `rg "project_grant_from_option|project_grant_to_option" shared/src/domain/api_token.gleam apps/server/src/scrumbringer_server/services/api_tokens.gleam` | las definiciones deben estar en shared; el servicio solo debe llamar al owner compartido | La conversion `project_id` nullable queda centralizada. |
| `rg "Some\\(0\\)" apps/server/src/scrumbringer_server/services/workflows/handlers.gleam` | sin matches | El workflow handler no debe conocer el sentinel de ausencia que viene de JSON. |
| `rg "decode_create_task_payload_normalizes_non_positive_optional_ids_test" apps/server/test/tasks_payloads_test.gleam` | debe encontrar el test de payload | El contrato de create task queda protegido en la frontera Parse. |
| `rg "fn normalize_active|Some\\(0\\) -> Ok\\(Some\\(False\\)\\)" apps/server/src/scrumbringer_server/http/{rules.gleam,workflows.gleam}` | sin matches | Los handlers de rules/workflows no deben interpretar el flag entero de PATCH. |
| `rg "optional_active_flag_decoder|active: Option\\(Bool\\)|decode_update_payload_decodes_inactive_flag_test|decode_update_payload_rejects_unknown_active_flag_test" apps/server/src/scrumbringer_server/http apps/server/test/{rules_payloads_test.gleam,workflows_payloads_test.gleam}` | debe encontrar el helper, los payloads tipados y tests de `0/2` | La convencion `0/1` queda protegida en payloads. |
| `rg "option_to_value\\([^\\n]*, 0\\)" apps/server/src/scrumbringer_server/services/rules_engine.gleam` | sin matches | El rules engine no debe tener `0` anonimos para valores de query/creacion. |
| `rg "no_task_type_filter_value|no_card_id_create_value|no_task_parent_card_id" apps/server/src/scrumbringer_server/services/rules_engine.gleam` | debe encontrar las constantes privadas | Los valores tecnicos quedan nombrados junto al owner que los usa. |
| `rg "pub type Project \\{|pub type ProjectMember \\{" apps/server/src/scrumbringer_server shared/src` | solo matches en `shared/src/domain/project.gleam` | Los records internos del servidor ya no compiten por el nombre canonico. |
| `rg "#\\(\\\"org_id\\\"|#\\(\\\"project_id\\\"" apps/server/src/scrumbringer_server/http/projects/presenters.gleam` | sin matches | El presenter publico de proyectos no debe filtrar campos internos. |
| `rg "project_json_does_not_expose_internal_org_id_test|project_member_json_does_not_expose_internal_project_id_test" apps/server/test/unit/presenters_test.gleam` | debe encontrar ambos tests | El contrato de frontera de `Project`/`ProjectMember` queda protegido sin DB. |
| `rg "fn maybe_add_(aria_label|placeholder|autofocus)" apps/client/src/scrumbringer_client/components/*crud_dialog.gleam` | sin matches | Los helpers de atributos opcionales viven en `crud_dialog_base.gleam`. |
| `rg "submit_button_with_locale_attrs" apps/client/src apps/client/test` | sin matches | No debe volver el submit con atributos arbitrarios en `ui/dialog`. |
| `rg "attribute\\.type_\\(\"submit\"\\)|attribute\\.form\\(|btn-loading" apps/client/src/scrumbringer_client/features/pool/create_dialog.gleam apps/client/src/scrumbringer_client/features/pool/position_edit_dialog.gleam apps/client/src/scrumbringer_client/features/pool/task_dependencies.gleam` | sin matches relevantes en los footers migrados | Los submits principales de esos dialogs pasan por `ui/dialog` y `ui/button`. |
| `rg "submit_button_with_locale_(form|click)\\(" apps/client/src apps/client/test` | matches en call sites migrados y tests | La variante elegida queda explicita: formulario externo o accion por mensaje. |
| `rg "html\\.button" apps/client/src/scrumbringer_client --glob '*.gleam'` | solo encuentra `ui/button.gleam` e `ui/icon_picker.gleam` | El uso cualificado directo de `html.button` esta cerrado salvo la primitiva y el control de seleccion de iconos. |
| `rg "import lustre/element/html\\.\\{[^\\n]*button" apps/client/src/scrumbringer_client/features apps/client/src/scrumbringer_client/ui --glob '*.gleam'` | encuentra imports directos de `button` en primitives/helpers UI, layout, pool, card trees, admin y otras features | No es un fallo automatico; es el barrido que obliga a clasificar cada caso antes de tocar codigo. |
| `rg "btn-xs btn|btn-sm btn|attribute\\.attribute\\(\"aria-label\", remove_label\\)|attribute\\.attribute\\(\"title\", remove_label\\)" apps/client/src/scrumbringer_client/features/assignments/components/{project_card.gleam,user_card.gleam}` | sin matches | Las acciones inline de assignments pasan por `ui/button`; los toggles de expansion quedan fuera del barrido por ser controles con `aria-expanded`. |
| `rg "btn-xs btn-secondary|btn btn-sm btn-secondary task-detail-edit-toggle" apps/client/src/scrumbringer_client/features/admin/rule_metrics_view.gleam apps/client/src/scrumbringer_client/features/tasks/detail_editor.gleam` | sin matches | Las acciones simples de metricas y entrada a edicion de tarea pasan por `ui/button`; quedan fuera quick ranges y prioridad por ser controles con estado ARIA propio. |
| `rg "attribute\\.type_\\(\"submit\"\\)|btn-loading" apps/client/src/scrumbringer_client/features/auth/view.gleam` | solo queda `btn-loading` dentro de `loading_class` | Los submits de auth pasan por `ui/button.submit`; el literal de loading queda encapsulado como compatibilidad visual. |
| `rg "button\\(\\[event\\.on_click|btn btn-sm btn-primary|btn-icon btn-xs btn-danger-icon" apps/client/src/scrumbringer_client/features/admin/{workflow_rules_view.gleam,org_settings_view.gleam}` | sin matches | Workflow rules y org settings ya no reconstruyen acciones simples con clases legacy. |
| `rg "button\\(\\[" apps/client/src/scrumbringer_client/features apps/client/src/scrumbringer_client/ui --glob '*.gleam'` | contiene falsos positivos y controles reales en varias capas | Debe revisarse con contexto: `ui/button`, `ui/action_buttons`, tabs, menus, toasts, drawers, filas seleccionables, toggles y drag handles no tienen la misma semantica. |

Esta tabla es deliberadamente operacional. Si un dato cambia, la decision no debe actualizarse por intuicion: debe cambiar el estado del punto correspondiente en este informe.

## Contrato de no regresion

El refactor deja varias reglas que deben tratarse como contrato de mantenimiento. No son preferencias esteticas; evitan que la base vuelva al estado anterior.

| Contrato | No debe reaparecer | Alternativa aceptada |
| --- | --- | --- |
| Botones semanticos | `html.button` raw para acciones que ya caben en `ui/button` | `ui/button.text`, `ui/button.submit`, `ui/button.icon` o helper de `ui/dialog` |
| Submit de dialog | `submit_button_with_locale_attrs` o listas libres de atributos | `submit_button_with_locale_form` para formulario externo y `submit_button_with_locale_click` para accion por mensaje |
| CRUD dialogs | Helpers locales `maybe_add_placeholder`, `maybe_add_aria_label`, `maybe_add_autofocus` | `crud_dialog_base.with_optional_*` |
| Botones CRUD | Clases primarias/danger/cancel reconstruidas en cada dialog | Helpers de `crud_dialog_base` sobre `ui/button`, dejando solo clases de compatibilidad |
| Tipos canonicos | `pub type Task`, `Card`, `Project`, `Workflow`, `Rule`, `ApiToken` en owners operativos con el mismo significado que shared | Tipo shared, o record interno renombrado como `Record`, `Projection`, `Row` o `Summary` |
| Estado especifico de pantalla | Formularios, dialog targets o drag state dentro de `client_state/types.gleam` | Modulo de estado del owner real (`client_state/admin/*`, `client_state/member/*`, feature local) |
| Root update | Reglas de auth/feedback/apply de un subflujo ya extraido | Route adapter pequeno con tests propios |

Una regresion se considera real aunque los tests generales pasen si rompe uno de estos contratos y no anade una justificacion explicita. La validacion minima debe combinar `rg` dirigido y tests cercanos, no solo un conteo de lineas.

Excepciones aceptadas:

- Los botones internos de `ui/icon_picker.gleam` son controles de seleccion/tabs con clase y estado visual propios. No deben migrarse a `ui/button` sin un redisenio explicito de controles seleccionables.
- El handle de drag en `features/pool/task_card.gleam` no es una accion simple: es una superficie de arrastre con clase y comportamiento especificos. Migrarlo requiere revisar la interaccion de drag, no solo cambiar clases.
- `ui/tabs.gleam`, `ui/action_menu.gleam`, `ui/toast.gleam`, `ui/modal_close_button.gleam`, `ui/task_item.gleam`, `ui/card_with_tasks_surface.gleam` y `ui/task_actions.gleam` son helpers o primitivas UI que pueden envolver botones raw internamente. La regla para ellos no es "cero `button`", sino que expongan una API semantica y no obliguen a las features a reconstruir clases.
- Los botones de layout, drawer, filas seleccionables, toggles de expansion y controles segmentados deben evaluarse como controles interactivos, no como acciones textuales simples. Migrarlos a `ui/button` solo es correcto si `ui/button` cubre explicitamente su semantica ARIA y visual.

### Clasificacion reforzada de botones raw

El barrido de UI debe quedar dividido en cuatro grupos. Esta distincion evita
dos errores: declarar limpio un uso que sigue siendo deuda, o migrar controles
con estado propio a una primitiva pensada para acciones simples.

| Grupo | Ejemplos | Estado | Accion correcta |
| --- | --- | --- | --- |
| Primitiva o helper UI | `ui/button.gleam`, `ui/action_buttons.gleam`, `ui/modal_close_button.gleam`, `ui/tabs.gleam`, `ui/action_menu.gleam`, `ui/toast.gleam` | Aceptable si la API publica es semantica | Mantener raw interno y testear la API expuesta |
| Control de seleccion/expansion | `ui/icon_picker.gleam`, filas de card trees, quick ranges, prioridad, toggles de cards/tasks | Aceptable con `aria-pressed`, `aria-expanded`, `aria-controls` o rol equivalente | No migrar por defecto; crear una primitiva de control solo si hay 3+ usos con la misma semantica |
| Superficie gestual | Drag handle de task card, drawers responsive, filas clicables | Aceptable si el comportamiento depende de gestos/layout | No forzar `ui/button`; revisar con pruebas visuales/interaccion si se redisenan |
| Accion textual simple | Retry, Cancel, Save, Create, Back, Delete, Add cuando no tienen estado propio | Deuda si se monta con `button` raw y clases manuales | Migrar a `ui/button`, `ui/dialog` o `ui/action_buttons` preservando labels, disabled, testid y bubbling |

Con esta clasificacion, el informe deja de usar "botones raw" como una metrica
binaria. La deuda real no es que exista un `button`; la deuda es que una feature
vuelva a decidir manualmente intent, tamano, disabled, submit, accesibilidad o
clases que ya tienen owner compartido.

## Evidencia post-refactor de UI compartida

La limpieza de UI no debe medirse por haber creado mas helpers, sino por haber reducido las rutas donde se decide lo mismo. El estado actual deja tres niveles claros:

| Nivel | Owner | Responsabilidad |
| --- | --- | --- |
| Primitiva | `ui/button.gleam` | Tipo nativo (`button`/`submit`), intent, scope, shape, size, disabled, form target y clases semanticas |
| Dialog generico | `ui/dialog.gleam` | Copy localizado de acciones de dialog y distincion entre submit de formulario y accion por mensaje |
| CRUD especifico | `crud_dialog_base.gleam` | Validacion/parseo comun de campos, atributos opcionales y botones CRUD con labels de entidad |
| Componentes reutilizables simples | `ui/empty_state.gleam`, `ui/card_section_header.gleam`, `ui/copyable_input.gleam` | Delegan acciones en `ui/button` y solo conservan layout/copy propio |
| Acciones inline de feature | `features/assignments/components/{project_card,user_card}.gleam` | Reutilizan `ui/button` para acciones textuales y solo mantienen controles raw cuando necesitan estado ARIA propio |
| Acciones simples de vistas | `features/admin/rule_metrics_view.gleam`, `features/tasks/detail_editor.gleam` | Reutilizan `ui/button` para acciones textuales y mantienen raw solo controles de seleccion/chip/segmentados con estado ARIA |
| Submit de auth | `features/auth/view.gleam` | Usa un helper privado sobre `ui/button.submit` para los cuatro formularios de autenticacion |
| Acciones en contenedores clicables | `features/admin/workflow_rules_view.gleam` | Usa `ui/button.with_stop_propagation` para mantener el comportamiento sin reconstruir DOM raw |
| Icon actions de administracion | `features/admin/org_settings_view.gleam`, `ui/action_buttons.gleam` | Usan helpers semanticos de accion sobre `ui/button`, con disabled y `data-testid` cuando hace falta |

Este encaje es preferible a un componente CRUD universal porque cada capa tiene una frase de ownership. `ui/button` no sabe nada de dialogs; `ui/dialog` no sabe nada de entidades CRUD; `crud_dialog_base` no decide reglas remotas de producto.

Los dialogos de pool son una buena prueba de limite: crear tarea, editar posicion y anadir dependencias reutilizan el submit compartido porque su footer encaja en el contrato. El footer de detalle de tarea no se fuerza al helper porque contiene una politica visual propia (`task-detail-save`) y no se ha demostrado duplicacion equivalente en tres sitios. Mantenerlo fuera es una decision de bajo acoplamiento, no deuda oculta.

## Trazabilidad hallazgo-solucion-garantia

| Hallazgo | Solucion preferida | Garantia esperada | Prueba minima |
| --- | --- | --- | --- |
| Tipo duplicado con mismo significado que dominio compartido | Usar el tipo de `shared/src/domain` en el owner de producto | Una sola fuente semantica para cliente y servidor | Barrido de tipos publicos duplicados y tests de presenter/codec |
| Tipo de servidor parecido al dominio pero con campos internos | Renombrar como `Record`, `Row`, `Projection` o `Summary` | El nombre impide confundir contrato HTTP con persistencia/autorizacion | Tests de handler mas barrido de imports del tipo anterior |
| Estado especifico de pantalla en `client_state/types.gleam` | Moverlo al modulo de estado de la pantalla | El cambio de una pantalla no toca un modulo global | `rg` del tipo antiguo en `client_state/types.gleam` y tests de update/view |
| Root update que mezcla routing, contexto, auth y apply | Extraer route adapter por area funcional | El root decide el orden, el route aplica un submodelo concreto | Test de route feliz, test de error/auth y barrido de helpers antiguos |
| Strings de negocio fuera de frontera | Convertir a ADT en submit, mapper o presenter | Las reglas de negocio hacen pattern matching sobre variantes | Tests de parseo/conversion y barrido de strings en ramas de negocio |
| Sentinels SQL propagados | Encapsularlos con nombres privados en persistencia | El valor magico no cruza a dominio ni servicios de producto | Barrido de sentinels y revision de cada match por frontera |
| Helpers UI repetidos | Extraer solo piezas estables en 3+ dialogos y reutilizar componentes `ui/*` existentes | Menos boilerplate sin perder reglas locales y menos atributos arbitrarios | Tests de view y comparacion de parametros del helper |

La garantia importante no es que desaparezcan todos los parecidos visuales. La garantia es que una decision de producto tenga un unico owner y una unica prueba principal.

## Auditoria de completitud de cortes

Un corte de limpieza se considera completo solo si cumple las cuatro condiciones siguientes:

1. El root deja de importar el workflow antiguo o el modulo de feature que ya tiene route propio.
2. Los helpers de contexto, feedback, auth y `apply_*` desaparecen del root o quedan privados dentro del route.
3. Hay tests directos del nuevo owner que cubren al menos exito, error/auth y mensaje ignorado cuando aplique.
4. El informe y el inventario reflejan el nuevo owner para que el siguiente barrido no lo trate como modulo accidental.

Aplicado al estado actual:

| Corte | Root libre de workflow antiguo | Tests directos | Politica root explicitada | Estado |
| --- | --- | --- | --- | --- |
| Tasks create/notes/mutation/detail | Si; `features/tasks/update.gleam` fue eliminado | Si | Si, en cada owner de flujo | Cerrado |
| Capabilities CRUD/asignaciones | Si; root capabilities queda como dispatcher fino | Si | Si, via `AuthPolicy` y feedback local | Cerrado |
| Admin API tokens | Si | Si | Si, auth antes de apply | Cerrado |
| Admin assignments | Si | Si | Si, `RootPolicy` y fetch desde org settings | Cerrado |
| Admin capabilities | Si | Si | Si, selected project y feedback local | Cerrado |
| Admin projects | Si | Si | Si, sync de `core.projects` y `selected_project_id` | Cerrado |
| Admin invites | Si | Si | No requiere politica root adicional | Cerrado |
| Admin task types | Si | Si | Si, `RefreshPolicy` explicita | Cerrado |
| Admin org settings | Si | Si | Si, assignments fetch y current user update | Cerrado |

Esta tabla fuerza una interpretacion estricta: un modulo nuevo no cuenta como limpieza si el root conserva el mismo conocimiento operacional. La mejora solo es real cuando baja la responsabilidad del root y suben las pruebas del owner concreto.

## Riesgos residuales priorizados

El barrido deja menos problemas de tipos globales, pero todavia hay zonas donde la base de codigo puede volver a duplicar responsabilidades si se cambia deprisa.

| Riesgo | Donde aparece | Por que importa | Tratamiento recomendado |
| --- | --- | --- | --- |
| Updates con demasiadas responsabilidades | `features/admin/update.gleam` | Un cambio pequeno puede tocar dispatch, contexto, comandos y mutacion de modelo en el mismo modulo | Extraer subupdates por area funcional, con tests existentes como red |
| Aliases publicos de transicion | `client_state.gleam` | El riesgo principal ya se retiro para tipos especificos; solo deben quedar aliases transversales o root-model | No reintroducir aliases de feature; importar desde el owner real |
| Presenters que derivan significado | Presenters HTTP de tareas/cards/rules | Si recomponen entidad o estado, pueden divergir del dominio canonico | Aceptar tipos de dominio/projection clara y derivar solo la forma JSON |
| Projections internas con nombre de dominio | `Project`, `ProjectMember` del servidor | Mezclan contrato publico con campos internos de autorizacion/persistencia | Renombrar como records internos antes de convertir en frontera HTTP |
| Helpers CRUD demasiado genericos | Dialogos admin | Un helper amplio puede esconder reglas locales de producto | Extraer solo piezas repetidas en tres o mas dialogos y con pocos parametros |

Este orden mantiene el sesgo correcto: primero se evita nueva duplicacion en flujos activos, despues se aclaran nombres internos, y solo al final se mejora ergonomia visual/CRUD con helpers pequenos.

## Politica para cambios intermedios

Los cambios que nacieron durante iteraciones previas solo deben quedarse si cumplen una de estas condiciones:

- Mueven responsabilidad a un owner mas preciso.
- Eliminan un tipo o modulo duplicado.
- Reducen imports del root afectado.
- Anaden una prueba que protege comportamiento publico o una politica de auth/error.
- Confinan una frontera tecnica, como SQL, JSON, DOM o FFI.

Si un cambio no cumple ninguna de esas condiciones, debe retirarse aunque compile. En esta limpieza no basta con "no molesta"; el codigo nuevo debe justificar su existencia por ownership, DRY, tipos o garantia de comportamiento.

Casos a vigilar especialmente:

| Tipo de residuo | Sintoma | Accion |
| --- | --- | --- |
| Adapter temporal sin callers directos | El modulo existe pero los tests siguen entrando por el root antiguo | Migrar tests al owner real o eliminar el adapter |
| Alias de compatibilidad perpetuo | El alias evita cambiar imports nuevos | Documentar como temporal o migrar callers |
| Helper prematuro | Tiene muchos parametros y solo un caller | Inlinear o mantener la funcion privada junto al flujo |
| Tipo movido sin cambiar semantica | El nombre nuevo no aclara owner | Revertir el movimiento o renombrar como projection/estado de UI |
| Comentario obsoleto | Sigue mencionando el modulo anterior | Actualizarlo en el mismo corte que elimina el owner viejo |

Esta politica responde directamente a la duda de limpieza: no se deben conservar intentos que no llegaron a resolver el problema. Un intento solo pasa a ser solucion cuando reduce superficie mental y tiene una prueba o barrido que lo respalda.

## Refuerzo del criterio: que significa "mejor" en esta limpieza

La mejor solucion aqui no es la que deja mas archivos pequenos ni la que introduce mas ADTs. Es la que reduce el numero de razones por las que un mismo comportamiento puede cambiar.

Para decidir si una mejora supera a otra se usa esta matriz:

| Pregunta | Respuesta que favorece ejecutar | Respuesta que favorece posponer |
| --- | --- | --- |
| Hay un concepto duplicado? | Dos tipos/modulos representan la misma entidad o estado de negocio | Solo hay codigo parecido por casualidad |
| Hay owner claro? | El modulo destino ya existe o su nombre responde a un flujo de producto | Hay que inventar una capa generica para justificarlo |
| El compilador ayuda? | El movimiento elimina imports antiguos o hace exhaustivo un ADT | El movimiento solo desplaza funciones privadas |
| Hay tests cercanos? | Existen tests del feature, mapper, presenter o view afectado | Solo se podria validar con exploracion manual amplia |
| Baja el riesgo futuro? | Un cambio de producto tocaria menos sitios | El cambio solo reduce lineas sin aclarar responsabilidad |

Con esta matriz, las extracciones de tasks y capabilities eran superiores a una division por carpetas porque cada una tenia owner, tests y reglas de producto propias. En cambio, un helper CRUD universal o un dispatcher generico siguen descartados porque aumentarian conceptos antes de borrar responsabilidades duplicadas.

## Criterios de evidencia

El informe debe poder comprobarse con tres tipos de evidencia:

- Evidencia estructural: el tipo o modulo obsoleto desaparece, o queda renombrado como projection interna.
- Evidencia de imports: los tests y callers importan el owner real, no un facade historico.
- Evidencia de comportamiento: los tests del flujo afectado cubren exito, error y autorizacion cuando aplique.

La evidencia negativa tambien cuenta. Si un `rg` encuentra el nombre antiguo, no implica automaticamente fallo, pero obliga a clasificar el match:

- Compatibilidad temporal aceptada.
- Comentario/documentacion pendiente de actualizar.
- Uso real que demuestra que la migracion no ha terminado.
- Nombre reutilizado con otro significado, que deberia renombrarse para evitar ambiguedad.

Este criterio evita declarar limpio un cambio solo porque compila.

## Refuerzo operativo del informe

Este informe debe funcionar como una herramienta de control, no como una
declaracion de intenciones. Para reforzarlo, cada recomendacion queda atada a
una de estas cuatro pruebas:

| Prueba | Que demuestra | Ejemplo de aceptacion |
| --- | --- | --- |
| Barrido estructural | El owner incorrecto dejo de publicar el concepto | `Project` solo aparece como tipo canonico en `shared/src/domain/project.gleam` |
| Barrido de imports | Los callers usan el modulo owner, no un facade historico | Tests de drag importan `client_state/member/pool.gleam` para `Rect` |
| Test cercano | La garantia vive junto al flujo que decide comportamiento | Tests de route admin cubren exito, auth/error y politicas root |
| Frontera contenida | Strings/sentinels/JSON/SQL no suben a dominio | `__unset__`, `0` y `-1` quedan nombrados en persistencia |

Un punto solo puede marcarse como cerrado si al menos dos de esas pruebas lo
respaldan, y una de ellas debe ser un test o un barrido repetible. En cambios de
contrato publico, el test cercano es obligatorio.

### Definicion estricta de cerrado

Un corte esta cerrado cuando cumple simultaneamente:

1. El modulo antiguo ya no es el punto de entrada mental ni tecnico.
2. El nuevo owner tiene un nombre que explica su responsabilidad de producto.
3. La prueba principal se ejecuta contra el owner real.
4. El root deja de conocer detalles operativos del flujo movido.
5. Los nombres canonicos del dominio no compiten con records internos.

Si solo se ha movido codigo, pero el root conserva la decision o el tipo antiguo
sigue siendo el import habitual, el corte esta incompleto.

### Definicion de residuo aceptable

No todo match de `rg` despues de un refactor es deuda. Un residuo es aceptable
solo si cae en una de estas categorias:

- Tipo interno renombrado como `Record`, `Row`, `Projection` o `Summary`.
- Valor tecnico confinado en SQL, JSON, DOM o FFI.
- Alias transversal de root-model, no alias de feature.
- Test que comprueba compatibilidad externa de un contrato que se mantiene.
- Comentario historico que aparece en documentacion de migracion, no en codigo
  operativo.

Cualquier otro residuo debe clasificarse como pendiente o retirarse en el mismo
corte. Esta regla responde directamente a la preocupacion de si quedan cambios
intermedios que "no resolvieron": si no mueven ownership, no reducen duplicacion
o no protegen comportamiento, no deben quedarse.

### Matriz de semaforo

| Estado | Criterio | Accion |
| --- | --- | --- |
| Verde | Owner claro, tests cercanos y barrido limpio | Mantener y documentar como cerrado |
| Amarillo | Owner claro, pero falta test o hay frontera de contrato pendiente | Mantener como parcial y no expandir el patron aun |
| Rojo | Codigo movido sin reducir responsabilidad o sin callers directos | Retirar, inlinear o redisenar antes de seguir |

El semaforo evita dos extremos: declarar todo limpio por haber pasado tests, o
seguir refactorizando por estetica cuando ya no hay deuda semantica.

## Corte ejecutado: `features/admin/update.gleam`

Tras eliminar el orquestador obsoleto de tasks, el mayor riesgo real estaba en `features/admin/update.gleam`. No por longitud aislada, sino porque agrupaba tres responsabilidades:

- routing de mensajes admin;
- construccion de contextos localizados;
- aplicacion de submodelos, auth policy, feedback y cambios en `core`.

El patron correcto ya esta demostrado por `features/admin/api_tokens_route.gleam`: un route adapter pequeno que recibe el `Model`, llama al update del feature, aplica el submodelo y traduce auth/feedback sin mover reglas de negocio al root.

El orden ejecutado para reforzar admin es:

1. `assignments_route.gleam` - ejecutado

   Fue prioritario porque `features/assignments/update.gleam` ya tenia un contrato propio y el root admin solo aportaba contexto, feedback, auth timing y actualizacion del submodelo. Tambien tenia politicas de root (`ReplaceAssignmentsView`, feedback de rol) que convenia encerrar.

2. `capabilities_route.gleam` - ejecutado

   Ya existe una division interna entre CRUD y asignaciones. El adapter admin deberia quedarse con selected project, textos localizados, feedback, auth y apply del submodelo. Esto consolidaria el patron validado en capabilities sin mezclarlo con project assignments.

3. `projects_route.gleam` - ejecutado

   Tenia mas riesgo porque no solo actualiza `admin.projects`: tambien sincroniza `core.projects` y `selected_project_id`. El route deja esa politica explicita y testeada sin mezclarla con otros flujos admin.

4. `invites_route.gleam` - ejecutado

   Es un corte mas simple que projects y consolida el patron de contexto, feedback, auth y apply de submodelo.

5. `task_types_route.gleam` - ejecutado

   Quedaba despues de projects/invites porque arrastra refresh de seccion y dialogos CRUD. El route mantiene esa politica visible y testeada sin crear un motor CRUD.

6. `members_route.gleam` - ejecutado

   Quedo despues de los routes grandes porque es una agregacion de area: list/add/remove/release-all/role/search siguen teniendo owners de comportamiento propios, pero el root ya no conoce su orden interno.

No se recomienda seguir extrayendo routes por simetria. El criterio de calidad es que cada corte reduzca imports y ramas del root admin, y que deje tests verdes antes del siguiente.

## Contrato esperado de un route admin

Un route admin debe cumplir estas reglas:

- Exponer `try_update(model, inner, ...) -> Option(#(Model, Effect(Msg)))` o una firma igual de directa.
- Construir el `Context` y `FeedbackContext` del feature en un solo modulo.
- Aplicar exactamente un submodelo admin, salvo que el feature tenga una politica explicita para tocar `core`.
- Traducir `AuthPolicy` cerca del apply, no dentro del feature update.
- No importar vistas.
- No conocer detalles de formularios salvo textos localizados necesarios para validacion.
- No reimplementar reglas que ya vivan en `features/<area>/update.gleam`.

Si un route necesita demasiados parametros, la respuesta no debe ser crear un framework de adapters. Primero hay que revisar si el feature update esta exponiendo una politica demasiado amplia o si el route esta absorbiendo una responsabilidad que pertenece al feature.

## Refuerzo de tipos y ADT

El criterio de tipos queda asi:

- ADT obligatorio: estados que cambian comportamiento o hacen invalidas combinaciones de campos. Ejemplos: `TaskState`, `RuleTarget`, `ProjectGrant`, politicas de auth/refresh/root.
- Record suficiente: datos que siempre existen juntos y no representan alternativas excluyentes. Ejemplos: modelos de pantalla, contextos de update, formularios draft.
- Projection interna: datos de servidor que se parecen al dominio compartido pero incluyen campos privados de persistencia/autorizacion. Deben llamarse `Record`, `Projection`, `Row` o `Summary`.
- String aceptable: valores de formulario, JSON, SQL o DOM. Debe convertirse a ADT antes de decidir reglas de negocio.
- Option aceptable: ausencia real. No debe sustituir un ADT cuando hay estados con reglas distintas.

La mejora optima no consiste en envolver todos los IDs ni en convertir todos los formularios en ADTs. Consiste en asegurar que los estados con semantica de producto no se representen como combinaciones sueltas de flags, strings u options.

## Refuerzo DRY

DRY aqui significa "una unica fuente de decision", no "cero repeticion visual".

Repeticion que si debe eliminarse:

- Dos records publicos con el mismo significado.
- Dos presenters o mappers reconstruyendo el mismo estado de negocio.
- Dos update roots aplicando la misma auth policy con ramas divergentes.
- Tests que validan un facade viejo en lugar del owner real.

Repeticion que puede quedarse:

- Formularios con campos distintos aunque compartan layout.
- Contextos locales con nombres explicitos.
- Strings de `<select>` antes de submit.
- Helpers pequenos repetidos dos veces si extraerlos vuelve menos legible el flujo.

Esta distincion es importante para no convertir una limpieza de ownership en una capa generica accidental.

## Secuencia de cierre reforzada

Cada iteracion pendiente deberia cerrar con este bloque:

1. Barrido antes:
   - localizar imports del modulo antiguo;
   - medir responsabilidades con `rg` de funciones `apply_*`, `*_context`, `*_auth_error`;
   - identificar tests existentes del feature.
2. Corte pequeno:
   - mover un route o una projection, no varias familias a la vez;
   - mantener el contrato del feature;
   - evitar renombrados masivos si no cambian ownership.
3. Barrido despues:
   - confirmar que el root ya no contiene helpers del area extraida;
   - confirmar que los tests importan el owner real;
   - actualizar `docs/lustre_inventory.yml` si aparece o desaparece un modulo relevante.
4. Validacion:
   - `gleam format --check src test`;
   - `gleam check --target javascript` en cliente;
   - `gleam test --target javascript` en cliente;
   - checks de servidor cuando se toquen dominio, HTTP o persistencia.

Una iteracion no debe darse por cerrada si solo se movio codigo pero los nombres antiguos siguen siendo el punto de entrada mental del feature.

## Garantias de calidad exigibles

Cada fase debe cerrar con garantias distintas. No basta con que compile.

### Garantias de tipos

- No debe quedar ningun record publico duplicado con el mismo significado que un tipo compartido.
- Si dos records se parecen pero no son iguales, el nombre debe explicar la diferencia: contrato de dominio, row/projection de persistencia o estado de UI.
- Los ADT canonicos (`TaskState`, `RuleTarget`, `ProjectGrant`) deben ser el punto de decision de negocio; los strings solo deben vivir en DB, JSON o formularios DOM.
- Cualquier tipo movido fuera de `client_state/types.gleam` debe vivir junto al `Model` o feature que lo modifica.

### Garantias de DRY

- Una extraccion es valida si elimina duplicacion semantica, no solo lineas parecidas.
- No se debe crear un helper comun hasta que borre repeticion en tres sitios o elimine un estado invalido.
- Los presenters no deben reconstruir entidades que ya vienen normalizadas desde mappers o dominio.
- Los servicios no deben publicar un tipo local con el mismo nombre y forma que un tipo compartido.

### Garantias de tests

- Tras tocar dominio compartido: `gleam check` en cliente y servidor.
- Tras tocar presenters o contratos HTTP: tests de presenter/handler o tests de API que cubran JSON resultante.
- Tras mover estado de cliente: tests de update y view del feature afectado.
- Tras extraer updates grandes: al menos un test de dispatch feliz y uno de error/autorizacion por subflujo extraido.

### Garantias de limpieza

- Ejecutar `rg` para confirmar que el tipo antiguo ya no aparece en su owner incorrecto.
- Revisar imports muertos despues de cada movimiento; un import global que desaparece es buena senal de menor acoplamiento.
- No dejar aliases antiguos salvo que reduzcan el riesgo de migracion. Si se dejan, deben apuntar al nuevo owner y revisarse en un siguiente corte.
- Evitar renombrados masivos si no cambian responsabilidad real.

### Garantias de responsabilidad

Cada modulo nuevo o movido debe poder responder a una frase de ownership:

- `domain/*`: contrato semantico compartido por cliente y servidor.
- `services/*` o `persistence/*`: lectura/escritura, autorizacion interna o projection de DB.
- `http/*/presenters`: conversion a JSON, sin reconstruir reglas de negocio.
- `client_state/*`: estado que guarda la UI.
- `features/*/update`: transiciones y efectos de un flujo de producto.
- `components/*`: vista reutilizable sin ownership de datos remotos.

Si un modulo necesita dos frases independientes para describirse, probablemente todavia mezcla responsabilidades. Si un tipo se importa desde muchas areas solo porque "esta a mano", probablemente esta en el owner equivocado.

### Garantias de ADT y boundary

- Un ADT es obligatorio cuando las variantes cambian comportamiento o datos asociados, como `TaskState`, `RuleTarget` o `ProjectGrant`.
- Un record es suficiente cuando todos los campos existen simultaneamente y no codifican estados excluyentes.
- Un `Option` es correcto para ausencia real, no para esconder un estado con reglas propias.
- Un string es aceptable en formularios, SQL o JSON, pero debe convertirse a ADT antes de ejecutar reglas de negocio.
- Un tipo duplicado solo es aceptable si el nombre explica una projection distinta, por ejemplo `ProjectRecord` o `RuleSummary`.
- Un tipo opaco solo debe introducirse cuando protege una invariante que ya ha demostrado riesgo real o esta en una frontera publica estable.

## Refuerzo aplicado: registro de decisiones accionables

Este refuerzo convierte el informe en una herramienta de ejecucion. Cada
hallazgo accionable debe poder contestar cuatro preguntas:

1. Que decision duplicada elimina.
2. Que owner real recibe la responsabilidad.
3. Que tests o barridos demuestran que el corte quedo cerrado.
4. Que alternativa se descarta para evitar sobreingenieria.

Si una propuesta no puede responder esas preguntas, no debe pasar de candidato
a tarea de refactor.

### Hallazgo A: helpers admin de listas remotas con scope

Estado: ejecutado.

Evidencia:

```sh
rg "fn (prepend_for_scope|replace_loaded_by_id|remove_loaded_by_id|map_loaded)" \
  apps/client/src/scrumbringer_client/features/admin/workflows.gleam \
  apps/client/src/scrumbringer_client/features/admin/task_templates.gleam
```

Resultado observado antes del corte: los dos modulos mantenian el mismo bloque privado de
helpers para insertar, reemplazar y borrar elementos en `Remote(List(_))` con
scope de organizacion o proyecto.

Por que si merece refactor:

- La duplicacion no es visual: expresa la misma decision de producto, elegir si
  una entidad admin recien creada pertenece al scope de organizacion o al scope
  del proyecto seleccionado.
- El owner natural no es `workflows` ni `task_templates`, sino una utilidad
  pequena de admin para listas remotas con scope.
- La firma puede quedar estrecha y pura: no necesita `Model`, `Msg`, efectos,
  copy localizada ni reglas de negocio de workflow/template.
- Ya existen tests cercanos de update para workflows y task templates; se puede
  anadir un test unitario pequeno del helper sin depender de DOM.

Solucion ejecutada:

- Se creo `features/admin/scoped_remote_list.gleam`.
- Expone solo:
  - `prepend_for_scope(org, project, project_id, item)`;
  - `replace_by_id(remote, updated, id)`;
  - `remove_by_id(remote, target_id, id)`.
- Mantiene privados `prepend_loaded_or_new` y `map_loaded`.
- Sustituye los bloques privados duplicados en `workflows.gleam` y
  `task_templates.gleam`.
- Retira el import de `gleam/list` que ya no necesitaba `task_templates.gleam`.
- Anade `admin_scoped_remote_list_test.gleam` para cubrir scope, replace,
  remove y preservacion de estados no cargados.

Definition of Done:

| Garantia | Criterio |
| --- | --- |
| Duplicacion eliminada | Cumplido: el barrido anterior queda vacio en `workflows.gleam` y `task_templates.gleam` |
| Owner claro | Las operaciones puras viven en `features/admin/scoped_remote_list.gleam` |
| Sin framework CRUD | El helper no conoce dialogos, payloads, APIs ni `Msg` |
| Tests cercanos | `admin_scoped_remote_list_test.gleam` cubre scope, replace y remove; workflows/task templates conservan tests de update |
| Sin residuo | No queda un helper local equivalente renombrado en ninguno de los dos modulos |

Alternativas descartadas:

- Crear un motor CRUD admin generico: excesivo, porque el duplicado es solo la
  transformacion local de `Remote(List(_))`.
- Moverlo a `ui` o `client_state`: incorrecto, no es vista ni estado global.
- Mantener la duplicacion por estar solo en dos sitios: aqui si hay excepcion a
  la regla de tres usos porque el bloque es exacto, la firma es pequena y el
  owner de scope admin queda claro.

V/C/R:

| Valor | Complejidad | Riesgo | Decision |
| --- | --- | --- | --- |
| Medio-alto | Baja | Bajo | Ejecutado antes de otro corte amplio de pool o card trees |

### Hallazgo B: pool y card trees siguen grandes, pero no equivalen

Estado: parcial bajo vigilancia.

Evidencia actual:

- `features/pool/update.gleam` sigue cerca de 874 lineas.
- `features/card trees/update.gleam` sigue cerca de 182 lineas.
- Pool ya tiene `task_route.gleam`, `metrics_route.gleam`,
  `rule_metrics_route.gleam`, `positions_route.gleam`, `skills_route.gleam`
  y `route_support.gleam`.
- Card Trees ya saco filtros, seleccion, refresh, dialogos, movimientos, expansion y create a owners propios.

Lectura reforzada:

- Pool no debe cortarse otra vez por longitud. El siguiente corte valido debe
  encontrar otra familia funcional concreta, distinta de tareas, metricas
  operativas, metricas de reglas, posiciones, skills y auth, con handlers,
  apply y tests separables.
- Card Trees tampoco debe dividirse por secciones visuales. El siguiente corte
  solo tiene sentido si separa una responsabilidad de producto distinta de
  filtros, seleccion, refresh, dialogos, movimientos, expansion y create, y si
  reduce imports del root. El residuo actual se considera shell de contratos,
  feedback y root policy.

Control previo obligatorio:

```sh
rg -n "case inner|apply_|context|auth|refresh|dialog|selected_|expanded_" \
  apps/client/src/scrumbringer_client/features/pool/update.gleam \
  apps/client/src/scrumbringer_client/features/card trees/update.gleam
```

Decision:

- Posponer cualquier corte que solo divida por longitud.
- Con el helper admin ya ejecutado, priorizar el siguiente corte solo si el
  barrido encuentra otra duplicacion exacta o una familia funcional clara.

### Hallazgo C: raw buttons no deben tratarse como una deuda unica

Estado: parcial sano.

El informe queda reforzado con una clasificacion mas estricta: un `button` raw
es deuda solo si representa una accion simple que ya cabe en `ui/button`,
`ui/action_buttons`, `ui/task_actions`, `ui/dialog` o `ui/modal_close_button`.

No es deuda automatica cuando el boton es:

- primitiva del propio sistema de UI;
- control segmentado con `aria-pressed`;
- toggle de expansion con `aria-expanded` y contenido custom;
- control de drag, seleccion o interaccion gestual;
- superficie de compatibilidad que necesita decoders especificos.

Control:

```sh
rg -n "import lustre/element/html\\.\\{[^\\n]*button|^\\s*button\\(" \
  apps/client/src/scrumbringer_client
```

Interpretacion:

- No exigir cero matches.
- Clasificar cada match como primitiva, helper UI, control interactivo
  especifico o deuda migrable.
- Solo migrar el ultimo grupo.

### Hallazgo D: el balance de lineas no mide limpieza

Estado: criterio reforzado.

La diferencia desde `83081cff1cc1d04ca2ad907f60f7cd8841de4ad` muestra muchas
adiciones porque el trabajo incluyo features, tests, planes y documentacion. La
pregunta correcta no es si el diff tiene pocas lineas, sino si las lineas nuevas
dejaron owners mas fuertes que los anteriores.

Metricas que si importan:

- Menos tipos canonicos duplicados fuera de `shared`.
- Menos roots que conozcan subflujos internos.
- Mas tests cerca del modulo owner.
- Menos strings/sentinels fuera de fronteras tecnicas.
- Menos acciones simples reconstruyendo clases CSS en cada vista.

Metricas que no bastan:

- `wc -l` aislado.
- Ratio bruto de adiciones/borrados.
- Numero de ficheros creados.
- Numero de helpers extraidos.

Decision:

- Usar el balance de lineas solo como alarma para preguntar por ownership.
- No usarlo como criterio para forzar borrados que reduzcan claridad o pruebas.

## Encaje con la filosofia del producto

La filosofia del producto prioriza autoasignacion de tareas y comunicacion del equipo fuera del producto. Eso cambia la jerarquia de importancia tecnica:

- `Task` es la entidad central. Su estado, reclamacion, bloqueo, dependencia y asignacion deben tener el modelo mas fuerte.
- La UI debe hacer obvio que la tarea pertenece al flujo de trabajo del equipo, no a un sistema pesado de gestion interna.
- El codigo debe evitar duplicar reglas de ownership de tarea en distintos puntos, porque eso podria producir diferencias entre lo que el usuario ve, lo que el servidor permite y lo que los tests validan.
- Las entidades auxiliares (`Card`, `Workflow`, `Rule`, `Capability`) deben apoyar ese flujo sin convertirse en modelos paralelos con logica repetida.

Por ese motivo la mejora de `Task` tiene el mayor valor de producto, aunque no sea la primera por riesgo tecnico. La consolidacion inicial de `Card` y `RuleTemplate` es una forma barata de validar el patron antes de tocar la entidad que define la experiencia principal.

## 1. Dominio compartido y duplicacion de entidades

### 1.1 `Task`

Problema original:

- Existe una `Task` canonica en `shared/src/domain/task.gleam`.
- El servidor tambien definia una `Task` publica en `apps/server/src/scrumbringer_server/persistence/tasks/mappers.gleam`.
- La version del servidor reconstruye parcialmente el contrato: expone `type_id`, `type_name`, `type_icon` y `ongoing_by_user_id`, mientras el dominio compartido ya modela `TaskTypeInline` y `OngoingBy`.
- `apps/server/src/scrumbringer_server/http/tasks/presenters.gleam` volvia a montar JSON con logica que ya podia derivar de la entidad compartida.

Mejora concreta:

- Cambiar el mapper del servidor para devolver `domain/task.Task`.
- Construir ahi `TaskTypeInline(id: type_id, name: type_name, icon: type_icon)`.
- Construir ahi `ongoing_by: Option(OngoingBy)` en vez de propagar `ongoing_by_user_id`.
- Mantener cualquier shape SQL intermedio como tipo privado y nombrado explicitamente, por ejemplo `TaskRowProjection`, si hace falta separar lectura SQL de entidad de dominio.
- Revisar el presenter para aceptar `domain/task.Task` y eliminar duplicaciones de campos.

Estado actual:

- Ejecutado: el mapper de tareas devuelve `domain/task.Task`.
- Ejecutado: el presenter acepta `domain/task.Task`.
- Ejecutado: `TaskTypeInline` y `OngoingBy` se construyen antes de llegar al presenter.
- Ejecutado: `status` y `work_state` del JSON se derivan desde `TaskState`, no desde campos redundantes.
- Protegido por test: `task_json_derives_status_and_work_state_from_task_state_test` cubre drift entre `TaskState` y campos obsoletos.

Impacto DRY:

- Desaparece una entidad publica que compite con la canonica.
- Se reduce la reconstruccion manual de `task_type` y `ongoing_by`.
- El cliente y el servidor pasan a hablar la misma forma semantica, no dos variantes parecidas.

Impacto de tipos:

- `TaskState`, `TaskStatus`, `WorkState`, `TaskTypeInline` y `OngoingBy` quedan alineados en un unico record canonico.
- El servidor deja de filtrar detalles parciales que obligan a recomponer significado mas tarde.

Riesgo y limite:

- Es el cambio de mayor impacto porque toca mapper, presenter y tests HTTP.
- No conviene crear una capa generica de "projection mapper"; basta con una conversion local y explicita.

### 1.2 `Card`

Problema:

- `shared/src/domain/card.gleam` define `Card`.
- `apps/server/src/scrumbringer_server/services/cards_db.gleam` define otro `Card` con la misma forma.
- El modulo del servidor ya usa funciones del dominio de card para color y estado, pero mantiene el record duplicado.

Mejora concreta:

- Eliminar el `Card` local de `cards_db.gleam`.
- Importar `domain/card.{type Card, Card}`.
- Mantener la logica SQL en el servicio, pero devolver la entidad compartida.
- Ajustar presenters y handlers que hoy dependan del tipo de `cards_db`.

Impacto DRY:

- Es una consolidacion directa, con bajo riesgo y alto retorno.
- Evita que futuras evoluciones de `Card` tengan que hacerse en dos records.

Impacto de tipos:

- El contrato de card queda definido una sola vez.
- Las reglas de color y estado siguen en el dominio, donde ya estan.

Riesgo y limite:

- Bajo. Es un buen primer cambio para validar el patron antes de abordar `Task`.

### 1.3 `Project` y `ProjectMember`

Problema:

- El dominio compartido define `Project` y `ProjectMember`.
- El servidor define variantes parecidas pero con campos extra: `org_id` en `Project` y `project_id` en `ProjectMember`.
- Esos campos extra pueden ser necesarios para autorizacion y consultas internas.

Mejora concreta:

- No reemplazar automaticamente estos tipos por los compartidos.
- Renombrar los tipos internos del servidor si son proyecciones de persistencia, por ejemplo `ProjectRecord` y `ProjectMemberRecord`.
- Convertir a `domain/project.Project` y `domain/project.ProjectMember` en la frontera HTTP cuando se responde al cliente.
- Mantener los campos internos solo en los servicios que los necesitan.

Estado actual:

- Ejecutado el renombrado de proyecciones internas.
- `scrumbringer_server/services/projects_db.gleam` expone `ProjectRecord` y `ProjectMemberRecord`.
- `scrumbringer_server/services/store_state.gleam` expone `StoredProject` y `StoredProjectMember`.
- El barrido `rg "pub type Project \\{|pub type ProjectMember \\{" apps/server/src/scrumbringer_server shared/src` solo debe encontrar los tipos canonicos en `shared/src/domain/project.gleam`.
- Ejecutado: `http/projects/presenters.gleam` no expone `org_id` de `ProjectRecord` ni `project_id` de `ProjectMemberRecord`.
- Protegido por tests: `project_json_does_not_expose_internal_org_id_test` y `project_member_json_does_not_expose_internal_project_id_test`.

Impacto DRY:

- Se elimina la ambiguedad de tener dos `Project` publicos con significados distintos.
- No se fuerza al dominio compartido a cargar campos que solo existen para autorizacion del servidor.

Impacto de tipos:

- El nombre del tipo explica la responsabilidad: contrato compartido frente a record interno.
- Se evita mezclar identidad organizativa interna con el modelo que consume la UI.

Riesgo y limite:

- Medio. Requiere revisar llamadas para no perder `org_id` donde sea necesario.
- No conviene crear wrappers de ID para todo ahora; primero hay que aclarar responsabilidades de records.
- No mover `org_id` ni `project_id` internos al dominio compartido: siguen siendo campos de autorizacion/persistencia del servidor.

### 1.4 `Workflow`, `Rule` y `RuleTemplate`

Problema:

- El dominio compartido ya define `Workflow`, `Rule`, `RuleTemplate` y el ADT `RuleTarget`.
- El servidor duplica `Workflow`, `Rule` y `RuleTemplate` en servicios.
- `RuleTarget` esta bien centralizado, pero los records no.
- La `Rule` compartida incluye `templates`, mientras algunas consultas del servidor manejan reglas sin plantillas.

Mejora concreta:

- Usar `domain/workflow.RuleTemplate` directamente en servidor.
- Para `Workflow`, usar el tipo compartido cuando la entidad represente el contrato de producto. Si una consulta es estrictamente interna, renombrarla como projection.
- Para `Rule`, decidir explicitamente entre:
  - devolver `domain/workflow.Rule` con `templates: []` cuando la ausencia de plantillas sea solo una optimizacion de consulta;
  - crear un `RuleSummary` interno si semanticamente no se estan cargando detalles completos.
- Mantener `RuleTarget` como ADT canonico y limitar `resource_type`/`to_state` string a SQL y JSON.

Impacto DRY:

- Se elimina duplicacion de `RuleTemplate`.
- Se reduce la probabilidad de drift entre reglas compartidas y reglas de servidor.

Impacto de tipos:

- `RuleTarget` sigue expresando correctamente que una regla apunta a task o card con estados distintos.
- `RuleSummary` solo deberia existir si realmente representa una lectura parcial. Si no, el tipo compartido es suficiente.

Riesgo y limite:

- Bajo para `RuleTemplate`.
- Medio para `Rule`, porque hay que confirmar si las plantillas ausentes significan "no cargadas" o "no hay".
- No conviene introducir un ADT de carga generico tipo `Loaded/NotLoaded` para todos los records.

### 1.5 API tokens e integration users

Problema detectado:

- El servidor modelaba bien `ProjectGrant` como ADT: `AllProjects | ProjectOnly(Int)`, pero el ADT vivia en el servicio operativo de tokens.
- El cliente mantenia tipos de API tokens e integration users dentro de `client_state/types.gleam`.
- No existia un contrato compartido claro para los metadatos publicos del token.

Mejora concreta:

- Crear un modulo compartido pequeno, por ejemplo `shared/src/domain/api_token.gleam`, con:
  - `ApiToken`
  - `CreatedApiToken`
  - `IntegrationUser`
  - `ProjectGrant` para hacer explicita la semantica de `project_id`.
- Mantener `VerifiedToken`, `bearer` y detalles de verificacion exclusivamente en servidor.
- Mover `ApiTokensModel` y `ApiTokenForm` a un modulo de estado de admin del cliente, no al dominio.

Impacto DRY:

- El contrato que viaja por HTTP queda definido una vez.
- Se limpia `client_state/types.gleam`, que antes mezclaba entidades, formularios y estado de interaccion.

Impacto de tipos:

- `ProjectGrant` es un buen ADT porque evita confundir "todos los proyectos" con "project_id ausente por error".
- La UI puede seguir recibiendo `project_id: Option(Int)` en el codec mientras el contrato HTTP siga siendo nullable; la conversion semantica queda centralizada en el dominio compartido.

Riesgo y limite:

- Medio-bajo. Requiere ajustar decoders y presenters.
- No se deben compartir tipos internos de seguridad del servidor.

Estado actual:

- El contrato publico vive en `shared/src/domain/api_token.gleam`.
- `ProjectGrant` y sus conversiones viven en `shared/src/domain/api_token.gleam`.
- El estado de pantalla vive en `client_state/admin/api_tokens.gleam`.
- El servidor mantiene fuera del dominio compartido los detalles que pertenecen a seguridad/verificacion.

## 2. ADT, strings y flags

### 2.1 Estados de tarea

Situacion actual:

- `TaskState` esta bien modelado como ADT: disponible, reclamada y completada no son flags independientes.
- `TaskStatus` y `WorkState` conviven con `TaskState`.
- El mapper y el presenter ya derivan `TaskStatus` y `WorkState` desde `TaskState`; los campos redundantes quedan como compatibilidad del contrato compartido, no como fuente de decision.

Mejora concreta:

- Mantener `TaskState` como owner del ciclo de vida con metadatos.
- Derivar `TaskStatus` y `WorkState` desde `TaskState` cuando se pueda.
- Evitar que mappers o presenters calculen estados en paralelo desde flags sueltos.
- Consolidar conversiones de DB alrededor de `task_state.from_db` cuando se necesiten `claimed_by`, `claimed_at` o `completed_at`.

Impacto:

- Reduce combinaciones invalidas como `completed_at` con estado disponible.
- Evita divergencias entre status textual, claim metadata y work state.

Limite:

- No eliminar `TaskStatus` si sigue siendo util como contrato compacto, filtro o campo SQL.

### 2.2 `RuleTarget`

Situacion actual:

- `RuleTarget` ya captura bien la diferencia entre reglas de task y reglas de card.
- El servidor traduce strings de DB a ADT y ADT a columnas.
- El dialogo de reglas en cliente guarda `resource_type` y `to_state` como strings de formulario.

Mejora concreta:

- Mantener strings en el formulario si son valores directos de `<select>`.
- Convertir una sola vez a `RuleTarget` en submit/validacion.
- Evitar branching de negocio repartido por strings como `"task"` o `"card"`.
- Si se repite mucha logica de formulario, crear un `RuleTargetDraft` local al dialogo, no un nuevo tipo global.

Impacto:

- La logica de negocio queda tipada.
- La UI sigue simple y no se sobre-modela el DOM.

### 2.3 Sentinels en SQL

Problema:

- Hay sentinels como `"__unset__"`, `0` o `-1` para representar campos no actualizados o ausentes en operaciones SQL.
- Son practicos, pero fragiles si se propagan fuera de la frontera de persistencia.
- En tasks ya existe una API superior correcta (`FieldUpdate`) para updates parciales, y la conversion a parametros SQL queda confinada en constantes privadas de `persistence/tasks/queries.gleam`.
- En cards y workflows el patron ya esta mejor encaminado porque los valores tecnicos tienen constantes privadas (`no_card tree_*`, `unchanged_text_value`).

Mejora concreta:

- Encapsular cada sentinel en funciones privadas del modulo que habla con SQL.
- Nombrar esas funciones por semantica, no por valor tecnico.
- Cuando varios modulos repitan exactamente el mismo patron, extraer un helper de persistencia pequeno.
- En `persistence/tasks/queries.gleam`, mantener nombres privados para:
  - filtro sin id seleccionado;
  - id opcional ausente en create;
  - texto sin cambio en update;
  - id opcional sin cambio;
  - id opcional borrado.
- Mantener `sql/tasks_update.sql` como frontera tecnica: puede seguir comparando contra `$7 = -1` o `$3 = '__unset__'`, siempre que el valor venga nombrado desde Gleam y no suba a dominio/servicio.
- Mantener el mismo patron en `task_templates_db.gleam` y `card trees_db.gleam`, donde los valores de update/create tambien quedan nombrados localmente.

Impacto:

- Se limita el dano de valores magicos.
- Se evita crear un sistema generico de parametros nullable antes de comprobar que realmente compensa.
- Se preserva el contrato SQL generado por squirrel, por lo que el riesgo de regresion queda bajo.

Criterio de cierre:

- `rg "\"__unset__\"|-1|option_to_value\\(value, 0\\)" apps/server/src/scrumbringer_server/persistence apps/server/src/scrumbringer_server/services` puede seguir encontrando SQL generado o casos legitimos, pero cada match manual debe estar en una constante privada, una funcion de conversion de frontera o una query SQL.
- Ningun modulo de dominio, HTTP validator o workflow handler debe conocer los valores concretos `0`, `-1` o `"__unset__"` como significado de update.
- No introducir helpers publicos hasta que al menos tres modulos compartan exactamente la misma semantica de sentinel.

## 3. Responsabilidad de estado en cliente

Problema detectado:

- `apps/client/src/scrumbringer_client/client_state/types.gleam` funcionaba como cajon global.
- Mezclaba:
  - estado generico de UI;
  - modelos de API tokens;
  - dialog modes;
  - formularios de proyectos;
  - modelos de assignments.

Mejora concreta:

- Mantener solo tipos verdaderamente transversales en modulos pequenos, por ejemplo:
  - `client_state/dialog_state.gleam`
  - `client_state/operation_state.gleam`
- Mover tipos de API tokens a:
  - dominio compartido para entidades de contrato;
  - `client_state/admin/api_tokens.gleam` para formulario y modelo de pantalla.
- Mover `AssignmentsModel` y `AssignmentsAddContext` a `client_state/admin/assignments.gleam`.
- Mover `ReleaseAllTarget` a `client_state/admin/members.gleam`.
- Mover tipos de drag a un owner de pool, por ejemplo `client_state/member/pool.gleam`, si solo se usan ahi.
- Mover dialog modes junto al feature que los consume.

Impacto DRY:

- Baja el numero de imports globales que arrastran tipos no relacionados.
- Hace mas barato cambiar una pantalla sin tocar un modulo compartido por accidente.

Impacto de tipos:

- Cada tipo queda cerca de su owner real.
- Los records dejan de parecer dominio cuando son estado de UI.

Riesgo y limite:

- Medio por numero de imports.
- Debe hacerse por grupos, no en un unico cambio masivo.
- No crear un nuevo `types.gleam` por feature si el modulo de estado existente ya es suficiente.

Estado actual:

- El modulo global queda reducido a `OperationState` y `DialogState`.
- Los modelos/formularios/targets de pantalla ya viven en los modulos de estado que los poseen.
- El siguiente riesgo no es el modulo global, sino la concentracion de orquestacion en updates grandes.

Estado recomendado tras la primera limpieza:

- `client_state/types.gleam` queda reducido a `OperationState` y `DialogState`, que son transversales y tienen uso real en varios features.
- `client_state/admin/api_tokens.gleam`, `client_state/admin/assignments.gleam`, `client_state/admin/members.gleam`, `client_state/admin/invites.gleam`, `client_state/admin/projects.gleam`, `client_state/admin/task_types.gleam` y `client_state/member/pool.gleam` son ejemplos del patron correcto: el `Model`, el formulario/contexto, el target de dialogo, el preview o el estado de interaccion viven con el owner que los actualiza.
- Los aliases publicos especificos de feature ya no deben mantenerse en `client_state.gleam`. Si un modulo necesita `InviteLinkForm`, `TaskTemplateDialogMode`, `Rect` o `AssignmentsModel`, debe importar el modulo owner.

Siguiente limpieza optima, sin sobreingenieria:

1. Revisar `features/admin/update.gleam`.
2. Extraer solo subflujos con owner claro y tests existentes: rutas por area en admin.
3. No introducir dispatcher generico ni framework TEA.
4. Mantener `DialogState` y `OperationState` transversales mientras sigan compartidos por varios features.
5. Mantener en `client_state.gleam` solo aliases transversales o root-model; no anadir nuevos tipos especificos al cajon global.

## 4. Modulos grandes de update y organizacion

### 4.1 `features/tasks/*_update.gleam`

Problema:

- El modulo `features/tasks/update.gleam` agrupaba creacion, mutacion, detalle y notas.
- Ya existen modulos de estado como `create_state`, `detail_state`, `note_state` y `mutation_state`, pero parte de la logica sigue concentrada en el update principal.

Mejora concreta:

- Extraer por responsabilidad:
  - `features/tasks/create_update.gleam`
  - `features/tasks/detail_update.gleam`
  - `features/tasks/notes_update.gleam`
  - reforzar `features/tasks/mutation_update.gleam`
- Eliminar `features/tasks/update.gleam` cuando los cuatro owners sean directos.

Estado actual:

- Creacion ejecutada. `features/tasks/create_update.gleam` expone solo `Context`, `Policy`, `Update` y `try_update`; los handlers locales de apertura, validacion, submit y respuesta son privados y los tests cubren el flujo por mensajes `MemberCreate*`.
- Notas ejecutado. `features/tasks/notes_update.gleam` expone solo `Context`, `AuthPolicy`, `Update` y `try_update`; los handlers locales de carga, dialogo, submit, creacion y borrado son privados y los tests cubren el flujo por mensajes `MemberNote*`.
- Mutacion ejecutada. `features/tasks/mutation_update.gleam` contiene `MutationContext`, `DispatchContext`, `Policy`, `Update`, `try_update`, optimistic update y rollback. Los handlers de click/success/error son privados; `handle_claim_dropped` queda publico porque `pool/drag_update.gleam` lo usa como integracion real de drag, y `should_refetch_work_sessions`/`error_feedback` quedan publicos como helpers puros con tests directos.
- Detalle ejecutado. `features/tasks/detail_update.gleam` expone solo contratos reales, `try_update` y `error_feedback`; apertura/cierre, tabs, edicion, metricas, update ok/error y `error_effect` son internos. Los tests cubren el comportamiento por mensajes `MemberTaskDetail*`, `MemberTaskUpdated` y `MemberTaskMetricsFetched`, salvo `error_feedback` como helper puro.
- `features/tasks/update.gleam` fue eliminado como modulo obsoleto.
- `features/pool/task_route.gleam` es ahora el adapter de area que une pool con create/notes/dependencies/mutation/detail.
- `features/pool/update.gleam` ya no importa los subupdates concretos de tarea ni conoce su orden interno.
- `features/pool/drag_update.gleam` mantiene la interaccion de drag, pero recibe el `MutationContext` desde `task_route.mutation_context` para no duplicar el contrato de mutacion.

Mejor corte pendiente:

- No queda corte pendiente en tasks. Los tests de create, notes, mutation y detail importan los owners reales.
- En pool no queda pendiente el corte de la familia tarea; cualquier nuevo corte debe demostrar otra familia funcional con mezcla de contexto/apply/auth, no solo tamano de archivo.

Por que este corte es mejor que un dispatcher generico:

- El detalle tiene reglas propias: carga paralela, tabs, formularios y autorizacion de edicion.
- Las mutaciones de tarea tienen reglas distintas: usuario actual, bloqueo por dependencia, optimistic update, rollback y refresh.
- Pool necesita adaptar esos flujos al estado member (`pool`, `notes`, `dependencies`) y al refresh de la vista; eso justifica un route de area, no un subupdate generico.
- Un dispatcher comun habria juntado conceptos que el producto mantiene separados.

Impacto:

- Cada flujo queda testeable y localizable.
- Se reutilizan modulos existentes en vez de inventar una arquitectura nueva.
- `pool/update.gleam` baja a 874 lineas tras extraer tambien `metrics_route.gleam`, `rule_metrics_route.gleam`, `positions_route.gleam` y `skills_route.gleam`; conserva dispatch principal, now-working y fallback exhaustivo.
- `pool/task_route.gleam` queda en 631 lineas con una responsabilidad unica: adaptar la familia tarea dentro de pool.

Limite:

- No introducir un dispatcher generico de TEA. La forma actual de Lustre ya da una estructura suficiente.

### 4.2 `features/admin/update.gleam`

Problema:

- Mezcla proyectos, invitaciones, assignments, API tokens y varios apply/update helpers.
- Hay repeticion de patrones de contexto, autorizacion y aplicacion de subupdates.

Mejora concreta:

- Extraer adapters por area:
  - `features/admin/projects_route.gleam`
  - `features/admin/invites_route.gleam`
  - `features/admin/assignments_route.gleam`
  - `features/admin/api_tokens_route.gleam`
  - `features/admin/members_route.gleam`
- Cada adapter deberia construir contexto, llamar al update de feature y aplicar resultado.

Orden recomendado:

1. API tokens, ejecutado porque ya tenia contrato compartido y estado propio.
2. Assignments, ejecutado porque ya tenia update propio y politicas de root claras.
3. Capabilities, ejecutado porque ya se habia validado la separacion en `features/capabilities`.
4. Projects, ejecutado despues porque sincroniza `core.projects` y `selected_project_id`.
5. Invites, ejecutado como corte pequeno para consolidar el patron.
6. Task types, ejecutado porque arrastra refresh de seccion y dialogos CRUD.
7. Org settings, ejecutado porque conectaba permisos, cache de usuarios, assignments y usuario actual.
8. Members/search, ejecutado porque el root conocia seis adapters hermanos y el orden interno de esa familia.
9. Resto de CRUD admin solo si otro barrido demuestra que los adapters locales restantes mezclan responsabilidad real.

Estado actual:

- API tokens ejecutado. `features/admin/api_tokens_route.gleam` contiene `try_update`, construccion de contexto localizado, conversion de `AuthPolicy` y apply del submodelo `api_tokens`.
- `features/admin/update.gleam` delega en `api_tokens_route.try_update` y ya no importa `api_tokens_update`.
- Assignments ejecutado. `features/admin/assignments_route.gleam` contiene `try_update`, construccion de contexto, feedback, auth timing before/after, root policies y `start_user_projects_fetch` para el caso disparado desde org settings.
- `features/admin/update.gleam` delega en `assignments_route.try_update` y ya no importa `features/assignments/update.gleam`.
- Capabilities ejecutado. `features/admin/capabilities_route.gleam` contiene `try_update`, selected project, textos localizados, feedback de exito/error, auth y apply del submodelo `capabilities`.
- `features/admin/update.gleam` delega en `capabilities_route.try_update` y ya no importa `features/capabilities/update.gleam`.
- Projects ejecutado. `features/admin/projects_route.gleam` contiene `try_update`, contexto localizado, feedback, auth y sincronizacion explicita de `core.projects` y `selected_project_id`.
- `features/admin/update.gleam` delega en `projects_route.try_update` y ya no importa `features/projects/update.gleam`.
- Invites ejecutado. `features/admin/invites_route.gleam` contiene `try_update`, contexto localizado, feedback, auth y apply del submodelo `invites`.
- `features/admin/update.gleam` delega en `invites_route.try_update` y ya no importa `features/invites/update.gleam`.
- Task types ejecutado. `features/admin/task_types_route.gleam` contiene `try_update`, contexto localizado, feedback, auth, apply del submodelo y ejecucion explicita de `RefreshPolicy`.
- `features/admin/update.gleam` delega en `task_types_route.try_update` y ya no importa `features/task_types/update.gleam`.
- Org settings ejecutado. `features/admin/org_settings_route.gleam` contiene `try_update`, contexto localizado, feedback, auth, apply de `admin.members` y politicas root para `assignments_route.start_user_projects_fetch` y `org_settings.current_user_after_saved`.
- `features/admin/update.gleam` delega en `org_settings_route.try_update` y ya no importa `features/admin/org_settings.gleam` directamente.
- Members/search ejecutado. `features/admin/members_route.gleam` contiene el routing de area para member list/add/remove/release-all/role/search y delega en los adapters concretos ya testeados.
- `features/admin/update.gleam` delega en `members_route.try_update` y ya no importa `member_list_update`, `member_add_update`, `member_remove_update`, `member_release_all_update`, `member_role_update` ni `search_update`.
- Route support ejecutado. `features/admin/route_support.gleam` contiene solo `apply_auth_check_before` y `apply_auth_check_after`; los `auth_error` quedan locales a cada route.
- El siguiente corte admin no debe asumirse por tamano: debe salir de un barrido que demuestre helpers repetidos, responsabilidad mezclada o tests atrapados en el root.

Impacto:

- Reduce la longitud del update principal.
- Evita que cualquier cambio de una seccion de admin toque todo el modulo.

Limite:

- No crear un `UpdateAdapter` generico hasta que tres o mas rutas compartan exactamente la misma firma y comportamiento.

### 4.3 `features/capabilities/update.gleam`

Problema:

- Mezcla CRUD de capabilities, asignaciones capability->member, asignaciones member->capability, feedback y lookup helpers.

Mejora concreta:

- Separar:
  - `features/capabilities/crud_update.gleam`
  - `features/capabilities/assignments_update.gleam`
- Mantener `features/capabilities/update.gleam` como delegador fino.

Estado actual:

- Ejecutado. `update.gleam` conserva el dispatch, `AuthPolicy` y la composicion de feedback/autorizacion.
- Ejecutado el cierre de facade: `update.gleam` ya no reexporta `Context`, `Success`, `FeedbackContext`, `ErrorFeedbackContext` ni un wrapper `success_effect`; los consumidores usan `features/capabilities/types.gleam` como owner del contrato.
- `crud_update.gleam` contiene listado y create/edit/delete de capabilities.
- `assignments_update.gleam` contiene asignacion member->capability y capability->member.
- `types.gleam` contiene el contrato compartido del feature para evitar ciclos entre el dispatch y los subupdates.

Impacto:

- Es una extraccion con fronteras claras.
- Reduce el acoplamiento entre gestion de catalogo y membresia/asignaciones.

Limite:

- No fusionar esto con assignments de proyecto si las reglas de producto no son identicas.

### 4.4 `features/pool/update.gleam` y `features/card trees/update.gleam`

Problema:

- Son modulos grandes, pero parte de su tamano viene de orquestar muchos subflujos.
- Ya existen modulos auxiliares en card trees y rutas parciales en pool.

Mejora concreta:

- No empezar por una division mecanica por longitud.
- En card trees, mantener el primer corte de filtros ejecutado: `filters.gleam` ya contiene `toggle_show_completed`, `toggle_show_empty` y `set_search_query`.
- En card trees, mantener el corte de seleccion ejecutado: `selection.gleam` ya contiene `select_card tree` junto a `selected_progress`.
- En card trees, mantener el corte de refresh ejecutado: `refresh.gleam` ya contiene el routing de `MemberProjectCard TreesFetched` siguiendo el patron existente de `pool/card_refresh.gleam`.
- En card trees, mantener el corte de dialogos ejecutado: `dialog_update.gleam` contiene apertura/cierre, cambios de campos, submits y respuestas de create/edit/delete/activate; el atajo Escape en `pool/shortcut_update.gleam` consume ese owner directamente.
- En card trees, mantener tambien el corte de movimiento ejecutado: `movement_update.gleam` contiene drag start/end, drop, movimiento por click de cards/tasks, validacion de card trees `Ready`, lookup de origen y respuestas ok/error.
- En card trees, mantener tambien el corte de expansion ejecutado: `expansion.gleam` contiene toggle de summary y cards expandidas, con tests directos de expand/collapse y preservacion de otras cards.
- En card trees, mantener tambien el corte de create ejecutado: `create_update.gleam` contiene quick-create de task/card desde card trees, y el route aplica la root policy de abrir card dialog.
- En card trees, mover los siguientes handlers solo a modulos nuevos o existentes cuando el owner sea igual de claro; no quedan candidatos evidentes distintos de contratos, feedback y root policy tras filtros, seleccion, refresh, dialogos, movimientos, expansion y create.
- En pool, mantener el corte ya ejecutado de `task_route.gleam` como owner de la familia tarea.
- En pool, extraer nuevos adapters solo si aparece otra familia clara con mezcla de contexto, auth, efectos y apply.
- No mover drag completo a `task_route.gleam`: drag es interaccion de pool; solo reutiliza `mutation_context` porque esa parte si pertenece a tarea.
- No mover summary/card expansion a `filters.gleam`: son estado de vista, no criterio de filtrado; el owner correcto es `card trees/expansion.gleam`.
- No crear `card trees/route.gleam` todavia: `pool/card trees_route.gleam` ya compone los workflows root-aware y dentro de card trees cada familia extraida tiene owner concreto.

Impacto:

- Se reduce riesgo de regresion.
- Las extracciones siguen el lenguaje del producto, no una clasificacion artificial.
- La reduccion del root no se mide solo por lineas: se mide por imports retirados, owners claros y tests cercanos.

## 5. Reutilizacion UI y CRUD

Problema:

- Existe `crud_dialog_base.gleam`, que ya centraliza lifecycle, validaciones simples, shell, botones y submit idle.
- Los dialogos CRUD todavia repiten modelos, mensajes y vistas create/edit/delete.
- Parte de los botones historicos usa clases raw en vez de helpers de `ui/button`.

Mejora concreta:

- No crear un componente CRUD universal.
- Ampliar `crud_dialog_base` solo con helpers pequenos y comprobados:
  - campo de texto requerido;
  - campo de descripcion;
  - bloque de confirmacion destructiva;
  - helper de error de validacion;
  - botones submit/cancel/danger alineados con `ui/button`.
- Aplicar los helpers por dialogo y eliminar duplicacion solo cuando el resultado siga siendo legible.

Impacto DRY:

- Reduce repeticion real sin ocultar los formularios de negocio.
- Mantiene cada dialogo facil de leer y modificar.

Impacto UI/UX:

- Botones, estados loading, danger y errores quedan mas consistentes.
- Menos divergencia visual accidental entre entidades editables.

Limite:

- Si un helper necesita muchos parametros o callbacks, probablemente es peor que repetir cinco lineas locales.

## 6. Modelado de errores

Problema:

- Hay buenos errores especificos en varios servicios.
- En algunos flujos se colapsan errores a strings genericos demasiado pronto, por ejemplo validaciones de workflows.

Mejora concreta:

- Mantener errores tipados hasta la frontera HTTP o UI.
- Crear variantes concretas solo cuando cambien el tratamiento:
  - `InvalidTypeId`
  - `InvalidCardId`
  - `InvalidCard TreeId`
  - `InvalidCapabilityId`
- Conservar un fallback como `InvalidReference(String)` si hay referencias poco frecuentes.

Impacto:

- Mejores tests.
- Mejor copy de error.
- Menos parsing de strings.

Limite:

- No modelar cada mensaje textual como variante si la aplicacion no lo distingue.

## Plan recomendado

Este plan debe leerse como plan vivo. Las fases ya ejecutadas quedan como referencia del patron validado y de sus criterios de cierre; no implican que haya que rehacerlas. Las fases parciales o pendientes indican el siguiente trabajo real.

### Fase 1: consolidaciones de bajo riesgo

Estado: ejecutada en los puntos principales; los sentinels revisados quedan tratados como frontera tecnica nombrada.

1. Sustituir el `Card` duplicado del servidor por `domain/card.Card`.
2. Sustituir `RuleTemplate` duplicado por `domain/workflow.RuleTemplate`.
3. Encapsular sentinels SQL existentes con nombres privados y revisar que no salgan de persistencia.
4. Anadir tests de mapper/presenter donde se toque el contrato JSON.

Resultado esperado:

- Menos duplicacion de records.
- Primer patron validado sin cambiar flujos complejos.

Criterio de cierre:

- `rg "pub type Card \\{|pub type RuleTemplate \\{" apps/server/src/scrumbringer_server` no debe encontrar duplicados publicos en servicios.
- Los handlers que respondan cards/rules deben depender del dominio compartido o de projections internas con nombre explicito.

### Fase 2: consolidacion de `Task`

Estado: ejecutada en mapper y presenter. Queda vigilancia futura para no reintroducir calculos paralelos de lifecycle en nuevos handlers o presenters.

1. Hacer que el mapper de tareas devuelva `domain/task.Task`.
2. Eliminar el `Task` publico del mapper o renombrar una projection interna si sigue haciendo falta.
3. Ajustar presenters y tests HTTP.
4. Revisar que `TaskState` sea la fuente para derivar status/work state.

Resultado esperado:

- La entidad central del producto queda con un unico contrato semantico.
- Menos reconstruccion manual en servidor.

Criterio de cierre:

- El mapper de tareas no debe exportar una `Task` propia.
- El presenter debe aceptar `domain/task.Task`.
- El presenter debe derivar `status` y `work_state` desde `TaskState`.
- Los tests deben cubrir drift entre campos redundantes y `TaskState`. El test unitario actual cubre el caso de mayor riesgo visible: claimed/ongoing con campos obsoletos.
- Si se cambia el contrato compartido de `Task`, entonces si conviene ampliar cobertura a disponible, reclamada, ongoing y completada en codec/presenter.

### Fase 3: limpieza de estado cliente

Estado: ejecutada para el cajon global principal y para los aliases publicos especificos de feature. Queda como riesgo cualquier import nuevo que vuelva a usar `client_state.gleam` como owner accidental.

1. Extraer API token entities/form/model del cajon global.
2. Extraer assignments a su modulo de admin.
3. Extraer drag state al owner de pool.
4. Extraer dialog modes a sus owners admin.
5. Extraer formularios/search/icon preview a owners admin.
6. Dejar en tipos globales solo piezas verdaderamente transversales.

Resultado esperado:

- Menor acoplamiento entre pantallas.
- Imports mas explicitos.
- Mejor responsabilidad de tipos.

Criterio de cierre:

- `client_state/types.gleam` no debe contener modelos de pantalla como `ApiTokensModel`, `AssignmentsModel` o targets de dialogo especificos.
- `client_state/types.gleam` debe contener solo `OperationState` y `DialogState`, salvo que otro tipo demuestre uso transversal real.
- Cada estado movido debe tener tests del feature pasando sin depender de constructores desde el modulo global.
- Las migraciones deben hacerse por feature para que el compilador actue como red de seguridad.

### Fase 4: modularizacion de updates

Estado: parcial avanzado. Capabilities, los cuatro flujos de tasks, `pool/task_route`, `admin/api_tokens_route`, `admin/assignments_route`, `admin/capabilities_route`, `admin/projects_route`, `admin/invites_route`, `admin/task_types_route`, `admin/org_settings_route` y `admin/members_route` ya prueban el patron. Los soportes comunes extraidos son deliberadamente pequenos: `admin/route_support.gleam` y `pool/route_support.gleam`, ambos limitados a auth before/after.

1. Mantener `members_route.gleam` como agregacion de area: agrupa list/add/remove/release-all/role/search y reduce imports/cadena del root.
2. Mantener tasks como referencia de corte ejecutado: owners concretos y sin modulo orquestador obsoleto.
3. Mantener capabilities como referencia de corte ya ejecutado: dispatch fino mas subupdates concretos.
4. Mantener `pool/task_route.gleam` como route de familia: agrupa los adapters de tarea que antes vivian en el root de pool.
5. Mantener los `route_support.gleam` limitados a auth before/after; no ampliarlos a contextos, feedback o ADTs.
6. Revisar card trees solo con la misma evidencia: owner funcional claro, tests cercanos y barrido de imports antes/despues.

Resultado esperado:

- Updates mas pequenos.
- Menos repeticion de context/apply.
- Roots que sigan existiendo como shells de dispatch y no como owners ocultos de varios subflujos.
- Menor riesgo al cambiar una funcionalidad concreta.

Criterio de cierre:

- El modulo principal debe quedar como orquestador legible, no como owner de todas las transiciones. En capabilities, este criterio ya se cumple.
- Cada subupdate debe exponer una API concreta de feature, no un dispatcher generico.
- Los tests existentes deben migrarse con el flujo, no quedarse probando solo el modulo antiguo.

Definition of Done por route admin:

| Route | Debe contener | No debe contener | Tests minimos |
| --- | --- | --- | --- |
| `projects_route` | Contexto de proyectos, feedback, auth y sincronizacion explicita de `core.projects`/`selected_project_id` | Reglas visuales de `projects/view` o un helper generico para core policies | Creacion/actualizacion o borrado con core sync, 401, mensaje ignorado |
| `invites_route` | Contexto de invites, feedback, auth y apply de `admin.invites` | Conocimiento de projects, assignments o members | Fetch exitoso, 401, mensaje ignorado |
| `task_types_route` | Contexto CRUD, refresh de seccion y apply de dialogo/lista | Motor CRUD comun ni conocimiento de otros dialogos admin | Exito CRUD, error de validacion/API, refresh esperado |
| `org_settings_route` | Contexto de org settings, apply de members y politicas root de assignments/current user | Conocimiento visual de permisos o mutacion directa de otras pantallas sin `RootPolicy` | Cache de usuarios con fetch de assignments, guardado de usuario actual, 401, mensaje ignorado |
| Otros routes admin | Una unica area funcional y su submodelo | Mutaciones de varios submodelos salvo politica root explicita | Exito, error/auth y no-op para mensaje ajeno |

Un route queda terminado cuando `features/admin/update.gleam` deja de importar el workflow del feature extraido y tampoco conserva sus helpers `*_context`, `*_feedback_context`, `*_auth_error` o `apply_*`. Si queda alguno, el corte es parcial y debe marcarse como tal.

Orden de extraccion reforzado:

1. `projects_route` - ejecutado; mezcla admin con `core`, por eso se extrajo con pruebas de sincronizacion.
2. `invites_route` - ejecutado; consolida el patron tras projects.
3. `task_types_route` - ejecutado; toca dialogos y refresh, y esa politica queda visible.
4. `org_settings_route` - ejecutado; mezclaba cache de usuarios, permisos, assignments y usuario actual.
5. `members_route` - ejecutado; no por longitud, sino porque la familia members/search mantenia seis adapters y repeticion de auth/context/apply.
6. Resto de admin solo si el barrido demuestra helpers repetidos o responsabilidad mezclada.

Este orden es mejor que extraer todo admin de golpe porque conserva una prueba de comportamiento por corte y evita esconder cambios de `core` dentro de una migracion masiva.

### Fase 5: DRY en UI CRUD

Estado: ejecutado parcialmente. Ya se abordaron cuatro cortes seguros tras estabilizar owners de update: atributos opcionales de campos repetidos en varios dialogos, merge de payload fields duplicado en tres CRUD dialogs, acciones comunes de footer delegadas en `ui/button` y submit compartido de `ui/dialog` sin atributos arbitrarios.

1. Identificar repeticion real en tres o mas dialogos.
2. Anadir helpers pequenos a `crud_dialog_base` - ejecutado para `aria-label`, `placeholder`, `autofocus` y payload fields opcionales.
3. Migrar botones raw a `ui/button` donde no rompa comportamiento - ejecutado en los helpers comunes de `crud_dialog_base`.
4. Mantener formularios especificos en sus modulos.

Resultado esperado:

- Consistencia visual y de estados.
- Menos boilerplate sin esconder reglas de producto.

Criterio de cierre:

- Los helpers nuevos en `crud_dialog_base` deben tener nombres de UI concretos y pocos parametros.
- No debe aparecer un componente CRUD universal.
- Los dialogos migrados deben seguir mostrando claramente sus reglas de negocio locales.

Evidencia actual:

- `with_optional_aria_label`, `with_optional_placeholder` y `with_autofocus_when` tienen tests directos en `crud_dialog_base_test.gleam`.
- `prepend_fields` tiene test directo de orden de merge y reemplaza `append_fields` local en `workflow_crud_dialog`, `rule_crud_dialog` y `task_template_crud_dialog`.
- `ui/button.gleam` soporta botones `submit` asociados a `form` externo, acumulacion de clases de compatibilidad y `autofocus` nativo; `crud_dialog_base.gleam` usa ese contrato para cancel, submit, primary action y danger action, y card trees lo usa para el dialogo de activacion.
- `ui/dialog.gleam` separa submit por formulario (`submit_button_with_locale_form`) de submit-like por mensaje (`submit_button_with_locale_click`), eliminando `submit_button_with_locale_attrs`.
- Los dialogos CRUD migrados siguen renderizando sus campos y reglas locales; solo delegan atributos opcionales repetidos.
- El barrido `rg "fn maybe_add_(aria_label|placeholder|autofocus)" apps/client/src/scrumbringer_client/components/*crud_dialog.gleam` debe quedar vacio.
- El barrido `rg "fn append_fields|append_fields\\(" apps/client/src/scrumbringer_client/components/*crud_dialog.gleam` debe quedar vacio.
- El barrido `rg "html\\.button|lustre/element/html\\.\\{.*button|element/html\\.\\{.*button" apps/client/src/scrumbringer_client/components/crud_dialog_base.gleam` debe quedar vacio.
- El barrido `rg "submit_button_with_locale_attrs|html\\.button|lustre/element/html\\.\\{.*button|element/html\\.\\{.*button" apps/client/src/scrumbringer_client/ui/dialog.gleam` debe quedar vacio.

## Barridos de control recomendados

Antes de cerrar una iteracion de limpieza, ejecutar estos barridos:

```sh
rg "pub type Card \\{|pub type RuleTemplate \\{|pub type Task \\{" apps/server/src/scrumbringer_server
rg "IconPreview|InviteLinkForm|OrgUsersSearchState|ProjectDialogForm|CardDialogMode|WorkflowDialogMode|TaskTemplateDialogMode|RuleDialogMode|TaskTypeDialogMode|DragState|PoolDragState|ReleaseAllTarget|AssignmentsModel|ApiTokensModel" apps/client/src/scrumbringer_client/client_state/types.gleam
rg "pub type (IconPreview|InviteLinkForm|DragState|PoolDragState|Rect|CardDialogMode|WorkflowDialogMode|TaskTemplateDialogMode|RuleDialogMode|TaskTypeDialogMode|OrgUsersSearchState|ProjectDialogForm|AssignmentsAddContext|ReleaseAllTarget|AssignmentsModel)\\b|rect_contains_point" apps/client/src/scrumbringer_client/client_state.gleam
rg "\"__unset__\"| -1| 0" apps/server/src/scrumbringer_server/services apps/server/src/scrumbringer_server/persistence
rg "projects_context|invite_links_context|task_types_context|org_settings_context|apply_projects_update|apply_invites_update|apply_task_types_update|apply_org_settings_update|projects_auth_error|invite_links_auth_error|task_types_auth_error|org_settings_auth_error" apps/client/src/scrumbringer_client/features/admin/update.gleam
rg "submit_button_with_locale_attrs|html\\.button|lustre/element/html\\.\\{.*button|element/html\\.\\{.*button" apps/client/src/scrumbringer_client/ui/dialog.gleam
rg "member_(list|add|remove|release_all|role)_update|search_update|update_without_member_|update_without_org_users_search" apps/client/src/scrumbringer_client/features/admin/update.gleam
rg "fn apply_auth_check_before|fn auth_error" apps/client/src/scrumbringer_client/features/admin/*_route.gleam apps/client/src/scrumbringer_client/features/admin/*_update.gleam
gleam format --check src test
gleam check --target javascript
gleam check --target erlang
```

Los dos primeros `rg` deben tender a cero para duplicados publicos. El barrido de sentinels no debe tender necesariamente a cero, porque puede encontrar valores legitimos, pero cada aparicion debe estar nombrada o confinada a persistencia.

Barridos reforzados por owner:

```sh
rg "TaskMutationContext|TaskMutationDispatchContext|TaskMutationPolicy|TaskMutationUpdate|try_task_mutation_update|TaskDetailContext|TaskDetailEditContext|TaskDetailDispatchContext|TaskDetailAuthPolicy|TaskDetailUpdate|try_task_detail_update" apps/client/src apps/client/test
rg "ApiTokensModel|AssignmentsModel|ReleaseAllTarget|DragState|PoolDragState|DialogMode|IconPreview" apps/client/src/scrumbringer_client/client_state/types.gleam apps/client/src/scrumbringer_client/client_state.gleam
rg "pub type Project \\{|pub type ProjectMember \\{" apps/server/src/scrumbringer_server shared/src
rg "case .*\"task\"|case .*\"card\"|\"claimed\"|\"available\"|\"completed\"" apps/client/src apps/server/src
```

Interpretacion:

- El primer barrido debe dejar de apuntar al orquestador antiguo cuando mutacion se extraiga.
- El segundo debe permanecer vacio o limitado a tipos transversales reales; en el root no deben reaparecer aliases especificos de feature.
- El tercero debe encontrar solo el contrato canonico compartido. Si vuelve a aparecer en servidor, debe llamarse projection/record si contiene campos internos.
- El cuarto no debe ser cero necesariamente; sirve para revisar que los strings de negocio se convierten a ADTs en la frontera correcta.

Barrido especifico para routes admin ya extraidos:

```sh
rg "features/(projects|invites|task_types)/update as|features/admin/org_settings$|projects_workflow|invite_links_workflow|task_types_workflow|org_settings\\.try_update|apply_(projects|invites|task_types|org_settings)_update" apps/client/src/scrumbringer_client/features/admin/update.gleam
```

Barrido especifico para el siguiente corte recomendado:

```sh
rg "member_(list|add|remove|release_all|role)_update|search_update|update_without_member_|update_without_org_users_search" apps/client/src/scrumbringer_client/features/admin/update.gleam
rg "fn apply_auth_check_before|fn auth_error" apps/client/src/scrumbringer_client/features/admin/*_route.gleam apps/client/src/scrumbringer_client/features/admin/*_update.gleam
```

Interpretacion:

- El primer barrido debe permanecer en cero tras crear `members_route.gleam`.
- El segundo no debe mostrar `apply_auth_check_before/after` privados en routes admin. Puede seguir mostrando `auth_error` porque cada route traduce su ADT local a `Option(ApiError)`.

El cierre de `members_route.gleam` se valida con el primer barrido. El segundo valida que `route_support.gleam` no crecio mas alla de la mecanica comun de auth y que las politicas locales siguen en cada route.

## Reglas de parada

La limpieza debe parar cuando se cumpla una de estas condiciones:

- El siguiente movimiento solo cambia ubicacion de codigo sin aclarar ownership.
- Un helper nuevo necesita mas parametros que el bloque local que reemplaza.
- La extraccion obliga a introducir tipos genericos que no existen en el lenguaje del producto.
- El cambio toca demasiados flujos sin una prueba directa para cada uno.

Estas reglas son importantes porque la mejor refactorizacion aqui no es hacer la base de codigo mas abstracta, sino hacerla mas verdadera: menos conceptos duplicados, tipos con dueños claros y fronteras mas faciles de verificar.

## Criterios de aceptacion finales

La refactorizacion puede considerarse suficientemente limpia cuando se cumplan estas condiciones:

- No hay records publicos duplicados con el mismo significado que un tipo de `shared/src/domain`.
- Los records de servidor con campos internos tienen nombre de projection/record y no se confunden con contratos HTTP.
- `client_state/types.gleam` solo contiene tipos transversales.
- `features/tasks/update.gleam` no existe o no tiene imports reales; los owners de create, notes, mutation y detail son directos.
- `features/admin/update.gleam` no concentra aplicacion de subupdates de todas las areas.
- Los routes admin extraidos aparecen en `docs/lustre_inventory.yml` y tienen tests propios; si el inventario no crece con el modulo nuevo, el corte queda incompleto a nivel de trazabilidad.
- `crud_dialog_base.gleam` contiene helpers concretos y pequenos, no un motor CRUD.
- Los tests de cada flujo importan el owner real que se esta validando.
- Los comandos de check/test pasan en el target afectado.

No hace falta que todos los modulos bajen de un numero arbitrario de lineas. Hace falta que cada modulo tenga un motivo unico para cambiar.

## Decisiones descartadas

Estas opciones pueden parecer limpiezas atractivas, pero no son el mejor encaje ahora.

### Framework generico de CRUD

Descartado.

Motivo:

- Los dialogos comparten shell, botones y validaciones simples, pero cada entidad tiene campos y reglas propias.
- Un framework CRUD obligaria a pasar demasiados callbacks y configuracion.
- El resultado probablemente seria menos legible que formularios locales con helpers pequenos.

Alternativa recomendada:

- Reforzar `crud_dialog_base` solo con piezas repetidas y estables.

### Dispatcher generico para updates

Descartado.

Motivo:

- Los updates grandes no son iguales entre si; mezclan contextos, auth, comandos y efectos diferentes.
- Un dispatcher universal ocultaria el flujo TEA y haria mas dificil seguir un mensaje concreto.

Alternativa recomendada:

- Extraer adapters por feature: tasks, admin, capabilities, pool o card trees.

### Wrappers opacos para todos los IDs

Descartado por ahora.

Motivo:

- Podria mejorar seguridad de tipos, pero tocaria una superficie muy grande.
- El coste de migracion seria alto y no ataca primero la duplicacion real detectada.

Alternativa recomendada:

- Usar nombres de campo claros y tipos de dominio compartidos.
- Considerar wrappers opacos solo en fronteras donde ya se hayan producido bugs por mezclar IDs.

### ADT para todo estado de formulario

Descartado.

Motivo:

- Muchos strings de formulario son simplemente valores de `<select>`.
- Convertir cada campo de UI en ADT global aumentaria conceptos sin mejorar el modelo de negocio.

Alternativa recomendada:

- Mantener strings en el formulario.
- Convertir a ADT canonico en submit o validacion.

### Mover todos los records de servidor al dominio compartido

Descartado.

Motivo:

- Algunos records del servidor contienen campos internos de autorizacion o persistencia.
- El dominio compartido perderia claridad si absorbiera datos que la UI no debe conocer.

Alternativa recomendada:

- Compartir records que son contrato de producto.
- Renombrar projections internas cuando tengan campos adicionales.
- Convertir en la frontera HTTP.

### Partir modulos grandes solo por lineas

Descartado.

Motivo:

- Un modulo grande no siempre es un problema estructural si tiene una sola responsabilidad clara.
- Partir por longitud crea archivos pequenos pero puede empeorar navegacion y ownership.

Alternativa recomendada:

- Partir cuando existan responsabilidades separables, repeticion de ramas o ownership claro.

## Garantias de calidad

Para cada fase de codigo se deberian ejecutar:

```sh
gleam format --check src test
gleam check
gleam test
```

En cliente JavaScript:

```sh
gleam test --target javascript
```

En servidor Erlang:

```sh
gleam check --target erlang
gleam test --target erlang
```

Cuando se cambien contratos HTTP:

- Anadir o actualizar tests de presenter/decoder.
- Verificar que el JSON mantiene los nombres publicos esperados.
- Probar al menos un flujo end-to-end si la entidad participa en una pantalla critica.

## Anexo: auditoria reforzada del estado actual

Este anexo recoge los controles ejecutables que sostienen el estado del informe.
Su objetivo es que una futura iteracion pueda distinguir entre deuda real,
residuo aceptable y falso positivo.

### Resultado estructural actual

| Control | Resultado actual | Lectura |
| --- | --- | --- |
| `wc -l client_state.gleam` | 399 lineas | Root todavia es amplio, pero ya actua como shell de `Model`/`Msg` y aliases transversales. |
| `wc -l client_state/types.gleam` | 14 lineas | El cajon global de tipos quedo reducido a tipos transversales reales. |
| `wc -l features/admin/update.gleam` | 346 lineas | Admin queda como dispatcher/root; los routes grandes y la familia members/search ya fueron extraidos. |
| `wc -l features/capabilities/update.gleam` | 288 lineas | Capabilities queda como dispatcher fino sobre CRUD y assignments; no conserva aliases publicos de los contratos de `types.gleam`. |
| Barrido de tipos canonicos servidor/shared | Solo `shared/src/domain/*` publica `Task`, `Card`, `Workflow`, `Rule`, `ApiToken`, `IntegrationUser`, `Project` y `ProjectMember` | Los nombres de dominio ya no compiten con records publicos del servidor. |

La lectura correcta no es "todo modulo grande esta mal". La lectura es que los
roots restantes deben juzgarse por responsabilidad, imports y tests, no por
lineas aisladas.

### Barridos con resultado esperado vacio

Estos barridos deben seguir vacios despues de nuevas limpiezas:

```sh
rg -n "pub type (IconPreview|InviteLinkForm|DragState|PoolDragState|Rect|CardDialogMode|WorkflowDialogMode|TaskTemplateDialogMode|RuleDialogMode|TaskTypeDialogMode|OrgUsersSearchState|ProjectDialogForm|AssignmentsAddContext|ReleaseAllTarget|AssignmentsModel)\\b|rect_contains_point" apps/client/src/scrumbringer_client/client_state.gleam
rg -n "fn append_fields|append_fields\\(" apps/client/src/scrumbringer_client/components/*crud_dialog.gleam
rg -n "features/(api_tokens|assignments|capabilities|projects|invites|task_types)/update as|features/admin/org_settings$|projects_workflow|invite_links_workflow|task_types_workflow|apply_(projects|invites|task_types|org_settings)_update" apps/client/src/scrumbringer_client/features/admin/update.gleam
rg -n "features/tasks/update" apps/client/src apps/client/test
```

Interpretacion:

- Si el primer barrido encuentra algo, `client_state.gleam` vuelve a ser facade
  de tipos de feature.
- Si el segundo encuentra algo, se ha reintroducido duplicacion local que ya
  pertenece a `crud_dialog_base.gleam`.
- Si el tercero encuentra algo, un route admin extraido vuelve a depender del
  root antiguo o conserva helpers obsoletos.
- Si el cuarto encuentra algo, el orquestador obsoleto de tasks ha reaparecido
  como dependencia mental o tecnica.

### Barridos con falsos positivos esperables

Estos barridos no deben exigirse a cero. Deben clasificarse match por match:

```sh
rg -n "\"__unset__\"|-1|0|empty_.*value|unchanged_.*value|optional_.*filter|positive_int" apps/server/src/scrumbringer_server/persistence/tasks apps/server/src/scrumbringer_server/services
rg -n "case .*\"task\"|case .*\"card\"|\"claimed\"|\"available\"|\"completed\"" apps/client/src apps/server/src
```

Interpretacion:

- En persistencia, un sentinel es aceptable si esta en constante privada,
  conversion de frontera o SQL generado. Es deuda si aparece en dominio,
  presenter, validator HTTP o workflow handler como regla de producto.
- En UI/formularios, un string de `<select>` es aceptable antes de submit. Es
  deuda si decide comportamiento de negocio sin pasar por ADT canonico.

### Estado de cierres y parciales

| Area | Estado reforzado | Por que no seguir tocando ahora |
| --- | --- | --- |
| Tasks update | Cerrado | Cada flujo tiene owner directo; extraer mas seria partir por estetica. |
| Pool task routing | Cerrado para familia tarea | `task_route.gleam` concentra dependencias, notas, create, mutation y detail; el root no importa esos subupdates. |
| Capabilities update | Cerrado | El dispatcher ya separa CRUD y assignments sin framework generico. |
| Client root types | Cerrado bajo vigilancia | Los tipos especificos viven en owners reales; solo hay que impedir regresiones. |
| Admin routes extraidos | Cerrado para routes listados | El siguiente corte requiere evidencia nueva de responsabilidad mezclada. |
| CRUD helpers | Parcial sano | Ya se extrajo repeticion estable, los botones comunes pasan por `ui/button` y `ui/dialog` evita atributos arbitrarios en submit; nuevas piezas deben auditarse antes de crear mas helpers. |
| Project HTTP contract | Cerrado en frontera publica | El presenter ya no expone `org_id` ni `project_id`; los records internos conservan esos campos para autorizacion/persistencia. |
| Sentinels SQL | Parcial sano | El valor tecnico sigue existiendo por la query, pero queda nombrado en la frontera. |

Esta tabla fija el criterio de calidad: no se debe buscar "mas limpieza" en un
area cerrada salvo que aparezca nueva duplicacion semantica. La mejora siguiente
debe salir de un barrido, no de una sensacion de que aun hay muchas lineas.

### Reglas de no regresion

1. No anadir aliases de feature a `client_state.gleam`.
2. No publicar en servidor un tipo con nombre canonico si el dominio compartido
   ya lo define.
3. No extraer un helper UI con menos de tres usos o sin eliminar un estado
   invalido.
4. No convertir strings de formulario a ADT global si solo viven en DOM.
5. No mover `org_id`, `VerifiedToken`, bearer tokens ni datos de autorizacion al
   dominio compartido.
6. No crear dispatchers genericos para updates mientras los route adapters
   concretos sigan siendo pequenos y testeables.
7. No marcar un corte como cerrado si los tests siguen importando el facade
   antiguo.

Estas reglas son las garantias de que la limpieza no se convierta en
sobreingenieria. El repositorio mejora cuando reduce decisiones duplicadas, no
cuando aumenta el numero de capas.

### Controles ejecutados en este refuerzo

Estos controles se han repetido al reforzar el informe y fijan el estado base
para la siguiente iteracion.

| Control | Resultado actual | Decision que respalda |
| --- | --- | --- |
| `wc -l apps/client/src/scrumbringer_client/client_state.gleam apps/client/src/scrumbringer_client/client_state/types.gleam apps/client/src/scrumbringer_client/features/admin/update.gleam apps/client/src/scrumbringer_client/features/capabilities/update.gleam` | `399`, `14`, `346`, `288` lineas | Los roots restantes se juzgan por responsabilidad e imports, no por longitud aislada |
| `wc -l apps/client/src/scrumbringer_client/features/pool/update.gleam apps/client/src/scrumbringer_client/features/pool/task_route.gleam apps/client/src/scrumbringer_client/features/pool/metrics_route.gleam apps/client/src/scrumbringer_client/features/pool/rule_metrics_route.gleam apps/client/src/scrumbringer_client/features/pool/positions_route.gleam apps/client/src/scrumbringer_client/features/pool/skills_route.gleam` | `874`, `631`, `74`, `72`, `70` y `75` lineas | Pool conserva el shell de dispatch; tarea, metricas operativas, metricas de reglas, posiciones y skills tienen routes root-aware propios; no se valora solo el total de lineas |
| `wc -l apps/client/src/scrumbringer_client/features/card trees/update.gleam apps/client/src/scrumbringer_client/features/card trees/dialog_update.gleam apps/client/src/scrumbringer_client/features/card trees/movement_update.gleam apps/client/src/scrumbringer_client/features/card trees/create_update.gleam apps/client/src/scrumbringer_client/features/card trees/expansion.gleam apps/client/src/scrumbringer_client/features/card trees/filters.gleam apps/client/src/scrumbringer_client/features/card trees/selection.gleam apps/client/src/scrumbringer_client/features/card trees/refresh.gleam` | `182`, `620`, `341`, `62`, `36`, `76`, `45` y `171` lineas | Card Trees conserva un shell de contratos/feedback/root policy; dialogos, movimientos, create, expansion, filtros, seleccion y refresh ya salieron a owners existentes |
| `rg "api_card trees\|dialog_helpers\|parent_card_ids\|app_effects\|handle_card tree_(activate\|activated\|edit_clicked\|delete_clicked\|dialog_closed\|name_changed\|description_changed\|create_submitted\|created\|edit_submitted\|delete_submitted\|updated\|deleted\|create_clicked)" apps/client/src/scrumbringer_client/features/card trees/update.gleam` | Sin matches | El workflow general de card trees ya no contiene APIs/helpers/handlers de dialogo; delega en `card trees/dialog_update.gleam` desde `pool/card trees_route.gleam` |
| `rg "api_cards\|task_operations_api\|card_in_card tree\|task_in_card tree\|can_move_between_ready_card trees\|is_ready_card tree\|handle_card tree_(card_drag\|task_drag\|drag_ended\|dropped\|card_move\|task_move)\|MemberCard Tree(CardDragStarted\|TaskDragStarted\|DragEnded\|DroppedOn\|CardMoveClicked\|TaskMoveClicked\|CardMoved\|TaskMoved)" apps/client/src/scrumbringer_client/features/card trees/update.gleam` | Sin matches | El workflow general de card trees ya no contiene APIs/helpers/handlers de movimiento; delega en `card trees/movement_update.gleam` desde `pool/card trees_route.gleam` |
| `rg "domain/card\|domain/task\|on_card tree_card_moved\|on_card tree_task_moved" apps/client/src/scrumbringer_client/features/card trees/update.gleam` | Sin matches | El contrato general de card trees ya no arrastra tipos ni callbacks de movimiento; `movement_update.Context` contiene esa responsabilidad |
| `rg "^pub fn\|^pub type" apps/client/src/scrumbringer_client/features/card trees/movement_update.gleam` | Solo `Context` y `try_update` | Los handlers internos de drag/drop/move no quedan como API publica accidental del modulo |
| `rg "^pub fn\|^pub type" apps/client/src/scrumbringer_client/features/card trees/refresh.gleam` + barrido de usos | Solo quedan publicos `try_update`, `mark_pending` y `loading_unless_loaded`; `ProjectFetched`, `project_fetched`, `project_failed`, `card trees_fetched` y `card trees_failed` son privados | Las derivaciones internas de refresh dejan de ser API externa; produccion conserva solo el route de refresh y los helpers usados al arrancar carga multi-proyecto |
| `rg "dict\|member_card tree_summary_expanded\|member_card tree_expanded_cards\|handle_card tree_summary_toggled\|handle_card tree_card_toggled\|card tree_card_expanded_or_default" apps/client/src/scrumbringer_client/features/card trees/update.gleam` | Sin matches | El workflow general de card trees ya no contiene estructuras ni helpers de expansion local; delega en `card trees/expansion.gleam` |
| `rg "dialog_mode\|member_create_parent_card_id\|member_create_card_id\|MemberCard TreeCreate(Task\|Card)Clicked\|handle_card tree_create_task_clicked" apps/client/src/scrumbringer_client/features/card trees/update.gleam` | Sin matches | El workflow general de card trees ya no contiene estado ni mensajes de quick-create; delega en `card trees/create_update.gleam` |
| `rg "^pub fn\|^pub type" apps/client/src/scrumbringer_client/features/card trees/dialog_update.gleam` + barrido de usos | Solo quedan publicos `try_update` y `handle_card tree_dialog_closed`; los tests directos de create/edit/delete pasan por `try_update` | La API publica accidental de dialogos queda cerrada: produccion conserva el route normal y el cierre por Escape, y los handlers internos dejan de ser contrato externo |
| `rg "fn (prepend_for_scope\|replace_loaded_by_id\|remove_loaded_by_id\|map_loaded)" apps/client/src/scrumbringer_client/features/admin/workflows.gleam apps/client/src/scrumbringer_client/features/admin/task_templates.gleam` | Sin matches | La deuda DRY concreta se cerro: el owner admin pequeno para listas remotas con scope org/proyecto es `scoped_remote_list.gleam` |
| `rg` de tipos especificos de feature en `client_state.gleam` | Sin matches | El root de estado no conserva forms, dialog targets, drag state ni modelos de pantalla |
| `rg "features/tasks/update" apps/client/src apps/client/test` | Sin matches | El orquestador obsoleto de tasks no sigue siendo dependencia tecnica |
| `rg` de subupdates de tarea en `features/pool/update.gleam` | Sin matches para create/mutation/detail/notes/dependencies/detail permissions/lookups | El root de pool ya no adapta la familia tarea directamente |
| `rg "metrics_workflow\|apply_pool_metrics_update\|metrics_auth_error\|update_member_metrics\|update_admin_metrics\|client_state/(admin\|member)/metrics\|features/metrics/update" apps/client/src/scrumbringer_client/features/pool/update.gleam` | Sin matches | El root de pool ya no adapta directamente metricas operativas member/admin; delega en `pool/metrics_route.gleam` |
| `rg "features/admin/rule_metrics|rule_metrics_workflow|rule_metrics_context|apply_pool_rule_metrics_update|rule_metrics_auth_error" apps/client/src/scrumbringer_client/features/pool/update.gleam` | Sin matches | El root de pool ya no adapta directamente metricas de reglas; delega en `pool/rule_metrics_route.gleam` |
| `rg "position_update|position_update_context|apply_pool_positions_update|position_auth_error|update_member_positions|client_state/member/positions" apps/client/src/scrumbringer_client/features/pool/update.gleam` | Sin matches | El root de pool ya no adapta directamente posiciones; delega en `pool/positions_route.gleam` |
| `rg "skills_workflow|skills_context|apply_pool_skills_update|skills_auth_error|update_member_skills|client_state/member/skills|selected_user_id" apps/client/src/scrumbringer_client/features/pool/update.gleam` | Sin matches | El root de pool ya no adapta directamente skills; delega en `pool/skills_route.gleam` |
| `rg` de botones raw en card trees | El dialogo de activacion ya no importa `html.button`; quedan botones raw en toggles/rows/drag donde son controles interactivos especificos | Las acciones simples migran a `ui/button` sin forzar controles de seleccion o expansion |
| `rg "button\\(|import lustre/element/html\\.\\{[^\\n]*button" src/scrumbringer_client/features/admin/capabilities_view.gleam src/scrumbringer_client/features/pool/create_dialog.gleam` | Sin matches | Las acciones simples migradas en capabilities y pool create ya no dependen de `button` raw |
| `rg "button\\(|import lustre/element/html\\.\\{[^\\n]*button" src/scrumbringer_client/features/admin/api_tokens_view.gleam src/scrumbringer_client/features/projects/view.gleam src/scrumbringer_client/features/metrics/view.gleam` | Sin matches | Las acciones simples migradas en API tokens, proyectos y metricas ya no dependen de `button` raw |
| `rg "modal_close_button|attribute\\.class\\(\\\"btn-close\\\"\\)|\\[text\\(\\\"X\\\"\\)\\]" src/scrumbringer_client/features/admin/rule_metrics_view.gleam` | Solo encuentra `modal_close_button` | El cierre del drilldown de metricas de reglas conserva la clase legacy via componente reusable y no reconstruye el boton raw |
| `rg "button\\(|import lustre/element/html\\.\\{[^\\n]*button|event\\.on_click\\(config\\.on_create_task_in_card" src/scrumbringer_client/features/my_bar/view.gleam` | Sin matches | Crear tarea desde una tarjeta en My Bar reutiliza `ui/action_buttons` y no reconstruye la accion con DOM raw |
| `rg "^\\s*button\\(|import lustre/element/html\\.\\{[^\\n]*button|attribute\\.class\\(\\\"auth-forgot\\\"\\)" src/scrumbringer_client/features/auth/view.gleam` | Sin matches | Forgot password conserva su clase visual local mediante `ui_button.with_class`, pero delega semantica, tipo nativo y click en `ui/button` |
| `rg "class\\(case is_selected|btn btn-primary btn-xs|btn btn-secondary btn-xs|attribute\\.class\\(case config\\.members\\.members_add_in_flight" src/scrumbringer_client/features/admin/views/members.gleam` | Sin matches | `Select`/`Selected` y `Add member` del alta de miembros ya no reconstruyen clases legacy; el control es deliberadamente estrecho porque el modulo conserva botones raw fuera de ese flujo |
| `rg "confirm_class|^\\s*button\\(|import lustre/element/html\\.\\{[^\\n]*button|btn-danger btn-loading|btn-primary btn-loading" src/scrumbringer_client/ui/confirm_dialog.gleam src/scrumbringer_client/features/admin/views/members.gleam src/scrumbringer_client/features/invites/view.gleam src/scrumbringer_client/features/card trees/dialogs.gleam` | Sin matches | Confirm dialogs usan `button.Intent` tipado y members ya no monta acciones simples con `button` raw ni clases combinadas legacy |
| `rg "attribute\\.class\\(\\\"task-card-primary-action\\\"\\)|icons\\.nav_icon\\(icons\\.HandRaised" src/scrumbringer_client/features/pool/task_card.gleam` | Sin matches | El claim primario de task card reutiliza `ui/task_actions.claim_icon`; la clase local queda como compatibilidad, no como reconstruccion raw del boton |
| `rg "attribute\\.class\\(\\\"btn-icon-only|attribute\\.attribute\\(\\\"data-testid\\\", \\\"preferences-btn\\\"\\)|attribute\\.attribute\\(\\\"data-testid\\\", \\\"logout-btn\\\"\\)|event\\.on_click\\(config\\.on_logout\\)|event\\.on_click\\(config\\.on_preferences_toggle\\)" src/scrumbringer_client/features/layout/right_panel.gleam` | Sin matches | Las acciones de perfil del right panel usan `ui/button.icon` y solo conservan clases/test ids via helpers semanticos |
| `rg "import lustre/element/html\\.\\{[^\\n]*button|view_heroicon_inline\\(\\\"bars-3|view_heroicon_inline\\(\\\"user-circle|attribute\\.class\\(\\\"mobile-(menu|user)-btn\\\"\\)|event\\.on_click\\(config\\.on_(left|right)_drawer_toggle\\)" src/scrumbringer_client/features/layout/member_mobile_shell.gleam` | Sin matches | Los botones del topbar movil usan `ui/button.icon`; el icono de menu queda tipado en `ui/icons.Menu` |
| `gleam format --check src test`, `gleam check --target javascript`, `gleam test --target javascript` en `apps/client` | Pasan; la suite JS reporta `1695 passed, no failures` tras cerrar API publica accidental en capabilities/dependencies, derivar opciones de reglas desde tipos canonicos y centralizar claimability | Las extracciones de `pool/task_route.gleam`, `pool/metrics_route.gleam`, `pool/rule_metrics_route.gleam`, `pool/positions_route.gleam`, `pool/skills_route.gleam`, dialogos/movimientos/create/expansion/filtros/seleccion/refresh de card trees, el helper admin `scoped_remote_list.gleam`, la migracion de botones del dialogo de activacion, y las nuevas acciones simples en pool/capabilities/API tokens/proyectos/metricas/My Bar/auth/members/confirm dialogs/right panel/shell movil quedan cubiertas por compilacion y tests de cliente |
| `rg "Some\\(0\\)" apps/server/src/scrumbringer_server/services/workflows/handlers.gleam` | Sin matches | El sentinel de ausencia de card en create task queda fuera del workflow handler |
| `rg` de `TaskState` en `http/tasks/presenters.gleam` | Encuentra `status: _status`, `work_state: _work_state`, `task_state.to_status(state)` y `task_state.to_work_state(state)` | El presenter ignora campos redundantes y serializa desde el ADT canonico |
| `rg "task_json_derives_status_and_work_state_from_task_state_test" apps/server/test/unit/presenters_test.gleam` | Encuentra el test | El drift de lifecycle queda protegido cerca del presenter |
| `rg` de `ProjectGrant` y conversiones | Definiciones en `shared/src/domain/api_token.gleam`; usos en servidor importan el owner compartido | El ADT de grant no vive en el servicio operativo |
| `rg` de normalizacion de create task | `decode_create_task` normaliza `card_id` y `parent_card_id`; el test de payload existe | La frontera JSON absorbe IDs no positivos antes del workflow |

Resultado del refuerzo:

- Las areas marcadas como cerradas tienen al menos un barrido negativo y un
  owner real verificable.
- Las areas parciales conservan una razon concreta: contrato HTTP, frontera SQL
  o limite UI/UX.
- No se justifica una nueva capa generica. El siguiente cambio debe salir de
  una evidencia parecida a la tabla anterior.

## Refuerzo de garantias de calidad

Este informe no debe usarse como una invitacion a seguir moviendo codigo hasta
que los archivos parezcan pequenos. Debe usarse como contrato de calidad para
decidir si una refactorizacion merece existir. La regla reforzada es esta:
cada cambio aceptado debe mejorar al menos una garantia de producto, una
garantia de tipos o una garantia de mantenimiento, y no debe degradar otra sin
un beneficio medible.

### Garantias por recomendacion

| Recomendacion | Garantia de producto | Garantia de tipos/codigo | Prueba minima de cierre |
| --- | --- | --- | --- |
| Mantener entidades canonicas en `shared/src/domain` | Cliente y servidor hablan del mismo concepto de tarea, card, workflow, rule, token o proyecto | No hay records publicos con el mismo nombre semantico fuera del dominio compartido | Barrido de `pub type` canonicos y tests de codec/presenter donde exista frontera HTTP |
| Mantener records internos con sufijo operativo | Autorizacion, persistencia y auditoria no contaminan el contrato publico | `Record`, `Stored*` o `Projection` explican que el shape no es dominio | Presenter no emite campos internos como `org_id`, hash, bearer o `project_id` redundante |
| Confinar sentinels en SQL/JSON/DOM | El usuario no hereda valores tecnicos como reglas de producto | `Option`, ADT o payload mapper absorben ausencia/activo/estado antes de negocio | Barrido que demuestre que el literal no decide comportamiento en workflow, service o presenter |
| Extraer routes/update por owner funcional | El flujo que el usuario entiende tiene un owner tecnico equivalente | El root pierde imports, contextos y apply del subflujo; los mensajes ignorados quedan cubiertos | Test de exito, auth/error cuando aplica, y mensaje ajeno ignorado |
| Centralizar UI solo con semantica comun | Acciones iguales se comportan igual y tienen accesibilidad consistente | `ui/button`, `ui/dialog`, `ui/action_buttons` o helper estrecho eliminan clases raw repetidas | Tres usos equivalentes o un estado invalido eliminado; no se fuerza sobre controles gestuales |
| Mantener roots residuales como shells | El producto conserva composicion explicita de areas sin esconder decisiones | El shell solo contiene contratos, feedback, root policy o dispatch exhaustivo | Barridos negativos de subupdates ya extraidos y ausencia de handlers operativos antiguos |

### Criterios reforzados de rechazo

Las siguientes soluciones deben rechazarse aunque parezcan "mas limpias" en una
lectura superficial:

| Propuesta | Motivo de rechazo | Alternativa correcta |
| --- | --- | --- |
| Crear un dispatcher generico de updates | Homogeneiza flujos distintos, exige callbacks amplios y esconde auth/root policies | Routes concretos por familia funcional con tests cercanos |
| Crear un CRUD universal | Mezcla dialogos que tienen copy, permisos, campos y side effects distintos | Helpers pequenos en `crud_dialog_base`, `ui/dialog` y `ui/button` |
| Mover todos los records del servidor a shared | Filtra persistencia/autorizacion al contrato publico | Compartir solo entidades canonicas; mantener `Record`/`Projection` internos |
| Envolver todos los IDs con tipos opacos en un unico corte | Aumenta churn y obliga a tocar muchas fronteras sin bug concreto | Introducir wrappers solo donde haya mezcla real de IDs o invariante nueva |
| Perseguir cero matches de sentinels | SQL, JSON y DOM necesitan representar ausencia o compatibilidad | Nombrar o convertir en la frontera; exigir que no crucen a negocio |
| Partir card trees/pool por longitud | Reduce lineas sin reducir decisiones duplicadas | Extraer solo si hay owner funcional claro y el root pierde imports operativos |

### Auditoria reforzada de card trees

Card Trees era el mejor candidato para dudas porque acumulo mucho codigo nuevo
en la rama. El refuerzo actual no lo da por limpio por intuicion: lo clasifica
por responsabilidades ya separadas y por lo que queda deliberadamente en el
shell.

| Responsabilidad | Owner actual | Estado | Motivo |
| --- | --- | --- | --- |
| Filtros de lista | `features/card trees/filters.gleam` | Cerrado bajo tests | Transiciones puras de filtros, sin efectos ni root policy |
| Seleccion de card tree | `features/card trees/selection.gleam` | Cerrado bajo tests | Actualiza selected/flags locales sin mezclar dialogos |
| Refresh multi-proyecto | `features/card trees/refresh.gleam` | Cerrado bajo tests | Respuestas fetch ok/error y derivaciones de refresh quedan juntas |
| Dialogos CRUD/activate | `features/card trees/dialog_update.gleam` | Cerrado bajo guardarrail | Owner claro y superficie publica reducida a `try_update` + cierre por Escape |
| Movimiento de cards/tasks | `features/card trees/movement_update.gleam` | Cerrado bajo guardarrail | Solo expone `Context` y `try_update`; handlers internos no son API publica |
| Expansion visual local | `features/card trees/expansion.gleam` | Cerrado bajo tests | Estado de vista separado de filtros y refresh |
| Quick-create desde card tree | `features/card trees/create_update.gleam` | Cerrado bajo tests | Apertura de task dialog y root policy de card quedan fuera del workflow general |
| Contratos, feedback y root policy | `features/card trees/update.gleam` | Residuo aceptado | No conviene extraer un modulo `contracts` mientras solo mueva tipos y aumente imports |

La mejora de mejor V/C/R dentro de card trees no era otro corte del shell
general, sino cerrar API publica accidental en `dialog_update.gleam`. El barrido
previo mostro que produccion usaba `try_update` desde
`pool/card trees_route.gleam` y `handle_card tree_dialog_closed` desde
`pool/shortcut_update.gleam`; el resto de handlers publicos aparecian como
detalle interno del propio modulo o como tests directos heredados del corte.

La limpieza ejecutada reduce esa API a:

- `try_update`, como entrada normal del route de card trees;
- `handle_card tree_dialog_closed`, mientras `pool/shortcut_update.gleam`
  necesite cerrar el dialogo desde Escape;
- ningun otro handler publico.

Los tests que llamaban directamente a `handle_card tree_create_submitted`,
`handle_card tree_edit_clicked` y `handle_card tree_deleted_ok` ahora envian
`MemberCard TreeCreateSubmitted`, `MemberCard TreeEditClicked` y
`MemberCard TreeDeleted` a `try_update`. Asi se cierra una deuda de API publica
accidental sin anadir capas ni cambiar comportamiento.

### Matriz final V/C/R reforzada

| Mejora candidata | Valor | Complejidad | Riesgo | Decision reforzada |
| --- | --- | --- | --- | --- |
| Auditar y reducir `pub` accidental en `card trees/dialog_update.gleam` | Medio | Baja-media | Bajo | Ejecutado: solo quedan publicos `try_update` y `handle_card tree_dialog_closed` |
| Extraer `card trees/update.gleam` a `contracts.gleam` | Bajo-medio | Media | Medio | Rechazar por ahora: mueve tipos sin borrar una decision duplicada clara |
| Seguir extrayendo pool por familias funcionales | Medio | Media | Medio | Solo ejecutar con evidencia de imports/context/apply repetidos, como se hizo con tasks/metrics/positions/skills |
| Crear helpers UI para todos los botones raw restantes | Bajo | Alta | Medio | Rechazar: toggles, rows, drag handles y controles segmentados no son acciones simples |
| Mantener barridos negativos de tipos canonicos | Alto | Baja | Bajo | Obligatorio como control de no regresion, sin nuevo codigo si el barrido sigue limpio |
| Migrar nuevas convenciones JSON a payload helpers | Medio-alto | Baja | Bajo | Ejecutar caso a caso cuando aparezca repeticion real como `active 0/1` |

Con esta matriz, el informe queda reforzado en dos sentidos: identifica el
siguiente corte con mejor relacion valor/coste/riesgo, y tambien explicita que
varias limpiezas intuitivas no deben hacerse porque no mejoran el diseno de
tipos ni reducen responsabilidades repetidas.

## Refuerzo adicional: aliases de shell, API publica y documentacion viva

El ultimo barrido no encuentra nueva duplicacion semantica de entidades, pero
si deja tres decisiones que conviene fijar para que el informe sea mas estricto
en futuras iteraciones.

### Aliases de `client_state/admin.gleam` y `client_state/member.gleam`

Los aliases publicos de estos dos modulos pueden parecer una regresion porque
son `pub type X = owner.Model`. El barrido, sin embargo, no encuentra usos
externos de `admin_state.InvitesModel`, `admin_state.ProjectsModel`,
`member_state.PoolModel`, `member_state.SkillsModel`, etc. en `apps/client/src`
ni en `apps/client/test`.

Lectura reforzada:

| Elemento | Estado | Decision |
| --- | --- | --- |
| Aliases de slices admin/member | Residuo aceptable | Se aceptan como nombres de campos dentro del shell `AdminModel`/`MemberModel`, no como API para callers externos |
| Imports externos de esos aliases | Sin matches | Si aparecen, deben migrarse al owner real del slice o justificarse explicitamente |
| `client_state.gleam` root | Shell transversal | Conserva `Model`, `Msg`, `CoreModel`, `Page`, `NavMode` y aliases de mensajes/slices necesarios para composicion Lustre |
| `client_state/types.gleam` | Cerrado bajo vigilancia | Debe seguir limitado a primitivas transversales como `OperationState` y `DialogState(form)` |

Guardarrail nuevo:

```sh
rg -n "admin_state\\.(InvitesModel|ProjectsModel|CapabilitiesModel|MembersModel|MetricsModel|WorkflowsModel|RulesModel|TaskTemplatesModel|TaskTypesModel|CardsModel|AssignmentsModel|ApiTokensModel)|member_state\\.(PoolModel|NowWorkingModel|MetricsModel|SkillsModel|PositionsModel|NotesModel|DependenciesModel)" apps/client/src apps/client/test --glob '*.gleam'
```

Resultado esperado: vacio. Si deja de estar vacio, el root de estado vuelve a
actuar como facade de tipos de feature y el caller debe importar el modulo owner
del slice.

### Superficie publica de updates extraidos

El cierre de una extraccion no basta con mover codigo: tambien hay que evitar
que los handlers internos se conviertan en contrato publico accidental. El
barrido actual refuerza este criterio:

| Modulo | API publica aceptada | Motivo |
| --- | --- | --- |
| `features/capabilities/update.gleam` | `AuthPolicy`, `Update`, `try_update` | Dispatcher fino; los contratos compartidos viven en `features/capabilities/types.gleam` |
| `features/capabilities/types.gleam` | `Context`, `Success`, `FeedbackContext`, `ErrorFeedbackContext`, `success_effect` | Owner real de contratos usados por CRUD, assignments y route admin |
| `features/tasks/create_update.gleam` | `Context`, `Policy`, `Update`, `try_update` | Creacion de tarea usa mensajes `MemberCreate*`; los handlers internos no son contrato externo |
| `features/tasks/notes_update.gleam` | `Context`, `AuthPolicy`, `Update`, `try_update` | Notas de tarea usan mensajes `MemberNote*`; los handlers internos no son contrato externo |
| `features/tasks/mutation_update.gleam` | `MutationContext`, `DispatchContext`, `Policy`, `Update`, `Success`, `ErrorLabels`, `Context`, `ErrorContext`, `try_update`, `handle_claim_dropped`, `should_refetch_work_sessions`, `error_feedback` | Click/release/complete/success/error entran por mensajes `Member*`; drag conserva un puente publico real |
| `features/tasks/detail_update.gleam` | `EditContext`, `Model`, `Context`, `DispatchContext`, `AuthPolicy`, `Update`, `SuccessContext`, `ErrorContext`, `try_update`, `error_feedback` | El route entra por mensajes `MemberTaskDetail*`, `MemberTaskUpdated` y `MemberTaskMetricsFetched`; `error_feedback` queda publico como helper puro testeado directamente |
| `features/card trees/dialog_update.gleam` | `try_update`, `handle_card tree_dialog_closed` | El route usa `try_update`; Escape necesita cerrar dialogo desde `pool/shortcut_update.gleam` |
| `features/card trees/refresh.gleam` | `try_update`, `mark_pending`, `loading_unless_loaded` | Refresh routing y helpers de carga multi-proyecto |
| `features/card trees/movement_update.gleam` | `Context`, `try_update` | Movimiento necesita callbacks root-aware; los handlers de drag/drop quedan privados |
| `features/card trees/create_update.gleam` | `try_update` | Quick-create no expone handlers internos |

Guardarrail nuevo:

```sh
rg -n "^pub fn|^pub type" apps/client/src/scrumbringer_client/features/capabilities/update.gleam apps/client/src/scrumbringer_client/features/capabilities/types.gleam apps/client/src/scrumbringer_client/features/tasks/{create_update,notes_update,mutation_update,detail_update}.gleam apps/client/src/scrumbringer_client/features/card trees/{dialog_update,refresh,movement_update,create_update}.gleam
```

Resultado esperado: no deben reaparecer aliases de compatibilidad ni handlers
internos publicos. Si un test necesita llamar a un handler interno, primero debe
intentarse cubrir el comportamiento por `try_update`.

Guardarrail especifico para detalle de tarea:

```sh
rg -n "detail_update\\.(handle_task|updated_ok|updated_error|error_effect)" apps/client/src apps/client/test --glob '*.gleam'
```

Resultado esperado: vacio. `error_feedback` puede seguir publico como helper
puro testeado directamente, igual que en `mutation_update.gleam`.

### Documentacion viva como parte de la limpieza

El codigo ya cambio lo bastante como para que algunos comentarios historicos
puedan quedarse desfasados aunque la arquitectura este bien. El ejemplo
detectado estaba en `client_state.gleam`: el comentario de cabecera hablaba de
un root anterior y la justificacion de `default_model` mencionaba campos y
defaults que ya viven en slices especificos.

Decision reforzada:

- La documentacion desfasada no invalida el corte arquitectonico, pero si debe
  tratarse como limpieza de bajo riesgo.
- Una limpieza solo puede considerarse completamente cerrada si el comentario
  operativo del modulo no describe el diseno anterior.
- Ejecutado: los comentarios de `client_state.gleam` ahora hablan de shell,
  composicion de slices, `CoreModel` real y defaults delegados.

Guardarrail nuevo:

```sh
rg -n "~450|~155|100\\+ Model fields|Feature-specific models, forms" apps/client/src/scrumbringer_client/client_state.gleam
```

Resultado actual: vacio en `client_state.gleam`. Este punto tenia valor
bajo-medio, complejidad baja y riesgo bajo; se ejecuto como limpieza final de
documentacion viva, sin anadir tipos, modulos ni helpers.

### Criterio reforzado de "no tocar"

Un punto queda explicitamente fuera de la siguiente iteracion si cumple estas
condiciones:

1. No hay import externo del alias/facade.
2. El modulo root pierde conocimiento operativo frente al estado anterior.
3. La API publica del owner queda reducida a entrada de route, contratos reales
   o helpers usados por otro owner.
4. Existe test cercano o barrido negativo que se pueda repetir.

Con este criterio, no es optimo eliminar ahora todos los aliases de
`client_state/admin.gleam` y `client_state/member.gleam`: no tienen callers
externos, explican campos del root y quitarlos produciria churn sin reducir una
decision duplicada. Si en el futuro empiezan a ser importados por features o
tests, dejan de ser residuo aceptable.

## Refuerzo final: auditoria critica de cierre

La revision reforzada cambia el informe en un punto importante: algunas areas
estan cerradas como ownership, pero no todas estan cerradas como API publica. La
distincion importa porque una extraccion puede mejorar el diseno y aun asi
dejar deuda si los tests o callers siguen tratando helpers internos como
contrato.

### Semaforo actualizado

| Area | Estado reforzado | Evidencia | Siguiente accion correcta |
| --- | --- | --- | --- |
| Tasks create/notes/mutation | Cerrado como owner y API publica | Los tests entran por `try_update`; los handlers internos ya no son publicos salvo integraciones justificadas de drag/helper puro en mutation | Mantener guardarrail de superficie publica; no seguir partiendo por longitud |
| Tasks detail | Cerrado como owner y API publica | `try_update` cubre mensajes `MemberTaskDetail*`, `MemberTaskUpdated` y `MemberTaskMetricsFetched`; el barrido de handlers publicos accidentales queda vacio | Mantener `error_feedback` como unico helper puro publico y repetir el guardarrail si se toca el flujo |
| People update | Cerrado como owner y API publica | `features/people/update.gleam` solo publica `try_update`; el barrido `people_update.handle_` queda vacio en src/test | Mantener tests por mensajes `MemberPeople*` si se amplian roster o expansiones |
| Metrics update | Cerrado como owner y API publica | `features/metrics/update.gleam` solo publica contratos de route y `try_update`; el barrido `metrics_update.handle_` queda vacio en src/test | Mantener direct tests por `MemberUpdate`/`AdminUpdate` desde `try_update`, no por handlers |
| Now working update | Cerrado como owner y API publica | `features/now_working/update.gleam` solo publica contratos de route y `try_update`; el barrido `now_working_update.handle_` queda vacio en src/test | Mantener la politica auth en `try_update`; no extraer timer/session handlers como API publica |
| Card detail update | Cerrado como owner y API publica | `features/pool/card_detail_update.gleam` solo publica `Model`, `Context` y `try_update`; el barrido de `opened/closed/metrics_fetched_*` queda vacio | Mantener `card_detail.gleam` como owner puro de estado local y `card_detail_update.gleam` como adapter effectful |
| Position update | Cerrado como owner y API publica | `features/pool/position_update.gleam` solo publica contratos de route y `try_update`; el barrido de helpers `fetched/opened/submitted/saved` queda vacio | Mantener validacion de coordenadas en `position_edit.gleam` y politica auth en `position_update.try_update` |
| Skills update | Cerrado como owner y API publica | `features/skills/update.gleam` solo publica contratos de route y `try_update`; el barrido `skills_update.handle_` queda vacio en src/test | Mantener fetch/toggle/save como handlers privados y tests por mensajes de pool |
| Card Trees | Cerrado por owners parciales, con shell residual aceptado | Filtros, seleccion, refresh, dialogos, movimiento, expansion y quick-create tienen owner propio | No extraer `contracts.gleam` mientras solo mueva tipos; revisar solo si reaparece conocimiento operativo |
| Pool | Parcial sano | Tareas, metricas, rule metrics, posiciones, skills y auth tienen routes/support concretos | Nuevos cortes solo con evidencia de otra familia funcional mezclada |
| Admin | Cerrado para routes extraidos | Routes por area y `route_support` concentran context/auth/apply repetidos | No crear dispatcher admin generico |
| UI compartida | Parcial sano | Acciones simples migran a `ui/button`/`ui/dialog`; controles gestuales o seleccionables quedan fuera | Clasificar cada `button` raw antes de migrar; no exigir cero matches |
| Dominio compartido/servidor | Cerrado bajo guardarrail | Tipos canonicos viven en `shared`; records internos usan sufijos operativos | Mantener barridos de `pub type` y presenters sin campos internos |

### Corte ejecutado antes de declarar tasks limpio

El corte con mejor V/C/R era cerrar la API publica accidental de
`features/tasks/detail_update.gleam`. Se ejecuto sin anadir abstraccion y
siguiendo el patron ya validado en create, notes y mutation:

1. Los tests directos de lifecycle, tabs, edicion, metricas y respuesta de
   update pasan por `detail_update.try_update`.
2. Solo `error_feedback` conserva tests directos porque traduce de forma pura
   `ApiError` a feedback.
3. `handle_task_details_opened`, `handle_task_details_closed`,
   `handle_task_detail_*`, `handle_task_metrics_fetched_*`, `updated_ok`,
   `updated_error` y `error_effect` son privados; los helpers muertos
   `handle_task_updated_ok/error` se retiraron.
4. Guardarrail repetible:

```sh
rg -n "detail_update\\.(handle_task|updated_ok|updated_error|error_effect)" apps/client/src apps/client/test --glob '*.gleam'
```

5. Validado con `gleam format --check src test`,
   `gleam check --target javascript` y `gleam test --target javascript` en
   `apps/client`.

V/C/R:

| Valor | Complejidad | Riesgo | Decision |
| --- | --- | --- | --- |
| Medio-alto | Baja-media | Bajo | Ejecutado; tasks update queda cerrado como owner y API publica |

Esta mejora fue preferible a nuevas extracciones grandes porque reduce una
superficie publica real, reutiliza el route `try_update` existente y no crea
ningun concepto nuevo.

### Refuerzo adicional: API publica accidental cerrada en subflujos pool/member

El ultimo barrido detecto otra forma de deuda menos visible que los modulos
largos: handlers internos que seguian siendo `pub` y tests que los llamaban
directamente. Eso no rompe comportamiento, pero congela pasos internos como si
fueran contrato. Para una base de codigo limpia, el contrato de un update debe
ser el mismo que usa produccion: mensaje de app -> `try_update` -> `Update` o
`Nil`.

Se cerro este punto en los subflujos que ya tenian owner claro:

| Modulo | API publica que queda | Handlers cerrados | Test de contrato |
| --- | --- | --- | --- |
| `features/pool/position_update.gleam` | `AuthPolicy`, `Update`, `Context`, `try_update` | fetch, open, close, x/y change, submit, save ok/error | `pool_position_update_test.gleam` entra por `MemberPosition*` |
| `features/skills/update.gleam` | `Context`, `AuthPolicy`, `Update`, `try_update` | fetch de capacidades, toggle, save ok/error | `skills_update_test.gleam` entra por `Member*Capability*` |
| `features/metrics/update.gleam` | contratos de route y `try_update` | handlers de metricas member/admin | `metrics_update_test.gleam` entra por `MemberUpdate`/`AdminUpdate` |
| `features/now_working/update.gleam` | `Model`, contratos de route y `try_update` | start, pause, tick, sessions ok/error | `now_working_update_test.gleam` entra por mensajes reales |
| `features/people/update.gleam` | `try_update` | roster y expansion de fila | `people_update_test.gleam` entra por `MemberPeople*` |
| `features/pool/card_detail_update.gleam` | `Model`, `Context`, `try_update` | open, close, metrics ok/error | `pool_card_detail_update_test.gleam` entra por mensajes de card detail |
| `features/auth/update.gleam` | `Action`, `Context`, efectos externos de invite/reset y `update` | login, forgot password, logout, accept invite y reset password handlers | `auth_update_test.gleam` entra por `auth_messages.Msg` |
| `features/pool/drag_update.gleam` | `Model`, `Context`, `try_update` | touch, hover, focus, highlight, drag rects, movement y drop handlers | `pool_drag_update_test.gleam` entra por `pool_messages.Msg` |
| `features/pool/view_mode_update.gleam` | `Context`, `RoutePolicy`, `Update`, `try_update` | `view_mode_changed` | `pool_view_mode_update_test.gleam` ya entra por `try_update` |
| `features/pool/shortcut_update.gleam` | `Model`, `Context`, `Update`, `try_update` | `handle` de shortcuts | `pool_shortcut_update_test.gleam` entra por `GlobalKeyDown` |
| `features/invites/update.gleam` | contratos de route, feedback/auth y `try_update` | fetch, dialog, create, regenerate, invalidate, copy, success/error helpers | `invites_update_test.gleam` entra por `admin_messages.Invite*` |
| `features/projects/update.gleam` | contratos de route, feedback/auth/core policy y `try_update` | create/edit/delete dialog handlers, success/error helpers y `project_dialog_delete_id` | `projects_update_test.gleam` entra por `admin_messages.Project*` y verifica `CorePolicy` |
| `features/admin/member_list.gleam` | contratos de route, auth y `try_update` | members fetched ok/error | `member_list_update_test.gleam` entra por `admin_messages.MembersFetched`; preload de capabilities se verifica por la entrada real |
| `features/admin/member_add.gleam` | contratos de route, feedback/auth/refresh y `try_update` | open/close, role change, user selection, submit, added ok/error y feedback de exito | `member_add_update_test.gleam` y `admin_member_add_flow_test.gleam` entran por `admin_messages.MemberAdd*`/`MemberAdded` |
| `features/admin/member_remove.gleam` | contratos de route, feedback/auth/refresh y `try_update` | click/cancel/confirm, removed ok/error y feedback de exito | `member_remove_update_test.gleam` entra por `admin_messages.MemberRemove*`/`MemberRemoved` |
| `features/admin/member_release_all.gleam` | contratos de route, feedback/auth y `try_update` | click/cancel/confirm, release ok/error, `success_effect`, `error_message` y lookup de target | `member_release_all_update_test.gleam` entra por `admin_messages.MemberReleaseAll*`; los errores especificos se prueban por resultado API |
| `features/admin/member_role.gleam` | contratos de route, parsers de input, feedback compartido y `try_update` | request y role changed ok | `member_role_update_test.gleam` entra por `admin_messages.MemberRole*`; `success_effect`/`error_effect` siguen publicos porque `assignments_route` los consume |
| `features/admin/search.gleam` | contratos de route, auth y `try_update` | cambio/debounce de query, resultados ok/error, stale responses y autoseleccion exacta | `admin_search_update_test.gleam` y `admin_member_add_flow_test.gleam` entran por `admin_messages.OrgUsersSearch*` |
| `features/admin/org_settings.gleam` | contratos de route, feedback/auth/root policy, `try_update` y `current_user_after_saved` | cache de usuarios, fetch de settings, cambio de rol, delete flow, saved/deleted ok/error | `org_settings_test.gleam` entra por `admin_messages.OrgUsersCache*`/`OrgSettings*`; `current_user_after_saved` sigue publico porque `org_settings_route.gleam` lo consume |
| `features/admin/rule_metrics.gleam` | contratos de route, auth, `try_update` e `init_tab` | rango de fechas, refresh, quick range, fetch ok/error, workflow expansion, drilldown y paginacion de ejecuciones | `admin_rule_metrics_update_test.gleam` entra por `pool_messages.AdminRuleMetrics*`; `init_tab` sigue publico porque `client_update.gleam` inicializa la pestana |
| `features/assignments/update.gleam` | contratos de route, feedback/auth/root policy, `try_update` y `start_user_projects_fetch` | modo/lista, busqueda, expansion, fetch de miembros/proyectos, inline add, remove y cambio de rol | `assignments_update_test.gleam` entra por `admin_messages.Assignments*`; `start_user_projects_fetch` sigue publico porque `assignments_route.gleam` lo consume para precargas desde org settings |
| `features/capabilities/update.gleam` | contratos de route, feedback/auth y `try_update`; sub-owners publican solo `try_update` | CRUD de capabilities y asignaciones usuario/capability; los handlers internos de `crud_update` y `assignments_update` quedan privados | `capabilities_update_test.gleam` entra por `admin_messages.Capability*`, `MemberCapabilities*` y `CapabilityMembers*`; `Success` queda publico en `types.gleam` como ADT compartido de feedback |
| `features/tasks/dependency_update.gleam` | `DependenciesModel`, `AuthPolicy`, `Update`, contextos y `try_update` | fetch de dependencias, dialogo de add, candidates, add/remove ok/error | `tasks_dependencies_update_test.gleam` entra por `pool_messages.MemberDependency*`; `pool/task_route.gleam` consume solo `try_update` y contratos |
| `features/task_types/update.gleam` | contratos de route, feedback/auth/refresh y `try_update` | fetch, dialog, create form, icon preview, submit, success/error y CRUD component handlers | `task_types_update_test.gleam` entra por `admin_messages.TaskType*` y verifica `RefreshPolicy` |
| `features/admin/task_templates.gleam` | contratos de route, feedback/auth, `try_update` y `fetch_task_templates` | fetch project, dialog open/close, CRUD transitions y feedback de exito | `admin_task_templates_update_test.gleam` entra por `pool_messages.TaskTemplate*` y `TaskTemplatesProjectFetched` |
| `features/admin/cards.gleam` | contratos de route, feedback/auth/focus, `try_update`, `fetch_cards_for_project` y dos puentes reales | fetch, dialog open/close, CRUD transitions y filtros de lista | `admin_cards_update_test.gleam` entra por `pool_messages.Cards*`; `handle_open_card_dialog_for_card tree` y `handle_card_viewed` siguen publicos por integraciones reales |
| `features/admin/workflows.gleam` | contratos de route, feedback/auth y entradas `try_workflows_update`, `try_rules_update`, `try_template_attachment_update` | fetch/dialog/CRUD de workflows, reglas, metricas de reglas y template attachment | `admin_workflows_update_test.gleam` entra por `pool_messages.Workflow*`, `Rule*` y `Template*`; los ADT de exito y transiciones locales son privados |

Este refuerzo cambia el liston de cierre: no basta con que el owner exista. El
owner tambien debe ocultar sus pasos internos salvo que haya una razon real para
exponerlos, como un helper puro compartido o una integracion externa concreta.

Guardarrail repetible:

```sh
rg -n "position_update\.(fetched_ok|fetched_error|opened|closed|x_changed|y_changed|submitted|saved_ok|saved_error)|skills_update\.handle_|metrics_update\.handle_|now_working_update\.handle_|people_update\.handle_|detail_update\.(handle_task|updated_ok|updated_error|error_effect)|card_detail_update\.(opened|closed|metrics_fetched_ok|metrics_fetched_error)" apps/client/src apps/client/test --glob '*.gleam'
```

Resultado actual: sin matches. La lectura correcta no es "ya no quedan
handlers privados", sino "los tests y callers externos ya no tratan esos
handlers internos como contrato".

Guardarrails adicionales tras los nuevos cierres:

```sh
rg -n "auth_update\.handle_|drag_update\.(touch_started|hover_opened|hover_closed|task_focused|task_blurred|task_created_feedback|highlight_expired|touch_ended|long_press_check|drag_to_claim_armed|my_tasks_rect_fetched|canvas_rect_fetched|drag_started|drag_moved|drag_offset_resolved|hover_notes_fetched|drag_ended)|view_mode_update\.view_mode_changed" apps/client/src apps/client/test --glob '*.gleam'
```

Resultado actual: sin matches. `auth/update.gleam` conserva publicos
`accept_invite_effect` y `reset_password_effect` porque el root todavia los usa
como frontera de efectos para token flows; no son handlers internos de UI.

Guardarrail especifico para los cierres de shortcuts e invites:

```sh
rg -n "shortcut_update\.handle|invites_update\.handle_|invites_update\.(success_effect|error_effect|error_message)|^pub fn handle_invite|^pub fn (success_effect|error_effect|error_message)|^pub type Success" apps/client/src/scrumbringer_client/features/pool/shortcut_update.gleam apps/client/src/scrumbringer_client/features/invites/update.gleam apps/client/test/pool_shortcut_update_test.gleam apps/client/test/invites_update_test.gleam
```

Resultado actual: sin matches. En invites, `Success` tambien pasa a privado
porque solo alimenta el feedback interno del propio `try_update`.

Guardarrail especifico para projects:

```sh
rg -n "projects_update\.(handle_|success_effect|error_message|project_dialog_delete_id)|^pub type Success|^pub fn handle_project|^pub fn (success_effect|error_message|project_dialog_delete_id)" apps/client/src/scrumbringer_client/features/projects/update.gleam apps/client/test/projects_update_test.gleam apps/client/src/scrumbringer_client/features/admin/projects_route.gleam
```

Resultado actual: sin matches. `project_dialog_delete_id` queda privado porque
la politica publica real es `CoreProjectDeleted(Option(Int))`, cubierta por
tests a traves de `try_update`.

Guardarrail especifico para task types:

```sh
rg -n "task_types_update\.(handle_|success_effect)|^pub type Success|^pub fn handle_task_type|^pub fn success_effect" apps/client/src/scrumbringer_client/features/task_types/update.gleam apps/client/test/task_types_update_test.gleam apps/client/src/scrumbringer_client/features/admin/task_types_route.gleam
```

Resultado actual: sin matches. `Success` y `success_effect` quedan privados
porque solo alimentan feedback interno del propio `try_update`.

Guardarrail especifico para task templates:

```sh
rg -n "task_templates_update\.(project_fetched_|open_dialog|close_dialog|template_(created|updated|deleted)|success_effect)|^pub type Success|^pub fn (project_fetched_|open_dialog|close_dialog|template_(created|updated|deleted)|success_effect)" apps/client/src/scrumbringer_client/features/admin/task_templates.gleam apps/client/test/admin_task_templates_update_test.gleam apps/client/src/scrumbringer_client/features/pool/admin_route.gleam
```

Resultado actual: sin matches. `fetch_task_templates` sigue publico porque es
frontera real del cliente para cargar la seccion admin; las transiciones
locales quedan privadas detras de `try_update`.

Guardarrail especifico para cards:

```sh
rg -n "cards\.(handle_cards_fetched|handle_open_card_dialog\(|handle_close_card_dialog|handle_card_crud|handle_show_empty|handle_show_completed|handle_state_filter|handle_search)|^pub fn handle_cards_fetched|^pub fn handle_open_card_dialog\(|^pub fn handle_close_card_dialog|^pub fn handle_card_crud|^pub fn handle_show_empty|^pub fn handle_show_completed|^pub fn handle_state_filter|^pub fn handle_search" apps/client/src/scrumbringer_client/features/admin/cards.gleam apps/client/test/admin_cards_update_test.gleam apps/client/src/scrumbringer_client/features/pool/admin_route.gleam apps/client/src/scrumbringer_client/features/pool/card trees_route.gleam apps/client/src/scrumbringer_client/features/pool/card_detail_update.gleam
```

Resultado actual: sin matches. `handle_open_card_dialog_for_card tree` sigue
publico porque `pool/card trees_route.gleam` lo usa para quick-create desde un
card tree; `handle_card_viewed` sigue publico porque `pool/card_detail_update`
lo usa para limpiar el indicador de notas nuevas al abrir una card.

Guardarrail unico para workflows/rules/template attachment:

```sh
rg -n "workflows_update\.(workflows_project_fetched_|open_workflow_dialog|close_workflow_dialog|workflow_(created|updated|deleted|success_effect)|rule_|rules_|open_rule|close_rule|workflow_rules|rule_metrics|rule_success_effect|attach_template|template_detach|template_attachment_success_effect)|^pub type (WorkflowSuccess|RuleSuccess|TemplateAttachmentSuccess)|^pub fn (workflows_project_fetched_|open_workflow_dialog|close_workflow_dialog|workflow_(created|updated|deleted|success_effect)|rule_|rules_|open_rule|close_rule|workflow_rules|rule_metrics|attach_template|template_detach|rule_success_effect|template_attachment_success_effect)" apps/client/src/scrumbringer_client/features/admin/workflows.gleam apps/client/test/admin_workflows_update_test.gleam apps/client/src/scrumbringer_client/features/pool/admin_route.gleam
```

Resultado actual: sin matches. La API publica restante de
`features/admin/workflows.gleam` son contextos, policies, updates y entradas
`try_*` consumidas por `pool/admin_route.gleam`.

Validacion ejecutada tras este corte:

| Comando | Resultado |
| --- | --- |
| `gleam format --check src test` en `apps/client` | Pasa |
| `gleam check --target javascript` en `apps/client` | Pasa |
| `gleam test --target javascript` en `apps/client` | Pasa, `1695 passed, no failures` |

Validacion documental y de diff:

| Control | Resultado |
| --- | --- |
| Parent branch resuelto | `origin/main` |
| `git diff --check -- apps/client/src/scrumbringer_client/features/admin/workflows.gleam apps/client/test/admin_workflows_update_test.gleam docs/codebase-cleanup-refactor-audit.md` | Sin salida |
| `git diff --no-index --check -- /dev/null docs/codebase-cleanup-refactor-audit.md` | Sin salida; el exit code `1` es esperado porque el fichero es nuevo frente a `/dev/null` |

V/C/R:

| Valor | Complejidad | Riesgo | Decision |
| --- | --- | --- | --- |
| Medio-alto | Baja | Bajo | Ejecutado; reduce superficie publica y alinea tests con entradas reales sin crear abstraccion nueva |

Los cierres de auth/drag/view mode tienen el mismo V/C/R: valor medio,
complejidad baja y riesgo bajo. Son preferibles a tocar `invites`, `projects` o
`assignments` en este punto porque no requieren redisenar flujos grandes ni
separar owners nuevos; solo corrigen visibilidad y entrada de test sobre owners
que ya existen.

El cierre posterior de `shortcut_update` mantiene ese V/C/R. El cierre de
`invites/update.gleam` sube a valor medio-alto y complejidad media-baja: habia
mas handlers, pero todos tenian mensaje `AdminMsg` equivalente y no habia
callers externos legitimos. `projects` y `assignments` se abordaron despues de
confirmar que el cambio seguia siendo mecanico y que sus politicas root ya
estaban encapsuladas en sus routes.

El cierre de `projects/update.gleam` se ejecuto despues de confirmar esa
mecanica: todos los handlers tenian `AdminMsg` equivalente y el route consume
solo `try_update` con `AuthPolicy`/`CorePolicy`. La complejidad es media-baja
por el `CorePolicy`, pero el riesgo queda bajo al verificar los casos de create,
edit, delete, errores y `CoreProjectDeleted` por la entrada real.

El cierre de `org_settings.gleam` completa la extraccion previa de
`org_settings_route.gleam`: el route ya era el owner de contexto, feedback,
auth y root policy, pero el modulo operativo seguia exponiendo handlers
internos y los tests los llamaban directamente. Los tests pasan ahora por
`OrgUsersCacheFetched`, `OrgSettingsUsersFetched`,
`OrgSettingsRoleChanged`, `OrgSettingsSaved`,
`OrgSettingsDelete*` y `OrgSettingsDeleted`. La unica funcion publica
operativa que queda fuera de `try_update` es `current_user_after_saved`, porque
`org_settings_route.gleam` la usa como helper puro para actualizar el usuario
actual del root.

Guardarrail especifico para org settings:

```sh
rg -n "org_settings\.(handle_org_users_cache_fetched|handle_org_settings_users_fetched|handle_org_settings_role_changed|handle_org_settings_delete|handle_org_settings_saved|handle_org_settings_deleted)|^pub fn handle_org" apps/client/src/scrumbringer_client/features/admin/org_settings.gleam apps/client/src/scrumbringer_client/features/admin/org_settings_route.gleam apps/client/test/org_settings_test.gleam apps/client/test/admin_org_settings_route_test.gleam
```

Resultado actual: sin matches. `current_user_after_saved` puede seguir
publico mientras `org_settings_route.gleam` sea quien aplica la politica root
`UpdateCurrentUser`.

El cierre de `rule_metrics.gleam` sigue el mismo criterio, pero con una
excepcion publica legitima: `client_update.gleam` llama a `init_tab` para
inicializar el rango de fechas al entrar en la pantalla de metricas de reglas.
El resto de transiciones operativas se prueban ahora por
`pool_messages.AdminRuleMetrics*` y `try_update`, que es la misma entrada que
usa `pool/rule_metrics_route.gleam`.

Guardarrail especifico para rule metrics:

```sh
rg -n "rule_metrics\.(handle_from_changed|handle_to_changed|handle_from_changed_and_refresh|handle_to_changed_and_refresh|handle_refresh_clicked|handle_quick_range_clicked|handle_fetched_|handle_workflow_|handle_drilldown_|handle_rule_details_|handle_executions_|handle_exec_page_changed)|^pub fn handle_" apps/client/src/scrumbringer_client/features/admin/rule_metrics.gleam apps/client/src/scrumbringer_client/features/pool/rule_metrics_route.gleam apps/client/test/admin_rule_metrics_update_test.gleam apps/client/test/pool_rule_metrics_route_test.gleam
```

Resultado actual: sin matches. `init_tab` no entra en el guardarrail porque es
un puente real de inicializacion de pantalla, no un handler interno de mensaje.

El cierre de `features/assignments/update.gleam` completa el corte previo de
`assignments_route.gleam`. El route ya era el owner de contexto, feedback,
auth timing, root policy y apply del submodelo; el workflow todavia exponia
handlers internos que los tests llamaban directamente. Los tests pasan ahora
por `AssignmentsViewModeChanged`, `AssignmentsSearch*`,
`AssignmentsProject/UserToggled`, `Assignments*Fetched`, `AssignmentsInlineAdd*`,
`AssignmentsRemove*` y `AssignmentsRole*`. La unica funcion publica adicional a
`try_update` es `start_user_projects_fetch`, porque org settings necesita
precargar proyectos por usuario cuando cambia la cache de usuarios.

Guardarrail especifico para assignments:

```sh
rg -n "assignments_update\.(handle_assignments|error_effect)|^pub fn handle_assignments|^pub fn error_effect" apps/client/src/scrumbringer_client/features/assignments/update.gleam apps/client/src/scrumbringer_client/features/admin/assignments_route.gleam apps/client/test/assignments_update_test.gleam apps/client/test/admin_assignments_route_test.gleam
```

Resultado actual: sin matches. `start_user_projects_fetch` queda fuera del
guardarrail porque es un puente real entre org settings y assignments, no un
handler interno.

El cierre de `member_add.gleam` se ejecuto despues de confirmar que produccion
entra por `member_add_update.try_update` y `members_route.try_update`. Los tests
directos de open/close, cambio de rol, seleccion, submit y resultado se
migraron a `member_add.try_update`; `admin_member_add_flow_test.gleam` dejo de
llamar al handler de submit. La API publica restante queda limitada a contratos
de integracion y `try_update`.

Guardarrail especifico para member add:

```sh
rg -n "member_add\.(handle_member_add|handle_member_added|success_effect)|^pub fn handle_member_add|^pub fn handle_member_added|^pub fn success_effect" apps/client/src/scrumbringer_client/features/admin/member_add.gleam apps/client/src/scrumbringer_client/features/admin/member_add_update.gleam apps/client/src/scrumbringer_client/features/admin/members_route.gleam apps/client/test/member_add_update_test.gleam apps/client/test/admin_member_add_flow_test.gleam
```

Resultado actual: sin matches.

`search.gleam` se cierra como API publica accidental del route de miembros. La
autoseleccion exacta de usuarios, las respuestas obsoletas, el debounce y los
errores se prueban por `OrgUsersSearchChanged`, `OrgUsersSearchDebounced` y
`OrgUsersSearchResults`, no por handlers internos.

Guardarrail especifico para org users search:

```sh
rg -n "search\.(handle_org_users_search_changed|handle_org_users_search_debounced|handle_org_users_search_results_ok|handle_org_users_search_results_error)|^pub fn handle_org_users_search" apps/client/src/scrumbringer_client/features/admin/search.gleam apps/client/src/scrumbringer_client/features/admin/search_update.gleam apps/client/src/scrumbringer_client/features/admin/members_route.gleam apps/client/test/admin_search_update_test.gleam apps/client/test/admin_member_add_flow_test.gleam
```

Resultado actual: sin matches.

`member_list.gleam` queda alineado con el mismo liston: fetch ok/error se
prueba con `MembersFetched(Ok/Error)` y no por handlers directos. La precarga
de capacidades por proyecto sigue cubierta, pero el contrato observable es
`try_update`.

Guardarrail especifico para member list:

```sh
rg -n "member_list\.(handle_members_fetched_ok|handle_members_fetched_error)|^pub fn handle_members_fetched" apps/client/src/scrumbringer_client/features/admin/member_list.gleam apps/client/src/scrumbringer_client/features/admin/member_list_update.gleam apps/client/src/scrumbringer_client/features/admin/members_route.gleam apps/client/test/member_list_update_test.gleam
```

Resultado actual: sin matches.

En `member_role.gleam` el cierre es deliberadamente parcial: se privatizan
`handle_member_role_change_requested` y `handle_member_role_changed_ok`, pero
se mantienen publicos `success_effect`, `error_effect` y `error_feedback`.
`member_role_update.gleam` y `assignments_route.gleam` usan esos helpers como
puente real para feedback de cambios de rol iniciados desde assignments.

Guardarrail especifico para member role:

```sh
rg -n "member_role\.(handle_member_role_change_requested|handle_member_role_changed_ok)|^pub fn handle_member_role_change_requested|^pub fn handle_member_role_changed_ok" apps/client/src/scrumbringer_client/features/admin/member_role.gleam apps/client/src/scrumbringer_client/features/admin/member_role_update.gleam apps/client/src/scrumbringer_client/features/admin/members_route.gleam apps/client/test/member_role_update_test.gleam
```

Resultado actual: sin matches.

El cierre de `member_release_all.gleam` tambien elimina helpers puros que no
tenian consumidores externos reales: `success_effect`, `error_message` y
`release_all_target_user_name`. Los tests de mensajes `FORBIDDEN`,
`SELF_RELEASE`, `NOT_FOUND` y error generico pasan por
`MemberReleaseAllResult(Error(_))`, que es la entrada que usa produccion.

Guardarrail especifico para member release-all:

```sh
rg -n "member_release_all\.(handle_member_release_all|success_effect|error_message|release_all_target_user_name)|^pub fn handle_member_release_all|^pub fn success_effect|^pub fn error_message|^pub fn release_all_target_user_name" apps/client/src/scrumbringer_client/features/admin/member_release_all.gleam apps/client/src/scrumbringer_client/features/admin/member_release_all_update.gleam apps/client/src/scrumbringer_client/features/admin/members_route.gleam apps/client/test/member_release_all_update_test.gleam
```

Resultado actual: sin matches.

El cierre de `member_remove.gleam` sigue el mismo criterio: la integracion real
es `member_remove_update.try_update` desde `members_route`, y los handlers de
confirmacion/removal no son reutilizados por otros owners. Los tests pasan a
verificar click, cancel, confirm, ok/error por `try_update`, dejando privados
los pasos internos y `success_effect`.

Guardarrail especifico para member remove:

```sh
rg -n "member_remove\.(handle_member_remove|handle_member_removed|success_effect)|^pub fn handle_member_remove|^pub fn handle_member_removed|^pub fn success_effect" apps/client/src/scrumbringer_client/features/admin/member_remove.gleam apps/client/src/scrumbringer_client/features/admin/member_remove_update.gleam apps/client/src/scrumbringer_client/features/admin/members_route.gleam apps/client/test/member_remove_update_test.gleam
```

Resultado actual: sin matches.

### Backlog residual reforzado

El siguiente trabajo no debe empezar por "que archivo es largo", sino por esta
lista corta de oportunidades que todavia podrian tener valor. Cada una necesita
la evidencia indicada antes de tocar codigo.

| Oportunidad | Evidencia previa obligatoria | Corte maximo permitido | Criterio de no ejecucion |
| --- | --- | --- | --- |
| Reducir API publica accidental en otro update | `rg "^pub fn|^pub type"` muestra handlers operativos publicos y tests los llaman directamente | Migrar tests a `try_update`, privatizar handlers y anadir guardarrail | Si el `pub` es contrato usado por otro owner o helper puro compartido |
| Nuevo route en pool | `pool/update.gleam` vuelve a importar contexto/apply/auth de una familia funcional no extraida | Un route concreto con test de exito, auth y mensaje ignorado | Si solo reduce lineas o mueve `case` sin borrar imports operativos |
| Nuevo corte en card trees | El shell mezcla efectos/root policy de un owner que ya tiene nombre de producto | Extraer un owner por vez y mantener `update.gleam` como shell | Si el corte solo crea `contracts.gleam` o wrappers de tipos |
| Mas UI compartida | Tres acciones simples repiten intent, disabled/loading y accesibilidad | Helper estrecho sobre `ui/button`/`ui/dialog` | Si el control es toggle, drag, segmented control, row clickable o primitiva UI |
| Nuevos payload helpers | Dos o mas endpoints repiten la misma convencion de transporte | Helper de frontera en `payload_fields.gleam` con test | Si la convencion aparece una sola vez o pertenece a SQL generado |
| Tipos compartidos adicionales | Un tipo publico con significado canonico aparece fuera de `shared/src/domain` | Mover contrato a shared o renombrar server como `Record`/`Projection` | Si el shape contiene `org_id`, hash, bearer, auditoria o persistencia interna |

Esta tabla convierte el informe en una herramienta de decision: si no se puede
rellenar la columna de evidencia, la mejora no es candidata. Asi se evita
mantener cambios intermedios que no cerraron nada y tambien se evita introducir
capas "por limpieza" que no reducen responsabilidad duplicada.

### Riesgo de limpiar de mas

El informe tambien queda reforzado con limites negativos. No deben ejecutarse
estas limpiezas mientras no aparezca nueva evidencia:

| Limpieza tentadora | Por que no es optima ahora | Senal que la reactivaria |
| --- | --- | --- |
| Extraer contratos de `card trees/update.gleam` a otro modulo | Moveria tipos y aumentaria imports sin borrar una decision duplicada clara | Otro modulo necesita esos contratos como owner real, no solo como comodidad |
| Eliminar aliases de slices admin/member | No tienen callers externos y ayudan a leer el shell de estado | Un feature/test empieza a importarlos como facade en vez de importar el owner real |
| Crear CRUD universal | Mezcla copy, permisos y efectos distintos | Tres o mas dialogos comparten exactamente el mismo contrato de campos, submit, auth y feedback |
| Migrar todo `button` raw | Algunos botones son controles de seleccion, drag, toggles o primitiva UI | Un barrido clasifica un caso como accion simple repetida con intent/accesibilidad comun |
| Envolver todos los IDs | Mucho churn y poco valor sin bugs de mezcla de IDs | Bug real o frontera donde el tipo opaco elimine una combinacion invalida frecuente |

### Criterio de cierre reforzado

Desde este punto, "limpio" debe significar las cuatro cosas a la vez:

1. El owner funcional existe.
2. La API publica solo expone entrada de route, contratos reales o helpers puros.
3. Los tests ejercitan el comportamiento por la misma entrada que usa
   produccion, salvo helpers puros deliberados.
4. Hay un barrido negativo que protege contra reintroducir la deuda.

Con este liston, el informe no sobregeneraliza: reconoce mejoras reales, marca
tasks como cerrado tras el corte de `detail_update` y descarta limpiezas que
solo producirian churn.

### Refuerzo de suficiencia final

El informe queda reforzado con una prueba mas estricta de suficiencia: una
mejora no se considera optima por estar identificada, sino por cerrar una deuda
concreta con el menor concepto nuevo posible. La lectura final por dimension es
esta:

| Dimension | Decision reforzada | Evidencia exigida | Riesgo residual |
| --- | --- | --- | --- |
| DRY | Extraer solo repeticion que duplique una decision, no solo lineas parecidas | El owner nuevo elimina imports/ramas duplicadas en dos o mas callers o centraliza una frontera repetida | Crear helpers genericos si se mide por `wc -l` |
| Tipos y ADT | Usar ADT cuando modela negocio o elimina estados invalidos; no para envolver todo formulario | Barrido de tipos canonicos en `shared/src/domain`, tests de payload/presenter o pattern matching exhaustivo | Mover a shared records que contienen autorizacion, hash, bearer o datos internos |
| API publica | Cada update debe exponer entrada de route, contratos reales y helpers puros deliberados | `rg` negativo de handlers internos y tests entrando por `try_update` o route | Un test directo a un helper interno vuelve a congelar implementacion como contrato |
| UI/UX compartida | Reutilizar primitivas cuando expresan comando, intent, dialogo o accesibilidad comun | Clasificacion de botones/acciones por semantica; no exigir cero `button` raw | Forzar toggles, drag, segmented controls o rows interactivas a un helper incorrecto |
| Servidor/HTTP | Parse/presenter absorben convenciones de transporte antes de servicios/workflows | Tests cercanos de payload/presenter y barridos de sentinels fuera de frontera | Reintroducir `Some(0)`, `active 0/1` o campos internos en handlers |
| Limpieza final | Retirar codigo intermedio si no cerro owner, frontera o test | Guardarrail negativo o borrado de modulo/import obsoleto | Mantener cambios cosmeticos que solo mueven codigo |

La consecuencia practica es que el informe ya no recomienda "seguir
refactorizando" de forma abierta. Recomienda una cola condicionada por
evidencia: si el barrido no muestra API accidental, duplicacion de owner,
sentinel fuera de frontera o tipo canonico duplicado, la accion correcta es no
tocar.

### Checklist operativo para futuros cortes

Antes de aceptar otro corte de limpieza, debe poder rellenarse esta ficha:

| Pregunta | Respuesta minima aceptable |
| --- | --- |
| Que responsabilidad estaba mezclada o repetida? | Nombre de owner anterior, owner nuevo y decision duplicada retirada |
| Que API publica se estrecha? | Lista de simbolos que dejan de ser `pub` o justificacion de cada `pub` que queda |
| Que tipo mejora? | ADT/record compartido/confinamiento de sentinel, o "ninguno" si el corte es solo de API |
| Que test protege el comportamiento? | Test por entrada de produccion; helper puro solo si esta explicitamente justificado |
| Que barrido impide la regresion? | Comando `rg` repetible con resultado esperado y falsos positivos aceptados |

Si una fila no tiene respuesta concreta, el corte no esta listo. Este criterio
protege el patron DRY sin convertirlo en sobreingenieria: solo se extrae cuando
la extraccion borra conocimiento duplicado y se puede verificar.

### Refuerzo de auditoria objetiva

Para que el informe no dependa de una impresion subjetiva de limpieza, esta
seccion fija los barridos que deben repetirse antes de dar por cerrado el
trabajo. El parent de referencia sigue siendo `origin/main`; el alcance debe
leerse con `git diff --name-only origin/main...HEAD` y cada archivo tocado debe
entrar en una de estas categorias: owner cerrado, frontera publica estrechada,
tipo mejor modelado, test acercado a produccion, o residuo justificado.

Evidencia objetiva ya comprobada:

| Barrido | Resultado actual | Lectura |
| --- | --- | --- |
| `rg -n "should\\." apps/client/test apps/server/test shared/test` | Sin matches | Los tests activos no usan el estilo deprecated `should`; los matches restantes estan en docs/build |
| `rg -n "pub type (Task\|Card\|Workflow\|Rule\|ApiToken\|IntegrationUser\|Project\|ProjectMember) \\{" apps/server/src shared/src` | Solo `shared/src/domain/*` | Las entidades canonicas principales no se duplican como tipos publicos de servidor |
| `rg -n "Some\\(0\\)\|#\\(\\\"active\\\"\|payload_fields" apps/server/src apps/client/src apps/server/test apps/client/test shared/src --glob '*.gleam'` | `Some(0)` queda confinado a `http/payload_fields.gleam` y tests; cliente emite `active` por helper | El sentinel historico de transporte esta en frontera, no en negocio |
| Barridos especificos de task types, projects, templates, cards, workflows, org settings, rule metrics, assignments, capabilities y members | Sin matches en handlers cerrados | Los cortes ya ejecutados tienen guardarrail repetible |

La superficie publica restante debe clasificarse, no borrarse en bloque:

| Area | Estado reforzado | Decision optima |
| --- | --- | --- |
| `features/capabilities/crud_update.gleam` y `features/capabilities/assignments_update.gleam` | Cerrado como API publica accidental | Cada sub-owner expone `try_update`; `features/capabilities/update.gleam` compone esos entrypoints; los tests entran por mensajes admin reales. `Success` sigue publico porque `types.success_effect` lo comparte entre CRUD y assignments |
| `features/tasks/dependency_update.gleam` | Cerrado como API publica accidental | `pool/task_route.gleam` consume `try_update`; los tests entran por `pool_messages.MemberDependency*`; los handlers internos quedan privados |
| `features/pool/filters.gleam` y `features/pool/preferences.gleam` | Residuo aceptable mientras sean owners puros de estado compartidos por update/shortcuts/tests | No forzar cierre si el valor es solo reducir `pub`; actuar solo si aparece duplicacion de routing o tests congelando comportamiento effectful |
| `features/pool/card_detail.gleam` y `features/pool/position_edit.gleam` | Owners puros consumidos por adapters effectful (`card_detail_update`, `position_update`) | Mantener publicos si se tratan como API pura interna; cerrar solo si el adapter puede absorberlos sin mezclar efectos y estado |
| `features/admin/member_role.gleam` y `member_role_update.gleam` | Excepciones publicas conocidas (`success_effect`, `error_effect`) por consumo real desde assignments/admin route | No tocar sin cambiar la integracion que los consume |
| `features/tasks/mutation_update.gleam` | Excepcion publica conocida: drag/drop y helpers puros deliberados | No perseguir cero `pub`; conservar mientras el drag sea una frontera real |

El corte de capabilities confirma el criterio del informe: no se creo un
dispatcher generico ni un facade nuevo. Se reutilizo el patron ya probado en
otros updates, con sub-owner estrecho, `try_update` publico, handlers privados
y un ADT de feedback compartido solo donde dos owners lo consumen.

Guardarrail de capabilities:

```sh
rg -n "(crud_update|assignments_update)\.(handle_|success_effect)|^pub fn handle_" apps/client/src/scrumbringer_client/features/capabilities apps/client/test/capabilities_update_test.gleam
```

Resultado actual: sin matches. Si `Success` aparece como `pub type` en
`features/capabilities/types.gleam`, no es deuda de handler operativo: es el
ADT compartido usado por `types.success_effect` desde CRUD y assignments.

Guardarrail de task dependencies:

```sh
rg -n "dependency_update\.handle_|^pub fn handle_(dependencies|dependency)" apps/client/src/scrumbringer_client/features/tasks/dependency_update.gleam apps/client/src/scrumbringer_client/features/pool/task_route.gleam apps/client/test/tasks_dependencies_update_test.gleam
```

Resultado actual: sin matches.

Barrido global residual:

```sh
rg -n "^pub fn handle_" apps/client/src/scrumbringer_client/features --glob '*.gleam'
```

Lectura actual:

| Residuo | Clasificacion | Motivo |
| --- | --- | --- |
| `pool/filters.gleam`, `pool/preferences.gleam`, `pool/card_detail.gleam`, `pool/position_edit.gleam` | API pura interna aceptada | Son owners de estado consumidos por adapters effectful y tests puros; cerrarlos exigiria mezclar estado puro con efectos |
| `admin/cards.gleam` | Puentes reales | `handle_open_card_dialog_for_card tree` y `handle_card_viewed` conectan card trees/card detail con admin cards |
| `card trees/dialog_update.gleam` | Puente real | `handle_card tree_dialog_closed` lo usa shortcut/Escape |
| `auth/helpers.gleam` | Helper transversal deliberado | Centraliza 401/auth para routes admin y pool |
| `tasks/mutation_update.gleam` | Integracion real de drag/drop | `handle_claim_dropped` lo consume `pool/drag_update.gleam` |

Con esta lectura, el siguiente corte no debe salir de este barrido salvo que un
caller nuevo convierta uno de estos residuos en facade accidental. La deuda
real de `pub handle_` operativa queda cerrada para capabilities y dependencies.

### Puerta de cierre antes de commit

Antes de afirmar que la base queda limpia, debe pasar esta puerta:

1. `git diff --name-only origin/main...HEAD` revisado y cada archivo clasificado.
2. `rg -n "should\\." apps/client/test apps/server/test shared/test` sin matches.
3. Barrido de tipos canonicos confirma que `Task`, `Card`, `Workflow`, `Rule`,
   `ApiToken`, `IntegrationUser`, `Project` y `ProjectMember` publicos viven en
   `shared/src/domain`.
4. Barrido de handlers internos por cada corte ejecutado con resultado vacio o
   falso positivo documentado.
5. `gleam format --check src test` y `gleam test` en cada app/shared afectado.
6. Ningun cambio se conserva si solo movio codigo de sitio sin owner retirado,
   frontera publica estrechada, tipo mejorado o test mas cercano.

Si una modificacion no supera el punto 6, debe retirarse aunque compile. Esta
regla es la proteccion principal contra mantener intentos intermedios que no
llegaron a resolver el problema.

### Auditoria de cierre reforzada

El cierre queda reforzado con una comprobacion nueva: ya no basta con decir que
un modulo esta mejor dividido. Cada area tocada debe poder explicarse como una
de estas cuatro salidas:

| Salida | Definicion | Ejemplo aceptado en la rama |
| --- | --- | --- |
| Owner cerrado | Un modulo deja de mezclar contexto, auth, feedback, apply o subflujos de otra familia funcional | Routes admin/pool y sub-updates de tasks/capabilities |
| Frontera publica estrechada | Handlers operativos dejan de ser `pub` y produccion/tests entran por `try_update` o route | `task_types`, `projects`, `templates`, `cards`, `workflows`, `org_settings`, `rule_metrics`, `assignments`, `capabilities`, `dependencies`, `members` |
| Tipo mejor alineado | El contrato canonico queda en `shared` o el record interno queda nombrado como persistencia/proyeccion | `Project`, `ProjectMember`, `ApiToken`, `IntegrationUser`, `Task`, `Card`, `Workflow`, `Rule` |
| Residuo justificado | La API restante tiene consumidor real o separa core puro de efecto | `pool/filters`, `pool/preferences`, `pool/card_detail`, `pool/position_edit`, `auth/helpers`, `admin/cards`, `card trees/dialog_update`, `tasks/mutation_update` |

Si una modificacion no encaja en ninguna salida, no debe permanecer como
limpieza. Esta es la regla que evita conservar intentos intermedios que
compilan pero no reducen responsabilidad duplicada.

#### Gates ejecutados en el refuerzo

El refuerzo incluye una puerta de verificacion ejecutada con base de test local
en `localhost:5433`:

```sh
PGPASSWORD=scrumbringer psql -h localhost -p 5432 -U scrumbringer -d scrumbringer_test -Atc 'select 1'
```

Resultado: falla por conexion rehusada. No se usa como gate valido.

```sh
PGPASSWORD=scrumbringer psql -h localhost -p 5433 -U scrumbringer -d scrumbringer_test -Atc 'select 1'
```

Resultado: `1`.

```sh
DATABASE_URL='postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_test?sslmode=disable' make test
```

Resultado:

| Suite | Resultado |
| --- | --- |
| `apps/server` | `483 passed, no failures` |
| `apps/client` | `1695 passed, no failures` |
| `shared` | `170 passed, no failures` |
| `packages/birl` | `9 passed, no failures` |

`make test` aplica migraciones antes de la suite de servidor. Por tanto, la
limitacion anterior de `DATABASE_URL` queda resuelta para este cierre concreto.
La suite de `packages/lustre_http` no forma parte de `make test`; ya habia sido
validada aparte como paquete independiente y debe seguir ejecutandose cuando se
toque ese paquete.

Guardarrails repetidos en este refuerzo:

```sh
rg -n "should\\." apps/client/test apps/server/test shared/test
```

Resultado: sin matches.

```sh
rg -n "pub type (Task|Card|Workflow|Rule|ApiToken|IntegrationUser|Project|ProjectMember) \\{" apps/server/src shared/src
```

Resultado: solo tipos canonicos en `shared/src/domain/*`.

```sh
rg -n "(crud_update|assignments_update)\\.(handle_|success_effect)|^pub fn handle_" apps/client/src/scrumbringer_client/features/capabilities apps/client/test/capabilities_update_test.gleam
```

Resultado: sin matches.

```sh
rg -n "dependency_update\\.handle_|^pub fn handle_(dependencies|dependency)" apps/client/src/scrumbringer_client/features/tasks/dependency_update.gleam apps/client/src/scrumbringer_client/features/pool/task_route.gleam apps/client/test/tasks_dependencies_update_test.gleam
```

Resultado: sin matches.

#### Veredicto reforzado por dimension

| Dimension | Veredicto | Justificacion | Siguiente accion correcta |
| --- | --- | --- | --- |
| DRY | Mejorado y acotado | Los cortes que permanecen eliminan owners duplicados o APIs accidentales; no se introduce CRUD universal ni facade generica | Mantener solo nuevos helpers con tres usos o una decision de frontera clara |
| Tipos/ADT | Sano bajo guardarrail | Las entidades canonicas principales viven en `shared`; records internos conservan datos de autorizacion/persistencia | Repetir barrido de `pub type` antes de tocar servidor o shared |
| API publica de updates | Cerrada para deudas detectadas | Capabilities y dependencies ya siguen el mismo patron que los cortes previos: `try_update` publico, handlers privados, tests por mensaje real | No perseguir cero `pub`; clasificar residuos por consumidor real |
| UI compartida | Parcial sano | Botones/dialogos se han movido hacia primitivas reutilizables cuando el intent era comun | No forzar controles gestuales, toggles, tabs o rows seleccionables a helpers de accion simple |
| Servidor/HTTP | Sano bajo frontera | Payload/presenter absorben convenciones de transporte; tests DB pasan con migraciones | Vigilar que sentinels y campos internos no vuelvan a handlers o contratos publicos |
| Limpieza final | Con criterio objetivo | Una modificacion solo permanece si cierra owner, frontera, tipo o test | Borrar en futuros cortes cualquier cambio que solo mueva codigo de sitio |

#### Lista cerrada de residuos aceptados

El barrido global de handlers publicos restantes es deliberadamente no vacio.
La lectura correcta no es convertirlo en deuda automatica, sino conservar esta
lista cerrada:

| Modulo | Simbolos | Motivo de aceptacion |
| --- | --- | --- |
| `features/pool/card_detail.gleam` | `handle_opened`, `handle_closed`, `handle_metrics_fetched_ok`, `handle_metrics_fetched_error` | Core puro de estado consumido por adapter effectful |
| `features/pool/filters.gleam` | Handlers de filtros y busqueda | Core puro compartido por update, shortcuts y tests |
| `features/pool/preferences.gleam` | Handlers de preferencias visuales | Core puro de preferencias consumido por route/update |
| `features/pool/position_edit.gleam` | Handlers del editor de posicion | Core de formulario y save/fetch consumido por adapter especifico |
| `features/admin/cards.gleam` | `handle_open_card_dialog_for_card tree`, `handle_card_viewed` | Puentes reales desde card trees/card detail |
| `features/card trees/dialog_update.gleam` | `handle_card tree_dialog_closed` | Puente real para Escape/shortcut |
| `features/auth/helpers.gleam` | `handle_auth_error`, `handle_401_or` | Helper transversal de auth usado por routes |
| `features/tasks/mutation_update.gleam` | `handle_claim_dropped` | Integracion publica real de drag/drop |

Un nuevo `pub fn handle_` fuera de esta tabla debe tratarse como deuda por
defecto hasta que demuestre consumidor externo real. Un simbolo dentro de la
tabla se reabre solo si empieza a actuar como facade accidental o si sus tests
congelan implementacion effectful en vez de comportamiento observable.

#### Rechazos reforzados

Estas soluciones no son optimas ahora, aunque podrian reducir lineas:

| Propuesta rechazada | Por que no es mejor | Evidencia que podria reabrirla |
| --- | --- | --- |
| Partir mas `pool/update.gleam` por tamano | Tareas, metricas, rule metrics, posiciones, skills y auth ya tienen owners; otro corte sin familia nueva solo mueve imports | Un subflujo vuelve a mezclar contexto/apply/auth o tests directos de otro owner |
| Extraer contratos genericos de card trees | Aumentaria imports y conceptos sin retirar decision duplicada | Otro owner necesita esos contratos como frontera real |
| Crear framework CRUD/UI | Los dialogos comparten piezas, no un flujo unico de producto | Tres o mas dialogos con mismo contrato de campos, submit, permisos y feedback |
| Envolver todos los IDs | Churn alto sin bug probado de mezcla | Bug real o frontera donde el tipo opaco elimine estados invalidos frecuentes |
| Eliminar todos los `button` directos | Algunos son primitivas, controles de seleccion, tabs, drag o toggles | Clasificacion que detecte acciones simples repetidas con intent/accesibilidad comun |

Con este refuerzo, el informe queda menos permisivo: una mejora candidata no
es optima por sonar limpia, sino por superar evidencia de owner, frontera,
tipo, test y guardarrail.

#### Corte adicional: valores canonicos en rule CRUD

El barrido de strings de negocio mostro un caso pequeno y accionable en
`components/rule_crud_dialog.gleam`: el formulario ya validaba el submit con
`workflow.parse_rule_target`, pero las opciones del selector de estado repetian
los valores wire de `TaskStatus` y `CardState` como literales locales.

Solucion ejecutada:

1. `state_options_for_resource_type` conserva la frontera DOM como `String`,
   porque los valores vienen de un `<select>`.
2. Los valores de tarea se derivan de
   `task_status.task_status_to_string(Available | Claimed(Taken) | Completed)`.
3. Los valores de card se derivan de
   `card.state_to_string(Pendiente | EnCurso | Cerrada)`.
4. No se introduce un ADT propio del formulario ni un mapper generico: el
   dominio compartido sigue siendo el owner de los valores canonicos.
5. `rule_crud_dialog_test.gleam` anade pruebas puras que verifican los valores
   canonicos de las opciones sin acoplarse al copy i18n.

V/C/R:

| Valor | Complejidad | Riesgo | Decision |
| --- | --- | --- | --- |
| Medio | Baja | Bajo | Ejecutado; elimina drift posible entre UI y dominio sin cambiar el contrato del formulario |

Validacion local del corte:

```sh
cd apps/client
gleam format --check src test
gleam check --target javascript
gleam test --target javascript
```

Resultado: `1695 passed, no failures`.

#### Corte adicional: claimability compartida

El plan de hardening de pull flow exigia que blocked no siguiera como override
modal y que click, drag/drop, canvas card, list row y detalle compartieran una
misma regla de claimability. El barrido confirmo que el override ya estaba
retirado, pero quedaban comprobaciones locales de `blocked_count` repartidas en
vistas y mutacion, ademas de CSS obsoleto `.blocked-claim-*`.

Solucion ejecutada:

1. `features/tasks/claimability.gleam` queda como owner pequeno de
   `can_claim(task)`.
2. `can_claim` usa `TaskState` como fuente de verdad para exigir tarea
   disponible y `blocked_count == 0`.
3. `mutation_update.gleam` usa el helper para click y drag/drop.
4. `task_card.gleam`, `task_row.gleam` y `task_detail_footer.gleam` usan el
   mismo helper para mostrar, ocultar o deshabilitar claim.
5. Se eliminan las clases CSS `.blocked-claim-*`, ya sin consumidores.
6. `pull-flow-model-hardening-plan.md` deja de describir el override bloqueado
   como estado actual y marca la limpieza como ejecutada.
7. `tasks_claimability_test.gleam` cubre disponible/desbloqueada, disponible
   bloqueada, claimed y completed.

V/C/R:

| Valor | Complejidad | Riesgo | Decision |
| --- | --- | --- | --- |
| Alto | Baja-media | Bajo | Ejecutado; borra una decision duplicada de producto y un residuo CSS sin crear framework |

Guardarrail especifico:

```sh
rg -n "member_blocked_claim_task|MemberBlockedClaimCancelled|MemberBlockedClaimConfirmed|blocked_claim_modal|blocked-claim|BlockedClaim" apps/client/src apps/client/test --glob '*.gleam'
```

Resultado: sin matches.

### Refuerzo final solicitado: cierre por deuda, no por volumen

Este refuerzo anade una lectura mas estricta del resultado: la base de codigo
no queda "limpia" porque haya menos ruido visual ni porque todos los modulos
sean pequenos. Queda mejor cuando cada deuda encontrada tiene una salida
verificable: owner unico, frontera publica menor, tipo canonico o test mas
cercano a produccion.

La auditoria posterior a los ultimos cortes deja este mapa:

| Deuda observada | Cambio aceptado | Por que es DRY | Garantia |
| --- | --- | --- | --- |
| Valores wire de estados repetidos en `rule_crud_dialog` | El selector deriva opciones desde `task_status_to_string` y `card.state_to_string` | El dominio compartido vuelve a ser el owner de los valores canonicos | Tests de opciones canonicas y suite cliente `1695 passed` |
| Claimability repartida entre vistas y mutacion | `features/tasks/claimability.gleam` centraliza `can_claim` | Una sola decision define si una tarea puede reclamarse en click, drag, card, row y detalle | Tests de disponible/bloqueada/claimed/completed y guardarrail sin override bloqueado |
| CSS de override bloqueado sin consumidor | Se eliminan `.blocked-claim-*` | Se retira residuo de una UX que ya no existe | Barrido negativo de `blocked-claim` en codigo Gleam activo |
| Plan de pull flow con lenguaje historico ambiguo | El plan distingue estado original de estado implementado | La documentacion ya no contradice el comportamiento actual | `pull-flow-model-hardening-plan.md` marca la limpieza como Done |

Estos cambios son mejores que seguir partiendo roots porque atacan decisiones
duplicadas de producto. En cambio, partir otro shell sin borrar conocimiento
operativo solo moveria codigo y aumentaria el numero de imports.

#### Requisitos de aceptacion reforzados

Un corte futuro solo debe entrar si puede rellenar esta matriz antes de tocar
codigo:

| Pregunta | Respuesta exigible |
| --- | --- |
| Que decision estaba duplicada? | Nombre concreto de regla, payload, handler, presenter, tipo o helper |
| Quien sera el owner unico? | Modulo existente preferentemente; modulo nuevo solo si tiene responsabilidad de producto estrecha |
| Que queda menos publico? | Simbolos que dejan de ser `pub` o frontera que deja de filtrar datos internos |
| Que tipo mejora? | ADT/record canonico, sentinel confinado o decision explicita de no crear tipo nuevo |
| Que test lo prueba como produccion? | Entrada por route, `try_update`, presenter, payload o helper puro justificado |
| Que barrido detecta regresion? | Comando `rg` repetible y resultado esperado |

Si una respuesta es "reduce lineas" o "queda mas ordenado" pero no identifica
owner, frontera, tipo o test, la mejora no debe ejecutarse.

#### Evidencia de cierre actual

Los gates ejecutados despues de reforzar el informe son:

| Gate | Resultado |
| --- | --- |
| `gleam format --check src test` en `apps/client` | Pasa |
| `gleam check --target javascript` en `apps/client` | Pasa |
| `gleam test --target javascript` en `apps/client` | `1695 passed, no failures` |
| `DATABASE_URL=...:5433/scrumbringer_test make test` | Server `483`, client `1695`, shared `170`, birl `9`; sin fallos |

Barridos de regresion relevantes:

```sh
rg -n "should\\." apps/client/test apps/server/test shared/test
```

Resultado: sin matches.

```sh
rg -n "member_blocked_claim_task|MemberBlockedClaimCancelled|MemberBlockedClaimConfirmed|blocked_claim_modal|blocked-claim|BlockedClaim" apps/client/src apps/client/test --glob '*.gleam'
```

Resultado: sin matches.

```sh
rg -n "can_claim_task|blocked_claim_modal|blocked-claim" apps/client/src apps/client/test --glob '*.gleam'
```

Resultado: sin matches para las obsolescencias; la regla vigente es
`claimability.can_claim`.

```sh
rg -n "pub type (Task|Card|Workflow|Rule|ApiToken|IntegrationUser|Project|ProjectMember) \\{" apps/server/src shared/src
```

Resultado: solo tipos canonicos en `shared/src/domain`.

#### Estado reforzado por area

| Area | Estado | Decision |
| --- | --- | --- |
| Task claimability | Cerrado | `TaskState` mas `blocked_count` gobiernan la capacidad de reclamar; servidor sigue siendo autoridad final |
| Rule CRUD state values | Cerrado | La UI mantiene strings de DOM, pero los valores nacen de los tipos canonicos |
| Updates con handlers publicos accidentales | Cerrado para los casos detectados | Mantener barridos; no exigir cero `pub` cuando hay consumidor real |
| Pool y card trees roots | Parcial sano | No tocar por tamano; solo por nueva familia funcional con contexto/apply/auth duplicado |
| UI compartida | Parcial sano | Seguir usando primitivas existentes para acciones simples; no forzar toggles, drag, tabs o rows a helpers genericos |
| Tipos compartidos | Sano bajo guardarrail | No mover a `shared` records con autorizacion, persistencia, hashes, bearer o auditoria |

#### Que no se ha dejado a medias

El refuerzo tambien revisa el riesgo de conservar intentos que no resolvieron
el problema. En los cortes actuales no queda una solucion intermedia activa:

- el override de blocked claim no queda como flujo alternativo;
- la CSS asociada al override se retiro;
- las vistas y mutaciones no conservan reglas divergentes de claimability;
- el plan de pull flow ya no describe el override como estado vigente;
- las opciones del dialogo de reglas no conservan literales canonicos propios
  para los estados de tarea/card.

Lo que queda como "parcial sano" no es intento fallido: son fronteras que aun
tienen consumidores reales o shells que componen owners ya extraidos. Deben
vigilarse, pero no refactorizarse sin nueva evidencia.

#### Veredicto reforzado

Las mejoras indicadas y ejecutadas son optimas bajo el estado actual porque
cumplen simultaneamente:

1. reducen una decision duplicada de producto o una frontera publica accidental;
2. reutilizan owners existentes del dominio o crean un owner estrecho;
3. no convierten detalles de UI, SQL o DOM en ADTs globales;
4. quedan protegidas por tests y barridos repetibles.

El siguiente mejor cambio no se puede elegir por intuicion ni por numero de
lineas. Debe salir del primer barrido que encuentre una decision duplicada real
con test cercano y coste bajo. Hasta entonces, la opcion tecnicamente correcta
es mantener guardarrails y no introducir mas estructura.

#### Corte adicional: trazabilidad del inventario Lustre

La puerta de aceptacion del informe exige que los routes extraidos queden
reflejados en `docs/lustre_inventory.yml`. El barrido detecto una omision
documental: `features/pool/task_route.gleam` ya existia, tenia test propio y
el informe lo clasificaba como cerrado, pero no aparecia en el inventario junto
a los otros routes de pool.

Solucion ejecutada:

1. Se anade `features/pool/task_route` al `module_index`.
2. Se actualiza `src_modules_found` con el conteo actual de
   `apps/client/src` + `shared/src`.
3. Se actualiza `src_modules_inventoried` con el numero real de entradas del
   `module_index`.
4. La nota de cobertura queda alineada con los refactors de routes admin/pool.

V/C/R:

| Valor | Complejidad | Riesgo | Decision |
| --- | --- | --- | --- |
| Medio | Baja | Bajo | Ejecutado; corrige trazabilidad sin tocar comportamiento ni introducir abstraccion |

Guardarrail:

```sh
rg -n "features/pool/task_route" docs/lustre_inventory.yml apps/client/test/pool_task_route_test.gleam apps/client/src/scrumbringer_client/features/pool/task_route.gleam
```

Resultado esperado: matches en inventario, test y modulo.

## Conclusion

La limpieza con mejor relacion beneficio/riesgo no esta en crear nuevas
abstracciones, sino en alinear los tipos existentes con sus owners reales. El
dominio compartido ya tiene varias entidades canonicas; el trabajo ejecutado ha
reducido duplicados de servidor, ha dejado el estado global de cliente solo para
tipos transversales y ha movido los flujos principales de
tasks/admin/capabilities a owners mas precisos.

El informe reforzado deja una lectura mas estricta: no queda justificado seguir
partiendo modulos por tamano. El siguiente trabajo debe atacar deuda con
evidencia concreta:

- vigilar que los sentinels de persistencia sigan confinados en constantes privadas y no reaparezcan como literales en dominio, HTTP o workflows;
- vigilar que `Workflow`, `Rule`, `ApiToken` e `IntegrationUser` no reaparezcan como tipos publicos de servidor y que los shapes internos mantengan sufijo `Record`;
- extraer mas admin solo si el root vuelve a mostrar contexto/apply/auth repetido con tests propios;
- tratar pool como parcialmente saneado: tareas y auth ya tienen owners; el siguiente corte exige otra familia funcional clara;
- revisar card trees con el mismo liston usado en pool, no por longitud;
- ampliar `crud_dialog_base` solo con piezas repetidas en tres o mas dialogos;
- rechazar cualquier limpieza que no pueda demostrar owner retirado, frontera
  estrechada, tipo mejor modelado o test mas cercano a la entrada real.

Este camino sigue reduciendo duplicacion, mejora tipos y ordena la base de
codigo sin introducir sobreingenieria. La regla final es sencilla: cada cambio
que se quede debe borrar una decision duplicada, estrechar una frontera tecnica
o acercar una prueba al owner real. Si solo mueve codigo de sitio, debe
descartarse.
