# Fin Refactor Plan

## Objetivo

Cerrar los ultimos bloques de diseno necesarios tras la reestructuracion de
ScrumBringer, evitando abrir pantallas o subsistemas nuevos sin una necesidad
clara.

Este plan recoge decisiones de producto pendientes para completar la experiencia
del proyecto despues de Card Show, Task Show, Pool, Plan, Kanban, Capacidades y
Personas.

## Prerequisitos Y Frontera

Este plan asume ejecutados y validados:

- `docs/card-task-show-redesign-plan.md`
- `docs/pool-work-surface-unification-plan.md`

`fin_refactor` no debe redisenar Pool, Card Show ni Task Show. Solo debe
consumir esas superficies y anadir lo necesario para:

- onboarding y settings de proyecto;
- automatizaciones, reglas, plantillas y ejecuciones;
- trazabilidad de tasks creadas por automatizacion;
- seeds y validaciones finales.

Si durante la implementacion aparece una contradiccion real con esos planes, se
debe documentar y aplicar el ajuste minimo. No reabrir decisiones ya cerradas por
preferencia estetica o refactor oportunista.

## Alcance Activo

### Directrices Transversales

Todo bloque de este plan debe seguir estas reglas para evitar nuevas pantallas
incompatibles entre si:

- Usar una superficie operativa comun cuando sea una vista de trabajo o
  configuracion frecuente.
- Preferir `work_surface` para cabecera, resumen, filtros y cuerpo.
- Usar `filter_bar` para controles de busqueda/refinamiento.
- Usar `data_table` solo cuando la informacion sea realmente tabular.
- Evitar CRUDs aislados cuando el usuario esta configurando un flujo.
- Evitar modales grandes como primera opcion; usar panel/drawer progresivo para
  crear o editar salvo confirmaciones destructivas.
- Mantener el lenguaje de producto en UI y dejar nombres tecnicos para el
  dominio interno cuando no haya coste.
- Cada pantalla nueva o redisenada debe tener:
  - empty state util;
  - loading/skeleton;
  - errores visibles y accionables;
  - validacion con agent-browser en desktop y mobile.
- Los mockups ASCII de este documento fijan jerarquia, comportamiento, densidad
  y relaciones entre controles. No fijan copy final, espaciado exacto ni
  composicion pixel-perfect.
- Ningun mockup debe contradecir las decisiones de dominio. Si el modelo impide
  guardar una regla incompleta, los ejemplos deben mostrar estados sanos,
  pausados o `requiere revision`, no configuraciones nuevas con 0 plantillas.

### 1. Onboarding / Creacion De Proyecto

El wizard debe ayudar a configurar el proyecto sin convertir ScrumBringer en una
herramienta pesada o metodologica.

Pasos recomendados:

```text
Crear proyecto

1. General
   - Nombre
   - Proposito breve

2. Estructura Y Pool
   - Profundidad maxima
   - Nombre visible de cada nivel
   - Nota formativa con ejemplos
   - Limite blando
   - Explicacion de saturacion/frustracion

3. Capacidades
   - Capacidades iniciales

4. Equipo
   - Invitar miembros o saltar

5. Revision
   - Confirmar configuracion
```

Mockup orientativo:

```text
Crear proyecto                                             Paso 2 de 5
Estructura Y Pool

Como quieres descomponer el trabajo?

Profundidad maxima
[ 3 niveles v ]

Nombres visibles
Nivel 1  [ Hito                                      ]
Nivel 2  [ Entrega                                   ]
Nivel 3  [ Historia                                  ]

Ejemplos comunes
Ligero: Card -> Task
Producto: Hito -> Entrega -> Historia -> Task
Operaciones: Flujo -> Task

Limite blando del Pool
[ 20 ] tareas
Este limite no bloquea. Sirve para evitar saturacion y frustracion cuando hay
demasiadas tareas disponibles en el Pool.

[Atras]                                           [Continuar]
```

Decisiones cerradas:

- No hay perfiles seleccionables ni campo precargado.
- El wizard muestra una nota textual con ejemplos, solo para formar al usuario.
- El usuario configura manualmente la estructura.
- La estructura minima no se puede saltar.
- El resto de pasos puede saltarse.
- Capacidades se configuran antes de invitar/asignar equipo.

Nota formativa sugerida:

```text
Ejemplos comunes:
- Ligero: Card -> Task
- Producto: Hito -> Entrega -> Historia -> Task
- Operaciones: Flujo -> Task
```

### 2. Project Settings

Settings debe ser la version compacta y editable del mismo modelo mental del
wizard.

Secciones recomendadas:

```text
Project Settings

[General] [Estructura y Pool] [Capacidades] [Equipo]
```

Mockup orientativo de `Estructura y Pool`:

```text
Project Settings - Default
Configura como se organiza el trabajo sin cambiar la forma de reclamarlo.

[General] [Estructura y Pool] [Capacidades] [Equipo]

Profundidad maxima                       [ 3 niveles v ]

Nombres visibles
1  [ Hito      ]
2  [ Entrega   ]
3  [ Historia  ]

Pool
Limite blando                            [ 20 ]
Evita saturacion y frustracion. No bloquea la creacion de tareas.

[Guardar cambios]
```

Permisos:

- Solo managers editan settings.
- Lectura parcial para miembros no se implementa de momento salvo que aparezca
  una necesidad clara.

#### Estructura

Settings permite modificar:

- nombres visibles de niveles;
- profundidad maxima.

Reglas:

- Aumentar profundidad maxima no tiene efecto destructivo.
- Reducir profundidad maxima puede dejar cards fuera del nuevo limite.
- La reduccion afecta a cards cuya profundidad real queda por encima del nuevo
  maximo, junto con su subarbol descendiente.
- Las cards fuera del limite no se eliminan fisicamente.
- Las cards fuera del limite se cierran logicamente para conservar historial.
- Debe mostrarse confirmacion previa con el numero de cards afectadas.
- Si alguna card afectada contiene tasks claimed/ongoing, no se debe cerrar
  automaticamente. El guardado queda bloqueado hasta que esas tasks se liberen
  o cierren mediante comunicacion del equipo.
- Si las cards afectadas solo contienen tasks abiertas no reclamadas, el flujo
  usa la misma politica que el cierre manual de card: aviso con conteo y cierre
  logico de ese trabajo si el manager confirma.

Flujo recomendado para reduccion destructiva:

```text
Reducir profundidad

Este cambio cerrara 12 cards que estan por debajo del nuevo limite de niveles.
No se eliminaran fisicamente: quedaran cerradas para conservar historial.

Si alguna card contiene tareas reclamadas o en curso, deberas resolverlas antes
de aplicar el cambio.

[Cancelar] [Revisar cards afectadas]
```

No mostrar `Confirmar cambio` directamente cuando hay cards afectadas. Primero:

1. Revisar cards afectadas.
2. Mostrar lista compacta.
3. Confirmacion final.

#### Pool

Decisiones cerradas:

- Limite blando por defecto: `20`.
- Configurable por proyecto.
- Nunca bloquea.
- Debe explicar su objetivo: evitar saturacion y frustracion del equipo.

Copy recomendado:

```text
Este limite no bloquea. Sirve para evitar saturacion y frustracion cuando hay
demasiadas tareas disponibles en el Pool.
```

### 3. Automatizaciones / Motor De Reglas

El motor de reglas debe permitir workflows organicos: no pasos que alguien debe
seguir, sino trabajo que se crea automaticamente en el Pool cuando ocurre algo
relevante.

Modelo mental de producto:

```text
cuando pasa esto -> se crea este trabajo -> esto ocurrio realmente
```

Decisiones cerradas:

- La UI principal no debe ser tres CRUDs separados.
- Debe existir una unica consola de `Automatizaciones`.
- Los nombres internos finales deben representar el modelo real. `Workflow`,
  `Rule`, `TaskTemplate` y `RuleExecution` solo se conservan si siguen siendo
  semanticamente correctos; si no, se renombran o eliminan.
- No se mantiene compatibilidad legacy como objetivo.
- En la interfaz se usara lenguaje de producto:
  - `Motor`
  - `Regla`
  - `Plantilla`
  - `Ejecucion`
- Un motor agrupa reglas.
- Una regla escucha un evento.
- Una plantilla define que task se crea en el Pool.
- Una ejecucion muestra que regla se activo, que plantilla se uso y que task se
  creo. Si un evento ya fue procesado por idempotencia, no debe crear una nueva
  ejecucion de negocio; puede aparecer solo como diagnostico tecnico.
- Las automatizaciones nunca asignan trabajo a una persona; solo crean trabajo
  disponible en el Pool.
- Tras integrar la consola, el sidebar izquierdo debe mostrar una sola entrada
  `Automatizaciones`. `Plantillas` y `Metricas` dejan de ser entradas
  principales en esta iteracion.

Permisos y auditoria:

- Solo managers pueden crear, editar, pausar, reactivar o archivar motores,
  reglas y plantillas.
- Los miembros pueden ver la trazabilidad de una task creada por automatizacion
  desde Task Show, porque afecta a su contexto operativo.
- La consola completa de Automatizaciones puede quedar restringida a managers
  en esta iteracion para reducir complejidad.
- Cada cambio de configuracion debe registrar actor, fecha, entidad afectada y
  cambio realizado.
- Un motor, regla o plantilla sin ejecuciones puede eliminarse fisicamente.
- Un motor, regla o plantilla con ejecuciones debe archivarse o pausarse, no
  borrarse fisicamente, para no romper auditoria ni trazabilidad.

#### Eventos Del Motor

El motor no debe quedar modelado como un caso especial de "cuando una task se
completa". Ese sera el primer evento importante, pero la arquitectura debe
expresar que escucha hechos del sistema.

Tipo conceptual recomendado:

```gleam
pub type AutomationEngineStatus {
  EngineActive
  EnginePaused
}

pub type AutomationTrigger {
  TaskCreated(task_type_id: Option(Int))
  TaskClaimed(task_type_id: Option(Int))
  TaskReleased(task_type_id: Option(Int))
  TaskCompleted(task_type_id: Option(Int))
  CardActivated(scope: CardAutomationScope)
  CardClosed(scope: CardAutomationScope)
}

pub type CardAutomationScope {
  AnyCard
  AtDepth(depth: CardDepth)
}

pub type CardDepth {
  CardDepth(Int)
}
```

Eventos soportados en la primera version:

- `TaskCreated`
- `TaskClaimed`
- `TaskReleased`
- `TaskCompleted`
- `CardActivated`
- `CardClosed`

Eventos aparcados:

- `TaskBlocked`
- `TaskUnblocked`

Estos eventos no deben implementarse ni mostrarse en UI en esta iteracion.

Reglas:

- No prometer en UI eventos que no esten implementados.
- La UI solo debe ofrecer eventos soportados. No construir controles visibles
  para eventos aparcados.
- El dominio debe usar un ADT, no strings sueltos como `completed`.
- Cada trigger soportado debe tener tests de dominio, servidor y flujo UI.
- Las reglas de task pueden filtrar por tipo de task o aplicar a cualquier tipo.
- Las reglas de card no tienen `card_type`: las cards representan estructura,
  no trabajo ejecutable tipado.
- Las reglas de card solo pueden aplicar a `AnyCard` o `AtDepth`.
- No incluir `InSubtree`, color, titulo, creador, prioridad ni query builder en
  reglas de card. Esa granularidad acopla automatizaciones a ramas concretas y
  rompe la simplicidad del producto.
- `CardDepth` debe construirse de forma validada para evitar profundidades
  invalidas.
- En esta version no existe activacion por vencimiento. Las due dates son una
  senal visual y operativa transversal, no un trigger de automatizacion.
- Las tasks creadas por automatizacion no deben disparar otras automatizaciones.
  Esta restriccion debe estar expresada en tipos o en una frontera de dominio
  clara, no como un `if` disperso.
- Una regla crea exactamente una task desde una plantilla. No hay fan-out de
  multiples plantillas por regla en esta version.
- Un motor pausado no evalua ninguna regla.
- Una regla pausada no se evalua aunque su motor este activo.
- Una regla `RequiresReview` no se evalua y debe mostrarse como accion pendiente
  de configuracion, no como ejecucion fallida.

Semantica exacta de los triggers soportados:

| Trigger | Cuando ocurre | Resultado esperado | Idempotencia |
| --- | --- | --- | --- |
| `TaskCreated` | Una task se crea manualmente y queda available | Crea la task definida por plantilla si la regla aplica | No debe duplicar si el mismo evento se procesa dos veces |
| `TaskClaimed` | Una task pasa a claimed/taken | Crea trabajo derivado si la regla aplica | No debe duplicar para la misma task y regla |
| `TaskReleased` | Una task reclamada vuelve a available | Crea trabajo derivado si la regla aplica | No debe duplicar para la misma task y regla |
| `TaskCompleted` | Una task transiciona a closed con razon done | Crea la task definida por plantilla en el Pool | No debe duplicar si el mismo evento se procesa dos veces |
| `CardActivated` | Una card pasa de draft a active y cumple `AnyCard` o `AtDepth` | Crea trabajo inicial definido por plantilla, sin asignarlo | Una misma activacion no debe generar dos veces el mismo trabajo |
| `CardClosed` | Una card pasa a closed y cumple `AnyCard` o `AtDepth` | Crea trabajo derivado si la regla aplica | Un mismo cierre no debe generar dos veces el mismo trabajo |

Aclaraciones:

- `TaskCreated` no incluye tasks creadas por automatizacion.
- `CardActivated` puede crear trabajo adicional desde plantilla, pero no es el
  mecanismo que libera al Pool las leaf tasks descendientes. Esa liberacion
  pertenece al flujo de activacion de cards y debe seguir funcionando aunque no
  haya reglas.
- `CardClosed` solo se dispara si el cierre de card ya fue aceptado por las
  reglas de cierre del producto. Si hay tasks claimed/ongoing y el cierre queda
  bloqueado, no hay evento de automatizacion.

Matriz minima de cobertura:

| Trigger | Dominio | Servidor | UI | Agent-browser |
| --- | --- | --- | --- | --- |
| `TaskCreated` | Elegibilidad, filtro por tipo, idempotencia | Creacion dispara regla y crea trabajo | Builder, frase, preview, ejecucion visible | Crear task y ver task derivada |
| `TaskClaimed` | Elegibilidad, filtro por tipo, idempotencia | Claim dispara regla y crea trabajo | Builder con evento claimed | Reclamar task y ver ejecucion |
| `TaskReleased` | Elegibilidad, filtro por tipo, idempotencia | Release dispara regla y crea trabajo | Builder con evento released | Liberar task y ver ejecucion |
| `TaskCompleted` | Elegibilidad, filtro por tipo, idempotencia | Rule execution, task creada, auditoria | Builder, frase, preview, ejecucion visible | Completar task y ver task generada |
| `CardActivated` | `AnyCard`, `AtDepth`, profundidad valida, idempotencia | Activacion dispara regla y crea trabajo | Builder con scope any/depth, aviso de ruido | Activar card y ver trabajo en Pool |
| `CardClosed` | `AnyCard`, `AtDepth`, profundidad valida, idempotencia | Cierre dispara regla y crea trabajo | Builder con scope any/depth | Cerrar card y ver ejecucion |

#### Tipado De Reglas Y Acciones

El modelo debe hacer irrepresentables las combinaciones peligrosas:

- regla guardada sin plantilla;
- regla con multiples plantillas;
- task creada por automatizacion que vuelve a disparar automatizaciones;
- trigger de due date;
- scope de card por subtree o query arbitraria.

Tipos conceptuales recomendados:

```gleam
pub type AutomationRule {
  AutomationRule(
    id: RuleId,
    engine_id: EngineId,
    trigger: AutomationTrigger,
    action: AutomationAction,
    status: AutomationRuleStatus,
  )
}

pub type AutomationAction {
  CreateTask(template_id: TaskTemplateId)
}

pub type AutomationRuleStatus {
  Active
  Paused
  RequiresReview(reason: RuleReviewReason)
}

pub type RuleReviewReason {
  TemplateMissing
  TaskTypeMissing
  CardDepthNoLongerExists
  InvalidMigratedData
}
```

Resultado de procesamiento:

```gleam
pub type AutomationProcessResult {
  Executed(execution_id: RuleExecutionId)
  NoMatchingRule
  Skipped(reason: AutomationSkipReason)
  DuplicateEvent
}

pub type AutomationSkipReason {
  EnginePaused
  RulePaused
  RuleRequiresReview(reason: RuleReviewReason)
  CreatedByAutomation
}

pub type RuleExecutionOutcome {
  CreatedTask(task_id: TaskId)
  Failed(reason: RuleExecutionError)
}
```

Regla de auditoria:

- `RuleExecution` se crea solo cuando una regla valida se intenta ejecutar.
- `DuplicateEvent` no crea una nueva ejecucion de negocio.
- `NoMatchingRule` no crea ejecucion.
- `Skipped` puede exponerse como diagnostico agregado, pero no debe mezclarse
  con ejecuciones de negocio.

No debe existir un constructor publico de `AutomationRule` que permita guardar
una regla activa sin `AutomationAction`. El builder de UI puede tener un estado
intermedio, pero debe ser otro tipo:

```gleam
pub type RuleDraft {
  RuleDraft(
    engine_id: Option(EngineId),
    trigger: Option(AutomationTrigger),
    template_id: Option(TaskTemplateId),
  )
}

pub type ValidRuleDraft {
  ValidRuleDraft(
    engine_id: EngineId,
    trigger: AutomationTrigger,
    action: AutomationAction,
  )
}
```

La transicion `RuleDraft -> ValidRuleDraft -> AutomationRule` debe ser el unico
camino para guardar. Cualquier error debe volver como `Result`, con mensajes de
UI concretos.

Origen de tasks:

```gleam
pub type TaskCreationSource {
  Manual(user_id: UserId)
  Automation(execution_id: RuleExecutionId)
}

pub type RuleTriggerSource {
  UserAction(user_id: UserId)
}
```

Solo `RuleTriggerSource` puede entrar al evaluador de reglas. Una task creada
con `Automation(...)` nunca se convierte en `RuleTriggerSource`, por lo que no
puede encadenar reglas por accidente.

Idempotencia:

- Cada hecho del sistema debe tener un identificador estable de evento.
- La clave de idempotencia recomendada es `(event_id, rule_id)`.
- Si se reprocesa el mismo evento para la misma regla, el resultado es
  `DuplicateEvent` y no se crea task ni `RuleExecution` nueva.
- No usar solo `(task_id, rule_id)` para todos los triggers: `TaskClaimed`,
  `TaskReleased` y `TaskCompleted` son hechos distintos sobre la misma task.

Variables de plantilla:

- Las variables deben mostrarse como chips insertables en el editor de
  plantilla.
- Las variables disponibles dependen del trigger elegido.
- Renombrar `{{father}}` a `{{origin}}` en el modelo nuevo; `father` es ambiguo
  y mezcla card padre con hecho origen.
- Variables iniciales recomendadas:
  - comunes: `{{origin}}`, `{{trigger}}`, `{{project}}`, `{{user}}`;
  - triggers de task: `{{task_title}}`, `{{task_type}}`;
  - triggers de card: `{{card_title}}`, `{{card_level}}`.
- No incluir `{{due_date}}` inicialmente. El vencimiento queda como senal visual
  de producto, no como entrada del motor.

Lifecycle de plantillas:

- Una plantilla usada por reglas activas no se puede borrar directamente.
- Para borrarla, la UI debe pedir primero sustituir la plantilla en esas reglas
  o pausar/eliminar explicitamente las reglas afectadas.
- `RequiresReview(TemplateMissing)` queda reservado para datos importados,
  migraciones o corrupciones que dejen una regla previamente valida sin
  plantilla. No debe ser un camino normal de UI.
- Editar una plantilla usada afecta solo a futuras tasks generadas.
- Las tasks ya creadas conservan su contenido y trazabilidad a la plantilla y
  version que las genero.
- Cada edicion de plantilla incrementa una version interna.
- `RuleExecution` debe guardar `template_id` y `template_version`, no solo el
  contenido resultante de la task.

#### Vencimientos Fuera Del Motor

Las due dates no deben generar reglas ni plantillas en esta fase. La razon de
producto es que ScrumBringer ya debe hacer visible el vencimiento donde el equipo
trabaja, sin convertir el calendario en otro motor de ruido automatico.

Validaciones visuales que deben mantenerse o incorporarse:

- Pool: en canvas, las tasks vencidas, vencen hoy o vencen pronto muestran una
  senal compacta de vencimiento sin hacer crecer la task card; la fecha explicita
  vive en lista, hover preview, detalle, tooltip o `aria-label`.
- Pool: las tasks bloqueadas o reclamadas siguen visibles con su estado real; el
  vencimiento no debe ocultar bloqueos ni propiedad temporal.
- Plan/Kanban: las cards vencidas muestran la fecha en rojo y semibold/bold; si
  se muestran contadores agregados, deben permitir detectar descendientes
  vencidos sin abrir cada card.
- Capacidades: las vistas por capacidad deben conservar la senal de vencimiento
  en tasks activas para que una capacidad saturada con vencidos sea visible.
- Personas: el trabajo reclamado/en curso de cada persona debe conservar la senal
  de vencimiento cuando aplique.
- Card Show: debe mostrar due date de la card y senales agregadas de
  descendientes vencidos.
- Task Show: debe mostrar due date propia, due date heredada de card cuando sea
  efectiva y actividad asociada a cambios de due date.

Severidad visual:

- `Overdue`: fecha anterior a hoy. Usar danger, texto semibold/bold y etiqueta
  textual `Vencida`.
- `DueToday`: fecha igual a hoy. Usar warning fuerte y etiqueta `Hoy`.
- `DueSoon`: fecha dentro de los proximos 7 dias. Usar warning discreto.
- `Future`: mas de 7 dias. No debe competir visualmente con estado, bloqueo o
  accion principal.
- `Closed`: no muestra urgencia por vencimiento; puede conservar la fecha como
  dato historico.

No se debe implementar:

- `TaskDueDateOverdue` como trigger.
- jobs de automatizacion por vencimiento.
- outcomes de reglas causados por vencimiento.
- plantillas especificas que solo existan para avisos de due date.

Seeds y validacion:

- Las seeds deben incluir tasks vencidas, tasks que vencen hoy, tasks que vencen
  pronto, cards vencidas y cards con descendientes vencidos.
- Agent-browser debe recorrer Pool, Plan, Kanban, Capacidades, Personas, Card
  Show y Task Show para comprobar que los vencimientos se ven sin depender del
  motor de reglas.
- Los tests de UI deben cubrir al menos: senal compacta de due date en Pool,
  fecha de card vencida en rojo/semibold, due date efectiva heredada en Task
  Show y ausencia del trigger de vencimiento en el builder de reglas.

#### Vista Principal

La consola debe compartir lenguaje visual con Pool, Plan, Kanban, Capacidades y
Personas.

Estructura recomendada:

```text
Automatizaciones - Default
Crea trabajo automatico en el Pool sin asignarlo a nadie.

2 motores activos   4 reglas   3 plantillas   12 creadas
                                           [ + Motor ]

Vista: [ Motores ] [ Plantillas ] [ Ejecuciones ]
Buscar... Estado [Activas v] Evento [Todos v]
```

No usar cards grandes como estructura principal. La vista debe usar una
superficie operativa con filas expandibles:

```text
v Release flow                              Activo - sano
  3 reglas - 12 tasks creadas - ultima ejecucion hace 2h

  Cuando Task Development pase a Done
    -> QA Verification      Task - P3 - creo 8
    -> Deploy to Staging    Task - P3 - creo 4

  [ + Regla ] [Ejecuciones] [Pausar]

> Bug resolution                         Requiere revision
  1 regla afectada - plantilla eliminada - no se evalua
```

Mockup completo orientativo:

```text
Automatizaciones - Default
Crea trabajo automatico en el Pool sin asignarlo a nadie.

2 motores activos   4 reglas   3 plantillas   12 creadas       [ + Motor ]

Vista: [ Motores ] [ Plantillas ] [ Ejecuciones ]
Buscar...                         Estado [Activas v] Evento [Todos v]

v Release flow                                             Activo - sano
  3 reglas  2 plantillas  12 tasks creadas  ultima hace 2h

  Cuando una task Development se complete
    -> QA Verification                         Task - P3 - creo 8

  Cuando una card se active
    -> Kickoff checklist                       Task - P2 - creo 4

  [ + Regla ] [Ejecuciones] [Pausar]

> Bug resolution                                         Requiere revision
  1 regla afectada  plantilla eliminada  no se evalua
```

#### Modos De Vista

La consola tiene tres modos internos, no tres pantallas desconectadas:

1. **Motores**
   - Vista principal.
   - Muestra motores, estado de salud y reglas como frases de causa/efecto.
   - Permite expandir un motor para ver sus reglas y plantillas asociadas.

2. **Plantillas**
   - Biblioteca reutilizable.
   - Muestra nombre, tipo, prioridad, usos, tasks creadas y ultima ejecucion.
   - Debe permitir ver en que reglas se usa una plantilla.
   - Debe avisar si una plantilla no se usa.

   Mockup orientativo:

   ```text
   Plantillas
   Buscar...                                      Uso [Todas v]

   Nombre                Tipo       Prioridad   Usos   Creadas   Ultima
   QA Verification       QA         P3          2      8         hace 2h
   Kickoff checklist     Planning   P2          1      4         hace 1d
   Unused review         Review     P3          0      0         nunca   aviso

   Al seleccionar:
   Vista previa
   "QA Verification" se creara como task disponible en el Pool.
   Usada por: Release flow / Development completed
   ```

3. **Ejecuciones**
   - Historial/auditoria.
   - Muestra fecha, motor, regla, plantilla, origen, outcome y task creada.
   - Aqui si tiene sentido usar una tabla densa.
   - Debe distinguir ejecuciones creadas, errores reales y diagnostico no
     ejecutivo.
   - Los eventos duplicados por idempotencia no son ejecuciones de negocio
     nuevas; deben quedar como `ignorados` o diagnostico avanzado, no como
     outcome principal.

   Mockup orientativo:

   ```text
   Ejecuciones
  Buscar...  Outcome [Todos v]  Evento [Todos v]  Fecha [7 dias v]

   Fecha       Motor          Regla                    Outcome       Task
   10:32       Release flow   Development completed    Creada        #482 QA Verification

   Diagnostico
   09:18       Release flow   Development completed    Ignorada      duplicado para #471
   Ayer        Bug flow       Bug closed               Requiere revision
                                                                    plantilla eliminada
   ```

#### Creacion De Reglas

La creacion no debe ser un CRUD tecnico. Debe ser un constructor progresivo en
panel/drawer:

```text
Nueva regla

Cuando:
[ Task v ] [ tipo Development v ] [ pase a Done v ]

Crear en el Pool:
[ Buscar plantilla...                       ]
[ + Crear plantilla nueva ]

Vista previa:
Cuando una task Development se complete,
se creara "QA Verification" en el Pool.

[Crear regla]
```

Mockup orientativo con evento no basado en completion:

```text
Nueva regla

Cuando:
[ Card v ] [ se active v ]

Aplicar a:
[ Cualquier card v ]

Crear en el Pool:
[ Kickoff checklist                                ]
[ + Crear plantilla nueva ]

Vista previa:
Cuando una card se active,
se creara "Kickoff checklist" en el Pool.

Aviso:
Si activas una card con muchas subcards, esta regla puede crear mucho trabajo.

[Cancelar]                                      [Crear regla]
```

Opciones de alcance para cards:

```text
Aplicar a:
[ Cualquier card v ]

Opciones:
- Cualquier card
- Cards de nivel: Hito
- Cards de nivel: Entrega
- Cards de nivel: Historia
```

No debe existir selector de subtree en esta version.

Reglas UX:

- La regla siempre debe poder leerse como una frase.
- La preview antes de guardar es obligatoria.
- Debe ser posible crear una plantilla desde el flujo sin salir de la regla.
- Asociar plantillas existentes debe ser rapido y searchable.
- Una regla incompleta no se puede guardar. El boton de guardar debe quedar
  deshabilitado hasta tener trigger valido, exactamente una plantilla valida,
  motor valido y preview resoluble.
- El backend debe rechazar la misma configuracion incompleta aunque la UI falle.
- `Requiere revision` solo puede aparecer para reglas que eran validas y dejaron
  de serlo por cambios posteriores: plantilla eliminada, tipo de task retirado,
  profundidad de card ya no valida, o migracion de datos inconsistente.
- Crear una plantilla desde una regla debe volver al builder con la plantilla
  ya seleccionada.
- Si la regla generara muchas tasks por un evento comun, debe avisar del riesgo
  de ruido en el Pool.
- Si el usuario cambia el trigger despues de seleccionar plantilla, la preview y
  las variables disponibles deben recalcularse; si la plantilla usa variables ya
  no disponibles, la regla no puede guardarse hasta corregirlas.

#### Plantillas

Las plantillas deben ser reutilizables, pero no deben obligar al usuario a
navegar fuera del flujo de regla.

Cada plantilla debe mostrar:

- nombre;
- tipo de task;
- prioridad;
- descripcion con variables;
- reglas que la usan;
- numero de tasks creadas;
- ultima ejecucion;
- vista previa de la task que generara.

Cuando se edite una plantilla usada por reglas activas, debe advertirse que el
cambio afectara futuras tasks generadas, no tareas ya creadas.

#### Trazabilidad

Toda task creada por automatizacion debe exponer su origen en Task Show:

```text
Creada por automatizacion
Release flow - regla "Development done" - plantilla "QA Verification"
```

Desde ese bloque debe poderse navegar al motor, la regla y la plantilla.

Mockup orientativo en Task Show:

```text
Origen
Creada por automatizacion
Release flow -> Development completed -> QA Verification

[Ver motor] [Ver regla] [Ver plantilla]
```

#### Metricas Y Salud

Las metricas no deben ser una pantalla decorativa ni el punto de entrada
principal. Deben funcionar como salud operativa del motor.

Senales recomendadas:

- reglas evaluadas;
- tasks creadas;
- eventos duplicados ignorados;
- reglas que requieren revision por datos cambiados;
- plantillas sin uso;
- automatizaciones ruidosas que crean demasiadas tasks;
- ultima ejecucion.

El bug actual de metricas debe corregirse: el cliente envia fechas de input
`date` como `YYYY-MM-DD`, mientras que el servidor espera RFC3339. La solucion
debe ser explicita y testeada en cliente/servidor.

Decision recomendada:

- Las consultas de metricas deben aceptar fechas de calendario `YYYY-MM-DD`.
- El servidor convierte esas fechas a rango inclusivo del dia en UTC.
- No exigir RFC3339 a un control HTML `date`.
- Los tipos de cliente deben nombrar esto como rango de fecha, no timestamp.

#### Componentizacion

Reutilizar primero:

- `features/layout/work_surface.gleam`
- `ui/filter_bar.gleam`
- `ui/badge.gleam`
- `ui/data_table.gleam`
- `ui/empty_state.gleam`
- `ui/skeleton.gleam`
- `ui/confirm_dialog.gleam`
- `ui/form_field.gleam`
- `ui/button.gleam`

Componentes nuevos recomendados, especificos y pequenos:

- `features/automations/rule_sentence.gleam`
- `features/automations/template_picker.gleam`
- `features/automations/template_usage_summary.gleam`
- `features/automations/execution_row.gleam`
- `features/automations/rule_builder.gleam`

Evitar una abstraccion generica tipo `workflow_builder` hasta que haya una
segunda necesidad real. La prioridad es claridad de producto y componentes
pequenos.

#### Tests De Comportamiento

No basta con testear que se crea una fila. Los tests deben comprobar el contrato
de producto:

```text
hecho del sistema -> regla elegible -> plantilla aplicada -> task claimable en
Pool -> ejecucion auditable -> trazabilidad visible
```

Tests minimos por trigger soportado:

- `TaskCreated` crea una task desde plantilla.
- `TaskCreated` respeta filtro por tipo de task.
- `TaskClaimed` crea una task desde plantilla.
- `TaskReleased` crea una task desde plantilla.
- `TaskCompleted` crea una task desde plantilla.
- `TaskCompleted` respeta filtro por tipo de task.
- `TaskCompleted` no duplica task si el mismo evento se procesa dos veces.
- `CardActivated` puede crear tasks iniciales desde plantilla.
- `CardActivated` respeta `AnyCard` y `AtDepth`.
- `CardActivated` no asigna automaticamente las tasks creadas.
- `CardClosed` respeta `AnyCard` y `AtDepth`.
- Motor pausado no ejecuta reglas.
- Regla pausada no ejecuta nada.
- Regla sin plantilla no se puede guardar desde UI.
- Regla incompleta o invalida se rechaza en servidor.
- Regla que queda invalida por cambios posteriores aparece como `requiere
  revision` y no ejecuta nada.
- Plantilla incompleta no puede seleccionarse como accion de regla.
- Ejecucion registra motor, regla, plantilla, origen, outcome y task creada.
- Ejecucion registra version de plantilla usada.
- Task creada aparece en Pool como claimable si no esta bloqueada.
- Task creada muestra trazabilidad en Task Show.
- Las tasks creadas por automatizacion no disparan nuevas automatizaciones.
- Usuario no manager no puede crear, editar, pausar ni archivar automatizaciones.
- Entidad de automatizacion con ejecuciones se archiva, no se borra fisicamente.

#### Validacion Agent-Browser De Automatizaciones

El bloque de automatizaciones debe cerrarse con un guion especifico de
agent-browser, no solo con una pasada visual generica.

Smoke funcional obligatorio, a repetir durante desarrollo:

1. Crear un motor.
2. Crear una plantilla desde la biblioteca.
3. Crear una regla `TaskCompleted` usando esa plantilla.
4. Completar una task que dispara la regla.
5. Ver la task generada en el Pool.
6. Abrir la task generada y comprobar trazabilidad.
7. Ver la ejecucion registrada como `creada`.

Casos de borde obligatorios antes de cerrar:

1. Reprocesar o repetir el evento y comprobar que se ignora como duplicado sin
   crear otra ejecucion de negocio.
2. Crear una regla `CardActivated`.
3. Activar una card y comprobar que se crea trabajo en el Pool.
4. Crear una regla `CardActivated` limitada a un nivel y comprobar que solo se
   dispara en ese nivel.
5. Crear una regla `CardClosed` limitada a un nivel y comprobar que solo se
   dispara en ese nivel.
6. Crear reglas `TaskCreated`, `TaskClaimed` y `TaskReleased` con tipo de task
   opcional y comprobar filtro por tipo.
7. Intentar guardar una regla sin plantilla y comprobar que la UI lo impide y
   que el servidor tambien lo rechaza.
8. Simular una regla que queda invalida por plantilla eliminada y comprobar que
   aparece como `requiere revision`, sin ejecutarse.
9. Ver una plantilla sin uso marcada con aviso.
10. Editar una plantilla usada y comprobar copy: afecta solo a futuras tasks.
11. Pausar motor/regla y comprobar que no genera nuevas tasks.
12. Validar que una task creada por automatizacion no dispara otra regla.
13. Validar que Task Show muestra motor, regla, plantilla y version/origen de la
    ejecucion.
14. Intentar editar automatizaciones como miembro no manager y comprobar que no
    se permite.
15. Archivar una regla con ejecuciones y comprobar que la trazabilidad historica
    sigue navegable.
16. Validar filtros de Motores, Plantillas y Ejecuciones.
17. Validar desktop y mobile.

Cada defecto encontrado debe corregirse y el guion debe repetirse hasta no dejar
errores conocidos.

#### Orden De Implementacion

Para controlar riesgo y evitar una gran reescritura:

1. Corregir rango de fechas de metricas y tests asociados.
2. Definir `AutomationTrigger` como ADT y conectar los triggers soportados.
3. Crear la consola `Automatizaciones` con cabecera, chips, filtros y modo
   `Motores`, reutilizando endpoints actuales.
4. Sustituir tabla de reglas por `rule_sentence` y filas expandibles.
5. Integrar `Plantillas` como modo interno con busqueda, usos y preview.
6. Integrar `Ejecuciones` como modo interno usando `data_table`.
7. Rehacer creacion/edicion con `rule_builder` en panel/drawer.
8. Cubrir tests de comportamiento por trigger soportado.
9. Retirar rutas, vistas y copy duplicados que hayan quedado obsoletos.
10. Validar con agent-browser los flujos completos y ajustar UI/UX.

#### Limpieza Esperada

Al ejecutar este bloque:

- retirar o absorber vistas CRUD antiguas que queden duplicadas;
- evitar mantener una pantalla independiente de plantillas si queda integrada
  como modo de vista;
- revisar si `Rule Metrics` debe quedar como modo `Ejecuciones` o como vista
  avanzada solo si aporta valor real;
- eliminar copy que obligue al usuario a entender tablas tecnicas;
- mantener tests de motor existentes y reforzar tests de UI sobre los flujos:
  crear motor, crear plantilla, crear regla, seleccionar plantilla, ver ejecuciones
  y verificar trazabilidad desde una task creada;
- eliminar cualquier rama de codigo que asuma que las reglas solo se disparan
  por `TaskCompleted` si esa suposicion no pertenece a una frontera concreta;
- eliminar cualquier rama de codigo que implemente vencimiento como trigger de
  automatizacion si existe tras la refactorizacion;
- retirar pantallas o rutas de metricas/plantillas si quedan absorbidas por la
  consola y no aportan acceso directo necesario.

### 4. Seeds Y Estados De Validacion

Las seeds deben servir para probar el producto real, no solo para tener datos.

Se deben mantener dos familias:

1. **Proyecto sano**
   - Pool controlado.
   - Cards activas bien acotadas.
   - Tasks disponibles/reclamadas/en curso/cerradas.
   - Capacidades razonables.
   - Notas fijadas utiles.
   - Actividad representativa sin ruido.
   - Automatizaciones sanas: motor activo, regla con plantilla, ejecuciones
     recientes y tasks creadas trazables.

2. **Proyecto de estres**
   - Pool saturado.
   - Cards con varios niveles.
   - Due dates vencidas.
   - Bloqueos.
   - Tasks sueltas.
   - Cards draft/active/closed.
   - Notas fijadas y no fijadas.
   - Activity rica.
   - Automatizaciones con avisos: plantilla sin uso, regla que requiere revision
     por datos cambiados, eventos duplicados ignorados y motor ruidoso.

Validaciones esperadas:

- Pool sano no supera el limite blando.
- Pool saturado muestra advertencia sin bloquear.
- Plan muestra estructura con varias profundidades.
- Kanban, Capacidades y Personas tienen datos suficientes para validar filtros.
- Card Show y Task Show tienen notas fijadas, actividad, due dates y bloqueos.
- Automatizaciones permite comprobar causa, efecto y resultado real.
- Una task creada por automatizacion muestra trazabilidad a motor, regla y
  plantilla.
- El builder de reglas no permite guardar configuraciones incompletas.
- Los vencimientos se validan en vistas operativas, no en automatizaciones.

## Alcance Aparcado

### Right Sidebar / Actividad Global

No se disena una vista global nueva.

Decision:

- El right sidebar se mantiene como esta.
- Si tras validar Card/Task Activity falta visibilidad global, se estudiara si
  encaja dentro del right sidebar.
- No se crea una pantalla nueva de actividad global.

### Notificaciones

No se toca todavia.

Decision:

- No introducir notificaciones sueltas.
- Antes de disenar notificaciones debe existir una vision homogenea, alineada
  con la filosofia de ScrumBringer.
- Evitar avisos que conviertan el producto en ruido.

## Fuera De Alcance Por Ahora

- Busqueda global.
- Redisenio mobile global.
- UI de permisos finos.

Estos puntos solo deben reabrirse si aparecen problemas reales en validacion o
uso.
