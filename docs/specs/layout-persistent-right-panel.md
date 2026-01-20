# Especificación UX: Panel Derecho Persistente

## Resumen

Unificar el layout de la vista de usuario no-admin para que el panel derecho sea persistente en todas las secciones (Pool, Mi barra, Mis skills), eliminando la barra superior "En curso" y consolidando la información en el panel derecho.

## Problema Actual

### Inconsistencia de Layout

| Vista | Estructura Actual |
|-------|-------------------|
| **Pool** | Sidebar + Contenido + Panel derecho "Mis tareas" |
| **Mi barra** | Barra superior "En curso" + Sidebar + Contenido |
| **Mis skills** | Barra superior "En curso" + Sidebar + Contenido |

**Impacto UX:**
- Confusión cognitiva: el panel aparece/desaparece según la vista
- Pérdida de contexto: al salir del Pool, el usuario pierde visibilidad de sus tareas
- Redundancia: la información de "En curso" y "Mis tareas" está fragmentada

## Solución Propuesta

### Nuevo Layout Unificado

```
┌───────────────────────────────────────────────────────────────┐
│ Topbar (título, proyecto, usuario, tema, logout)              │
├──────────┬─────────────────────────────────┬──────────────────┤
│ Sidebar  │      Contenido Principal        │  Panel Derecho   │
│          │      (varía según sección)      │  (persistente)   │
│ - Pool   │                                 │                  │
│ - Mi bar │                                 │  ┌────────────┐  │
│ - Skills │                                 │  │ En curso   │  │
│          │                                 │  │ (timer)    │  │
│          │                                 │  ├────────────┤  │
│          │                                 │  │ Mis tareas │  │
│          │                                 │  │ (lista)    │  │
│          │                                 │  └────────────┘  │
└──────────┴─────────────────────────────────┴──────────────────┘
```

### Contenido del Panel Derecho

1. **Sección "En curso"** (Now Working)
   - Timer activo con tiempo acumulado
   - Botones: Pausar, Completar, Liberar
   - Estado: "ninguna" cuando no hay tarea activa

2. **Sección "Mis tareas"** (Tareas reclamadas)
   - Lista de tareas reclamadas por el usuario
   - Cada tarea con: título, tipo, prioridad
   - Acciones: Empezar, Completar, Liberar
   - Empty state cuando no hay tareas

## Cambios Técnicos

### Archivos a Modificar

#### 1. `client_view.gleam`
- Eliminar `now_working_view.view_panel(model)` de `view_member()`
- Unificar el layout para usar siempre el patrón de Pool con panel derecho
- Crear nuevo componente `view_member_right_panel()` que combine:
  - Now Working status/timer
  - Lista de tareas reclamadas

#### 2. `features/pool/view.gleam`
- Extraer `view_right_panel()` a un componente compartido
- O mover la lógica a `client_view.gleam`

#### 3. `features/now_working/view.gleam`
- Eliminar `view_panel()` (barra superior)
- Crear `view_now_working_section()` para usar dentro del panel derecho
- Simplificar a solo mostrar:
  - Estado actual (tarea activa o "ninguna")
  - Timer si hay tarea activa
  - Botón de pausa si hay tarea activa

### Archivos a Eliminar/Limpiar

#### Código Muerto a Eliminar
- `view_panel()` en `now_working/view.gleam` (después de migrar funcionalidad)
- CSS relacionado con `.now-working` como barra superior

### Nuevo Componente: `view_member_right_panel`

```gleam
/// Panel derecho persistente para vista de usuario.
/// Combina Now Working status y lista de tareas reclamadas.
fn view_member_right_panel(model: Model, user: User) -> Element(Msg) {
  div([attribute.class("member-right-panel")], [
    // Sección 1: Now Working
    view_now_working_section(model),
    // Sección 2: Mis tareas
    view_claimed_tasks_section(model, user),
  ])
}

/// Sección Now Working dentro del panel derecho.
fn view_now_working_section(model: Model) -> Element(Msg) {
  div([attribute.class("panel")], [
    h3([], [text(i18n_t(model, i18n_text.NowWorking))]),
    case update_helpers.now_working_active_task(model) {
      opt.None ->
        div([attribute.class("now-working-empty")], [
          text(i18n_t(model, i18n_text.NowWorkingNone))
        ])
      opt.Some(active) ->
        view_active_task_timer(model, active)
    }
  ])
}

/// Sección de tareas reclamadas (reutiliza lógica de pool/view).
fn view_claimed_tasks_section(model: Model, user: User) -> Element(Msg) {
  // ... lógica existente de view_right_panel en pool/view.gleam
}
```

## CSS Cambios

### Nuevo CSS para Panel Derecho Unificado

```css
/* Panel derecho persistente */
.member-right-panel {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 16px;
  background: var(--sb-surface);
  border-left: 1px solid var(--sb-border);
  min-width: 280px;
  max-width: 320px;
}

/* Sección Now Working dentro del panel */
.member-right-panel .now-working-section {
  padding: 12px;
  background: var(--sb-elevated);
  border-radius: 8px;
}

.member-right-panel .now-working-empty {
  color: var(--sb-muted);
  font-style: italic;
  text-align: center;
  padding: 8px;
}

.member-right-panel .now-working-active {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.member-right-panel .now-working-timer {
  font-size: 1.5rem;
  font-weight: 600;
  font-family: monospace;
  text-align: center;
}
```

### CSS a Eliminar

```css
/* Eliminar estilos de barra superior "En curso" */
.now-working { ... }
.now-working-error { ... }
/* ... otros estilos relacionados con la barra superior */
```

## Plan de Implementación

### Fase 1: Crear Panel Derecho Unificado
1. Crear `view_member_right_panel()` en `client_view.gleam`
2. Crear `view_now_working_section()` para el panel
3. Reutilizar lógica de tareas reclamadas de `pool/view.gleam`

### Fase 2: Unificar Layout Member
1. Modificar `view_member()` para usar layout consistente
2. Eliminar llamadas a `now_working_view.view_panel()`
3. Aplicar panel derecho a todas las secciones

### Fase 3: Limpieza
1. Eliminar `view_panel()` de `now_working/view.gleam`
2. Limpiar CSS no usado
3. Verificar que no queden referencias huérfanas

### Fase 4: Responsive Móvil
Ver sección "Diseño Móvil" más abajo para detalles completos.

## Diseño Móvil

### Filosofía Móvil (del Brief)

> **"Mobile: no se muestra el Pool; solo My Bar + lista Now Working + acciones rápidas (start/pause/complete/release)."**

| Aspecto | Desktop | Mobile |
|---------|---------|--------|
| **Propósito** | Explorar, elegir, organizar | **Ejecutar, trackear** |
| **Pool** | Sí | **No** (redirige a MyBar) |
| **My Bar** | Panel lateral | Contenido principal |
| **Now Working** | Sección en panel | **Foco principal** (lista) |
| **Acciones** | Todas | **start/pause/complete/release** |

**Razón UX:** En móvil el usuario está *ejecutando* trabajo, no *planificando*. Elegir del Pool requiere pantalla grande y reflexión. Las acciones móviles son tácticas y rápidas.

### Contexto Técnico

| Breakpoint | Comportamiento |
|------------|----------------|
| ≤640px | Body apila verticalmente, nav 100% ancho |
| ≤768px | Touch targets 44px min, topbar envuelve |
| ≤1024px | pool-layout apila, pool-right 100% ancho |

**Comportamiento actual:**
- `is_mobile()` detecta `window.innerWidth < 768px`
- Pool **redirige a MyBar** automáticamente
- Nav móvil solo muestra MyBar y Skills

### Modelo de Datos Móvil

El brief especifica que **Now Working soporta 0..N tareas simultáneas**:

```
Tareas del usuario:
├── Now Working (activas con timer)     ← FOCO MÓVIL
│   ├── Task A  00:15:32  [⏸][✓]
│   └── Task B  00:03:45  [⏸][✓]
└── Claimed (pausadas/sin iniciar)      ← Secundario
    ├── Task C  [▶][↩]
    └── Task D  [▶][↩]
```

### Solución: Mini-Bar + Now Working Sheet

```
┌─────────────────────────────────────┐
│ Mi barra          [A] [☀] [×]       │
├─────────────────────────────────────┤
│ [Mi barra] [Mis skills]             │
├─────────────────────────────────────┤
│                                     │
│    Contenido Principal              │
│    (My Bar / Skills)                │
│                                     │
├─────────────────────────────────────┤
│ ▲ Now Working (2)    00:19:17  [⏸] │  ← Mini-bar
└─────────────────────────────────────┘
```

### Componentes Móvil

#### 1. Mini-Bar Sticky (Bottom)

Muestra resumen de **todas** las sesiones activas:
- Contador: "Now Working (N)" donde N = número de tareas activas
- Timer agregado: suma de tiempo de todas las sesiones activas
- Botón pausa global (pausa todas) o indicador si hay múltiples
- Botón expandir (▲) para ver lista completa

```css
/* Mini-bar sticky en móvil */
@media (max-width: 768px) {
  .member-mini-bar {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    padding: 10px 12px;
    background: var(--sb-elevated);
    border-top: 1px solid var(--sb-border);
    box-shadow: 0 -4px 12px rgba(0,0,0,0.1);
    z-index: 40;
  }

  .member-mini-bar-status {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 8px;
    min-width: 0;
  }

  .member-mini-bar-task {
    font-weight: 600;
    font-size: 14px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .member-mini-bar-timer {
    font-variant-numeric: tabular-nums;
    font-size: 14px;
    color: var(--sb-muted);
  }

  .member-mini-bar-actions {
    display: flex;
    gap: 6px;
    flex-shrink: 0;
  }

  /* Padding inferior para contenido no quede oculto */
  .member-content-mobile {
    padding-bottom: 60px;
  }
}
```

#### 2. Now Working Sheet (Bottom Sheet)

Al tocar ▲ se expande un bottom sheet con **dos secciones ordenadas por prioridad**:

**Sección 1: Now Working (primaria)**
- Lista de tareas con timer activo
- Cada fila: icono tipo + título + timer + [⏸ Pausar] [✓ Completar]
- Acciones táctiles grandes (44px mínimo)

**Sección 2: Claimed (secundaria)**
- Lista de tareas reclamadas pero pausadas/sin iniciar
- Cada fila: icono tipo + título + [▶ Start] [↩ Release]
- Separador visual claro entre secciones

```css
/* Bottom sheet expandido */
.member-panel-sheet {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  max-height: 70vh;
  background: var(--sb-surface);
  border-top: 1px solid var(--sb-border);
  border-radius: 16px 16px 0 0;
  box-shadow: 0 -8px 24px rgba(0,0,0,0.15);
  transform: translateY(100%);
  transition: transform 200ms ease-out;
  z-index: 45;
  overflow: hidden;
}

.member-panel-sheet.open {
  transform: translateY(0);
}

.member-panel-sheet-handle {
  display: flex;
  justify-content: center;
  padding: 12px;
  cursor: pointer;
}

.member-panel-sheet-handle::before {
  content: "";
  width: 40px;
  height: 4px;
  background: var(--sb-border);
  border-radius: 2px;
}

.member-panel-sheet-content {
  padding: 0 16px 16px;
  overflow-y: auto;
  max-height: calc(70vh - 40px);
}
```

### Mockup ASCII - Móvil

#### Estado: Sin sesiones activas (Now Working vacío)
```
┌──────────────────────────┐
│ Mi barra       [A] [☀][×]│
├──────────────────────────┤
│ [Mi barra] [Mis skills]  │
├──────────────────────────┤
│                          │
│  Mis métricas            │
│  ─────────────           │
│  Ventana: 30 días        │
│  Recl | Lib | Compl      │
│    3  |  1  |   5        │
│                          │
│  Tareas reclamadas (2)   │
│  • Task C                │
│  • Task D                │
│                          │
├──────────────────────────┤
│ ▲ Now Working (0)        │
└──────────────────────────┘
```

#### Estado: Con 1 sesión activa
```
┌──────────────────────────┐
│ Mi barra       [A] [☀][×]│
├──────────────────────────┤
│ [Mi barra] [Mis skills]  │
├──────────────────────────┤
│                          │
│  Mis métricas            │
│  ...                     │
│                          │
├──────────────────────────┤
│ ▲ Now Working (1) 00:15:32│
└──────────────────────────┘
```

#### Estado: Con múltiples sesiones activas
```
┌──────────────────────────┐
│ Mi barra       [A] [☀][×]│
├──────────────────────────┤
│ [Mi barra] [Mis skills]  │
├──────────────────────────┤
│  ...                     │
├──────────────────────────┤
│ ▲ Now Working (2) 00:19:17│  ← Timer agregado
└──────────────────────────┘
```

#### Estado: Sheet expandido
```
┌──────────────────────────┐
│ Mi barra       [A] [☀][×]│
├──────────────────────────┤
│ [Mi barra] [Mis skills]  │
├──────────────────────────┤
│  (contenido oscurecido)  │
│                          │
╔══════════════════════════╗
║     ───────────          ║ ← handle
║                          ║
║  NOW WORKING             ║
║  ─────────────           ║
║  🐛 Fix bug    00:15:32  ║
║           [⏸ Pausar] [✓] ║
║  ✨ Feature    00:03:45  ║
║           [⏸ Pausar] [✓] ║
║                          ║
║  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  ║
║                          ║
║  CLAIMED (pausadas)      ║
║  ─────────────           ║
║  📝 Task C    [▶ Start]  ║
║  🔧 Task D    [▶ Start]  ║
║                          ║
╚══════════════════════════╝
```

**Acciones rápidas por estado:**

| Estado | Acciones disponibles |
|--------|---------------------|
| Now Working | ⏸ Pause, ✓ Complete |
| Claimed | ▶ Start, ↩ Release |

### Interacciones Móvil

| Gesto | Acción |
|-------|--------|
| Tap en mini-bar | Expande bottom sheet |
| Tap en handle ▼ | Colapsa bottom sheet |
| Swipe down en sheet | Colapsa bottom sheet |
| Tap en ⏸ (mini-bar) | Pausa/Reanuda sin expandir |
| Tap fuera del sheet | Colapsa bottom sheet |

### Implementación Gleam

```gleam
/// Vista móvil para member con mini-bar y now working sheet.
fn view_member_mobile(model: Model, user: User) -> Element(Msg) {
  div([attribute.class("member member-mobile")], [
    view_member_topbar_mobile(model),
    view_member_nav_horizontal(model),
    div([attribute.class("member-content-mobile")], [
      view_member_section_content(model, user),
    ]),
    view_now_working_mini_bar(model),
    case model.member_panel_expanded {
      True -> view_now_working_sheet(model, user)
      False -> element.none()
    },
  ])
}

/// Mini-bar sticky - muestra resumen de TODAS las sesiones activas.
fn view_now_working_mini_bar(model: Model) -> Element(Msg) {
  let sessions = get_active_sessions(model)
  let count = list.length(sessions)
  let total_time = aggregate_session_time(model, sessions)

  div([
    attribute.class("member-mini-bar"),
    event.on_click(ToggleMemberPanel),
  ], [
    span([attribute.class("member-mini-bar-expand")], [text("▲")]),
    div([attribute.class("member-mini-bar-status")], [
      span([attribute.class("member-mini-bar-label")], [
        text("Now Working (" <> int.to_string(count) <> ")"),
      ]),
      case count > 0 {
        True ->
          span([attribute.class("member-mini-bar-timer")], [
            text(format_duration(total_time)),
          ])
        False -> element.none()
      },
    ]),
  ])
}

/// Bottom sheet con lista Now Working + Claimed.
fn view_now_working_sheet(model: Model, user: User) -> Element(Msg) {
  let sessions = get_active_sessions(model)
  let claimed = get_claimed_not_working(model, user)

  div([attribute.class("member-panel-sheet open")], [
    // Handle para cerrar
    div([
      attribute.class("member-panel-sheet-handle"),
      event.on_click(ToggleMemberPanel),
    ], []),

    div([attribute.class("member-panel-sheet-content")], [
      // Sección 1: NOW WORKING (primaria)
      div([attribute.class("sheet-section sheet-section-primary")], [
        h3([], [text("NOW WORKING")]),
        case sessions {
          [] -> div([attribute.class("empty")], [text("No active sessions")])
          _ -> div([], list.map(sessions, view_session_row))
        },
      ]),

      // Separador
      hr([attribute.class("sheet-divider")]),

      // Sección 2: CLAIMED (secundaria)
      div([attribute.class("sheet-section")], [
        h3([], [text("CLAIMED")]),
        case claimed {
          [] -> div([attribute.class("empty")], [text("No paused tasks")])
          _ -> div([], list.map(claimed, view_claimed_row))
        },
      ]),
    ]),
  ])
}

/// Fila de sesión activa con acciones: Pause, Complete.
fn view_session_row(session: WorkSession) -> Element(Msg) {
  div([attribute.class("session-row")], [
    span([attribute.class("session-icon")], [text(session.task_icon)]),
    span([attribute.class("session-title")], [text(session.task_title)]),
    span([attribute.class("session-timer")], [
      text(format_duration(session.accumulated_s)),
    ]),
    div([attribute.class("session-actions")], [
      button([
        attribute.class("btn-action"),
        event.on_click(NowWorkingPauseClicked(session.task_id)),
      ], [text("⏸")]),
      button([
        attribute.class("btn-action btn-complete"),
        event.on_click(TaskCompleteClicked(session.task_id)),
      ], [text("✓")]),
    ]),
  ])
}

/// Fila de tarea reclamada (pausada) con acciones: Start, Release.
fn view_claimed_row(task: Task) -> Element(Msg) {
  div([attribute.class("claimed-row")], [
    span([attribute.class("claimed-icon")], [text(task.type_icon)]),
    span([attribute.class("claimed-title")], [text(task.title)]),
    div([attribute.class("claimed-actions")], [
      button([
        attribute.class("btn-action btn-start"),
        event.on_click(NowWorkingStartClicked(task.id)),
      ], [text("▶")]),
      button([
        attribute.class("btn-action"),
        event.on_click(TaskReleaseClicked(task.id)),
      ], [text("↩")]),
    ]),
  ])
}
```

### Estado Adicional para Móvil

```gleam
// En client_state.gleam
type Model {
  Model(
    // ... campos existentes ...
    member_panel_expanded: Bool,  // NEW: controla bottom sheet
  )
}

// Nuevo mensaje
type Msg {
  // ... mensajes existentes ...
  ToggleMemberPanel  // NEW: toggle bottom sheet
}
```

### CSS Adicional para Móvil

```css
/* Overlay cuando sheet está abierto */
.member-panel-overlay {
  display: none;
}

@media (max-width: 768px) {
  .member-panel-overlay.visible {
    display: block;
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.3);
    z-index: 42;
  }
}

/* Transición suave del contenido */
@media (max-width: 768px) {
  .member-content-mobile {
    transition: filter 200ms ease;
  }

  .member-content-mobile.dimmed {
    filter: brightness(0.7);
    pointer-events: none;
  }
}
```

## Criterios de Aceptación

### Desktop (≥768px)
- [ ] Panel derecho visible en Pool, Mi barra y Mis skills
- [ ] Now Working status siempre visible en panel derecho
- [ ] Timer funciona correctamente desde el panel
- [ ] Acciones (Empezar, Pausar, Completar, Liberar) funcionan
- [ ] No existe barra superior "En curso"
- [ ] No hay código muerto relacionado con barra superior

### Móvil (<768px)
- [ ] Pool no accesible (redirige a MyBar)
- [ ] Mini-bar sticky visible en parte inferior
- [ ] Mini-bar muestra "Now Working (N)" con contador de sesiones activas
- [ ] Mini-bar muestra timer agregado (suma de todas las sesiones)
- [ ] Tap en mini-bar expande Now Working sheet
- [ ] Sheet sección primaria: lista NOW WORKING con timer por tarea
- [ ] Sheet sección secundaria: lista CLAIMED (pausadas)
- [ ] Acciones NOW WORKING: ⏸ Pause, ✓ Complete
- [ ] Acciones CLAIMED: ▶ Start, ↩ Release
- [ ] Swipe down o tap fuera cierra sheet
- [ ] Contenido tiene padding inferior (60px)
- [ ] Touch targets ≥44px

### General
- [ ] Tests existentes pasan
- [ ] Build sin warnings de código no usado
- [ ] Transiciones suaves entre estados

## Mockup ASCII

### Desktop - Pool
```
┌─────────────────────────────────────────────────────────────┐
│ Pool    Proyecto: [▼ Todos]          admin@ex  [Admin] [×]  │
├─────────┬────────────────────────────────┬──────────────────┤
│ App     │ [Filtros] [Lienzo] [Lista] [+] │ En curso         │
│         │                                │ ─────────────    │
│ • Pool  │  ┌────┐  ┌────┐  ┌────┐       │ ninguna          │
│ ○ Mi bar│  │Task│  │Task│  │Task│       │                  │
│ ○ Skills│  └────┘  └────┘  └────┘       │ Mis tareas       │
│         │                                │ ─────────────    │
│         │                                │ ✋ No hay tareas │
└─────────┴────────────────────────────────┴──────────────────┘
```

### Desktop - Mi Barra
```
┌─────────────────────────────────────────────────────────────┐
│ Mi barra  Proyecto: [▼ Todos]        admin@ex  [Admin] [×]  │
├─────────┬────────────────────────────────┬──────────────────┤
│ App     │ Mis métricas                   │ En curso         │
│         │ ──────────────────             │ ─────────────    │
│ ○ Pool  │ Ventana: 30 días               │ 🐛 Fix bug       │
│ • Mi bar│ Recl | Liber | Compl           │ 00:15:32         │
│ ○ Skills│   3  |   1   |   5             │ [Pausar]         │
│         │                                │                  │
│         │ 🎒 No hay tareas reclamadas    │ Mis tareas       │
│         │                                │ ─────────────    │
│         │                                │ • Fix bug [▶][✓] │
└─────────┴────────────────────────────────┴──────────────────┘
```

## Notas de Implementación

### Reutilización de Código
- La lógica de `view_right_panel()` en `pool/view.gleam` ya tiene la lista de tareas reclamadas
- `now_working_view` tiene la lógica del timer que se debe preservar
- `update_helpers.now_working_active_task()` funciona correctamente tras el fix de work sessions

### Consideraciones de Estado
- `member_work_sessions` contiene las sesiones activas
- `member_tasks` contiene todas las tareas (filtrar por claimed_by)
- El timer usa `now_working_tick` para actualizaciones por segundo

### i18n Keys Necesarias
- `NowWorking` - "En curso"
- `NowWorkingNone` - "ninguna"
- Ya existentes: `MyTasks`, `NoClaimedTasks`, etc.
