# Informe de Mejoras UX - ScrumBringer

> **Versión:** 1.1
> **Fecha:** 2026-01-20
> **Auditoría realizada por:** Sally (UX Expert)
> **Validado por:** Product Owner
> **Total de mejoras:** 75

---

## Resumen Ejecutivo

Este documento contiene todas las mejoras de usabilidad identificadas y validadas para ScrumBringer. Las mejoras están organizadas por área funcional y priorizadas para facilitar la planificación de sprints.

**Conclusión UX:** La implementación completa del catálogo producirá una interfaz más cohesionada y usable, con jerarquía visual clara, menor fricción en tareas clave, estados vacíos guiados y feedback consistente. El conjunto P0/P1 ya eleva la claridad y confianza del usuario; el resto consolida pulido visual, accesibilidad y rendimiento percibido.

### Distribución por Prioridad

| Prioridad | Cantidad | Descripción |
|-----------|----------|-------------|
| P0 - Crítica | 19 | Bugs y mejoras que afectan funcionalidad core |
| P1 - Alta | 24 | Mejoras importantes para UX del MVP |
| P2 - Media | 22 | Mejoras de calidad y pulido |
| P3 - Baja | 10 | Nice-to-have y fase 2 |

---

## Leyenda

- **ID**: Identificador único para tracking
- **Prioridad**: P0 (crítica) → P3 (baja)
- **Esfuerzo**: S (small), M (medium), L (large), XL (extra large)

---

## 1. ERRORES Y BUGS (P0)

### E01 - Error "Failed to decode response" en My Bar/My Skills
**Prioridad:** P0 | **Esfuerzo:** M

**Problema:** El mensaje "Error En curso: Failed to decode response" aparece y rompe la confianza del usuario.

**Solución:**
1. Fix del bug en backend (decodificación de respuesta)
2. Mejorar UI del error:
   - Banner colapsable (no intrusivo)
   - Mensaje amigable: "No pudimos cargar los datos. Puede ser un problema temporal."
   - Botón "Reintentar" que reintenta la petición
   - Opción de colapsar el banner

**Especificación visual:**
```
┌─────────────────────────────────────────────────────────┐
│ ⚠️ No pudimos cargar los datos     [Reintentar] [✕]    │
└─────────────────────────────────────────────────────────┘
```

---

### E02 - Capabilities no aparecen sin refresh
**Prioridad:** P0 | **Esfuerzo:** S | **Estado:** Resuelto (pendiente de verificación)

**Problema:** Las capacidades recién creadas no aparecen en Pool sin refresh manual.

**Solución aplicada:** Refresh al navegar Admin → Member views.

**Acción:** Verificar que la solución es consistente en todos los flujos.

---

### E03 - Jerarquía visual formulario vs listado en Admin
**Prioridad:** P0 | **Esfuerzo:** M

**Problema:** En las vistas de Admin, el formulario de creación y el listado compiten por atención visual.

**Solución:**
1. Separar en "cards" visuales distintas
2. Listado arriba (lo que ya existe)
3. Formulario de creación abajo (o en sección colapsable)
4. Título claro para cada sección

**Especificación visual:**
```
┌─────────────────────────────────────────────────────────┐
│ Capacidades                                             │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ LISTADO                                             │ │
│ │ ┌───────────────────────────────────────────────┐   │ │
│ │ │ Nombre                              Acciones  │   │ │
│ │ ├───────────────────────────────────────────────┤   │ │
│ │ │ desarrollador                       [✏️] [🗑️] │   │ │
│ │ │ maquetador                          [✏️] [🗑️] │   │ │
│ │ └───────────────────────────────────────────────┘   │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ CREAR NUEVA CAPACIDAD                               │ │
│ │                                                     │ │
│ │ Nombre: [_________________________]                 │ │
│ │                                                     │ │
│ │                              [Crear]                │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

### E04 - Admin → Proyectos: lista y creación compiten visualmente
**Prioridad:** P0 | **Esfuerzo:** M

**Problema:** En la vista de Proyectos, el listado existente y el formulario de creación compiten en el mismo bloque sin separación visual ni jerarquía clara.

**Solución:**
1. Separar en dos cards visuales distintas
2. Card superior: "Proyectos existentes" con listado + acciones
3. Card inferior: "Crear nuevo proyecto" con formulario
4. Espaciado de 24px entre cards

**Especificación visual:**
```
┌─────────────────────────────────────────────────────────┐
│ Proyectos existentes                                    │
├─────────────────────────────────────────────────────────┤
│ ┌───────────────────────────────────────────────────┐   │
│ │ Nombre           Descripción          Acciones    │   │
│ ├───────────────────────────────────────────────────┤   │
│ │ Default          Proyecto principal   [✏️] [🗑️]   │   │
│ │ TaskOnlyRule     Solo tareas          [✏️] [🗑️]   │   │
│ └───────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

       ↕️ 24px spacing

┌─────────────────────────────────────────────────────────┐
│ Crear nuevo proyecto                                    │
├─────────────────────────────────────────────────────────┤
│ Nombre: [_________________________]                     │
│ Descripción: [_________________________]                │
│                                        [Crear proyecto] │
└─────────────────────────────────────────────────────────┘
```

---

### E05 - Admin → Miembros: botón "Añadir miembro" parece input
**Prioridad:** P0 | **Esfuerzo:** S

**Problema:** El botón "Añadir miembro" tiene estilo visual que lo hace parecer un campo de texto ancho en lugar de un CTA (Call to Action).

**Solución:**
1. Aplicar estilo de botón principal (`btn-primary`)
2. Separar del header de la sección
3. Alinear a la izquierda o centrar según contexto
4. Añadir icono `user-plus` antes del texto

**Especificación visual:**
```
┌─────────────────────────────────────────────────────────┐
│ Miembros del proyecto                                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ ┌───────────────────────────────────────────────────┐   │
│ │ Usuario           Email              Rol          │   │
│ ├───────────────────────────────────────────────────┤   │
│ │ Admin User        admin@example.com  Admin        │   │
│ └───────────────────────────────────────────────────┘   │
│                                                         │
│ [👤+ Añadir miembro]  ← Botón estilo primary            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**CSS sugerido:**
```css
.btn-add-member {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 10px 16px;
  background: var(--sb-primary);
  color: white;
  border: none;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
}
```

---

### E06 - Admin → Capacidades: listado sin acciones ni contexto
**Prioridad:** P0 | **Esfuerzo:** M

**Problema:** El listado de capacidades muestra solo nombres sin acciones de editar/eliminar y sin contexto de cuántos usuarios o tareas usan cada capacidad.

**Solución:**
1. Añadir columna de acciones (editar, eliminar) por fila
2. Añadir contador de uso (si hay datos disponibles)
3. Hover state para filas

**Especificación visual:**
```
┌────────────────────────────────────────────────────────────────┐
│ Capacidades                                                    │
├────────────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────────────┐ │
│ │ Nombre          Uso                              Acciones  │ │
│ ├────────────────────────────────────────────────────────────┤ │
│ │ desarrollador   3 usuarios · 12 tareas           [✏️] [🗑️] │ │
│ │ maquetador      2 usuarios · 5 tareas            [✏️] [🗑️] │ │
│ └────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
```

**Nota:** Mostrar columna "Uso" solo si hay métricas disponibles.

---

### E07 - Admin → Tipos de tarea: formulario largo sin agrupación
**Prioridad:** P0 | **Esfuerzo:** M

**Problema:** El formulario de creación de tipos de tarea tiene varios campos (nombre, icono, capacidad) sin agrupación visual, lo que dificulta el escaneo.

**Solución:**
1. Dividir formulario en bloques semánticos con títulos
2. Bloque 1: "Identidad" (nombre)
3. Bloque 2: "Apariencia" (icono + preview destacado)
4. Bloque 3: "Configuración" (capacidad asociada)
5. Preview del icono más prominente

**Especificación visual:**
```
┌─────────────────────────────────────────────────────────┐
│ Crear tipo de tarea                                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ IDENTIDAD                                               │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Nombre: [_________________________]                 │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ APARIENCIA                                              │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Icono: [bug____________] [−]                        │ │
│ │                                                     │ │
│ │ Preview:  🐛  ← Grande y visible                    │ │
│ │                                                     │ │
│ │ [Pick a common icon... ▼]                           │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ CONFIGURACIÓN                                           │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Capacidad (opcional): [Ninguna ▼]                   │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│                                        [Crear tipo]     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### E08 - Admin → Fichas: estado vacío sin orientación
**Prioridad:** P0 | **Esfuerzo:** S

**Problema:** Cuando no hay fichas, el mensaje "Aún no hay fichas" es frío y no guía al usuario hacia la acción.

**Solución:**
1. Añadir ilustración o icono grande
2. Microcopy orientada a acción
3. CTA prominente para crear la primera ficha

**Especificación visual:**
```
┌─────────────────────────────────────────────────────────┐
│ Fichas - Default                                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│              [📋 Icono grande con opacidad]             │
│                                                         │
│              Aún no hay fichas en este proyecto         │
│                                                         │
│     Las fichas agrupan tareas relacionadas.             │
│     Crea tu primera ficha para organizar el trabajo.    │
│                                                         │
│              [+ Crear primera ficha]                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### E09 - Admin → Métricas: tablas vacías con guiones
**Prioridad:** P0 | **Esfuerzo:** M

**Problema:** Cuando no hay datos, las métricas muestran guiones "-" y tablas vacías que no comunican claramente el estado ni qué hacer.

**Solución:**
1. Reemplazar guiones por mensaje "Sin datos suficientes"
2. Añadir tooltip explicando qué se necesita para ver datos
3. Sugerir acción: "Crea tareas y espera actividad para ver métricas"

**Especificación visual:**
```
┌─────────────────────────────────────────────────────────┐
│ Resumen de métricas                                     │
│ Ventana: 30 días                                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Reclamadas    Liberadas    Completadas    Flujo %   │ │
│ ├─────────────────────────────────────────────────────┤ │
│ │ 0             0            0              —         │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ℹ️ Sin datos suficientes                            │ │
│ │                                                     │ │
│ │ Las métricas se calculan a partir de la actividad   │ │
│ │ del equipo. Crea tareas en el Pool y espera a que   │ │
│ │ los miembros las reclamen.                          │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### E10 - Admin → Métricas de reglas: vista vacía sin instrucciones
**Prioridad:** P0 | **Esfuerzo:** S

**Problema:** La vista de "Métricas de reglas" aparece vacía sin ninguna instrucción de qué hacer, dejando al usuario perdido.

**Solución:**
1. Añadir callout visible con instrucciones
2. Destacar el selector de rango y el botón "Actualizar"
3. Si no hay reglas configuradas, indicarlo con link a Automatizaciones

**Especificación visual:**
```
┌─────────────────────────────────────────────────────────┐
│ Métricas de reglas                                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 💡 Cómo usar                                        │ │
│ │                                                     │ │
│ │ 1. Selecciona un rango de fechas                    │ │
│ │ 2. Pulsa "Actualizar" para cargar métricas          │ │
│ │                                                     │ │
│ │ Rango: [Últimos 30 días ▼]  [Actualizar]           │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ — o si no hay reglas —                                  │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ℹ️ No hay automatizaciones configuradas             │ │
│ │                                                     │ │
│ │ Las métricas de reglas muestran cuántas veces se    │ │
│ │ han ejecutado tus automatizaciones.                 │ │
│ │                                                     │ │
│ │ [Ir a Automatizaciones →]                           │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 2. LOGIN

### L01 - Indicador de carga en login
**Prioridad:** P1 | **Esfuerzo:** S

**Implementación:**
```css
.btn-loading {
  position: relative;
  color: transparent;
  pointer-events: none;
}

.btn-loading::after {
  content: "";
  position: absolute;
  width: 16px;
  height: 16px;
  border: 2px solid currentColor;
  border-right-color: transparent;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}
```

---

### L02 - Estados focus en inputs
**Prioridad:** P2 | **Esfuerzo:** S

**Implementación:**
```css
input:focus, textarea:focus, select:focus {
  outline: none;
  border-color: var(--sb-primary);
  box-shadow: 0 0 0 3px rgba(var(--sb-primary-rgb), 0.15);
}
```

---

### L03 - Mensajes de error inline
**Prioridad:** P1 | **Esfuerzo:** M

**Especificación:**
- Mostrar errores debajo del campo correspondiente
- Color: `var(--sb-error)` (#dc2626)
- Icono de error antes del texto
- Transición suave al aparecer

```html
<div class="form-field error">
  <label>Email</label>
  <input type="email" class="input-error" />
  <span class="field-error">
    <svg><!-- icon --></svg>
    Email o contraseña incorrectos
  </span>
</div>
```

---

## 3. HEADER GLOBAL

### H01 - Mover selector de idioma a Configuración
**Prioridad:** P2 | **Esfuerzo:** M

**Cambio:** No eliminar el selector, moverlo a menú de configuración (útil para QA/localización).

**Implementación:**
1. Crear menú desplegable con icono ⚙️
2. Incluir: Tema, Idioma
3. Leer idioma inicial de `navigator.language`
4. Permitir override manual en el menú

```
┌──────────────────────────────────────────────────────────┐
│ Pool    Proyecto [▼]    admin@example.com    [⚙️] [Salir]│
└──────────────────────────────────────────────────────────┘
                                                 ↓
                                    ┌─────────────────────┐
                                    │ Tema     [▼ Claro]  │
                                    │ Idioma   [▼ Español]│
                                    └─────────────────────┘
```

---

### H02 - Truncar email en pantallas pequeñas
**Prioridad:** P2 | **Esfuerzo:** S

**Breakpoints:**
- Desktop (>1024px): Email completo
- Tablet (768-1024px): Truncar con ellipsis (max 20 chars)
- Mobile (<768px): Solo inicial + avatar o ocultar

```css
@media (max-width: 1024px) {
  .user-email {
    max-width: 150px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
}

@media (max-width: 768px) {
  .user-email {
    display: none;
  }
  .user-avatar {
    display: flex;
  }
}
```

---

### H03 - Agrupar Tema en menú configuración
**Prioridad:** P2 | **Esfuerzo:** M

**Ver H01** - Implementación conjunta.

---

## 4. POOL (VISTA PRINCIPAL)

### P01 - Onboarding para pool vacío
**Prioridad:** P1 | **Esfuerzo:** M

**Especificación:**
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│              [Ilustración: pool vacío]                  │
│                                                         │
│              Tu pool está listo                         │
│                                                         │
│     Crea la primera tarea o espera a que tu equipo     │
│              añada trabajo al pool.                     │
│                                                         │
│     [+ Nueva tarea]        [Ver cómo funciona]          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Assets necesarios:**
- Ilustración SVG de pool vacío (estilo minimalista)
- O usar icono heroicons `inbox` grande con opacidad

---

### P02 - Reforzar visualización de DECAY con badge
**Prioridad:** P1 | **Esfuerzo:** S

**Nota:** Ya existe efecto de decay. Añadir badge explícito de días.

**Implementación:**
```html
<div class="task-card" data-decay="high">
  <span class="decay-badge">5d</span>
  <!-- resto de la tarjeta -->
</div>
```

```css
.decay-badge {
  position: absolute;
  top: 4px;
  right: 4px;
  font-size: 10px;
  padding: 2px 6px;
  border-radius: 4px;
  background: var(--sb-warning-subtle);
  color: var(--sb-warning);
}

[data-decay="high"] .decay-badge {
  background: var(--sb-error-subtle);
  color: var(--sb-error);
}
```

---

### P03 - Mejorar leyenda de prioridad/tamaño
**Prioridad:** P2 | **Esfuerzo:** S

**Nota:** Ya existe escala por prioridad. Añadir leyenda visual.

**Implementación:**
Tooltip o leyenda colapsable que explique:
```
Tamaño = Prioridad
┌──┐ Baja (1-2)
┌────┐ Media (3-4)
┌──────┐ Alta (5)
```

---

### P04 - Panel "Mis tareas" expandible/colapsable
**Prioridad:** P2 | **Esfuerzo:** M

**Especificación:**
- Ancho por defecto: 280px
- Ancho expandido: 400px
- Botón toggle en el borde del panel
- Guardar preferencia en localStorage

```css
.my-tasks-panel {
  width: var(--panel-width, 280px);
  transition: width 0.2s ease;
}

.my-tasks-panel.expanded {
  --panel-width: 400px;
}

.panel-toggle {
  position: absolute;
  left: -12px;
  top: 50%;
  transform: translateY(-50%);
}
```

---

### P05 - Mejorar botón de filtros
**Prioridad:** P2 | **Esfuerzo:** S

**De:** "Ocultar filtros"
**A:** Icono filtro + badge con cantidad de filtros activos

```html
<button class="filter-toggle">
  <svg><!-- funnel icon --></svg>
  <span class="filter-badge" data-count="2">2</span>
</button>
```

---

### P06 - Renombrar checkbox "Mis capacidades"
**Prioridad:** P2 | **Esfuerzo:** S

**De:** "Mis capacidades ☆"
**A:** "Solo para mis skills" o "Filtrar por mis capacidades"

---

### P07 - Campo "Ficha" en modal Nueva tarea
**Prioridad:** P1 | **Esfuerzo:** M

**Especificación del modal actualizado:**
```
┌─────────────────────────────────────────────────────────┐
│ Nueva tarea                                             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Título                                                  │
│ ┌─────────────────────────────────────────────────────┐ │
│ │                                                     │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ Descripción                                             │
│ ┌─────────────────────────────────────────────────────┐ │
│ │                                                     │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ Prioridad                    Tipo                       │
│ ┌───────────────┐           ┌───────────────────────┐   │
│ │ 3           ▼ │           │ Selecciona tipo     ▼ │   │
│ └───────────────┘           └───────────────────────┘   │
│                                                         │
│ Ficha (opcional)                                        │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Sin ficha                                         ▼ │ │
│ └─────────────────────────────────────────────────────┘ │
│ ↳ Opciones: fichas existentes + "+ Crear nueva ficha"   │
│                                                         │
│                        [Cancelar]  [Crear]              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### P08 - Crear ficha desde modal Nueva tarea
**Prioridad:** P1 | **Esfuerzo:** M

**Flujo:**
1. Usuario selecciona "+ Crear nueva ficha" en dropdown
2. Se expanden campos inline para crear ficha (título, descripción)
3. Al crear tarea, se crea también la ficha y se vincula

**Alternativa:** Abrir modal secundario para crear ficha.

---

## 5. MY BAR

### MB01 - Mejorar mensaje de error
**Prioridad:** P0 | **Esfuerzo:** S

**Ver E01** - Implementación del banner de error mejorado.

---

### MB02 - Estado vacío informativo
**Prioridad:** P2 | **Esfuerzo:** S

**Especificación:**
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│              [Icono: clipboard vacío]                   │
│                                                         │
│           No tienes tareas reclamadas                   │
│                                                         │
│     Ve al Pool para elegir tareas disponibles           │
│                                                         │
│              [Ir al Pool →]                             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 6. MY SKILLS

### MS01 - Indicador de skills activos
**Prioridad:** P2 | **Esfuerzo:** S

**Implementación:**
```
Mis capacidades (2 de 5 activas)
```

---

### MS02 - Descripción de cada skill
**Prioridad:** P3 | **Esfuerzo:** M

**Especificación:** Tooltip + texto corto debajo del nombre (no solo tooltip).

```html
<div class="skill-item">
  <div class="skill-header">
    <span class="skill-name">desarrollador</span>
    <input type="checkbox" />
  </div>
  <span class="skill-description">
    Tareas de código, APIs y arquitectura
  </span>
</div>
```

---

## 7. SIDEBAR ADMIN

### SA01 - Añadir iconos a cada sección
**Prioridad:** P1 | **Esfuerzo:** M

**Iconos propuestos (Heroicons):**

| Sección | Icono |
|---------|-------|
| Invitaciones | `envelope` |
| Org | `building-office` |
| Proyectos | `folder` |
| Métricas | `chart-bar` |
| Métricas de reglas | `chart-pie` |
| Miembros | `users` |
| Capacidades | `puzzle-piece` |
| Tipos de tarea | `tag` |
| Fichas | `document-text` |
| Automatizaciones | `bolt` |
| Plantillas | `document-duplicate` |

---

### SA02 - Agrupar por categorías
**Prioridad:** P1 | **Esfuerzo:** M

**Estructura final:**
```
ORGANIZACIÓN
├─ 🏢 Org
├─ 👥 Miembros
└─ ✉️ Invitaciones

PROYECTO
├─ 📁 Proyectos
├─ 🎯 Capacidades
└─ 🏷️ Tipos de tarea

CONTENIDO
├─ 📋 Fichas
├─ 📄 Plantillas de tarea
└─ ⚡ Automatizaciones

ANÁLISIS
├─ 📊 Métricas
└─ 📈 Métricas de reglas
```

---

### SA03 - Separadores visuales entre grupos
**Prioridad:** P1 | **Esfuerzo:** S

```css
.sidebar-group + .sidebar-group {
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px solid var(--sb-border);
}
```

---

### SA04 - Títulos de grupo
**Prioridad:** P1 | **Esfuerzo:** S

```css
.sidebar-group-title {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--sb-text-muted);
  padding: 0 12px 8px;
}
```

---

### SA05 - Estado activo más visible
**Prioridad:** P2 | **Esfuerzo:** S

```css
.sidebar-item.active {
  background: var(--sb-primary-subtle);
  color: var(--sb-primary);
  border-left: 3px solid var(--sb-primary);
}
```

---

## 8. ADMIN - INVITACIONES

### AI01 - Validación custom email
**Prioridad:** P1 | **Esfuerzo:** S

**Ver FG01** - Implementación global de validación.

---

### AI02 - Lista de invitaciones con acciones
**Prioridad:** P2 | **Esfuerzo:** M

**Especificación:**
```
┌────────────────────────────────────────────────────────┐
│ Links de invitación                                    │
├────────────────────────────────────────────────────────┤
│ user@example.com    https://...abc123    [📋] [🗑️]    │
│ otro@example.com    https://...def456    [📋] [🗑️]    │
└────────────────────────────────────────────────────────┘
```

---

### AI03 - Toast "Link copiado"
**Prioridad:** P2 | **Esfuerzo:** S

**Nota:** Ya existe sistema de toast global. Reutilizar con mensaje "Link copiado al portapapeles".

---

## 9. ADMIN - CAPACIDADES

### AC01 - Indicador de uso (condicional)
**Prioridad:** P3 | **Esfuerzo:** M

**Modificación:** Mostrar uso solo si hay métricas disponibles; si no, ocultar.

```html
<tr>
  <td>desarrollador</td>
  <td class="usage-count" v-if="hasMetrics">3 usuarios, 12 tareas</td>
  <td class="actions">...</td>
</tr>
```

---

### AC02 - Botón eliminar/editar por fila
**Prioridad:** P1 | **Esfuerzo:** S

**Implementación:** Iconos de acción al final de cada fila.

---

### AC03 - Confirmación al eliminar
**Prioridad:** P1 | **Esfuerzo:** S

**Ver IF02** - Modal de confirmación global.

---

## 10. ADMIN - TIPOS DE TAREA

### TT01 - Preview de icono mejorado
**Prioridad:** P2 | **Esfuerzo:** S

**Nota:** Ya existe preview. Mejorar feedback si el nombre del icono no existe.

```html
<div class="icon-preview">
  <svg v-if="iconExists"><!-- icono --></svg>
  <span v-else class="icon-error">Icono no encontrado</span>
</div>
```

---

### TT02 - Galería de iconos comunes
**Prioridad:** P2 | **Esfuerzo:** M

**Expandir dropdown con grid visual de iconos frecuentes:**
- bug, feature, task, story, spike, chore, docs

---

### TT03 - Indicador de uso por tipo
**Prioridad:** P3 | **Esfuerzo:** S

Similar a AC01.

---

## 11. ADMIN - FICHAS

### AF01 - Acceso directo a Fichas desde Pool
**Prioridad:** P1 | **Esfuerzo:** M

**Modificación:** Crear acceso directo desde Pool (no mover todo el admin).

**Opciones:**
1. Botón "Ver fichas" junto a "Nueva tarea" en Pool
2. Item "Fichas" en sidebar de App (Pool, Mi barra, Mis skills, **Fichas**)

---

### AF02 - Ver tareas asociadas a cada ficha
**Prioridad:** P1 | **Esfuerzo:** M

**Especificación:**
```
┌─────────────────────────────────────────────────────────┐
│ 📋 Login social                                         │
├─────────────────────────────────────────────────────────┤
│ Tareas (3)                    Progreso: ████░░ 66%      │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ✅ Configurar OAuth provider          [completada]  │ │
│ │ 🔵 Crear botones sociales             [en curso]    │ │
│ │ ⚪ Manejar callback                   [disponible]  │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

### AF03 - Crear tarea desde ficha
**Prioridad:** P1 | **Esfuerzo:** M

**Botón dentro de cada ficha:** "+ Nueva tarea para esta ficha"

---

### AF04 - Indicador de progreso por ficha
**Prioridad:** P2 | **Esfuerzo:** S

**Barra de progreso:** X/Y tareas completadas

---

## 12. ADMIN - AUTOMATIZACIONES

### AW01 - Builder visual de reglas
**Prioridad:** P3 (Fase 2) | **Esfuerzo:** XL

**Nota:** Prioridad baja, implementar en fase 2.

**Concepto:**
```
Cuando [tarea creada ▼] con [tipo = bug ▼]
Entonces [asignar capacidad ▼] [desarrollador ▼]
```

---

### AW02 - Plantillas de automatización
**Prioridad:** P2 | **Esfuerzo:** M

**Plantillas sugeridas:**
- "Bugs requieren desarrollador"
- "Docs requieren maquetador"
- "Alta prioridad notifica al equipo"

---

### AW03 - Preview de regla en lenguaje natural
**Prioridad:** P2 | **Esfuerzo:** S

**Ejemplo:**
> "Cuando se crea una tarea de tipo Bug, automáticamente requiere la capacidad Desarrollador"

---

## 13. ADMIN - MÉTRICAS

### AM01 - Gráficos de tendencias
**Prioridad:** P2 | **Esfuerzo:** L

**Librería sugerida:** Chart.js mini o sparklines SVG custom

---

### AM02 - Mensaje para datos insuficientes
**Prioridad:** P2 | **Esfuerzo:** S

**Ver E09** - Se unifica para evitar duplicidad y mantener una sola fuente de verdad.

---

### AM03 - Filtro de rango de fechas
**Prioridad:** P2 | **Esfuerzo:** M

**Opciones:** 7 días, 30 días, 90 días, Personalizado

---

### AM04 - Renombrar botón "Ver"
**Prioridad:** P3 | **Esfuerzo:** S

**De:** "Ver"
**A:** "Ver detalle" o icono `arrow-right` con tooltip

---

## 14. ADMIN - PLANTILLAS DE TAREA

### PT01 - Preview de plantilla
**Prioridad:** P2 | **Esfuerzo:** M

**Expandible o tooltip mostrando campos pre-rellenados.**

---

### PT02 - Duplicar plantilla
**Prioridad:** P3 | **Esfuerzo:** S

**Botón de acción:** Icono `document-duplicate`

---

## 15. FORMULARIOS GLOBALES

### FG01 - Validación custom
**Prioridad:** P1 | **Esfuerzo:** M

**Implementación:**
```javascript
// Gleam/Lustre - ejemplo conceptual
fn validate_field(value, rules) {
  rules
  |> list.filter_map(fn(rule) { rule(value) })
  |> list.first
}
```

**Estados visuales:**
- Normal: borde `var(--sb-border)`
- Focus: borde `var(--sb-primary)` + shadow
- Error: borde `var(--sb-error)` + mensaje rojo debajo
- Success: borde `var(--sb-success)` (opcional)

---

### FG02 - Estados de error consistentes
**Prioridad:** P1 | **Esfuerzo:** S

```css
.field-error {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-top: 4px;
  font-size: 12px;
  color: var(--sb-error);
}

.input-error {
  border-color: var(--sb-error);
}
```

---

### FG03 - Toast de éxito
**Prioridad:** P1 | **Esfuerzo:** S

**Nota:** Ya existe sistema de toast. Asegurar uso consistente en todas las acciones.

---

### FG04 - Botones con estado loading
**Prioridad:** P1 | **Esfuerzo:** S

**Ver L01** - Reutilizar implementación de loading.

---

## 16. RESPONSIVE - MOBILE

### RM01 - Sidebar Admin en hamburger menu
**Prioridad:** P1 | **Esfuerzo:** M

**Implementación:**
```css
@media (max-width: 768px) {
  .admin-sidebar {
    position: fixed;
    left: -280px;
    transition: left 0.3s ease;
    z-index: 100;
  }

  .admin-sidebar.open {
    left: 0;
  }

  .hamburger-menu {
    display: block;
  }
}
```

---

### RM02 - Header compacto
**Prioridad:** P1 | **Esfuerzo:** S

**Ver H02 y H03.**

---

### RM03 - Pool en mobile: validar UX
**Prioridad:** P2 | **Esfuerzo:** S

**Nota:** Ya hay redirección a My Bar en mobile. Validar que el comportamiento es correcto y documentar.

**Acción:** Test de usuario para confirmar que el flujo mobile es intuitivo.

---

### RM04 - Touch targets 44x44px
**Prioridad:** P1 | **Esfuerzo:** S

```css
@media (max-width: 768px) {
  button, a, .clickable {
    min-height: 44px;
    min-width: 44px;
  }
}
```

---

## 17. RESPONSIVE - TABLET

### RT01 - Reducir padding del sidebar
**Prioridad:** P2 | **Esfuerzo:** S

```css
@media (max-width: 1024px) {
  .admin-sidebar {
    width: 200px;
    padding: 8px;
  }

  .sidebar-item {
    padding: 8px;
    font-size: 13px;
  }
}
```

---

### RT02 - Panel "Mis tareas" colapsable
**Prioridad:** P2 | **Esfuerzo:** S

**Ver P04.**

---

## 18. ACCESIBILIDAD (A11Y)

### A01 - aria-label en botones de icono
**Prioridad:** P1 | **Esfuerzo:** M

**Ejemplo:**
```html
<button aria-label="Eliminar capacidad">
  <svg><!-- trash icon --></svg>
</button>
```

**Checklist:**
- [ ] Botones de cerrar modal
- [ ] Botones de acción en tablas
- [ ] Botones de navegación
- [ ] Toggle de filtros

---

### A02 - aria-describedby en formularios
**Prioridad:** P1 | **Esfuerzo:** S

```html
<input
  id="email"
  aria-describedby="email-error"
  aria-invalid="true"
/>
<span id="email-error" role="alert">
  Email inválido
</span>
```

---

### A03 - alt en imágenes/iconos
**Prioridad:** P1 | **Esfuerzo:** S

- Iconos decorativos: `alt=""`
- Iconos informativos: `alt="descripción"`
- Ilustraciones: `alt="descripción de la escena"`

---

### A04 - Skip link
**Prioridad:** P2 | **Esfuerzo:** S

```html
<a href="#main-content" class="skip-link">
  Saltar al contenido principal
</a>

<style>
.skip-link {
  position: absolute;
  left: -9999px;
}
.skip-link:focus {
  left: 10px;
  top: 10px;
  z-index: 1000;
}
</style>
```

---

### A05 - Contraste WCAG 2.1 AA
**Prioridad:** P1 | **Esfuerzo:** M

**Herramientas:**
- Lighthouse accessibility audit
- axe DevTools
- Contrast checker manual para colores custom

**Ratios mínimos:**
- Texto normal: 4.5:1
- Texto grande (>18px o >14px bold): 3:1
- Elementos UI: 3:1

---

### A06 - Focus visible en navegación por teclado
**Prioridad:** P1 | **Esfuerzo:** S

```css
:focus-visible {
  outline: 2px solid var(--sb-primary);
  outline-offset: 2px;
}

/* Ocultar outline solo para mouse */
:focus:not(:focus-visible) {
  outline: none;
}
```

---

## 19. INTERACCIONES Y FEEDBACK

### IF01 - Toast notifications (reforzar uso)
**Prioridad:** P1 | **Esfuerzo:** S

**Nota:** Ya existe sistema. Asegurar uso en:
- Crear/editar/eliminar cualquier entidad
- Errores de red
- Acciones copiadas al portapapeles

---

### IF02 - Confirmación de acciones destructivas
**Prioridad:** P1 | **Esfuerzo:** M

**Modal de confirmación:**
```
┌─────────────────────────────────────────────────────────┐
│ ¿Eliminar "desarrollador"?                              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Esta acción no se puede deshacer.                       │
│ Se eliminarán todas las asociaciones con esta           │
│ capacidad.                                              │
│                                                         │
│                    [Cancelar]  [Eliminar]               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**El botón destructivo debe ser rojo.**

---

### IF03 - Estados de carga (skeletons)
**Prioridad:** P2 | **Esfuerzo:** M

```css
.skeleton {
  background: linear-gradient(
    90deg,
    var(--sb-surface) 25%,
    var(--sb-hover) 50%,
    var(--sb-surface) 75%
  );
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}

@keyframes shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
```

---

### IF04 - Animaciones sutiles
**Prioridad:** P3 | **Esfuerzo:** S

```css
/* Transiciones globales */
* {
  transition:
    background-color 0.15s ease,
    border-color 0.15s ease,
    box-shadow 0.15s ease,
    opacity 0.15s ease;
}

/* Modal */
.modal {
  animation: fadeIn 0.2s ease;
}

@keyframes fadeIn {
  from { opacity: 0; transform: scale(0.95); }
  to { opacity: 1; transform: scale(1); }
}
```

---

## Apéndice A: Variables CSS Sugeridas

```css
:root {
  /* Colores base */
  --sb-primary: #0d9488;
  --sb-primary-subtle: rgba(13, 148, 136, 0.1);
  --sb-primary-rgb: 13, 148, 136;

  /* Estados */
  --sb-error: #dc2626;
  --sb-error-subtle: rgba(220, 38, 38, 0.1);
  --sb-warning: #d97706;
  --sb-warning-subtle: rgba(217, 119, 6, 0.1);
  --sb-success: #059669;
  --sb-success-subtle: rgba(5, 150, 105, 0.1);

  /* Superficies */
  --sb-bg: #f8fafc;
  --sb-surface: #ffffff;
  --sb-hover: #f1f5f9;
  --sb-border: #e2e8f0;

  /* Texto */
  --sb-text: #1e293b;
  --sb-text-muted: #64748b;
}
```

---

## Apéndice B: Resumen para Sprint Planning

### Sprint 1 (P0 - Errores críticos de Admin)
- E01, E02, E03 (errores base)
- E04 (proyectos: separar lista/form)
- E05 (miembros: botón CTA)
- E06 (capacidades: acciones por fila)
- E07 (tipos de tarea: agrupar formulario)
- E08 (fichas: estado vacío)
- E09 (métricas: mensaje sin datos)
- E10 (métricas reglas: instrucciones)

### Sprint 2 (P1 - UX Core)
- L01, L03 (login)
- P01, P02, P07, P08 (pool)
- SA01-SA04 (sidebar admin)
- FG01-FG04 (formularios)
- A01, A02, A05, A06 (accesibilidad)
- RM01, RM04 (mobile)
- IF01, IF02 (feedback)

### Sprint 3 (P1 restantes)
- AF01, AF02, AF03 (fichas)
- AC02, AC03 (capacidades)
- MB01 (my bar)
- AI01 (invitaciones)

### Sprint 4 (P2)
- H01, H02, H03 (header)
- P03, P04, P05, P06 (pool mejoras)
- TT01, TT02, AM01-AM04 (admin)
- RT01, RT02 (tablet)
- IF03 (skeletons)

### Backlog (P3 / Fase 2)
- MS02, AC01, TT03, AW01, PT02, IF04

---

*Documento generado: 2026-01-20*
*Próxima revisión: Al completar Sprint 1*
