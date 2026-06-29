# Manual de usuario de ScrumBringer

**Version:** 1.0  
**Fecha:** 2026-06-29  
**Audiencia:** miembros de equipo, managers de proyecto y administradores de organizacion  
**Capturas:** entorno local de desarrollo con datos demo

---

## Tabla de contenidos

1. [Introduccion](#introduccion)
2. [Conceptos clave](#conceptos-clave)
3. [Primer acceso](#primer-acceso)
4. [Pantallas principales](#pantallas-principales)
5. [Flujos esenciales](#flujos-esenciales)
6. [Si vienes de Monday, Jira o Redmine](#si-vienes-de-monday-jira-o-redmine)
7. [Permisos](#permisos)
8. [FAQ](#faq)
9. [Glosario](#glosario)

---

## Introduccion

ScrumBringer es una herramienta de gestion agil basada en trabajo compartido. Las tareas aparecen en un **Pool** y las personas las **reclaman** cuando tienen contexto, capacidad y disponibilidad. La herramienta evita que el trabajo dependa de asignaciones directas persona a persona.

La diferencia principal frente a herramientas como Monday, Jira o Redmine es esta:

- En una herramienta tradicional alguien suele crear trabajo y asignarlo a una persona.
- En ScrumBringer alguien crea trabajo visible, con prioridad, tarjeta, tipo y capacidad.
- Una persona adecuada lo reclama cuando puede hacerse responsable.

El manager no empuja cada tarea. Observa salud de flujo, carga, bloqueos, capacidades y estructura del proyecto.

Este manual cubre el uso diario, la configuracion principal y la traduccion mental necesaria para usuarios acostumbrados a tableros, issues, estados, responsables y flujos por fases.

---

## Conceptos clave

### Pool

El Pool es la pantalla central de trabajo. Muestra tareas abiertas disponibles para el equipo. Desde aqui puedes buscar, filtrar, abrir detalles y reclamar tareas.

![Pool de trabajo](user_guide/02-pool.png)

*Figura 1: Pool con filtros, tareas reclamables y panel lateral de actividad.*

### Tarea

Una tarea es una unidad de trabajo concreta. Tiene titulo, descripcion, prioridad, tipo, tarjeta asociada, capacidad, estado, notas, dependencias y actividad.

Estados principales:

- **Disponible:** esta en el Pool y puede reclamarse.
- **Reclamada:** alguien la ha tomado, pero no necesariamente la esta ejecutando ahora.
- **En curso:** es el foco activo de una persona.
- **Bloqueada:** depende de otro trabajo o necesita resolver una condicion previa.
- **Cerrada:** finalizada.

![Detalle de tarea](user_guide/04-detalle-tarea.png)

*Figura 2: Detalle de tarea con accion para reclamar, pestanas y contexto operativo.*

### Tarjeta

Una tarjeta agrupa trabajo relacionado. Puede representar una iniciativa, feature, modulo, historia padre, entregable, hito o grupo de tareas. Si necesitas estructura, usa tarjetas y subtarjetas.

Si vienes de Monday, piensa en la tarjeta como el contenedor de contexto. Si vienes de Jira o Redmine, piensa en la tarjeta como el agrupador superior donde viven tareas reclamables.

![Configuracion de tarjetas](user_guide/12-config-tarjetas.png)

*Figura 3: Configuracion de tarjetas con estado, progreso y acciones.*

### Capacidad

Una capacidad representa una especializacion real del equipo: Product, Design, Backend, Frontend, QA, Security u otra similar. Las tareas pueden requerir una capacidad y las personas pueden tener capacidades asignadas.

La vista de Capacidades permite ver donde se acumula trabajo por especialidad y reclamar tareas desde ese contexto.

![Vista de capacidades](user_guide/08-capacidades.png)

*Figura 4: Trabajo agrupado por capacidades, con tareas reclamables y tareas ya reclamadas.*

### Personas

Personas muestra carga, foco actual, disponibilidad, tareas reclamadas y senales de atencion. No esta pensada para reasignar trabajo de forma silenciosa, sino para conversar y desbloquear.

![Vista Personas](user_guide/09-personas.png)

*Figura 5: Estado operativo de personas, carga y siguiente trabajo visible.*

### Workflow

Un workflow en ScrumBringer no mueve un item entre columnas. Crea nuevo trabajo disponible en el Pool cuando ocurre un evento. Por ejemplo: al cerrar desarrollo, puede crear una tarea de QA con capacidad QA.

![Automatizaciones](user_guide/13-automatizaciones.png)

*Figura 6: Automatizaciones con motores, plantillas y ejecuciones.*

---

## Primer acceso

### Iniciar sesion

1. Abre la URL de ScrumBringer.
2. Escribe email y contrasena.
3. Pulsa **Acceso**.
4. Comprueba el proyecto seleccionado en el panel izquierdo.

![Acceso](user_guide/01-acceso.png)

*Figura 7: Pantalla de acceso con email, contrasena y recuperacion de contrasena.*

### Recuperar contrasena

Desde la pantalla de acceso, pulsa **Olvidaste la contrasena?**, escribe tu email y sigue el enlace de restablecimiento. En entornos sin envio de correo, la pantalla puede mostrar un enlace manual para copiar.

### Aceptar invitacion

Abre el enlace recibido, define una contrasena y completa el registro. La contrasena observada requiere al menos 12 caracteres.

---

## Pantallas principales

### Navegacion

La aplicacion se organiza en tres zonas:

- **Panel izquierdo:** proyecto activo y navegacion.
- **Panel central:** vista principal.
- **Panel derecho:** En curso, Mis tareas, contexto, preferencias y salida.

La seccion **Trabajo** contiene Pool, Kanban, Plan, Capacidades y Personas. La seccion **Configuracion** aparece para managers u org admins. La seccion **Organizacion** aparece para administradores de organizacion.

### Pool

Usa Pool para elegir el siguiente trabajo. Revisa prioridad, tipo, capacidad, estado y bloqueos antes de reclamar.

Controles principales:

- Buscar por texto.
- Filtrar por tipo y capacidad.
- Ver abiertas, reclamables o bloqueadas.
- Cambiar entre lienzo y lista.
- Reclamar o abrir una tarea.

### Nueva tarea

Una tarea necesita titulo, prioridad, tipo y tarjeta activa. La descripcion debe contener el contexto minimo para que otra persona pueda entenderla sin conversacion externa.

![Nueva tarea](user_guide/03-nueva-tarea.png)

*Figura 8: Formulario de creacion de tarea con tarjeta activa obligatoria.*

### Mis tareas y En curso

**Mis tareas** son tareas reclamadas. **En curso** es el foco activo actual. Esta separacion evita que una cola personal parezca trabajo realmente en progreso.

![Tarea reclamada](user_guide/05-tarea-reclamada.png)

*Figura 9: Tarea reclamada y visible en Mis tareas.*

### Kanban

Kanban muestra tarjetas por estado. Sirve para ver que tarjetas estan por iniciar, activas o cerradas. No sustituye al Pool: el trabajo se reclama desde tareas, no desde columnas.

![Kanban](user_guide/06-kanban.png)

*Figura 10: Kanban de tarjetas por estado.*

### Plan

Plan muestra la jerarquia de tarjetas. Usalo para entender iniciativas, entregables, subtarjetas y tareas directas.

![Plan](user_guide/07-plan.png)

*Figura 11: Vista Plan con jerarquia de tarjetas y progreso.*

### Configuracion de equipo

Permite gestionar miembros, roles, capacidades y tareas reclamadas.

![Configuracion de equipo](user_guide/10-config-equipo.png)

*Figura 12: Miembros del proyecto con rol, capacidades y tareas reclamadas.*

### Configuracion de capacidades

Permite crear capacidades y asignar miembros. Mantener pocas capacidades claras suele funcionar mejor que crear una capacidad para cada detalle.

![Configuracion de capacidades](user_guide/11-config-capacidades.png)

*Figura 13: Capacidades del proyecto y numero de miembros por capacidad.*

### Organizacion

Los administradores pueden gestionar proyectos, usuarios, invitaciones, equipo transversal, tokens API y metricas.

![Proyectos de organizacion](user_guide/14-org-proyectos.png)

*Figura 14: Gestion de proyectos a nivel organizacion.*

![Invitaciones](user_guide/15-org-invitaciones.png)

*Figura 15: Gestion de invitaciones de organizacion.*

---

## Flujos esenciales

### Elegir y reclamar trabajo

1. Entra en **Pool**.
2. Revisa prioridad, tipo, capacidad y bloqueos.
3. Usa **Mias** si quieres ver trabajo alineado con tus capacidades.
4. Abre la tarea si necesitas contexto.
5. Pulsa **Reclamar**.

Resultado: la tarea pasa a **Mis tareas**.

### Empezar, pausar, liberar y cerrar

1. Desde **Mis tareas**, pulsa **Empezar** para convertir una tarea en foco activo.
2. Pulsa **Pausar** si interrumpes el trabajo pero sigues siendo responsable.
3. Pulsa **Liberar** si no puedes continuar o conviene que otra persona la tome.
4. Pulsa **Cerrar tarea** cuando el trabajo este completo.

Liberar no es un fallo. Es una forma explicita de devolver trabajo al equipo.

### Crear una tarea

1. Pulsa **Nueva tarea**.
2. Escribe un titulo claro.
3. Anade descripcion si aporta contexto.
4. Define prioridad, tipo y tarjeta activa.
5. Crea la tarea.

Resultado: la tarea queda disponible en el Pool si encaja con los filtros activos.

### Usar notas y bloqueos

Usa **Notas** para decisiones, dudas, avances o contexto operativo. Usa **Bloqueos** cuando una tarea dependa de otra tarea abierta.

Ejemplos de notas utiles:

- "Producto confirma que el alcance no incluye exportacion CSV."
- "QA puede probar con usuario demo."
- "Bloqueado hasta cerrar la migracion de indices."

### Revisar estructura de trabajo

Usa **Plan** para entender donde vive cada tarea. Usa **Kanban** para ver tarjetas por estado. Usa **Configuracion > Tarjetas** para revisar estado, progreso y acciones de tarjetas.

### Encontrar trabajo por capacidad

1. Entra en **Capacidades**.
2. Revisa el trabajo agrupado por especialidad.
3. Filtra por tus capacidades si procede.
4. Reclama una tarea cuando puedas asumirla.

Esto sustituye la asignacion directa: el trabajo queda visible por capacidad y alguien adecuado lo reclama.

### Revisar carga del equipo

Usa **Personas** para ver foco actual, tareas reclamadas, personas disponibles y senales de atencion. Si alguien acumula demasiado trabajo, la accion recomendada es conversar, liberar trabajo o revisar bloqueos.

### Configurar equipo y capacidades

Managers y org admins pueden:

- Anadir miembros al proyecto.
- Cambiar rol de proyecto.
- Gestionar capacidades de una persona.
- Crear capacidades.
- Liberar tareas reclamadas de otra persona, preferiblemente tras hablar con ella.

### Disenar un flujo con automatizaciones

En ScrumBringer, disenar un flujo no significa crear columnas. Significa crear el siguiente trabajo cuando ocurre un evento.

1. Entra en **Configuracion > Automatizaciones**.
2. Revisa o crea un motor.
3. Define una plantilla de tarea: titulo, tipo, prioridad, tarjeta y capacidad.
4. Crea una regla que conecte evento y plantilla.
5. Revisa ejecuciones.
6. Comprueba en Pool y Capacidades que el trabajo nuevo aparece donde debe.

Ejemplo: al cerrar una tarea de desarrollo, ScrumBringer crea una tarea de QA en el Pool. Nadie queda asignado de forma automatica; alguien con capacidad QA la reclama.

### Seguir un entregable o historia padre

1. Crea una tarjeta de nivel alto, por ejemplo `Login de usuario`.
2. Si necesitas fases visibles, crea subtarjetas: `Definicion`, `Diseno`, `Backend`, `Frontend`, `QA`.
3. Dentro de cada subtarjeta, crea tareas concretas y reclamables.
4. Asocia tipos y capacidades coherentes.
5. Usa Plan para ver la estructura, Kanban para estado, Pool para tareas disponibles y Capacidades para carga por especialidad.

Resultado: sabes que falta para cerrar el entregable sin crear una matriz de fases ajena a ScrumBringer.

### Revisar bloqueos de un entregable

1. Abre la tarjeta o subtarjeta.
2. Revisa tareas directas.
3. Abre las tareas bloqueadas.
4. Mira **Bloqueos** y notas.
5. Usa el filtro de bloqueadas en Pool y la vista Personas para ver impacto.

Si el bloqueo es externo o conversacional, registralo en notas. Si depende de otra tarea, usa dependencias.

---

## Si vienes de Monday, Jira o Redmine

### Traduccion rapida

| Si esperas... | En ScrumBringer se hace asi... |
| --- | --- |
| Paneles y columnas de Monday | Tarjetas, tareas, capacidades y automatizaciones. |
| Issues asignadas de Jira | Tareas visibles en Pool que una persona reclama. |
| Tickets de Redmine por estado | Tareas con notas, dependencias, actividad y estados operativos. |
| Entregables padre | Tarjetas de nivel alto. |
| Fases de avance | Subtarjetas, tipos de tarea y capacidades. |
| Dashboard del sprint | Lectura combinada de Plan, Kanban, Pool, Capacidades, Personas y metricas. |
| Responsable de desbloqueo | Notas, dependencias y capacidades, evitando asignacion silenciosa. |

### Caso principal: crear un flujo como en Monday

En Monday podrias crear:

`Desarrollo -> QA -> Documentacion -> Hecho`

En ScrumBringer no mueves el mismo item por esas columnas. Lo modelas asi:

1. Una tarjeta guarda el contexto de la feature.
2. Una tarea de Backend aparece en el Pool.
3. Al cerrarse, una automatizacion crea una tarea de QA.
4. Al cerrarse QA, otra automatizacion puede crear una tarea de Documentacion.
5. Capacidades muestra si Backend, QA o Documentacion estan acumulando trabajo.

La diferencia es central: en Monday el flujo suele ser "este item cambia de columna"; en ScrumBringer es "al cerrar una parte, aparece el siguiente trabajo reclamable".

### Que no conviene copiar

Evita trasladar literalmente estos patrones:

- Una tarjeta por cada estado del proceso.
- Capacidades como nombres de personas.
- Automatizaciones que asignan trabajo a alguien.
- Medir salud solo por columnas.
- Mantener muchas tareas reclamadas como cola personal.

ScrumBringer busca trabajo visible, reclamable y revisable por capacidad.

---

## Permisos

ScrumBringer distingue roles de organizacion y proyecto.

- **Org admin:** gestiona usuarios, invitaciones, proyectos, equipo transversal, tokens API y metricas.
- **Miembro de organizacion:** puede entrar en proyectos donde fue anadido.
- **Manager de proyecto:** gestiona equipo, capacidades, tipos de tarea, tarjetas y automatizaciones del proyecto.
- **Miembro de proyecto:** ve y reclama tareas, usa notas, revisa vistas de trabajo y participa en el flujo.

Algunas acciones requieren cuidado: eliminar miembros, proyectos, capacidades, tarjetas, tipos de tarea, revocar tokens o liberar todas las tareas de otra persona.

---

## FAQ

### ScrumBringer asigna tareas automaticamente?

No. Puede crear tareas automaticamente mediante workflows, pero esas tareas quedan disponibles en el Pool.

### Cual es la diferencia entre reclamar y empezar?

Reclamar toma responsabilidad temporal. Empezar marca la tarea como foco activo.

### Puedo tener varias tareas reclamadas?

Si, pero conviene mantener pocas para no bloquear al equipo.

### Cuando creo una tarjeta y cuando creo una tarea?

Crea una tarjeta para agrupar contexto. Crea una tarea cuando hay una unidad concreta que alguien puede reclamar y completar.

### Que vista debe mirar un manager?

Pool, Personas, Capacidades, Plan, Kanban, metricas y configuracion. El objetivo es mantener sano el flujo, no asignar cada tarea.

---

## Glosario

**Autoasignacion:** forma de trabajo en la que una persona reclama una tarea disponible en lugar de recibirla asignada directamente.

**Bloqueo:** situacion que impide avanzar una tarea, normalmente por una dependencia abierta.

**Capacidad:** especializacion asociada a tareas y personas.

**En curso:** tarea que es foco activo de una persona.

**Entregable:** unidad de valor, feature, historia o modulo. En ScrumBringer normalmente se representa como una tarjeta de nivel alto.

**Fase:** parte reconocible de un flujo, como definicion, diseno, backend, frontend o QA. Puede representarse con subtarjetas, tipos de tarea, capacidades y automatizaciones.

**Hito:** ciclo, sprint o entrega de referencia. Puede representarse como proyecto o tarjeta de nivel alto, segun el alcance.

**Liberar:** devolver una tarea reclamada al Pool.

**Pool:** espacio compartido donde aparecen tareas abiertas disponibles para reclamar.

**Reclamar:** tomar propiedad temporal de una tarea y moverla a Mis tareas.

**Tarjeta:** agrupador de trabajo relacionado.

**Tarea:** unidad de trabajo que una persona puede reclamar, ejecutar y cerrar.

**Workflow:** automatizacion que crea nuevas tareas en el Pool cuando ocurren eventos definidos.
