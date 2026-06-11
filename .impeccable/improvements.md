# Registro de mejoras de rediseño

Fuente: `.impeccable/critique/2026-06-11T11-18-55Z__apps-client-src-scrumbringer-client.md`

Estado: audit y primeros pases de mejora en curso. Este registro captura las mejoras detectadas en critique para trazarlas contra los comandos de impeccable aplicados.

## Backlog

### RB-001 - Unificar la gramática de estado de tarea

Prioridad: P1

Superficies: pool cards, filas de tarea, right panel, kanban, mobile.

Problema: los estados available, claimed, now working, blocked, stale y completed aparecen repartidos entre iconos, posición, badges, timers, puntos, side stripes, animación y hover detail. El usuario tiene que aprender demasiadas señales antes de confiar en el estado.

Mejora registrada: definir una sola gramática reusable: chip de estado + slot de acción primaria + indicadores secundarios de salud.

Comando sugerido después del audit: `$impeccable clarify apps/client/src/scrumbringer_client`

Criterios de aceptación:
- Cada estado de tarea tiene una etiqueta visible y consistente.
- La acción primaria ocupa siempre el mismo lugar conceptual.
- Los indicadores secundarios no compiten con estado ni acción principal.
- Desktop, kanban, panel derecho y mobile comparten el mismo vocabulario.

### RB-002 - Hacer legible la acción primaria de pull/claim

Prioridad: P1

Estado: aplicado en `$impeccable polish apps/client/src/scrumbringer_client` el 2026-06-11.

Superficies: `apps/client/src/scrumbringer_client/features/pool`

Problema: claim es el comportamiento central del producto, pero en las tarjetas compite como icono pequeño contra drag, complete, blocked y preview.

Mejora registrada: convertir `Claim` en la acción más reconocible de las tareas disponibles, con label visible cuando haya espacio, ubicación estable, explicación de disabled/blocked y feedback claro tras reclamar.

Mejora aplicada: las tareas disponibles del pool renderizan un CTA `Reclamar` visible con icono y texto, separado de las acciones secundarias de esquina. El botón usa `aria-label` descriptivo, posición estable en desktop y lista móvil, y conserva `disabled` cuando las acciones están deshabilitadas. Las tareas bloqueadas siguen ocultando la acción de claim y muestran el badge de bloqueo.

Verificación: `gleam check` en `apps/client`, detector impeccable sin hallazgos, y capturas browser en desktop 1440x900, mobile 320x720 y apaisado 844x390.

Criterios de aceptación:
- La tarea disponible muestra una acción primaria entendible sin aprender iconos.
- Los estados disabled o blocked explican por qué no se puede reclamar.
- El cambio tras claim confirma resultado y nueva ubicación/estado.

### RB-003 - Sustituir side stripes como semántica visual

Prioridad: P2

Superficies: active task cards, task items, kanban task items, my cards.

Problema: los bordes laterales coloreados pueden confundirse con estado o urgencia, y además chocan con la guía de diseño registrada.

Mejora registrada: reservar puntos o swatches para identidad de card/proyecto; usar chips, borde completo o badges semánticos para estado y salud de flujo.

Comando sugerido después del audit: `$impeccable colorize apps/client/src/scrumbringer_client`

Criterios de aceptación:
- No se añaden nuevos `border-left` o `border-right` coloreados de más de 1px.
- Color de identidad y color de estado tienen roles separados.
- Los estados críticos no dependen solo de color.

### RB-004 - Convertir admin en herramienta de salud de flujo

Prioridad: P2

Superficies: `apps/client/src/scrumbringer_client/features/admin`

Problema: cards, workflows, members, tokens y rules se presentan principalmente como tablas y modales. Es mantenible, pero no prioriza atención, riesgo ni cambios relevantes.

Mejora registrada: añadir resúmenes operativos antes de las tablas: qué requiere atención, qué está stale o mal configurado, qué cambió recientemente.

Comando sugerido después del audit: `$impeccable layout apps/client/src/scrumbringer_client/features/admin`

Criterios de aceptación:
- La primera lectura de cada admin surface responde qué necesita revisión.
- Las tablas siguen existiendo para mantenimiento, no como única arquitectura.
- Los estados problemáticos tienen acciones cercanas y copy específico.

### RB-005 - Añadir contexto táctico en mobile

Prioridad: P2

Superficies: `apps/client/src/scrumbringer_client/features/now_working`

Problema: mobile ejecuta bien active/claimed work, pero pierde parte del contexto de escritorio: card, prioridad, antigüedad, bloqueo o razón de capacidad.

Mejora registrada: añadir una línea compacta de metadatos por fila mobile, manteniendo las acciones accesibles al pulgar.

Comando sugerido después del audit: `$impeccable adapt apps/client/src/scrumbringer_client/features/now_working`

Criterios de aceptación:
- Cada fila mobile conserva una razón clara de por qué importa esa tarea.
- La línea de contexto no desplaza ni debilita la acción principal.
- Los estados blocked/stale son visibles sin depender de hover.

### RB-006 - Revisar jerarquía tipográfica de login y runtime

Prioridad: P3

Superficies: login screen y shell inicial.

Problema: el overlay en navegador detectó `flat-type-hierarchy` en la pantalla no autenticada, con escala comprimida entre 13.3px, 14px, 16px y 24px.

Mejora registrada: revisar contraste de tamaños, peso y ritmo vertical en login/runtime después del audit, sin sobredimensionar la UI de producto.

Comando sugerido después del audit: `$impeccable typeset apps/client/src/scrumbringer_client`

Criterios de aceptación:
- Login distingue claramente título, ayuda, campos, errores y acciones.
- La escala sigue siendo compacta y de producto.
- No se introducen headings fluidos innecesarios.

### RB-007 - Completar audit antes de rediseñar

Prioridad: P1 para proceso

Superficies: `apps/client`, con foco en `apps/client/src/scrumbringer_client`.

Objetivo: validar calidad técnica y riesgos antes de implementar mejoras visuales.

Audit debe cubrir:
- Accesibilidad: contraste, foco, labels, icon-only actions, keyboard parity.
- Responsive: mobile shell, panel sheets, acciones bottom-friendly, tablas admin.
- CSS: tokens, side stripes existentes, sombras/bordes, z-index, overflow, transitions.
- Código UI: componentes duplicados, gramática de estados dispersa, disabled/error states.
- Runtime visual: inspección autenticada si hay API/session disponible; login como fallback.

Comando siguiente: `$impeccable audit apps/client`

### RB-008 - Reordenar acciones del login

Prioridad: P2

Estado: resuelto en `$impeccable layout apps/client/src/scrumbringer_client` el 2026-06-11.

Superficies: `apps/client/src/scrumbringer_client/features/auth`

Problema: en el login, el botón principal de acceso y la acción de recuperación de contraseña aparecen apilados con tratamiento similar. Esto hace que la acción secundaria compita visualmente con el acceso y empeora el ritmo del formulario.

Mejora registrada: mantener `Acceder` como acción primaria clara y convertir `Olvidaste tu contraseña` en un enlace/acción secundaria de baja fricción, alineado con el campo de contraseña o bajo el formulario con menor peso visual. Si se abre el flujo de recuperación, debe aparecer como panel/form secundario con jerarquía propia, no como un segundo CTA equivalente.

Comandos sugeridos después del audit: `$impeccable clarify apps/client/src/scrumbringer_client/features/auth`, `$impeccable layout apps/client/src/scrumbringer_client/features/auth`, `$impeccable typeset apps/client/src/scrumbringer_client`

Criterios de aceptación:
- El login tiene una sola acción primaria visual.
- La recuperación de contraseña se percibe como acción secundaria, no como CTA competidor.
- La disposición funciona en desktop y mobile sin apilados torpes.
- El flujo de recuperación conserva foco, copy claro y feedback accesible.

### RB-009 - Estabilizar layout del shell y canvas del pool

Prioridad: P1

Estado: aplicado en `$impeccable layout apps/client/src/scrumbringer_client` el 2026-06-11.

Superficies: app shell, `features/layout`, `features/pool`, estilos base/layout/pool.

Problema: el shell de tres paneles y el pool mezclaban anchuras rígidas con spacing literal. En mobile, el canvas mantenía posiciones absolutas y podía comprimir o solapar cards. En desktop, las posiciones iniciales de tareas sin coordenadas guardadas podían nacer con colisiones visuales.

Mejora registrada: usar la escala de spacing existente en paneles principales, hacer las columnas del shell menos rígidas, colapsar el pool interno antes de agotar el centro, convertir el canvas móvil en una lista/grid vertical y distribuir las posiciones iniciales en una retícula estable.

Comando sugerido de seguimiento: `$impeccable adapt apps/client/src/scrumbringer_client`

Criterios de aceptación:
- Login, shell desktop y pool no presentan controles o cards solapadas.
- El canvas desktop conserva drag/posicionamiento absoluto.
- El canvas mobile prioriza lectura y acciones táctiles sobre posición libre.
- Los paneles usan una densidad consistente con el sistema de diseño.

### RB-010 - Adaptar shell móvil, drawers y sheet de actividad

Prioridad: P1

Estado: aplicado en `$impeccable adapt apps/client/src/scrumbringer_client` el 2026-06-11.

Superficies: `features/layout`, `features/now_working`, `styles/layout.gleam`, `styles/ux.gleam`, `styles/pool.gleam`, `device.ffi.mjs`.

Problema: los drawers y el sheet móvil existían en el DOM aunque estuvieran cerrados, parte de la UI móvil usaba contenedores clicables no semánticos, y el layout móvil dependía solo del ancho. En móviles apaisados, el shell podía activarse como móvil pero el canvas seguía comportándose como tablero absoluto, generando vacío y cards cortadas.

Mejora aplicada: drawers y sheet cerrados salen del árbol accesible, los paneles abiertos declaran `role="dialog"` con labels, los botones de topbar exponen `aria-expanded`, la mini-bar pasa a ser un botón real, los drawers usan overlay y panel como hermanos para evitar cierres accidentales, y la detección responsive incluye pantallas bajas en horizontal. Los breakpoints críticos del canvas, mini-bar, sheet y overlay se alinean con esa detección.

Criterios de aceptación:
- Drawers y sheet cerrados no aparecen como diálogos ni contenido accionable en el árbol accesible.
- Drawers izquierdo/derecho se abren con `aria-expanded=true`, label propio y controles táctiles de al menos 44px.
- El sheet `En curso` se comporta como diálogo, conserva scroll interno y no bloquea acciones fuera de pantalla.
- El pool mobile usa lista/grid táctil tanto en 320px como en móvil apaisado 844x390.

### RB-011 - Consolidar jerarquía tipográfica del producto

Prioridad: P2

Estado: aplicado en `$impeccable typeset apps/client/src/scrumbringer_client` el 2026-06-11.

Superficies: tokens de tema, estilos base, tablas, layout, pool, diálogos, modales, notas y componentes auxiliares.

Problema: la UI mezclaba valores tipográficos sueltos en `px`, pesos numéricos inconsistentes y line-heights locales. El sistema documentaba una escala compacta de producto, pero el código no expresaba roles suficientes para headings, labels, body, metadatos, contadores y valores tabulares.

Mejora aplicada: se amplió `theme.design_tokens()` con stacks de fuente, rampa en `rem`, pesos, line-heights, tracking de labels y medida máxima de prosa. Las superficies principales ahora usan esos roles: login, paneles, filtros, tablas, pool, cards, drawers/sheet, detalle de tareas/tarjetas/hitos, notas, badges y métricas. Timers, contadores y progreso usan `tabular-nums` o mono cuando mejora la lectura.

Criterios de aceptación:
- La jerarquía distingue título, sección, label, body, metadata y contador sin depender solo de color.
- No se introduce una segunda familia decorativa ni tipografía fluida propia de marketing.
- Login, pool desktop, mobile 320px y móvil apaisado 844x390 no presentan overflow ni solapes por escala tipográfica.
- Los textos largos explicativos usan line-height y medida más cómodos sin romper la densidad del producto.

### RB-012 - Endurecer DataTable ante estados reales y móvil

Prioridad: P1

Estado: aplicado en `$impeccable harden apps/client/src/scrumbringer_client/ui/data_table.gleam` el 2026-06-11.

Superficies: `ui/data_table.gleam`, estilos `.data-table`, tablas de administración y organización.

Problema: el componente `DataTable` declaraba soporte responsive, pero su clase por defecto era solo `.table`, mientras parte del CSS responsive vivía en `.data-table`. Los headers sortables dependían de click en `th`, los estados remotos no anunciaban loading/empty de forma explícita, y errores vacíos del backend podían renderizar feedback sin contenido útil.

Mejora aplicada: `DataTable` usa por defecto `table data-table`, se envuelve en `data-table-scroll`, los headers tienen `scope="col"`, los sortables usan botón real con foco visible, loading/empty exponen `role="status"`/`aria-live`, forbidden usa `role="alert"`, y los errores vacíos caen a un mensaje seguro con código/status. El CSS responsive de tabla usa grid por celda y `overflow-wrap:anywhere` para textos largos, CJK/emoji/URLs y traducciones extensas.

Verificación: `gleam check` en `apps/client`, tests nuevos en `ui_data_table_test.gleam`, detector impeccable limpio sobre `ui/data_table.gleam`, y capturas browser de `/org/projects` en 1440x900 y 320x720.

Criterios de aceptación:
- Las tablas compartidas obtienen comportamiento responsive por defecto.
- Los headers sortables son operables con teclado y mantienen semántica de columna.
- Loading, empty, forbidden y errores vacíos siguen siendo entendibles para usuario y lector de pantalla.
- Textos largos no fuerzan overflow horizontal en cards móviles.

### RB-013 - Endurecer el panel derecho de actividad

Prioridad: P1

Estado: aplicado en `$impeccable harden apps/client/src/scrumbringer_client/features/layout/right_panel.gleam` el 2026-06-11.

Superficies: `features/layout/right_panel.gleam`, estilos del right panel en `styles/layout.gleam`, drawer de actividad móvil.

Problema: el panel derecho dependía de textos cortos y de acciones icon-only con semántica parcial. Las tareas y tarjetas podían perder contexto al truncarse, el popup de preferencias no se exponía como diálogo accesible y el perfil podía romper la lectura con emails largos.

Mejora aplicada: las tareas y tarjetas del panel añaden `title` y `aria-label` descriptivos, las acciones icon-only declaran tipo y label, el popup de preferencias usa `role="dialog"` con `aria-modal`, `aria-labelledby`, cierre explícito y selects etiquetados, y el CSS del panel añade `min-width:0`, truncado controlado y popup acotado para desktop y drawer móvil.

Verificación: `gleam check` en `apps/client`, tests nuevos en `right_panel_tasks_test.gleam`, detector impeccable limpio sobre `right_panel.gleam`, capturas browser del panel en desktop 1440x900 y mobile 320x720, incluyendo preferencias dentro del drawer.

Criterios de aceptación:
- Los nombres largos de tareas, tarjetas y usuario no fuerzan overflow horizontal.
- Las acciones de tarea/tarjeta siguen siendo entendibles con lector de pantalla aunque el texto visible se trunque.
- Preferencias se comporta como diálogo con título, cierre explícito y controles etiquetados.
- El contenido del panel derecho conserva legibilidad y acciones táctiles dentro del drawer móvil.

### RB-014 - Adaptar el pool a uso táctil y pantallas estrechas

Prioridad: P1

Estado: aplicado en `$impeccable adapt apps/client/src/scrumbringer_client/features/pool` el 2026-06-11.

Superficies: `features/pool/task_card.gleam`, `styles/pool.gleam`, `styles/layout.gleam`, `test/pool_task_card_test.gleam`.

Problema: el pool desktop se apoyaba en hover para exponer contexto de tarea. En móvil y dispositivos táctiles el preview se oculta, así que la tarjeta perdía tarjeta origen, antigüedad y descripción; además los filtros podían comprimirse como flex con anchos mínimos y las acciones necesitaban objetivos táctiles consistentes.

Mejora aplicada: las task cards renderizan una línea de contexto móvil con tarjeta, antigüedad y descripción cuando existe; el layout táctil mantiene claim/drag/complete como objetivos de 44px sin tapar contenido; el preview hover se suprime en contextos sin hover; y los filtros del centro pasan a grid responsive con controles full-width en móvil y una columna en pantallas muy estrechas.

Verificación: `gleam check` en `apps/client`, test nuevo de contexto móvil en `pool_task_card_test.gleam`, detector impeccable con solo avisos existentes sobre animación de tamaño en `styles/layout.gleam`, y capturas browser de `/app/pool?view=pool` en 320x720, 844x390 y 1440x900.

Criterios de aceptación:
- En móvil, las tarjetas del pool muestran contexto esencial sin depender de hover.
- El botón `Reclamar` queda en la parte superior de la tarjeta y no tapa título ni metadatos.
- Las acciones principales alcanzan 44px de área táctil en móvil/landscape.
- Los filtros no provocan overflow horizontal ni controles comprimidos en 320px.

### RB-015 - Pulido final de motion, touch y contratos visuales

Prioridad: P1

Estado: aplicado en `$impeccable polish apps/client/src/scrumbringer_client` el 2026-06-11.

Superficies: estilos globales, drawer responsive, barras de progreso, tokens de tema y tests de accesibilidad visual.

Problema: tras los pases de rediseño, quedaban detalles de polish sistémico: tests anclados a tokens antiguos, drawer móvil legacy animando `left`, barras de progreso con transición de `width`, acciones de claim mini dependientes de hover en touch y reduced-motion demasiado genérico para señales animadas como stale/new notes.

Mejora aplicada: el drawer admin móvil se mueve con `transform`; las barras de progreso usan `--progress-width` con `clip-path`; reduced-motion elimina delays y apaga shakes/indicadores pulsantes; claim mini queda visible en dispositivos coarse/touch; y los tests de tema/drawer/estilos reflejan el contrato visual vigente.

Verificación: `gleam check`, suite completa `gleam test` con 1538 tests pasando, detector impeccable limpio sobre `apps/client/src/scrumbringer_client`, búsqueda manual sin transiciones de anchura, posición lateral ni altura máxima, y capturas browser de pool desktop 1440x900, pool mobile 320x720, admin mobile y drawer abierto.

Criterios de aceptación:
- La suite del cliente queda verde después del rediseño.
- No quedan transiciones de layout en `width`, `left` o `max-height`.
- Las señales animadas respetan `prefers-reduced-motion`.
- Las acciones críticas de claim no dependen exclusivamente de hover en dispositivos táctiles.

### RB-016 - Clarificar gramática de estado y próxima acción de tareas

Prioridad: P1

Estado: aplicado en `$impeccable clarify apps/client/src/scrumbringer_client` el 2026-06-11.

Superficies: i18n, `ui/task_state.gleam`, hover de tareas, Pool, My Tasks, Now Working, grouped list, kanban/card surfaces y capability board.

Problema: el producto usaba términos distintos para el mismo flujo de tarea (`Claim`, `Claimed`, `Now Working`, `Start`, `Release`) según la superficie. En vistas compactas, varios botones icon-only no explicaban si la acción movía la tarea a Mis tareas, iniciaba trabajo activo o la devolvía al Pool. El hover del Pool tampoco enseñaba explícitamente el estado ni la próxima acción.

Mejora aplicada: `ui/task_state.gleam` centraliza label, hint y próxima acción por `TaskStatus`. Las traducciones EN/ES pasan a una gramática consistente: disponible -> reclamar a Mis tareas, reclamada -> lista para empezar, en curso -> trabajo activo, completada -> cerrada. Pool, My Tasks, Now Working, capability board y card surfaces usan esos helpers para tooltips, aria-labels, estados secundarios y empty states. El hover de tareas añade `Estado` y `Siguiente acción` sin cambiar el tamaño de la card.

Verificación: `gleam check`, suite completa `gleam test` con 1538 tests pasando, detector impeccable limpio (`[]`), y revisión browser en `http://127.0.0.1:8443/` con screenshots desktop `/tmp/scrumbringer-clarify-desktop.png` y mobile `/tmp/scrumbringer-clarify-mobile.png`.

Criterios de aceptación:
- Cada task expone el mismo vocabulario de estado y próxima acción en Pool, listas alternativas y paneles.
- Los botones compactos conservan texto corto donde importa, pero sus labels accesibles explican la acción completa.
- Los empty states de Now Working y My Tasks indican qué hacer después.
- El botón `Reclamar` permanece en la parte superior de la task card y no tapa título ni metadatos en desktop/mobile.

### RB-017 - Reforzar paleta estratégica en OKLCH

Prioridad: P1

Estado: aplicado en `$impeccable colorize apps/client/src/scrumbringer_client` el 2026-06-11.

Superficies: `theme.gleam`, `styles/components.gleam`, `styles/pool.gleam`, `DESIGN.md` y tests de tema.

Problema: la intención cromática estaba bien definida (teal para acción, semántica para estados), pero los tokens seguían en hex con restos de slate/blue genéricos y un filtro `invert(1)` para iconos en dark mode. Eso hacía que la identidad dependiera más de valores heredados que de una escala perceptual consistente, y producía iconos apagados o con tonos sucios en dark.

Mejora aplicada: la paleta light/dark pasa a OKLCH con neutrales tintados hacia el teal de producto, `--sb-primary-strong` queda definido para hovers, los roles semánticos se separan de la marca, las sombras usan OKLCH con alpha y los colores de tarjeta se expresan como escala compatible con light/dark. El dark mode deja de invertir SVGs y usa color explícito para iconos.

Verificación: contraste calculado para combinaciones críticas antes de aplicar, `gleam check`, suite completa `gleam test` con 1538 tests pasando, detector impeccable limpio (`[]`), y revisión browser con capturas `/tmp/scrumbringer-colorize-desktop.png`, `/tmp/scrumbringer-colorize-mobile.png` y `/tmp/scrumbringer-colorize-dark.png`.

Criterios de aceptación:
- Teal sigue reservado para acción, selección y ownership, no decoración.
- Textos normales, muted y enlaces mantienen contraste AA en superficies principales.
- Dark mode conserva profundidad por superficie y no por filtros de icono.
- Los colores semánticos siguen codificando estado sin depender solo del color.

### RB-018 - Cerrar fugas cromáticas de fondo e iconografía

Prioridad: P1

Estado: aplicado en segunda pasada de `$impeccable colorize apps/client/src/scrumbringer_client` el 2026-06-11.

Superficies: `styles/base.gleam`, `styles/layout.gleam`, `styles/ux.gleam`, `ui/icons.gleam` y `theme.gleam`.

Problema: tras mover los tokens de tema al contenedor `.app`, el `body` seguía declarando fondos con variables que no estaban en su scope. En dark mode, el fondo transparente de `.app` podía revelar blanco fuera de los paneles. Además quedaban literales `white`/`black` en acciones críticas y un helper de heroicons que dependía de `filter: invert(...)` para dark mode.

Mejora aplicada: `.app` pinta el fondo radial tematizado en todo el viewport con `100dvh`, los CTAs y badges usan `--sb-inverse` y mezclas OKLCH, los heroicons externos pasan a renderizarse como máscara `currentColor`, y el helper legacy `theme.icon_filter` deja de devolver filtros destructivos.

Verificación: `gleam check`, suite completa `gleam test` con 1538 tests pasando, detector impeccable limpio (`[]`), búsqueda manual sin `white`/`black`/`invert(...)` críticos en `src`, y revisión browser con capturas `/tmp/scrumbringer-colorize-2-dark.png`, `/tmp/scrumbringer-colorize-2-desktop.png` y `/tmp/scrumbringer-colorize-2-mobile.png`.

Criterios de aceptación:
- Dark mode no muestra fugas blancas en el viewport de pool.
- Los iconos externos heredan color del contexto sin filtros por tema.
- Botones y badges con fondos semánticos usan tokens de foreground, no blanco fijo.
- La revisión light/dark/mobile conserva contraste y jerarquía visual.

### RB-019 - Recuperar identificación rápida de card en tareas compactas

Prioridad: P1

Estado: aplicado como ajuste de feedback visual el 2026-06-11.

Superficies: `features/layout/right_panel.gleam`, `styles/layout.gleam`, `features/pool/task_card.gleam`, `styles/pool.gleam`.

Problema: al retirar los laterales coloreados de las tareas se redujo la ambigüedad entre identidad y estado, pero también se perdió una lectura rápida útil: saber a qué card pertenece cada task en el sidebar/right panel.

Mejora aplicada: las tasks de `MIS TAREAS` incorporan un swatch vertical interno de 4px con `--sb-card-accent`, separado del borde de la fila para que lea como identidad de card y no como estado. El CTA de claim del pool pasa a icon-only con la mano, manteniendo `aria-label` y `title` descriptivos.

Verificación: `gleam check`, suite completa `gleam test` con 1538 tests pasando, detector impeccable limpio (`[]`), y revisión browser con capturas `/tmp/scrumbringer-identity-swatch-desktop.png` y `/tmp/scrumbringer-identity-swatch-mobile.png`.

Criterios de aceptación:
- Las tasks compactas vuelven a asociarse visualmente a su card.
- La señal de card no reutiliza un border-left grande de estado.
- El botón claim del pool no muestra texto visible y conserva accesibilidad.
- Desktop y mobile mantienen lectura y espacio suficiente.

### RB-020 - Reagrupar filtros, header y acciones del Pool

Prioridad: P1

Estado: aplicado en `$impeccable layout apps/client/src/scrumbringer_client` el 2026-06-11.

Superficies: `features/layout/center_panel.gleam`, `features/pool/chrome.gleam`, `styles/layout.gleam`.

Problema: el bloque de filtros del centro y el header del Pool quedan demasiado próximos y con un ritmo de separación similar al interno. El botón contextual `+ Nueva tarea` puede leerse como asociado al bloque de filtros, no al Pool.

Propuesta: definir una composición semántica filtros -> header de contenido -> cuerpo, con separación y alineación que hagan que `Pool` y `+ Nueva tarea` formen un grupo claro. Evitar resolverlo como un margen aislado si no queda documentada la regla de agrupación.

Mejora aplicada: el header del Pool incorpora un grupo interno para título y acción, pasa a una retícula de título + CTA, añade una separación inferior con divider sutil y aumenta el ritmo entre filtros y superficie de trabajo. El botón `+ Nueva tarea` queda visualmente asociado al título del Pool y no al bloque de filtros.

Verificación: `gleam check`, suite de cliente `gleam test` con 1538 tests pasando, detector impeccable limpio (`[]`), y revisión browser con capturas `/tmp/scrumbringer-layout-rb020-rb022-desktop.png`, `/tmp/scrumbringer-layout-rb020-rb022-mobile.png` y `/tmp/scrumbringer-layout-rb020-rb022-mobile-320.png`.

Criterios de aceptación:
- `+ Nueva tarea` se percibe como acción del Pool, no de los filtros.
- La separación entre filtros y header es mayor o más estructural que la separación entre header y contenido.
- El patrón funciona en desktop y mobile.

### RB-021 - Definir jerarquía de acciones globales y contextuales

Prioridad: P2

Estado: aplicado en `$impeccable layout apps/client/src/scrumbringer_client` el 2026-06-11.

Superficies: `features/layout/left_panel.gleam`, `features/pool/chrome.gleam`, vistas admin con `section_header`.

Problema: el sidebar y las superficies de contenido pueden mostrar acciones con la misma etiqueta y peso visual, especialmente `+ Nueva tarea`. Esto crea competencia entre atajos globales y acciones propias de la vista activa.

Propuesta: establecer un contrato visual: sidebar como acceso rápido global, header de superficie como acción contextual. Ajustar peso, ubicación o presencia según la vista para que no compitan como primarios equivalentes.

Mejora aplicada: los botones `+ Nueva tarea` y `+ Nueva tarjeta` del sidebar pasan de acción primaria sólida a atajos globales con fondo tintado sutil y borde. La navegación queda separada de esos atajos mediante un divider ligero. La acción contextual `+ Nueva tarea` del header del Pool pasa a `btn-primary`, conservando su asociación directa con el título del Pool.

Verificación: `gleam check`, suite de cliente `gleam test` con 1539 tests pasando, detector impeccable limpio (`[]`), y revisión browser con capturas `/tmp/scrumbringer-layout-rb021-desktop.png`, `/tmp/scrumbringer-layout-rb021-mobile.png` y `/tmp/scrumbringer-layout-rb021-mobile-320.png`.

Criterios de aceptación:
- El usuario distingue qué acciones son globales y cuáles pertenecen a la vista actual.
- Acciones duplicadas no compiten con el mismo peso en el primer viewport.
- Las acciones contextuales se mantienen visualmente cerca del título de su superficie.

### RB-022 - Reducir dominancia de filtros en mobile

Prioridad: P2

Estado: aplicado en `$impeccable extract apps/client/src/scrumbringer_client` el 2026-06-11.

Superficies: `styles/layout.gleam`, `features/layout/center_panel.gleam`, vistas de trabajo con filtros.

Problema: en mobile el bloque de filtros ocupa el primer foco visual y retrasa la identificación del área de trabajo. El header del Pool y su acción aparecen justo después, sin una frontera suficientemente clara.

Propuesta: compactar filtros secundarios en mobile, mantener búsqueda y resumen de filtros visibles, y asegurar que el título/acción de la superficie se perciben antes o con más claridad que los controles secundarios.

Mejora aplicada: en mobile los filtros de trabajo mantienen controles de 44px, pero pasan a etiquetas inline y una retícula más compacta. La zona de filtros baja en altura y peso visual, mientras que el header del Pool aparece antes y con una frontera más clara respecto al canvas/listado.

Verificación: `gleam check`, suite de cliente `gleam test` con 1538 tests pasando, detector impeccable limpio (`[]`), y revisión browser en 390x844 y 320x720 sin overflow ni solapamientos visibles.

Criterios de aceptación:
- En mobile se identifica la superficie activa antes de tener que procesar todos los filtros.
- `Pool` y su acción principal permanecen agrupados aunque los controles se apilen.
- El primer contenido de trabajo aparece antes o tras una frontera visual más clara.

### RB-023 - Estandarizar composición admin header/filtros/contenido

Prioridad: P2

Estado: aplicado en `$impeccable layout apps/client/src/scrumbringer_client/features/admin` el 2026-06-11.

Superficies: `features/admin/*_view.gleam`, `ui/section_header.gleam`, `styles/tables.gleam`, `styles/dialogs.gleam`.

Problema: las vistas admin combinan headers reutilizables, filter bars inline y toolbar cards con ritmos distintos. Esto puede hacer que filtros y acciones parezcan pertenecer a bloques equivocados según la pantalla.

Propuesta: documentar y aplicar una composición común: header de sección, zona de filtros opcional y contenedor de contenido. Mantener la acción primaria asociada al header y no a la tabla ni a los filtros.

Mejora aplicada: se introdujo `ui/admin_surface.gleam` como composición común `header -> filtros opcionales -> contenido`. Cards y Assignments usan `admin-surface-filters` para que los filtros formen un bloque propio entre header y contenido; API Tokens, Org Users, Capabilities y Task Types usan `admin-surface-content` para que las tablas/listas compartan ritmo sin depender de cards locales. La acción primaria sigue renderizándose en `section_header`, asociada al título de sección.

Criterios de aceptación:
- Cards, Assignments, API Tokens y vistas similares comparten ritmo de header/filtros/contenido.
- Las acciones de crear permanecen asociadas al título de sección.
- Los filtros no parecen operar sobre una tabla o card distinta a la esperada.

### RB-024 - Crear roles semánticos de spacing para agrupación visual

Prioridad: P3

Estado: aplicado en `$impeccable extract apps/client/src/scrumbringer_client` el 2026-06-11.

Superficies: `styles/base.gleam`, `styles/layout.gleam`, `styles/pool.gleam`, `styles/tables.gleam`.

Problema: muchos bloques usan gaps locales de `8px`, `10px`, `12px` y `16px` sin que el token indique intención. Las distancias quedan limpias, pero a veces no distinguen controles relacionados, subgrupos y secciones separadas.

Propuesta: definir roles como controles relacionados, grupo de controles, bloque de sección y salto de superficie. Después, sustituir valores locales por esos roles donde afecten a agrupación y jerarquía.

Mejora aplicada: se añadieron roles `--sb-gap-tight`, `--sb-gap-related`, `--sb-gap-group`, `--sb-gap-section` y `--sb-gap-surface` sobre la escala base. `layout.gleam` los usa en los puntos que afectan a Pool y layout: separación de atajos globales frente a navegación, toolbar/filtros del centro, filtros mobile y composición `Pool` header/cuerpo. La intención de agrupación queda expresada en tokens reutilizables en vez de valores locales.

Verificación: `gleam check`, suite de cliente `gleam test` con 1538 tests pasando y detector impeccable limpio (`[]`).

Criterios de aceptación:
- Las separaciones críticas expresan intención, no solo tamaño.
- Los bloques adyacentes no parecen pertenecer al mismo grupo por usar gaps parecidos.
- Futuras auditorías pueden detectar inconsistencias de spacing con reglas más objetivas.

### RB-025 - Pulir login móvil y navegación org-level de Tokens API

Prioridad: P1

Estado: aplicado en `$impeccable polish apps/client/src/scrumbringer_client` el 2026-06-11.

Superficies: `styles/base.gleam`, `client_update.gleam`, `features/layout/left_panel_data.gleam`, rutas admin.

Problema: el login móvil podía volver a apilar `Acceso` y `¿Olvidaste la contraseña?`, contradiciendo la jerarquía ya aprobada en RB-008. Además `ApiTokens` estaba definido como sección org-level en permisos y router, pero faltaba en el cálculo de ruta actual y en la derivación del sidebar, lo que podía hacer que `/org/api-tokens` perdiera contexto visual o título tras sincronizar navegación.

Mejora aplicada: las acciones del login móvil se mantienen agrupadas en una fila responsive hasta anchos realmente críticos, con `Acceso` como primario y recuperación como enlace secundario. `ApiTokens` pasa a tratarse como org route también en `client_update.current_route` y `left_panel_data.admin_route`, manteniendo título, URL y estado activo de sidebar coherentes.

Verificación: `gleam check`, suite de cliente `gleam test` con 1544 tests pasando, detector impeccable limpio (`[]`), captura móvil de login `/tmp/scrumbringer-polish-login-mobile.png` y captura desktop de Tokens API `/tmp/scrumbringer-polish-api-tokens-desktop.png`.

Criterios de aceptación:
- El login móvil no presenta dos CTAs apilados salvo en ancho ultraestrecho.
- `Acceso` conserva dominancia visual frente a recuperación de contraseña.
- `/org/api-tokens` mantiene título `Tokens API - Scrumbringer`, contenido admin y sección activa.
- La corrección queda cubierta por tests de CSS, rutas y derivación del sidebar.

### RB-026 - Convertir Kanban en tablero operativo de cards

Prioridad: P1

Estado: aplicado en Fase 1 de `.impeccable/work-surfaces-redesign-phase.md` el 2026-06-11.

Superficies: `features/views/kanban_board.gleam`, `ui/card_with_tasks_surface.gleam`, `ui/card_with_tasks_preview.gleam`, `styles/layout.gleam`, `client_update.gleam`, `client_view.gleam`, i18n y tests de Kanban.

Problema: la vista Kanban no se leia con suficiente claridad como tablero de cards. Competia con lecturas de lista, no exponia salud compacta de cada card y en mobile el shell podia impedir que `/app/pool?view=cards` se viera como Kanban.

Mejora aplicada: Kanban mantiene su nombre visible y pasa a tener header de superficie, proposito breve, summary chips operativos, tres columnas reales en desktop y columnas apiladas en mobile. Las cards muestran identidad por color, progreso, tasks disponibles, reclamadas, en curso, bloqueadas cuando aplica y proximas tasks relevantes. Editar/borrar bajan de dominancia visual, crear task queda como accion contextual secundaria y los empty states explican el estado de cada carril.

Verificación: `gleam check`, suite de cliente `gleam test` con 1547 tests pasando, detector impeccable limpio (`[]`), y revisión browser con capturas `/tmp/scrumbringer-kanban-phase1-desktop-1440x900-final.png`, `/tmp/scrumbringer-kanban-phase1-mobile-390x844-final.png`, `/tmp/scrumbringer-kanban-phase1-mobile-320x720-final.png` y `/tmp/scrumbringer-kanban-phase1-mobile-320x720-card.png`.

Criterios de aceptación:
- Kanban se lee como tablero de cards, no como lista vertical.
- La primera lectura permite detectar cards activas, paradas o bloqueadas.
- Las cards comparten mini-gramatica con Hitos sin duplicar el Pool.
- Desktop y mobile no presentan columnas ilegibles ni overflow horizontal operativo.

### RB-027 - Convertir Capacidades en mapa de demanda por skill

Prioridad: P1

Estado: aplicado en Fase 2 de `.impeccable/work-surfaces-redesign-phase.md` el 2026-06-11.

Superficies: `features/capability_board/view.gleam`, `styles/layout.gleam`, i18n y tests de Capacidades.

Problema: la vista de Capacidades heredaba demasiada gramatica de Kanban: columnas visuales por estado, orden alfabetico y poca senal agregada por skill. Esto hacia dificil responder rapido donde habia presion operativa o falta de traccion.

Mejora aplicada: cada fila de capacidad incorpora proposito, resumen de disponibles/reclamadas/en curso/bloqueadas/antiguedad, chip de presion y grupos internos compactos por estado. El orden ahora prioriza bloqueos, demanda sin traccion, reclamadas sin suficientes activas y antiguedad. Claim sigue disponible pero baja de dominancia visual frente a Pool.

Verificación: `gleam check`, suite de cliente `gleam test` con 1548 tests pasando, detector impeccable limpio (`[]`), y revisión browser con capturas `/tmp/scrumbringer-capabilities-phase2-desktop-1440x900-final.png`, `/tmp/scrumbringer-capabilities-phase2-mobile-390x844.png`, `/tmp/scrumbringer-capabilities-phase2-mobile-320x720.png` y `/tmp/scrumbringer-capabilities-phase2-mobile-320x720-claimed.png`.

Criterios de aceptación:
- La primera lectura revela que capacidades tienen demanda o falta de traccion.
- Los grupos internos se leen como estados dentro de una skill, no como otro Kanban.
- Claim sigue accesible sin convertirse en accion principal visual.
- Desktop y mobile no presentan overflow ni grupos comprimidos.

### RB-028 - Reutilizar identidad de card en tareas de Capacidades

Prioridad: P2

Estado: aplicado el 2026-06-11.

Superficies: `features/capability_board/view.gleam`, `styles/layout.gleam` y tests de Capacidades.

Problema: las tareas dentro de Capacidades ya heredaban el color de card en borde/fondo, pero no el mismo simbolo de identidad usado en el sidebar. Esto dificultaba relacionar visualmente una task de Capacidades con su card cuando se escaneaban varias skills.

Mejora aplicada: las tasks de Capacidades reutilizan `task-card-identity-swatch` junto al icono de tipo, con tooltip de card cuando existe. El patron sigue siendo secundario, compacto y no compite con el claim icon-only.

Criterios de aceptación:
- Una task de Capacidades puede relacionarse visualmente con su card usando el mismo indicador que el sidebar.
- El swatch no desplaza ni tapa el texto de la task.
- Las tasks sin card no introducen una marca falsa.

### RB-029 - Convertir Personas en balance de carga del equipo

Prioridad: P1

Estado: aplicado en Fase 3 de `.impeccable/work-surfaces-redesign-phase.md` el 2026-06-11.

Superficies: `features/people/view.gleam`, `styles/layout.gleam`, i18n y tests de Personas.

Problema: la vista de Personas mostraba disponibilidad por miembro, pero obligaba a expandir para entender carga real y no preservaba suficiente contexto de card/estado en las tareas. Eso debilitaba la pregunta principal de la superficie: como esta distribuida la carga del equipo.

Mejora aplicada: Personas incorpora header de superficie con resumen de libres, ocupadas, trabajando ahora y reclamadas totales. Cada fila expone en colapsado estado, tareas en curso, reclamadas, cards implicadas y aviso de carga alta. Al expandir, las tareas se separan en `Active` y `Claimed`, conservan swatch de identidad de card y estado visible, y no introducen acciones que parezcan asignacion manual.

Verificación: `gleam check`, suite de cliente `gleam test` con 1551 tests pasando, detector impeccable limpio (`[]`) y revision browser desktop/mobile de Personas, Pool, panel derecho y navegacion lateral.

Criterios de aceptación:
- Sin expandir se entiende quien esta libre, ocupado o trabajando.
- La vista lee carga y capacidad, no reparto manual de tareas.
- Las tasks preservan card y estado con la gramatica comun del producto.
- La busqueda sigue siendo simple y no cambia el contrato de filtros.

### RB-030 - Aligerar el detalle de Personas eliminando jerarquia visual de card

Prioridad: P2

Estado: aplicado el 2026-06-11.

Superficies: `features/people/view.gleam`, `styles/layout.gleam`, tests de Personas y documentacion de fase.

Problema: la expansion de Personas introducia una lectura `persona -> card -> task` cuando habia varios contextos de card. Esto hacia que la card pareciera un contenedor principal dentro de una vista cuyo objetivo es leer carga por persona, y duplicaba contexto al mostrar tambien swatch y metadatos de card en cada task.

Mejora aplicada: la expansion de Personas pasa a listas planas bajo `Active` y `Claimed`. Cada task conserva el swatch de identidad de card con `title`/`aria-label`, pero deja de mostrar headers, cajas o nombres de card repetidos en el meta visible. El resumen colapsado mantiene los chips de cards implicadas porque ahi ayudan al escaneo de carga.

Criterios de aceptación:
- La expansion no muestra cards como contenedores de tareas.
- Las tareas se leen como lista ligera por estado de carga.
- El color de card sigue presente como contexto secundario y accesible.
- La fila colapsada sigue mostrando las cards implicadas por persona.
