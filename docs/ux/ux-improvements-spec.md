# ScrumBringer UX Improvements Specification

**Version:** 1.0
**Author:** Sally (UX Expert)
**Date:** 2026-01-22
**Status:** Ready for Implementation

---

## 1. Executive Summary

Este documento consolida las mejoras de usabilidad identificadas en el análisis de las 53 capturas de pantalla generadas en los tests E2E de Story 4.4. El objetivo es crear una interfaz **coherente, predecible y eficiente** en todas las vistas.

### Principios de Diseño Unificados

| # | Principio | Descripción |
|---|-----------|-------------|
| 1 | **Consistencia ante todo** | Mismos patrones, componentes y comportamientos en toda la aplicación |
| 2 | **Datos legibles** | Formateo human-friendly de fechas, números y texto largo |
| 3 | **Feedback inmediato** | Toda acción tiene respuesta visual instantánea |
| 4 | **Estados vacíos accionables** | Nunca mostrar solo "Sin datos", siempre sugerir acción |
| 5 | **Mobile-first pero desktop-optimized** | Diseñar primero para mobile, optimizar para desktop |
| 6 | **Accesibilidad por defecto** | WCAG 2.1 AA como mínimo en todos los componentes |

---

## 2. Sistema de Diseño Unificado

### 2.1 Paleta de Colores Estandarizada

```
PRIMARIOS
├── Primary:     #0D9488 (teal-600)     → CTAs, links activos, estados seleccionados
├── Primary-hover: #0F766E (teal-700)   → Hover de CTAs
└── Primary-light: #CCFBF1 (teal-100)   → Fondos de selección, badges

SEMÁNTICOS
├── Success:     #22C55E (green-500)    → Completado, disponible, positivo
├── Warning:     #F59E0B (amber-500)    → Atención, pendiente
├── Error:       #EF4444 (red-500)      → Errores, acciones destructivas
└── Info:        #3B82F6 (blue-500)     → Información, ayuda

NEUTRALES
├── Text-primary:   #1F2937 (gray-800)  → Texto principal
├── Text-secondary: #6B7280 (gray-500)  → Texto secundario, placeholders
├── Border:         #E5E7EB (gray-200)  → Bordes de inputs, cards
├── Background:     #F9FAFB (gray-50)   → Fondo de página
└── Surface:        #FFFFFF             → Fondo de cards, modals
```

### 2.2 Tipografía Unificada

```
ESCALA TIPOGRÁFICA
├── H1:      24px / 700 / 1.2    → Títulos de página
├── H2:      20px / 600 / 1.3    → Títulos de sección
├── H3:      16px / 600 / 1.4    → Subtítulos, headers de card
├── Body:    14px / 400 / 1.5    → Texto general
├── Small:   12px / 400 / 1.5    → Labels, metadata, timestamps
└── Tiny:    10px / 500 / 1.4    → Badges, contadores
```

### 2.3 Espaciado Consistente

```
ESCALA DE ESPACIADO (múltiplos de 4px)
├── xs:   4px    → Padding interno de badges
├── sm:   8px    → Gap entre elementos inline
├── md:   16px   → Padding de cards, gap de grid
├── lg:   24px   → Separación entre secciones
├── xl:   32px   → Margen de página
└── 2xl:  48px   → Separación de bloques principales
```

### 2.4 Touch Targets

```
TAMAÑOS MÍNIMOS
├── Botones:      44px altura mínima
├── Links:        44px área táctil (padding si es necesario)
├── Iconos:       44x44px área clickeable
└── Checkboxes:   24x24px visible, 44x44px área táctil
```

---

## 3. Componentes Estandarizados

### 3.1 Formateo de Datos

#### Fechas y Timestamps

**ANTES (inconsistente):**
```
2026-01-21T21:01:09Z
2026-01-21T08:16:58Z
```

**DESPUÉS (unificado):**
```
Formato relativo (< 7 días):  "hace 2 horas", "ayer", "hace 3 días"
Formato corto (≥ 7 días):     "21 ene 2026"
Formato completo (hover):      "21 de enero de 2026, 21:01"
```

**Implementación:**
```gleam
// Usar función centralizada
pub fn format_date(timestamp: Time, now: Time) -> String {
  let diff = time.diff(now, timestamp)
  case diff {
    d if d < duration.hours(1) -> "hace " <> format_minutes(d) <> " min"
    d if d < duration.hours(24) -> "hace " <> format_hours(d) <> " horas"
    d if d < duration.days(2) -> "ayer"
    d if d < duration.days(7) -> "hace " <> format_days(d) <> " días"
    _ -> format_short_date(timestamp)
  }
}
```

#### URLs y Texto Largo

**ANTES:**
```
http://localhost:8080/accept-invite?token=inv_orgmember_very_long_token_here
```

**DESPUÉS:**
```
Visible:    inv_orgmem...    [Copiar]
Tooltip:    http://localhost:8080/accept-invite?token=inv_orgmember...
```

**Regla:** Truncar a 20 caracteres + "..." con tooltip completo.

---

### 3.2 Tablas de Datos

**Especificación unificada para todas las tablas:**

```
ESTRUCTURA DE TABLA
┌─────────────────────────────────────────────────────────────┐
│ [Búsqueda rápida...]                        [+ Crear nuevo] │
├─────────────────────────────────────────────────────────────┤
│ COLUMNA ↑↓    │ COLUMNA ↑↓    │ ESTADO      │ ACCIONES     │
├───────────────┼───────────────┼─────────────┼──────────────┤
│ Dato          │ hace 2 días   │ ● Activo    │ [···]        │
│ Dato largo... │ 21 ene 2026   │ ○ Pendiente │ [···]        │
├───────────────────────────────────────────────────────────┤
│ Mostrando 1-10 de 45                    [<] 1 2 3 4 5 [>] │
└─────────────────────────────────────────────────────────────┘
```

**Características obligatorias:**
1. **Búsqueda:** Campo de búsqueda arriba a la izquierda
2. **Ordenamiento:** Flechas ↑↓ en headers clickeables
3. **Estados:** Badges de color con punto indicador (● ○)
4. **Acciones:** Menú de 3 puntos para acciones secundarias
5. **Paginación:** Footer con conteo y navegación (si > 10 items)

**Acciones destructivas:**
```
Botón "Eliminar" / "Quitar":
├── Color: text-red-600 (no fondo rojo)
├── Icono: Trash antes del texto
└── Confirmación: Modal obligatorio antes de ejecutar
```

---

### 3.3 Estados Vacíos Accionables

**ANTES (pasivo):**
```
Sin fichas asignadas
```

**DESPUÉS (accionable):**
```
┌────────────────────────────────────┐
│         📋                         │
│                                    │
│   Sin fichas asignadas             │
│                                    │
│   [Ver fichas disponibles →]       │
└────────────────────────────────────┘
```

**Plantilla para todos los estados vacíos:**

| Contexto | Icono | Mensaje | Acción |
|----------|-------|---------|--------|
| Sin tareas reclamadas | ✋ | "No tienes tareas activas" | "Reclamar una tarea →" |
| Sin fichas asignadas | 📋 | "Sin fichas asignadas" | "Ver fichas disponibles →" |
| Sin proyectos | 📁 | "No hay proyectos" | "+ Crear proyecto" |
| Sin miembros | 👥 | "Sin miembros en el equipo" | "+ Añadir miembro" |
| Lista vacía (filtro) | 🔍 | "Sin resultados para este filtro" | "Limpiar filtros" |
| Columna Kanban vacía | ✓ | "¡Todo completado!" | (sin acción) |

---

### 3.4 Navegación y Breadcrumbs

**Estructura de header unificada:**

```
┌─────────────────────────────────────────────────────────────────┐
│ [Logo] ScrumBringer    │ Admin > Miembros │ [🌙] [🌐] user@... │
├─────────────────────────────────────────────────────────────────┤
│ 📍 MIEMBROS - Project Alpha                    [+ Añadir ...]  │
└─────────────────────────────────────────────────────────────────┘
```

**Reglas:**
1. **Breadcrumb** siempre visible en sección central del header
2. **Título de página** con icono a la izquierda
3. **Contexto de proyecto** junto al título cuando aplique
4. **CTA primario** alineado a la derecha del título

---

### 3.5 Sidebar de Navegación

**Mejoras al sidebar actual:**

```
┌──────────────────────────┐
│ Project Alpha        [▼] │  ← Selector de proyecto (full width)
├──────────────────────────┤
│ TRABAJO                  │
│ ├─ + Nueva tarea         │
│ └─ + Nueva Ficha         │
├──────────────────────────┤
│ CONFIGURACIÓN        [▼] │  ← Colapsable
│ ├─ 👥 Equipo             │
│ ├─ 📚 Catálogo           │
│ └─ ⚙️ Automatización      │
├──────────────────────────┤
│ ORGANIZACIÓN         [▼] │  ← Colapsable (solo OrgAdmin)
│ ├─ ✉️ Invitaciones   (3) │  ← Badge con contador
│ ├─ 🏢 Org                │
│ └─ 📁 Proyectos      (2) │
└──────────────────────────┘
```

**Cambios:**
1. Secciones colapsables con chevron
2. Badges con contadores de items pendientes
3. Selector de proyecto ocupa ancho completo
4. Estado colapsado persiste en localStorage

---

### 3.6 Filtros Unificados

**ANTES (duplicado en Pool view):**
```
Fila 1: [Ocultar filtros] [Lienzo] [Lista] [Nueva tarea (n)]
Fila 2: Tipo [▼] Capacidad [▼] Mis capacidades [★] Buscar [____]
Fila 3: [Tag] [Tag] [Tag] ...
```

**DESPUÉS (consolidado):**
```
┌───────────────────────────────────────────────────────────────┐
│ [Pool ▼] [Lista] [Fichas]    │    [🔍 Buscar...]  [⚙️ Filtros]│
└───────────────────────────────────────────────────────────────┘

Al hacer click en [⚙️ Filtros]:
┌─────────────────────────────┐
│ Tipo        [Todas ▼]       │
│ Capacidad   [Todas ▼]       │
│ Mis caps    [★ Solo mías]   │
│ Estado      [● ○ ○ Todos]   │
├─────────────────────────────┤
│ [Limpiar]        [Aplicar]  │
└─────────────────────────────┘
```

**Reglas:**
1. View toggle siempre visible (Pool/Lista/Fichas)
2. Búsqueda siempre visible
3. Filtros avanzados en popover/dropdown
4. Mostrar badge de "filtros activos" cuando hay filtros aplicados

---

## 4. Responsive Design Unificado

### 4.1 Breakpoints

| Breakpoint | Ancho | Layout |
|------------|-------|--------|
| Mobile | < 640px | 1 columna, drawer nav, bottom sheet |
| Tablet | 640-1024px | 2 columnas, sidebar colapsable |
| Desktop | > 1024px | 3 columnas, sidebar expandido |

### 4.2 Mobile: Filtros Colapsados

**ANTES:**
```
Filtros ocupan ~40% de pantalla vertical
```

**DESPUÉS:**
```
┌─────────────────────────────┐
│ ≡  Pool  👤                 │  ← Header compacto
├─────────────────────────────┤
│ [Lienzo ▼]  [🔍]  [⚙️ 3]   │  ← Filtros colapsados, badge muestra activos
├─────────────────────────────┤
│                             │
│    [Cards de tareas]        │  ← Máximo espacio para contenido
│                             │
├─────────────────────────────┤
│ ▲ En curso (0)              │  ← Bottom sheet mejorado
│   ─────────                 │  ← Handle más grande (8px altura)
│ MIS TAREAS                  │
│ ✧ Dark mode    [▶] [↩]     │
└─────────────────────────────┘
```

### 4.3 Mobile: Drawer con Overlay

**Mejoras:**
```
┌─────────────────────────────┬───┐
│ Project Alpha           [×] │███│  ← Overlay oscuro a la derecha
├─────────────────────────────┤███│
│ TRABAJO                     │███│
│ ...                         │███│
└─────────────────────────────┴───┘
```

1. **Overlay** semi-transparente (rgba(0,0,0,0.5))
2. **Click fuera** cierra el drawer
3. **Botón X** visible en esquina superior derecha
4. **Swipe left** cierra el drawer

---

## 5. Pool View: Canvas Mejorado

### 5.1 Problema de Overlap

**ANTES:** Cards se superponen aleatoriamente en el canvas.

**DESPUÉS:** Sistema de layout inteligente:

```
Opción A: Grid auto-layout
┌────────────────────────────────────┐
│ [Card] [Card] [Card] [Card]        │
│ [Card] [Card] [Card]               │
│ [Card] [Card]                      │
└────────────────────────────────────┘

Opción B: Clustering por ficha (recomendado)
┌────────────────────────────────────┐
│ ┌─ Release ─────────────────────┐  │
│ │ [Card] [Card] [Card]          │  │
│ └───────────────────────────────┘  │
│ ┌─ Sprint Notes ────────────────┐  │
│ │ [Card] [Card]                 │  │
│ └───────────────────────────────┘  │
│ ┌─ Sin ficha ───────────────────┐  │
│ │ [Card] [Card] [Card] [Card]   │  │
│ └───────────────────────────────┘  │
└────────────────────────────────────┘
```

### 5.2 Task Cards Mejoradas

```
┌─────────────────────────────┐
│ [SN] 👆  ⋮                  │  ← Ficha badge + claim indicator + menu
│ ┌───┐                       │
│ │ 🐛│ Login broken          │  ← Icono de tipo + título
│ └───┘                       │
│ ─────────────────────────── │
│ 🏷️ Frontend  ⏱️ 2h          │  ← Tags + estimación (si aplica)
└─────────────────────────────┘
```

---

## 6. Accesibilidad Mejorada

### 6.1 Requisitos WCAG 2.1 AA

| Requisito | Estado Actual | Mejora Necesaria |
|-----------|---------------|------------------|
| Contraste 4.5:1 | ✅ Cumple | Mantener |
| Focus visible | ⚠️ Parcial | Añadir outline consistente |
| Skip link | ✅ Presente | Mantener |
| ARIA landmarks | ✅ Presente | Mantener |
| Touch targets 44px | ⚠️ Parcial | Aumentar en mobile |

### 6.2 Focus States Unificados

```css
/* Aplicar a TODOS los elementos interactivos */
:focus-visible {
  outline: 2px solid var(--primary);
  outline-offset: 2px;
  border-radius: 4px;
}
```

### 6.3 Keyboard Navigation

**Nuevos shortcuts sugeridos:**

| Shortcut | Acción |
|----------|--------|
| `n` | Nueva tarea |
| `f` | Abrir filtros |
| `1/2/3` | Cambiar vista (Pool/Lista/Fichas) |
| `/` | Focus en búsqueda |
| `Esc` | Cerrar modal/drawer |

---

## 7. Plan de Implementación

### Fase 1: Quick Wins (1-2 días)
- [ ] Implementar `format_date()` centralizado
- [ ] Añadir badges con contadores en sidebar
- [ ] Estandarizar botones destructivos (color + icono)
- [ ] Aumentar touch targets en mobile

### Fase 2: Componentes Core (3-5 días)
- [ ] Crear componente `EmptyState` reutilizable
- [ ] Implementar `DataTable` con búsqueda/sort/paginación
- [ ] Unificar sistema de filtros con popover
- [ ] Añadir breadcrumbs consistentes

### Fase 3: Layouts (3-5 días)
- [ ] Refactorizar Pool view con grid/clustering
- [ ] Implementar sidebar colapsable con persistencia
- [ ] Mobile: filtros colapsados + drawer con overlay
- [ ] Mobile: bottom sheet con handle mejorado

### Fase 4: Polish (2-3 días)
- [ ] Añadir keyboard shortcuts
- [ ] Implementar focus states consistentes
- [ ] Animaciones de transición (200ms ease-out)
- [ ] Testing de accesibilidad completo

---

## 8. Métricas de Éxito

| Métrica | Actual | Objetivo |
|---------|--------|----------|
| Tiempo para completar tarea (new user) | ~5 min | < 3 min |
| Clicks para crear tarea | 4 | 2 |
| Área de contenido en mobile | ~60% | > 75% |
| Lighthouse Accessibility | 85 | > 95 |
| Errores de usuario por sesión | ? | < 1 |

---

## 9. Anexos

### A. Capturas de Referencia

Todas las capturas analizadas se encuentran en:
```
/tmp/e2e-4.4-screenshots/
```

### B. Componentes a Crear

1. `EmptyState` - Estado vacío accionable
2. `DataTable` - Tabla con búsqueda/sort/paginación
3. `FilterPopover` - Filtros avanzados en popover
4. `Breadcrumb` - Navegación de contexto
5. `ConfirmDialog` - Modal de confirmación para acciones destructivas
6. `RelativeTime` - Formateo de fechas relativas

### C. Archivos a Modificar

| Archivo | Cambios |
|---------|---------|
| `client_view.gleam` | Layout refactor, breadcrumbs |
| `three_panel_layout.gleam` | Grid de Pool view |
| `grouped_list.gleam` | Unificar secciones "Sin ficha" |
| `i18n/*.gleam` | Añadir textos de estados vacíos |
| `components/*.gleam` | Nuevos componentes reutilizables |

---

**Documento preparado por Sally (UX Expert)**
*"User-Centric above all - Every design decision must serve user needs"*
