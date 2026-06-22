# Codebase Refactor Cleanup Planning Goal

## Objetivo

Disenar un plan completo de refactorizacion y limpieza de la base de codigo tras
la reestructuracion iniciada en el commit
`3511cf309cb45015109f81ab78733e6db34ca1a0`.

Este goal no ejecuta la refactorizacion. Su resultado es un informe accionable
que servira como entrada para un goal posterior de ejecucion.

Este goal debe ejecutarse despues de completar y comitear:

- `docs/card-task-show-redesign-plan.md`
- `docs/pool-work-surface-unification-plan.md`
- `docs/fin_refactor.md`

No debe diagnosticar como deuda final una zona que este a medio ejecutar por
uno de esos planes. Si alguno no se ha completado, el informe debe marcarlo como
prerequisito pendiente y no proponer una limpieza global sobre un estado
intermedio.

Frontera fuerte:

- Este goal genera `docs/codebase_refactor_cleanup_plan.md`.
- Este goal no aplica la refactorizacion global.
- Este goal no debe mezclar analisis con cambios amplios de codigo.
- Solo puede hacer cambios menores de documentacion si son necesarios para dejar
  claro el informe producido.

El plan debe dejar claro como conseguir una base de codigo cohesionada,
idiomatica en Gleam y Lustre, bien testeada, documentada, con responsabilidades
claras, sin codigo obsoleto y sin abstracciones innecesarias.

## Contexto De Cambio

Desde el commit base la refactorizacion ha afectado a toda la aplicacion:

- Dominio compartido.
- Modelo SQL y migraciones.
- Repositorios y casos de uso del servidor.
- Frontera HTTP y contratos compartidos.
- Estado y actualizaciones del cliente.
- Vistas principales.
- Componentes de UI.
- Seeds, tests y documentacion.

Por tamano y alcance, el analisis no debe empezar como revision fichero a
fichero. Primero debe entender la arquitectura y los flujos de producto; despues
debe bajar modulo a modulo solo en las zonas de mayor riesgo.

## Principios

### Calidad Gleam

- Modelar estados significativos con ADT cuando reduzcan estados ilegales o
  simplifiquen control de flujo.
- Mantener los strings en DB, JSON, formularios DOM y fronteras externas.
- Usar tipos canonicos de dominio en shared cuando cliente y servidor comparten
  contrato real.
- Reducir superficie `pub` cuando no aporte un contrato estable.
- Separar transformaciones puras de efectos, IO, SQL, HTTP y browser interop.
- Preferir Result/Option explicitos frente a sentinelas o combinaciones de flags.

### Calidad Lustre

- Reutilizar tipos de dominio antes de crear tipos especificos de UI.
- Mantener `Model` y `Msg` claros y pequenos.
- Nombrar mensajes como eventos: `User...`, `Api...`, `Parent...`, `Dom...`.
- Mantener efectos en los bordes.
- Evitar vistas que mezclen decision de dominio, query, estado global y markup.
- Validar accesibilidad, foco, teclado, responsive y estados vacios/cargando/error.

### Anti-Sobreingenieria

- No crear capas `service`, `manager`, `facade`, `builder` o `adapter` si no
  eliminan duplicacion real o acoplamiento concreto.
- No subir componentes a `ui/` solo por posibilidad futura de reutilizacion.
- No convertir diferencias legitimas de producto en una abstraccion comun.
- Preferir codigo local claro si una abstraccion generica exige demasiados
  parametros o callbacks.
- Rechazar mejoras con baja relacion valor/complejidad/riesgo.

## Metodo De Analisis

### 1. Preparar Baseline

1. Registrar rama, HEAD, estado de git y diff contra el commit base.
2. Registrar si el working tree contiene cambios no relacionados.
3. Ejecutar, si el estado lo permite:
   - `gleam format --check src test` en cada paquete relevante.
   - `gleam test --target erlang`.
   - `gleam test --target javascript`.
4. Si la baseline falla, documentar los fallos y separarlos de la deuda de
   refactor.

### 2. Inventario Por Capas

Construir un inventario desde el commit base:

- Archivos anadidos, modificados, borrados y renombrados.
- Modulos nuevos.
- Modulos eliminados.
- Modulos con mayor crecimiento.
- Modulos con mayor superficie publica.
- Modulos de mas de 700 lineas.
- Tests nuevos, eliminados y grandes.
- Migraciones y schema final.

Clasificar cada archivo por capa:

- `shared/domain`
- `shared/api`
- `db/migrations`
- `server/repository`
- `server/use_case`
- `server/http`
- `client/api`
- `client/state`
- `client/update`
- `client/views`
- `client/ui`
- `styles`
- `seeds`
- `tests`
- `docs`

### 3. Auditoria Por Flujos Criticos

Analizar flujos completos antes de proponer cambios locales:

1. Lifecycle de card.
2. Lifecycle de task.
3. Pool y claimability.
4. Estructura/Plan/arbol de cards.
5. Kanban.
6. Capacidades.
7. Personas.
8. Card Show.
9. Task Show.
10. Movimiento de cards.
11. Due dates y urgencia visual.
12. Blockers y dependencias.
13. Notas y actividad.
14. Automatizaciones/workflows/reglas/plantillas/ejecuciones.
15. Project settings y configuracion de niveles.
16. Seeds de validacion.

Para cada flujo, documentar:

- Entidades y tipos involucrados.
- Fuente de verdad.
- Fronteras DB/HTTP/JSON/UI.
- Estados ilegales que deberian ser irrepresentables.
- Duplicacion entre cliente, servidor y shared.
- Tests existentes.
- Tests faltantes.
- Codigo obsoleto o sospechoso.

### 4. Auditoria De Fronteras

Revisar que cada frontera tenga una responsabilidad clara:

- SQL y migraciones: estructura final, constraints, triggers, indices.
- Repository: conversion DB <-> dominio, queries, errores tecnicos.
- Use case: reglas de negocio y orquestacion.
- HTTP: payloads, permisos, errores, presenters.
- Shared contracts/codecs: contratos cliente-servidor.
- Client API: requests/decoders sin logica de negocio accidental.
- Client state/update: estado y transiciones.
- View/components: representacion visual y eventos.

Se debe buscar especialmente:

- lifecycle duplicado;
- mappers paralelos;
- presenters que recalculan negocio;
- clientes que reconstruyen reglas del servidor;
- strings canonicos dispersos;
- validaciones duplicadas sin razon;
- tipos publicos que solo usan un modulo;
- rutas o pantallas obsoletas.

### 5. Auditoria De Componentizacion UI

Revisar el lenguaje visual y la reutilizacion real:

- `work_surface`
- `scope_bar`
- `filter_bar`
- `data_table`
- `empty_state`
- `skeleton`
- `confirm_dialog`
- `form_field`
- `button`
- `action_menu`
- `search_select`
- `card_picker`
- `notes_list`
- `activity_feed`
- `show_tabs`

Detectar:

- componentes ubicados en una feature pero usados como shared;
- nombres que ya no reflejan responsabilidad;
- duplicacion de header/scope/filter/body;
- vistas que usan controles distintos para la misma decision;
- modales CRUD que deberian evolucionar a paneles o superficies operativas;
- tablas usadas donde el dato no es realmente tabular;
- componentes demasiado genericos que ocultan diferencias de producto.

### 6. Revision Modulo A Modulo En Zonas Calientes

Tras los pasos anteriores, hacer revision modulo a modulo solo en zonas con
senales de riesgo:

- Archivos de mas de 700 lineas.
- Modulos con mucha API publica.
- Modulos que mezclan varias capas.
- Modulos con nombres legacy o responsabilidad historica.
- Modulos con tests grandes y fragiles.
- Modulos que concentran cambios de varios objetivos.

Zonas iniciales a revisar:

- `apps/client/src/scrumbringer_client/client_view.gleam`
- `apps/client/src/scrumbringer_client/client_update.gleam`
- `apps/client/src/scrumbringer_client/components/card_detail_modal.gleam`
- `apps/client/src/scrumbringer_client/features/plan/structure_view.gleam`
- `apps/client/src/scrumbringer_client/features/capability_board/view.gleam`
- `apps/client/src/scrumbringer_client/features/people/view.gleam`
- `apps/client/src/scrumbringer_client/features/views/kanban_board.gleam`
- `apps/client/src/scrumbringer_client/features/plan/scope_bar.gleam`
- `apps/client/src/scrumbringer_client/components/*_crud_dialog.gleam`
- `apps/server/src/scrumbringer_server/sql.gleam`
- `apps/server/src/scrumbringer_server/seed_builder.gleam`
- `apps/server/src/scrumbringer_server/seed_db.gleam`
- `apps/server/src/scrumbringer_server/use_case/cards_db.gleam`
- `apps/server/src/scrumbringer_server/use_case/rules_engine.gleam`
- `apps/server/src/scrumbringer_server/use_case/workflows/handlers.gleam`
- `apps/server/src/scrumbringer_server/http/tasks/*`
- `apps/server/src/scrumbringer_server/http/cards.gleam`
- `shared/src/domain/task.gleam`
- `shared/src/domain/task_state.gleam`
- `shared/src/domain/task_status.gleam`
- `shared/src/domain/card.gleam`
- `shared/src/domain/card/*`

## Preguntas Que El Informe Debe Responder

1. Cual es la fuente de verdad de cada estado importante.
2. Que tipos son canonicos y cuales son solo frontera.
3. Que modulos tienen demasiada responsabilidad.
4. Que componentes deberian moverse, renombrarse o quedarse locales.
5. Que codigo debe eliminarse sin compatibilidad legacy.
6. Que tests son redundantes, fragiles o insuficientes.
7. Que seeds ya no representan bien el producto.
8. Que abstracciones actuales son utiles.
9. Que abstracciones actuales son sobreingenieria.
10. Que nuevas abstracciones se justifican por reutilizacion real.
11. Que cambios tienen mayor valor con menor complejidad y riesgo.

## Salida Esperada

El goal debe generar un documento nuevo:

`docs/codebase_refactor_cleanup_plan.md`

El documento debe contener:

1. Resumen ejecutivo.
2. Estado de baseline y comandos ejecutados.
3. Inventario por capas.
4. Diagnostico por flujo critico.
5. Diagnostico por frontera arquitectonica.
6. Diagnostico de componentizacion UI.
7. Zonas calientes modulo a modulo.
8. Codigo obsoleto o incompatible a eliminar.
9. Oportunidades de simplificacion.
10. Oportunidades de mejora de tipos.
11. Oportunidades de mejora Lustre/UI.
12. Plan de ejecucion por slices.
13. Tests que debe anadir o reforzar cada slice.
14. Criterios de aceptacion.
15. Validaciones agent-browser recomendadas.
16. Mejoras rechazadas por sobreingenieria.
17. Orden recomendado de commits para el goal de ejecucion posterior.

## Orden Recomendado Del Plan De Ejecucion Posterior

El informe debe proponer slices en este orden, salvo que el analisis demuestre
otra prioridad:

1. Baseline y limpieza de obsoletos evidentes.
2. Dominio shared y tipos canonicos.
3. SQL/schema/repositorios.
4. Use cases servidor.
5. HTTP/payloads/presenters/codecs.
6. Client API/state/update.
7. Componentes UI compartidos.
8. Vistas principales.
9. Automatizaciones.
10. Seeds.
11. Tests transversales.
12. Documentacion.
13. Barrido final anti-legacy, anti-duplicacion y anti-sobreingenieria.

## Criterio De Priorizacion

Cada mejora debe clasificarse con:

- Valor: alto, medio, bajo.
- Complejidad: alta, media, baja.
- Riesgo: alto, medio, bajo.

Priorizar:

1. Mayor valor.
2. Menor complejidad.
3. Menor riesgo.

Rechazar o posponer mejoras donde la complejidad aumente sin una reduccion real
de duplicacion, acoplamiento, riesgo o carga cognitiva.
