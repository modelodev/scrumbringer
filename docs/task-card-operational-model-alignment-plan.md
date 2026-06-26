# Task/Card Operational Model Alignment Plan

## Contexto

Este plan registra la solucion para alinear Pool, Kanban, Capacidades,
Personas y Plan con el modelo operativo actual de ScrumBringer.

El diagnostico previo detecto que las vistas no estaban rotas por render:

- Pool aparece vacio porque el endpoint general de tasks no devuelve trabajo
  abierto fuera de cards activas.
- Capacidades aparece vacia por la misma razon: no recibe tasks activas que
  agrupar por capacidad.
- Kanban aparece vacio porque no hay cards activas.
- Plan no muestra arbol porque los proyectos seed tienen solo cards raiz; no
  hay `parent_card_id`.
- Personas puede mostrar trabajo que Pool/Capacidades ocultan porque su query
  no aplica el mismo criterio operativo.

El problema real es que los datos y parte del backend todavia permiten estados
que el modelo nuevo ya no deberia tratar como normales.

## Regla De Dominio

Regla minima que se debe consolidar:

```text
Toda task tiene card.
Toda task abierta, reclamada o en curso vive en una card active.
Las cards draft son planificacion.
Las cards closed son historico.
```

Decisiones asociadas:

- No se permiten root tasks inicialmente.
- No se crean tasks nuevas en cards closed.
- Una task closed puede quedar como historico bajo la card donde se cerro.
- Si aparece trabajo nuevo relacionado con una card closed, se crea una task en
  una card active y se mantiene la relacion historica como mejora futura, no
  como excepcion al contenedor operativo.

## Objetivos

1. Hacer que Pool, Kanban, Capacidades, Personas y Plan funcionen con datos
   seed validos.
2. Eliminar estados operativos invalidos: tasks sin card y tasks abiertas en
   cards no activas.
3. Unificar backend para que todas las vistas lean el mismo universo valido de
   trabajo.
4. Blindar la regla en API/backend y, cuando los datos esten estabilizados, en
   base de datos.
5. Limpiar codigo, textos, tests y seeds que mantengan soporte implicito para
   root tasks o trabajo reclamable fuera de card activa.

## Orden Recomendado

No empezar por constraints duras en BBDD. Primero hay que estabilizar datos,
tests y backend para evitar bloquear migraciones o flujos legitimos mientras
todavia hay datos invalidos.

Orden:

1. Tests rojos de contrato.
2. Seed y migracion de datos dev.
3. Backend/API.
4. Frontend y tipos.
5. Constraints BBDD.
6. Limpieza.
7. Validacion con agent-browser.

## Fase 1: Tests Rojos

### Backend/API

Codificar tests que fallen antes de la correccion:

- Crear task sin `card_id` devuelve error de validacion.
- Crear task en card closed devuelve error de validacion.
- Crear task en card active funciona.
- Reclamar task en card draft devuelve error.
- Reclamar task en card active funciona.
- `GET /projects/:id/tasks` devuelve trabajo abierto de cards activas.
- `people_workload_list` no devuelve trabajo reclamado invalido.

### Frontend

Codificar tests de vistas con fixtures validos:

- Pool muestra tasks `available` bajo card active.
- Pool no muestra tasks bajo card draft.
- Capacidades agrupa tasks de cards activas por capacidad.
- Kanban muestra cards activas con contadores.
- Plan muestra arbol cuando existen `parent_card_id`.
- Personas muestra task y card para trabajo reclamado valido.
- Personas no necesita fallback operativo `No card` para trabajo reclamado.

### Seed Smoke

Agregar o ajustar test/smoke que valide que los proyectos demo tienen:

- al menos una card active;
- al menos una task available en card active;
- cero tasks abiertas sin card;
- cero tasks abiertas en card draft/closed;
- al menos una card hija si el proyecto se usa para validar Plan.

## Fase 2: Seed Y Datos Dev

Corregir seed para que sea representativo del modelo real:

- Crear jerarquia real de cards:
  - nivel 1: area/iniciativa;
  - nivel 2: historia/card ejecutable;
  - nivel 3 opcional si ya lo soporta el proyecto.
- Activar al menos una rama/card por proyecto demo.
- Crear tasks siempre con `card_id`.
- Crear tasks `available` y `claimed` solo en cards `active`.
- Mantener cards `draft` como planificacion sin trabajo reclamable.
- Mantener cards `closed` como historico.
- Eliminar root tasks del seed.

Migracion para datos dev actuales:

- Tasks sin card:
  - mover a una card active existente del proyecto; o
  - crear una card active explicita tipo `Triage` por proyecto y moverlas ahi.
- Tasks abiertas en cards draft:
  - activar la card si representa trabajo actual; o
  - mover la task a una card active.
- Cards planas:
  - asignar `parent_card_id` para formar un arbol real en proyectos demo.

No introducir compatibilidad legacy para mantener root tasks.

## Fase 3: Backend/API

Unificar la verdad operativa:

- `tasks_create` debe exigir `card_id`.
- `tasks_create` debe rechazar cards closed.
- `tasks_create` debe decidir de forma explicita si permite crear en draft.
  Para esta fase, si queremos que Pool funcione de forma inmediata, crear
  trabajo operativo desde Pool debe exigir card active.
- `tasks_claim` debe exigir card active.
- `tasks_list` ya esta cerca del modelo: no relajar su filtro para aceptar
  datos invalidos.
- `people_workload_list` debe alinearse con el mismo criterio operativo.

Errores API recomendados:

- `CARD_REQUIRED`
- `CARD_NOT_ACTIVE`
- `CARD_CLOSED`
- `TASK_CARD_REQUIRED`

Evitar duplicacion ad hoc:

- Si la condicion aparece en varias SQL, extraer una pieza local solo si reduce
  duplicacion real.
- No crear una capa generica de policy si basta con validar en los puntos de
  entrada y queries afectadas.

## Fase 4: Frontend Y Tipos

### Creacion De Task

- El formulario de task debe requerir card.
- Desde Pool, `Nueva tarea` abre el formulario normal con selector de card
  active.
- Si solo hay una card active, preseleccionarla.
- Si no hay cards active, mostrar empty state accionable:

```text
No hay cards activas.
Activa una card en Plan antes de crear trabajo.
```

### Pool

- No relajar Pool para mostrar root tasks.
- Pool debe mostrar solo trabajo disponible real: tasks `available` en cards
  active.
- Mantener `Nueva tarea`, pero exigir card active.

### Kanban

- Kanban debe seguir mostrando cards activas.
- La solucion no es mostrar cards draft como activas, sino seed/datos validos.

### Capacidades

- Capacidades debe agrupar tasks activas por capacidad.
- No debe tener fallback para trabajo operativo sin card.

### Personas

- Personas debe dejar de ser una excepcion.
- Las tasks reclamadas deben venir con card valida.
- El fallback `No card` debe eliminarse para trabajo operativo si ya no puede
  ocurrir.

### Plan

- Plan debe mostrar arbol si existen relaciones `parent_card_id`.
- La correccion principal aqui es seed/datos, no render.
- Mantener tests de expandir/colapsar con hijos reales.

### Tipos

Refactor gradual:

- Reducir `Option(Int)` para `card_id` donde el dominio operativo ya no admite
  ausencia.
- Mantener `Option` solo en fronteras donde representa input incompleto o datos
  historicos durante migracion.
- No propagar `NoCard` como caso normal en UI operativa.

## Fase 5: Constraints BBDD

Ejecutar cuando tests, seed y backend ya esten verdes.

Endurecimientos previstos:

- `tasks.card_id NOT NULL`.
- Constraint o trigger para impedir task abierta/reclamada sin card.
- Trigger para impedir task abierta/reclamada en card no active.
- Trigger o validacion transaccional para impedir claim si la card no esta
  active.
- Validacion para impedir que una card deje de estar active si conserva tasks
  abiertas, salvo que el flujo cierre/libere/mueva esas tasks explicitamente.

Mantener permitido:

- Tasks closed como historico.
- Cards draft sin trabajo reclamable.
- Cards closed sin nuevas tasks.

## Fase 6: Limpieza Y Refactor

Eliminar o actualizar:

- Textos de root task:
  - `Root Pool task`
  - `Pool raiz`
  - hints que expliquen creacion sin card.
- Tests que creen tasks operativas sin card.
- Helpers de fixtures que generen tasks sin card por defecto.
- Fallbacks visuales `No card` en trabajo reclamado/activo.
- Seeds duplicadas o planas que no sirvan para validar arbol.
- Ramas frontend que traten `card_id = None` como caso normal en Pool,
  Capacidades, Kanban o Personas.
- Cualquier compatibilidad interna para claimed tasks fuera de card active.

Refactor recomendado:

- Mantener condiciones de modelo cerca de cada frontera:
  - API create/claim;
  - SQL list/workload;
  - formularios de creacion.
- Extraer helpers solo cuando haya duplicacion real.
- No crear framework generico de "work item policy" si el modelo cabe en
  validaciones explicitas.

## Fase 7: Validacion Con Agent-Browser

Ejecutar con `scripts/dev-hot.sh` sano y base de datos seed/migrada.

### Pool

URL:

```text
http://192.168.1.120:8443/app/pool?project=2&view=pool
```

Validar:

- Se ven tasks disponibles.
- Los contadores de abiertas/reclamables no son cero si el seed tiene trabajo.
- `Nueva tarea` exige card active.
- Crear una task en card active hace que aparezca en Pool.

### Kanban

URL:

```text
http://192.168.1.120:8443/app/pool?project=2&view=cards&plan_mode=kanban
```

Validar:

- Hay cards activas en columnas.
- Los contadores reflejan trabajo real.
- No se muestran cards draft como trabajo activo.

### Capacidades

URL:

```text
http://192.168.1.120:8443/app/pool?project=2&view=capabilities
```

Validar:

- Se muestran grupos por capacidad.
- Filtro de capacidad reduce resultados correctamente.
- No aparece empty state si el seed tiene tasks activas.

### Plan

URL:

```text
http://192.168.1.120:8443/app/pool?project=2&view=cards&plan_mode=structure
```

Validar:

- Se ve arbol con hijos indentados.
- Expandir/colapsar funciona.
- No se limita a cards de primer nivel si hay `parent_card_id`.

### Personas

URL:

```text
http://192.168.1.120:8443/app/pool?project=2&view=people
```

Validar:

- Las personas con trabajo muestran task y card.
- No aparece trabajo reclamado sin card.
- No hay discrepancia con Pool/Capacidades sobre trabajo visible.

## Gates Finales

```sh
cd apps/server && gleam test
cd apps/client && gleam test
cd apps/client && gleam test --target javascript
git diff --check
scripts/dev-hot-status.sh
```

Si hay tests DB especificos con PostgreSQL:

```sh
cd apps/server && DATABASE_URL="postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable" gleam test
```

## Criterios De Finalizacion

- Pool muestra trabajo disponible bajo cards activas.
- Kanban muestra cards activas.
- Capacidades agrupa tasks activas por capacidad.
- Plan muestra jerarquia real.
- Personas no muestra trabajo operativo invalido.
- No quedan root tasks en seed.
- No quedan tasks abiertas/reclamadas sin card.
- No quedan tasks abiertas/reclamadas en cards no activas.
- La regla queda cubierta por tests de backend, frontend y BBDD.
- El codigo obsoleto de root tasks y fallbacks `No card` queda eliminado.
