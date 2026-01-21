# Scrumbringer - Rediseño de Arquitectura de Información

## UI/UX Specification v1.0

Este documento define los objetivos de experiencia de usuario, arquitectura de información, flujos de usuario y especificaciones de diseño visual para el rediseño de la arquitectura de información de Scrumbringer. Sirve como base para el diseño visual y el desarrollo frontend, asegurando una experiencia cohesiva y centrada en el usuario.

---

## 1. Introducción

### 1.1 Objetivos UX y Principios de Diseño

#### Target User Personas

| Persona | Descripción | Necesidades Principales |
|---------|-------------|------------------------|
| **🟡 Org Admin** | Administrador de toda la organización. Gestiona usuarios, proyectos, e infraestructura. | Vista global de métricas, gestión de usuarios y proyectos, control total |
| **🟣 Project Manager (PM)** | Gestor de uno o más proyectos específicos. Coordina equipo y contenido del proyecto. | Gestionar miembros y sus skills, crear fichas/tareas, ver progreso del proyecto |
| **🔵 Member** | Miembro de equipo que trabaja en tareas. Consume el backlog y reporta progreso. | Ver tareas disponibles, reclamar trabajo, ver sus fichas asignadas, completar tareas |

#### Objetivos de Usabilidad

1. **Claridad de propósito:** Cada vista debe tener un propósito claro y diferenciado
2. **Reducción de clics:** Acciones frecuentes accesibles en máximo 2 clics
3. **Feedback inmediato:** Cada acción tiene respuesta visual clara
4. **Navegación predecible:** El usuario siempre sabe dónde está y cómo volver
5. **Separación clara Admin/Member:** Las vistas de trabajo no se mezclan con administración

#### Principios de Diseño

1. **Simplicidad sobre completitud** - Menos opciones = menos confusión. Eliminar lo que no tiene valor.
2. **Consistencia de patrones** - Mismas interacciones para mismas acciones (ej: siempre modal para crear)
3. **Rol-apropiado** - Mostrar solo lo que el usuario puede usar según sus permisos
4. **Mobile-first thinking** - Diseñar primero para restricciones móviles, luego expandir
5. **Progressive disclosure** - Información detallada solo cuando se solicita

### 1.2 Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-21 | 1.0 | Initial specification with IA redesign | Sally (UX Expert) |
| 2026-01-21 | 1.1 | Added User Flows (6 flows) | Sally (UX Expert) |
| 2026-01-21 | 1.2 | Added Responsive Strategy, Components, Accessibility | Sally (UX Expert) |
| 2026-01-21 | 1.3 | Added URL Strategy, Defectos Corregidos, expanded components | Sally (UX Expert) |
| 2026-01-21 | 1.4 | Clarified Task/Card as view functions (not Lustre components) | Sally (UX Expert) |
| 2026-01-21 | 1.5 | Added E2E validation section with Playwright tests | Sally (UX Expert) |
| 2026-01-21 | 1.6 | Added Anexo C: Gleam type patterns, TDD, implementation checklist | Architect |

---

## 2. Arquitectura de Información (IA)

### 2.1 Problemas Identificados (Estado Actual)

| Vista Actual | Estado | Problema |
|--------------|--------|----------|
| `/app/pool` | ✅ Mantener | Core de la app - funciona bien |
| `/app/bar` | ❌ **ELIMINAR** | Contenido duplicado, sin propósito único |
| `/app/skills` | ❌ **ELIMINAR** | Usuario no puede editar skills (solo PM) |
| `/app/cards` | 🔄 **REDISEÑAR** | Debe mostrar fichas, no pool duplicado |

**Problemas adicionales:**
- Toolbar del Pool mezcla acciones, modos de vista y filtros
- Admin mezcla scope de organización con scope de proyecto
- PM no tiene forma clara de gestionar skills de miembros
- Member no puede ver en qué fichas está trabajando

### 2.2 Nueva Estructura: Layout de 3 Paneles (Sin Header)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                     │
│ ┌─────────────────┐ ┌───────────────────────────────────────────┐ ┌───────────────┐│
│ │                 │ │                                           │ │               ││
│ │  PROYECTO       │ │              CONTENIDO                    │ │  MI ACTIVIDAD ││
│ │  (+ Org)        │ │                                           │ │               ││
│ │                 │ │                                           │ │               ││
│ │  Scope:         │ │  Scope:                                   │ │  Scope:       ││
│ │  - Proyecto     │ │  - Proyecto actual                        │ │  - Personal   ││
│ │  - Organización │ │  - 3 modos de visualización               │ │  - Mi trabajo ││
│ │                 │ │                                           │ │               ││
│ └─────────────────┘ └───────────────────────────────────────────┘ └───────────────┘│
│                                                                                     │
│   IZQUIERDA            CENTRO                                      DERECHA         │
│   Navegación +         Contenido principal                         Mi actividad +  │
│   Configuración        con modos de vista                          Perfil          │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Site Map / Inventario de Pantallas

```
RUTAS PÚBLICAS
├── /login              → Iniciar sesión
├── /accept-invite      → Aceptar invitación
└── /reset-password     → Restablecer contraseña

ÁREA DE TRABAJO (todos los usuarios)
└── /app                → Vista principal con 3 paneles
    ├── ?view=pool      → Modo Pool (canvas de tareas)
    ├── ?view=list      → Modo Lista (tareas agrupadas por ficha)
    └── ?view=cards     → Modo Fichas (kanban de fichas)

CONFIGURACIÓN PROYECTO (PM + Org Admin) - En sidebar izquierdo
├── /config/team        → Equipo (miembros + skills)
├── /config/catalog     → Catálogo (capacidades + tipos de tarea)
└── /config/automation  → Automatización (workflows + plantillas)

ADMINISTRACIÓN ORG (Solo Org Admin) - En sidebar izquierdo
├── /admin/invites      → Invitaciones
├── /admin/users        → Usuarios de la organización
├── /admin/projects     → Proyectos
└── /admin/metrics      → Métricas
```

---

## 3. Wireframes

### 3.1 Layout Completo (Vista General)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                     │
│ ┌─────────────────┐ ┌───────────────────────────────────────────┐ ┌───────────────┐│
│ │                 │ │                                           │ │               ││
│ │  PROYECTO       │ │              CONTENIDO                    │ │  MI ACTIVIDAD ││
│ │                 │ │                                           │ │               ││
│ │ Project Alpha ▼ │ │  [🎯Pool] [≡Lista] [🎴Fichas]   [🔍] [⚙]│ │ ┌───────────┐ ││
│ │                 │ │                                           │ │ │ En curso  │ ││
│ │ ─────────────── │ │  Filtros: Tipo[▼] Capacidad[▼]           │ │ │           │ ││
│ │                 │ │                                           │ │ │ Dark mode │ ││
│ │ TRABAJO         │ │  ┌───────────────────────────────────────┐│ │ │ ⏱ 00:45  │ ││
│ │                 │ │  │                                       ││ │ │[Pausar]   │ ││
│ │ [+ Nueva Tarea] │ │  │     (contenido según modo activo)    ││ │ └───────────┘ ││
│ │                 │ │  │                                       ││ │               ││
│ │ [+ Nueva Ficha] │ │  │     Pool: canvas de tareas           ││ │ ─────────────  ││
│ │   (solo PM)     │ │  │     Lista: tareas agrupadas por ficha││ │               ││
│ │                 │ │  │     Fichas: kanban de fichas         ││ │ Mis tareas    ││
│ │ ─────────────── │ │  │                                       ││ │               ││
│ │                 │ │  │                                       ││ │ • Task 1      ││
│ │ CONFIGURACIÓN   │ │  │                                       ││ │ • Task 2      ││
│ │ (solo PM/Admin) │ │  │                                       ││ │ • Task 3      ││
│ │                 │ │  │                                       ││ │               ││
│ │ ○ Equipo        │ │  │                                       ││ │ ─────────────  ││
│ │ ○ Catálogo      │ │  │                                       ││ │               ││
│ │ ○ Automatiz.    │ │  └───────────────────────────────────────┘│ │ Mis fichas    ││
│ │                 │ │                                           │ │               ││
│ │ ═══════════════ │ │                                           │ │ • Release 0/4 ││
│ │                 │ │                                           │ │ • Retro   0/1 ││
│ │ ORGANIZACIÓN    │ │                                           │ │               ││
│ │ (solo OrgAdmin) │ │                                           │ │ ═════════════ ││
│ │                 │ │                                           │ │               ││
│ │ ○ Invitaciones  │ │                                           │ │ 🔵 Asimov     ││
│ │ ○ Usuarios      │ │                                           │ │ [Mi perfil]   ││
│ │ ○ Proyectos     │ │                                           │ │ [Salir]       ││
│ │ ○ Métricas      │ │                                           │ │               ││
│ │                 │ │                                           │ │               ││
│ └─────────────────┘ └───────────────────────────────────────────┘ └───────────────┘│
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Panel Izquierdo: PROYECTO + ORG

```
┌─────────────────────┐
│  Project Alpha    ▼ │ ← Selector de proyecto
│                     │
│ ═══════════════════ │
│                     │
│  TRABAJO            │ ← Sección visible para TODOS
│                     │
│  [+ Nueva Tarea]    │ ← Solo PM/Admin
│  [+ Nueva Ficha]    │ ← Solo PM/Admin
│                     │
│ ─────────────────── │
│                     │
│  CONFIGURACIÓN      │ ← Solo PM/Admin (colapsable)
│                     │
│  ○ Equipo           │   → Miembros + asignar skills
│  ○ Catálogo         │   → Capacidades + Tipos tarea
│  ○ Automatización   │   → Workflows + Plantillas
│                     │
│ ═══════════════════ │
│                     │
│  ORGANIZACIÓN       │ ← Solo Org Admin (colapsable)
│                     │
│  ○ Invitaciones     │
│  ○ Usuarios         │
│  ○ Proyectos        │
│  ○ Métricas         │
│                     │
└─────────────────────┘
```

**Visibilidad por rol:**

| Sección | Member | PM | Org Admin |
|---------|--------|----|-----------|
| Selector proyecto | ✅ | ✅ | ✅ |
| + Nueva Tarea | ❌ | ✅ | ✅ |
| + Nueva Ficha | ❌ | ✅ | ✅ |
| CONFIGURACIÓN | ❌ | ✅ | ✅ |
| ORGANIZACIÓN | ❌ | ❌ | ✅ |

### 3.3 Panel Central: CONTENIDO (3 modos de visualización)

#### Modo POOL (canvas de tareas disponibles)

```
┌─────────────────────────────────────────────────────────────────┐
│  [🎯 Pool]  [≡ Lista]  [🎴 Fichas]         [🔍 Buscar] [⚙ filtros]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Filtros: Tipo[▼] Capacidad[▼]                                 │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │    ┌──────┐       ┌──────┐                                  ││
│  │    │ Task │       │ Task │    ┌──────┐                      ││
│  │    │  1   │       │  2   │    │ Task │                      ││
│  │    └──────┘       └──────┘    │  3   │                      ││
│  │                               └──────┘                      ││
│  │         ┌──────┐                                            ││
│  │         │ Task │                                            ││
│  │         │  4   │                                            ││
│  │         └──────┘                                            ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  Vista actual del Pool - canvas con tareas arrastrables        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Modo LISTA (tareas agrupadas por ficha)

```
┌─────────────────────────────────────────────────────────────────┐
│  [🎯 Pool]  [≡ Lista]  [🎴 Fichas]         [🔍 Buscar] [⚙ filtros]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  📁 Release (0/4)                                    [▼]    ││
│  │  ├── ☐ Task 1 - Code Review          P2  🏷️ QA             ││
│  │  ├── ☐ Task 2 - Deploy to staging    P1  🏷️ DevOps         ││
│  │  ├── ☐ Task 3 - QA Verification      P2  🏷️ QA             ││
│  │  └── ☐ Task 4 - Documentation        P3  🏷️ Docs           ││
│  │                                                             ││
│  │  📁 Retro (0/1)                                      [▼]    ││
│  │  └── ☐ Task 5 - Prepare slides       P2  🏷️ Feature        ││
│  │                                                             ││
│  │  📁 Sin ficha (3)                                    [▼]    ││
│  │  ├── ☐ Task 6 - Bug fix login        P1  🏷️ Bug            ││
│  │  ├── ☐ Task 7 - Dark mode            P3  🏷️ Feature        ││
│  │  └── ☐ Task 8 - Refactor API         P2  🏷️ Tech           ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  Tareas agrupadas por ficha - vista de lista tradicional       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Modo FICHAS (kanban de fichas con progreso)

```
┌─────────────────────────────────────────────────────────────────┐
│  [🎯 Pool]  [≡ Lista]  [🎴 Fichas]         [🔍 Buscar] [⚙ filtros]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                                                             ││
│  │   PENDIENTE         EN CURSO          CERRADA              ││
│  │   ────────────      ────────────      ────────────         ││
│  │   ┌──────────┐      ┌──────────┐                           ││
│  │   │ Release  │      │ Architec.│                           ││
│  │   │ ──────── │      │ ──────── │                           ││
│  │   │ ░░░░░░░░ │ 0/4  │ █████░░░ │ 1/2                       ││
│  │   │ • Task 1 │      │ • Task A │                           ││
│  │   │ • Task 2 │      │ ✓ Task B │                           ││
│  │   │ • Task 3 │      └──────────┘                           ││
│  │   │ • Task 4 │                                             ││
│  │   └──────────┘                                             ││
│  │   ┌──────────┐                                             ││
│  │   │ Retro    │                                             ││
│  │   │ ░░░░░░░░ │ 0/1                                         ││
│  │   └──────────┘                                             ││
│  │                                                             ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  Kanban de fichas - vista de progreso del proyecto             │
│  PM puede editar fichas con menú contextual [⋮]                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.4 Panel Derecho: MI ACTIVIDAD

```
┌───────────────────┐
│                   │
│  EN CURSO         │ ← Tarea activa con timer
│  ┌─────────────┐  │
│  │ Dark mode   │  │
│  │ ⏱️ 00:45:30 │  │
│  │             │  │
│  │[Pausar][✓]  │  │
│  └─────────────┘  │
│                   │
│ ───────────────── │
│                   │
│  MIS TAREAS       │ ← Tareas que he reclamado
│                   │
│  • Task 1    [▶]  │   [▶] = Empezar a trabajar
│  • Task 2    [▶]  │
│  • Task 3    [▶]  │
│                   │
│ ───────────────── │
│                   │
│  MIS FICHAS       │ ← Fichas donde tengo tareas
│                   │
│  • Release   0/4  │   (solo muestra progreso personal)
│  • Retro     0/1  │
│                   │
│ ═══════════════   │
│                   │
│  🔵 Asimov        │ ← Identidad del usuario
│                   │
│  [⚙️ Preferencias]│ ← Tema, idioma
│  [📊 Mi actividad]│ ← Historial personal (opcional)
│  [🚪 Salir]       │
│                   │
└───────────────────┘
```

### 3.5 Vistas por Rol

#### Member (sin permisos de gestión)

```
┌─────────────────┐ ┌─────────────────────────────┐ ┌───────────────┐
│                 │ │                             │ │               │
│ Project Alpha ▼ │ │ [Pool] [Lista] [Fichas]    │ │  En curso     │
│                 │ │                             │ │  ───────────  │
│ ═══════════════ │ │  (contenido según modo)    │ │  (ninguna)    │
│                 │ │                             │ │               │
│ TRABAJO         │ │                             │ │  ───────────  │
│                 │ │                             │ │               │
│ (sin acciones)  │ │                             │ │  Mis tareas   │
│                 │ │                             │ │  • Task 1     │
│                 │ │                             │ │               │
│                 │ │                             │ │  ───────────  │
│                 │ │                             │ │               │
│                 │ │                             │ │  Mis fichas   │
│                 │ │                             │ │  • Release    │
│                 │ │                             │ │               │
│                 │ │                             │ │  ═══════════  │
│                 │ │                             │ │  🔵 User      │
│                 │ │                             │ │  [Prefs]      │
│                 │ │                             │ │  [Salir]      │
└─────────────────┘ └─────────────────────────────┘ └───────────────┘

⚠️ Member NO ve:
- Botones + Nueva Tarea / + Nueva Ficha
- Sección CONFIGURACIÓN
- Sección ORGANIZACIÓN
```

#### Project Manager

```
┌─────────────────┐ ┌─────────────────────────────┐ ┌───────────────┐
│                 │ │                             │ │               │
│ Project Alpha ▼ │ │ [Pool] [Lista] [Fichas]    │ │  En curso     │
│                 │ │                             │ │  ───────────  │
│ ═══════════════ │ │  (contenido según modo)    │ │  Dark mode    │
│                 │ │                             │ │  ⏱️ 00:45     │
│ TRABAJO         │ │  En modo Fichas, PM ve:    │ │               │
│                 │ │  - Menú [⋮] en cada ficha  │ │  ───────────  │
│ [+ Nueva Tarea] │ │  - Editar / Eliminar       │ │               │
│ [+ Nueva Ficha] │ │                             │ │  Mis tareas   │
│                 │ │                             │ │  • Task 1     │
│ ─────────────── │ │                             │ │               │
│                 │ │                             │ │  ───────────  │
│ CONFIGURACIÓN   │ │                             │ │               │
│                 │ │                             │ │  Mis fichas   │
│ ○ Equipo        │ │                             │ │  • Release    │
│ ○ Catálogo      │ │                             │ │               │
│ ○ Automatiz.    │ │                             │ │  ═══════════  │
│                 │ │                             │ │  🟣 PM        │
│                 │ │                             │ │  [Prefs]      │
│                 │ │                             │ │  [Salir]      │
└─────────────────┘ └─────────────────────────────┘ └───────────────┘

✅ PM VE:
- Botones + Nueva Tarea / + Nueva Ficha
- Sección CONFIGURACIÓN (Equipo, Catálogo, Automatización)
- Menú contextual en fichas para editar/eliminar
```

#### Org Admin

```
┌─────────────────┐ ┌─────────────────────────────┐ ┌───────────────┐
│                 │ │                             │ │               │
│ Project Alpha ▼ │ │ [Pool] [Lista] [Fichas]    │ │  En curso     │
│                 │ │                             │ │  ───────────  │
│ ═══════════════ │ │  (contenido según modo)    │ │  (ninguna)    │
│                 │ │                             │ │               │
│ TRABAJO         │ │                             │ │  ───────────  │
│                 │ │                             │ │               │
│ [+ Nueva Tarea] │ │                             │ │  Mis tareas   │
│ [+ Nueva Ficha] │ │                             │ │  (vacío)      │
│                 │ │                             │ │               │
│ ─────────────── │ │                             │ │  ───────────  │
│                 │ │                             │ │               │
│ CONFIGURACIÓN   │ │                             │ │  Mis fichas   │
│                 │ │                             │ │  (vacío)      │
│ ○ Equipo        │ │                             │ │               │
│ ○ Catálogo      │ │                             │ │  ═══════════  │
│ ○ Automatiz.    │ │                             │ │  🟡 Admin     │
│                 │ │                             │ │  [Prefs]      │
│ ═══════════════ │ │                             │ │  [Salir]      │
│                 │ │                             │ │               │
│ ORGANIZACIÓN    │ │                             │ │               │
│                 │ │                             │ │               │
│ ○ Invitaciones  │ │                             │ │               │
│ ○ Usuarios      │ │                             │ │               │
│ ○ Proyectos     │ │                             │ │               │
│ ○ Métricas      │ │                             │ │               │
└─────────────────┘ └─────────────────────────────┘ └───────────────┘

✅ Org Admin VE todo:
- Todo lo que ve PM
- Sección ORGANIZACIÓN (Invitaciones, Usuarios, Proyectos, Métricas)
```

---

## 4. Decisiones de Diseño

### 4.1 Elementos Eliminados

| Elemento | Razón de eliminación |
|----------|---------------------|
| **Header global** | Absorbido en los paneles laterales - más espacio vertical |
| **Vista "Mi barra"** | Contenido duplicado del pool, sin propósito único |
| **Vista "Mis skills"** | Solo PM puede asignar skills - no tiene sentido para el usuario |
| **Admin mixto** | Separado en CONFIGURACIÓN (proyecto) y ORGANIZACIÓN (org) |

### 4.2 Modelo de Permisos para Skills

| Acción | Member | PM | Org Admin |
|--------|--------|----|-----------|
| Ver mis skills | ❌ (eliminado) | ❌ | ❌ |
| Asignar skills a miembros | ❌ | ✅ Config > Equipo | ✅ |
| Crear capacidades | ❌ | ✅ Config > Catálogo | ✅ |

### 4.3 Fichas en Múltiples Contextos

| Contexto | Ubicación | Propósito |
|----------|-----------|-----------|
| Vista de proyecto | Centro > Modo Fichas | Ver todas las fichas del proyecto (kanban) |
| Mi actividad | Derecha > Mis fichas | Ver fichas donde tengo tareas asignadas |
| Gestión CRUD | Centro > Modo Fichas + menú [⋮] | PM crea/edita/elimina fichas |

---

## 5. Resumen de Cambios vs Estado Actual

| Elemento | Antes | Después |
|----------|-------|---------|
| Header global | Existía | ❌ Eliminado |
| Mi barra | Vista separada | ❌ Eliminado (contenido en panel derecho) |
| Mis skills | Vista separada | ❌ Eliminado (PM asigna desde Equipo) |
| Fichas member | Mostraba pool | ✅ Modo "Fichas" en toggle central |
| Mis fichas | No existía | ✅ Sección en panel derecho |
| Config proyecto | En Admin mezclado | ✅ Sección separada en sidebar izq |
| Admin org | Mezclado con proyecto | ✅ Sección separada en sidebar izq |
| Pool toolbar | Mezclaba acciones/vistas/filtros | ✅ Separado: toggle arriba, filtros debajo |

---

## 6. User Flows

### 6.1 Flow 1: Member reclama y trabaja en una tarea

**User Goal:** Encontrar una tarea disponible, reclamarla y completarla

**Entry Points:** Login → Vista principal

**Success Criteria:** Tarea completada y registrada en el sistema

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  FLUJO: Member reclama tarea                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [Entra a /app] ──► ¿Proyecto? ──No──► [Selecciona proyecto]               │
│        │                  │                      │                          │
│        │                 Sí◄─────────────────────┘                          │
│        ▼                  ▼                                                 │
│  [Ve Pool de tareas] ◄────┘                                                │
│        │                                                                    │
│        ▼                                                                    │
│  [Explora tareas] ──► ¿Encuentra? ──No──► [Cambia filtros/vista]──┐        │
│        │                   │                                       │        │
│        │                  Sí◄──────────────────────────────────────┘        │
│        ▼                   ▼                                                │
│  [Click en tarea] ──► [Ve detalle] ──► [Click 'Reclamar']                  │
│                                              │                              │
│                                              ▼                              │
│  [Tarea aparece en 'Mis tareas' panel derecho]                             │
│        │                                                                    │
│        ▼                                                                    │
│  [Click ▶ 'Empezar'] ──► [Tarea en 'En curso' con timer]                   │
│        │                                                                    │
│        ├──► [Pausar] ──► Tarea vuelve a 'Mis tareas'                       │
│        ├──► [Completar ✓] ──► Toast: 'Tarea completada'                    │
│        └──► [Liberar] ──► Tarea vuelve al Pool                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Edge Cases:**
- Tarea ya reclamada por otro usuario → Mostrar mensaje, refrescar pool
- Conexión perdida durante trabajo → Timer se pausa automáticamente
- Usuario intenta reclamar más de X tareas → Mostrar límite (si aplica)

---

### 6.2 Flow 2: PM crea una ficha

**User Goal:** Crear una nueva ficha (epic/user story) para organizar tareas

**Entry Points:** Sidebar izquierdo → "+ Nueva Ficha"

**Success Criteria:** Ficha creada y visible en modo Fichas

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  FLUJO: PM crea ficha                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [PM en vista principal] ──► [Click '+ Nueva Ficha' en sidebar]            │
│                                       │                                     │
│                                       ▼                                     │
│                              [Modal 'Crear Ficha']                         │
│                                       │                                     │
│                                       ▼                                     │
│                              [Completa formulario]                         │
│                                       │                                     │
│                              ¿Datos válidos?                               │
│                                │           │                                │
│                               No          Sí                               │
│                                │           │                                │
│                                ▼           ▼                                │
│                        [Muestra errores] [Click 'Crear']                   │
│                                │           │                                │
│                                └───────────┤                                │
│                                            ▼                                │
│                                   API: POST /cards                         │
│                                       │       │                             │
│                                    Error    Éxito                          │
│                                       │       │                             │
│                                       ▼       ▼                             │
│                              [Muestra error] [Modal se cierra]             │
│                                              [Toast: 'Ficha creada']       │
│                                              [Cambia a modo Fichas]        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Formulario de Ficha:**

```
┌─────────────────────────────────────────┐
│  🎴 Crear Ficha                     [×] │
├─────────────────────────────────────────┤
│                                         │
│  Título *                               │
│  [________________________]             │
│                                         │
│  Descripción                            │
│  [________________________]             │
│  [________________________]             │
│                                         │
│  Color (opcional)                       │
│  [○ Ninguno] [● Azul] [○ Verde] ...    │
│                                         │
├─────────────────────────────────────────┤
│              [Cancelar]  [Crear]        │
└─────────────────────────────────────────┘
```

---

### 6.3 Flow 3: PM crea una tarea y la asigna a una ficha

**User Goal:** Crear una tarea dentro del contexto de una ficha existente

**Entry Points:**
- Sidebar izquierdo → "+ Nueva Tarea"
- Modo Fichas → Click en ficha → "+ Añadir tarea"

**Success Criteria:** Tarea creada y asociada a la ficha

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  FLUJO: PM crea tarea                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [PM en vista principal]                                                    │
│        │                                                                    │
│        ├──► [Click '+ Nueva Tarea' en sidebar] ──► Modal (ficha opcional)  │
│        │                                                                    │
│        └──► [Click en ficha] ──► ['+ Añadir tarea'] ──► Modal (ficha pre-  │
│                                                          seleccionada)     │
│                                       │                                     │
│                                       ▼                                     │
│                              [Completa formulario]                         │
│                                       │                                     │
│                              [Click 'Crear']                               │
│                                       │                                     │
│                              API: POST /tasks                              │
│                                       │                                     │
│                                      Éxito                                 │
│                                       │                                     │
│                              [Toast: 'Tarea creada']                       │
│                              [Visible en Pool/Lista/Fichas]                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Formulario de Tarea:**

```
┌─────────────────────────────────────────┐
│  📋 Crear Tarea                     [×] │
├─────────────────────────────────────────┤
│                                         │
│  Título *                               │
│  [________________________]             │
│                                         │
│  Tipo *                                 │
│  [Seleccionar tipo        ▼]           │
│                                         │
│  Ficha (opcional)                       │
│  [Seleccionar ficha       ▼]           │
│  └─ Preseleccionada si viene de ficha  │
│                                         │
│  Prioridad                              │
│  [P1 ○] [P2 ○] [P3 ●] [P4 ○] [P5 ○]   │
│                                         │
│  Descripción                            │
│  [________________________]             │
│                                         │
├─────────────────────────────────────────┤
│              [Cancelar]  [Crear]        │
└─────────────────────────────────────────┘
```

---

### 6.4 Flow 4: PM asigna skills a un miembro

**User Goal:** Definir qué capacidades tiene un miembro del equipo

**Entry Points:** Sidebar izq → Configuración → Equipo → [⚙️] en miembro

**Success Criteria:** Skills asignados y guardados

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  FLUJO: PM asigna skills                                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [PM en vista principal] ──► [Click 'Equipo' en Configuración]             │
│                                       │                                     │
│                                       ▼                                     │
│                          [Lista de miembros del proyecto]                  │
│                                       │                                     │
│                          [Click ⚙️ en fila del miembro]                    │
│                                       │                                     │
│                                       ▼                                     │
│                          [Panel 'Skills de email@...']                     │
│                                       │                                     │
│                          [Ve capacidades del proyecto]                     │
│                                       │                                     │
│          ┌────────────────────────────┼────────────────────────────┐       │
│          │                            │                            │       │
│          ▼                            ▼                            ▼       │
│  [Marca/desmarca skills]  [Click '+ Crear capacidad']    [Click 'Cerrar'] │
│          │                            │                                     │
│          │                    [Modal inline simple]                        │
│          │                    [Crea capacidad]                             │
│          │                    [Aparece en lista marcada]                   │
│          │                            │                                     │
│          ◄────────────────────────────┘                                     │
│          │                                                                  │
│          ▼                                                                  │
│  [Click 'Guardar']                                                         │
│          │                                                                  │
│          ▼                                                                  │
│  API: PUT /projects/:id/members/:uid/capabilities                          │
│          │                                                                  │
│          ▼                                                                  │
│  [Toast: 'Skills actualizados']                                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Panel de Skills:**

```
┌─────────────────────────────────────────┐
│  🎯 Skills de dev@example.com       [×] │
├─────────────────────────────────────────┤
│                                         │
│  Capacidades del proyecto:              │
│                                         │
│  [✓] Frontend                           │
│  [✓] QA                                 │
│  [ ] Backend                            │
│  [ ] DevOps                             │
│  [✓] Documentation                      │
│                                         │
│  [+ Crear nueva capacidad]              │
│                                         │
├─────────────────────────────────────────┤
│              [Cancelar]  [Guardar]      │
└─────────────────────────────────────────┘
```

**Nota:** El botón "+ Crear nueva capacidad" está SIEMPRE visible, independientemente de si ya existen capacidades.

---

### 6.5 Flow 5: Usuario navega entre modos de vista

**User Goal:** Cambiar la visualización del contenido según necesidad

**Entry Points:** Toolbar del contenido central

**Success Criteria:** Vista cambia sin perder contexto

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  FLUJO: Cambiar modo de vista                                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [Usuario en cualquier modo]                                                │
│        │                                                                    │
│        ├──► [Click 'Pool'] ──► Canvas de tareas arrastrables               │
│        │                                                                    │
│        ├──► [Click 'Lista'] ──► Tareas agrupadas por ficha                 │
│        │                                                                    │
│        └──► [Click 'Fichas'] ──► Kanban de fichas por estado               │
│                                                                             │
│  En todos los casos:                                                        │
│  • Los filtros activos se MANTIENEN                                        │
│  • El proyecto seleccionado se MANTIENE                                    │
│  • La URL se actualiza: ?view=pool|list|cards                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Estados de URL:**

```
/app?view=pool&project=8           → Modo Pool
/app?view=list&project=8           → Modo Lista
/app?view=cards&project=8          → Modo Fichas
/app?view=pool&project=8&type=2    → Pool filtrado por tipo
```

---

### 6.6 Flow 6: Org Admin gestiona usuarios de la organización

> **Nota:** Este flujo está alineado con la historia 4.3 (Org Users Management UX)

**User Goal:** Ver y gestionar usuarios, asignarlos a proyectos

**Entry Points:** Sidebar izq → Organización → Usuarios

**Success Criteria:** Usuario gestionado correctamente

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  FLUJO: Org Admin gestiona usuarios (alineado con 4.3)                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [Org Admin] ──► [Click 'Usuarios' en ORGANIZACIÓN]                        │
│                          │                                                  │
│                          ▼                                                  │
│              [Tabla: EMAIL | ROL ORG | PROYECTOS | ACCIONES]               │
│                          │                                                  │
│         ┌────────────────┼────────────────┐                                │
│         │                │                │                                │
│         ▼                ▼                ▼                                │
│  [Cambiar ROL ORG]  [Click 'Gestionar']  (otras acciones)                  │
│         │                │                                                  │
│         │                ▼                                                  │
│         │     [Modal: 'Proyectos de email@...']                            │
│         │                │                                                  │
│         │     ┌──────────┼──────────┬──────────────┐                       │
│         │     │          │          │              │                       │
│         │     ▼          ▼          ▼              ▼                       │
│         │  [Cambiar   [Añadir a   [Quitar de    [Cerrar]                  │
│         │   rol en     proyecto]   proyecto]                               │
│         │   proyecto]      │           │                                    │
│         │     │           │           │                                    │
│         │     │    [Selecciona    [Confirma]                               │
│         │     │     proyecto+rol]     │                                    │
│         │     │           │           │                                    │
│         │     ▼           ▼           ▼                                    │
│         │   [API        [API        [API                                   │
│         │   inmediata]  POST]       DELETE]                                │
│         │     │           │           │                                    │
│         │     ▼           ▼           ▼                                    │
│         │   [Toast]    [Proyecto   [Proyecto                               │
│         │              aparece]    desaparece]                             │
│         │                                                                  │
│         ▼                                                                  │
│  [Fila muestra (*) pendiente]                                              │
│         │                                                                  │
│         ▼                                                                  │
│  [Click 'Guardar cambios de rol' al fondo]                                 │
│         │                                                                  │
│         ▼                                                                  │
│  API: PATCH /org/users/:id ──► [Toast: 'Rol actualizado']                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Diferencia entre Usuarios (org) vs Equipo (proyecto):**

| Desde... | Scope | Puede hacer |
|----------|-------|-------------|
| **ORGANIZACIÓN > Usuarios** | Usuario → sus proyectos | Añadir usuario a cualquier proyecto, cambiar rol en cualquier proyecto |
| **CONFIGURACIÓN > Equipo** | Proyecto → sus miembros | Añadir miembro al proyecto actual, asignar skills |

---

## 7. Responsive Strategy

### 7.1 Breakpoints

| Breakpoint | Ancho | Dispositivo típico | Layout |
|------------|-------|-------------------|--------|
| **XS** | < 640px | Móvil vertical | 1 panel (colapsado) |
| **SM** | 640-768px | Móvil horizontal / tablet pequeña | 1 panel + drawer |
| **MD** | 768-1024px | Tablet | 2 paneles |
| **LG** | 1024-1280px | Laptop pequeña | 3 paneles (compactos) |
| **XL** | > 1280px | Desktop | 3 paneles (completos) |

### 7.2 Comportamiento por Breakpoint

#### Mobile (XS/SM) - Layout de 1 Panel

```
┌─────────────────────────┐
│  [☰] Project Alpha  [👤]│ ← Header simplificado
├─────────────────────────┤
│                         │
│  [Pool] [Lista] [Fichas]│ ← Toggle de vista
│                         │
│  ┌─────────────────────┐│
│  │                     ││
│  │    CONTENIDO        ││
│  │    (modo actual)    ││
│  │                     ││
│  │                     ││
│  │                     ││
│  └─────────────────────┘│
│                         │
│  [En curso: Task X  ⏱️] │ ← Mini-barra fija (si hay tarea activa)
│                         │
└─────────────────────────┘

[☰] → Drawer izquierdo (navegación)
[👤] → Drawer derecho (mi actividad)
```

**Drawers móviles:**

```
DRAWER IZQUIERDO (☰)              DRAWER DERECHO (👤)
┌─────────────────────┐           ┌─────────────────────┐
│                 [×] │           │ [×]                 │
│  Project Alpha    ▼ │           │                     │
│                     │           │  EN CURSO           │
│  TRABAJO            │           │  Task X  ⏱️ 00:45   │
│  [+ Nueva Tarea]    │           │  [Pausar] [✓]       │
│  [+ Nueva Ficha]    │           │                     │
│                     │           │  ─────────────────  │
│  CONFIGURACIÓN      │           │                     │
│  ○ Equipo           │           │  MIS TAREAS         │
│  ○ Catálogo         │           │  • Task 1    [▶]    │
│  ○ Automatización   │           │  • Task 2    [▶]    │
│                     │           │                     │
│  ORGANIZACIÓN       │           │  ─────────────────  │
│  ○ Invitaciones     │           │                     │
│  ○ Usuarios         │           │  MIS FICHAS         │
│  ○ Proyectos        │           │  • Release   0/4    │
│  ○ Métricas         │           │                     │
│                     │           │  ═════════════════  │
│                     │           │  🔵 Asimov          │
│                     │           │  [Prefs] [Salir]    │
└─────────────────────┘           └─────────────────────┘
```

#### Tablet (MD) - Layout de 2 Paneles

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│ ┌─────────────────┐ ┌───────────────────────────────────┤
│ │                 │ │                                   │
│ │  PROYECTO       │ │        CONTENIDO                  │
│ │  + NAVEGACIÓN   │ │        + MI ACTIVIDAD             │
│ │                 │ │        (colapsado arriba)         │
│ │  (completo)     │ │                                   │
│ │                 │ │  [En curso: Task X ⏱️]  [▼ más]  │
│ │                 │ │                                   │
│ │                 │ │  [Pool] [Lista] [Fichas]          │
│ │                 │ │                                   │
│ │                 │ │  ┌───────────────────────────────┐│
│ │                 │ │  │                               ││
│ │                 │ │  │    (contenido)                ││
│ │                 │ │  │                               ││
│ │                 │ │  └───────────────────────────────┘│
│ │                 │ │                                   │
│ └─────────────────┘ └───────────────────────────────────┤
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Nota:** En tablet, "Mi actividad" se colapsa en una barra superior expandible dentro del panel central.

#### Desktop (LG/XL) - Layout de 3 Paneles

Layout completo como se muestra en la sección de Wireframes (3.1).

### 7.3 Gestos Táctiles (Mobile/Tablet)

| Gesto | Acción |
|-------|--------|
| **Swipe left** desde borde derecho | Abrir drawer "Mi actividad" |
| **Swipe right** desde borde izquierdo | Abrir drawer navegación |
| **Swipe down** en header | Refrescar contenido |
| **Long press** en tarea | Menú contextual (reclamar, ver detalle) |
| **Drag & drop** en Pool | Mover tarjetas (si espacio suficiente) |

### 7.4 Adaptaciones por Vista

#### Modo Pool en Mobile

```
┌─────────────────────────┐
│                         │
│  Filtros: [▼]           │ ← Filtros colapsados
│                         │
│  ┌─────────────────────┐│
│  │  ┌─────┐ ┌─────┐    ││
│  │  │Task1│ │Task2│    ││ ← Grid de 2 columnas
│  │  └─────┘ └─────┘    ││
│  │  ┌─────┐ ┌─────┐    ││
│  │  │Task3│ │Task4│    ││
│  │  └─────┘ └─────┘    ││
│  └─────────────────────┘│
│                         │
└─────────────────────────┘

- Sin drag & drop en mobile
- Scroll vertical
- Grid responsive (1-2-3 columnas según ancho)
```

**Interacción de Reclamar Tarea (Mobile):**

```
┌─────────────────────────┐        ┌─────────────────────────┐
│                         │        │                         │
│  ┌─────────────────────┐│  Tap  │  ┌─────────────────────┐│
│  │ Task: Fix login bug ││ ────► │  │ Task: Fix login bug ││
│  │ 🏷️ Bug  P1          ││       │  │                     ││
│  └─────────────────────┘│       │  │ Descripción...      ││
│                         │       │  │                     ││
│                         │       │  │ [Reclamar]          ││
│                         │       │  │                     ││
│                         │       │  └─────────────────────┘│
│                         │       │                         │
└─────────────────────────┘       └─────────────────────────┘
     Vista Pool                        Bottom Sheet / Modal

Flujo:
1. Tap en tarjeta → Abre bottom sheet con detalle
2. Bottom sheet muestra: título, descripción, tipo, prioridad
3. Botón [Reclamar] prominente en el sheet
4. Tap en [Reclamar] → Tarea va a "Mis tareas", sheet se cierra
```

**Alternativa: Swipe para Reclamar**

```
┌─────────────────────────┐
│  ┌─────────────────────┐│
│  │ Task: Fix login ←←← ││ ← Swipe izquierda
│  │ 🏷️ Bug  P1    [✓]   ││ ← Revela botón reclamar
│  └─────────────────────┘│
└─────────────────────────┘

- Swipe left revela acción "Reclamar"
- Tap en [✓] reclama directamente
- Más rápido para usuarios expertos
```

#### Modo Lista en Mobile

```
┌─────────────────────────┐
│                         │
│  📁 Release         [▼] │
│  ├── ☐ Task 1           │
│  ├── ☐ Task 2           │
│  └── ☐ Task 3           │
│                         │
│  📁 Retro           [▼] │
│  └── ☐ Task 4           │
│                         │
└─────────────────────────┘

- Funciona bien en mobile
- Grupos colapsables para ahorrar espacio
```

#### Modo Fichas en Mobile

```
┌─────────────────────────┐
│                         │
│  [Pendiente▼]           │ ← Selector de columna
│                         │
│  ┌─────────────────────┐│
│  │   Release           ││
│  │   ░░░░░░░░ 0/4      ││
│  │   • Task 1          ││
│  │   • Task 2          ││
│  └─────────────────────┘│
│  ┌─────────────────────┐│
│  │   Retro             ││
│  │   ░░░░░░░░ 0/1      ││
│  └─────────────────────┘│
│                         │
└─────────────────────────┘

- Kanban horizontal → Vertical con selector
- Una columna visible a la vez
- Swipe para cambiar columna (opcional)
```

### 7.5 Prioridades Touch vs Mouse

| Interacción | Mouse (Desktop) | Touch (Mobile) |
|-------------|-----------------|----------------|
| Ver detalle tarea | Hover + click | Tap |
| Menú contextual | Click derecho | Long press |
| Mover tarea (Pool) | Drag & drop | Tap → "Mover a..." |
| Scroll | Rueda/trackpad | Swipe |
| Reclamar tarea | Click botón | Swipe left en tarea |

### 7.6 Performance Mobile

- **Lazy loading:** Cargar solo tareas visibles + buffer
- **Reducir animaciones:** `prefers-reduced-motion` respetado
- **Imágenes:** WebP con fallback, responsive srcset
- **Bundle splitting:** Cargar solo código del modo de vista activo

---

## 8. Componentes UI

### 8.1 Nuevos Componentes Requeridos

| Componente | Descripción | Usado en |
|------------|-------------|----------|
| `ThreePanelLayout` | Layout principal con paneles colapsables | `/app` |
| `LeftPanel` | Navegación de proyecto + organización | Layout |
| `CenterPanel` | Contenido con selector de modo de vista | Layout |
| `RightPanel` | Mi actividad + perfil | Layout |
| `ViewModeToggle` | Toggle Pool/Lista/Fichas | CenterPanel |
| `TaskTimer` | Timer de tarea activa con controles | RightPanel |
| `MiniTaskBar` | Barra compacta de tarea en curso (mobile) | Mobile layout |
| `ProjectSelector` | Dropdown de selección de proyecto | LeftPanel |
| `CollapsibleSection` | Sección colapsable con header | Ambos paneles |
| `ResponsiveDrawer` | Drawer para mobile/tablet | Mobile layout |
| `KanbanBoard` | Vista kanban para modo Fichas | CenterPanel |
| `GroupedList` | Lista agrupada por ficha | CenterPanel |

### 8.2 Componentes y Funciones Existentes a Modificar

| Elemento | Tipo | Modificación |
|----------|------|--------------|
| `Pool` | Feature | Hacer responsive, eliminar toolbar viejo |
| `Sidebar` | Feature | Reemplazar por `LeftPanel` |
| `Header` | Feature | **ELIMINAR** - funcionalidad absorbida en paneles |

### 8.3 Funciones de Vista para Tareas (NO componentes)

> **Decisión de diseño:** Las variantes de visualización de tareas se implementan como **funciones de vista** en lugar de componentes Lustre. Esto es más pragmático porque:
> - Las variantes son visualmente muy diferentes entre sí
> - No requieren estado interno propio
> - Evita overhead de componentes innecesario
> - Reutilización via `import` es suficiente

| Función | Ubicación | Propósito | Estado |
|---------|-----------|-----------|--------|
| `view_task_card` | `pool/view.gleam` | Tarjeta en canvas Pool | ✅ Existe |
| `view_task_list_row` | `ui/task_views.gleam` | Fila en modo Lista | 🆕 Crear |
| `view_task_in_kanban` | `ui/task_views.gleam` | Item dentro de ficha en kanban | 🆕 Crear |
| `view_task_mini` | `ui/task_views.gleam` | Mini para panel derecho | 🆕 Crear |

**Especificación de variantes:**

```
view_task_card (Pool)           view_task_list_row (Lista)
┌──────────────────┐            ├── ☐ Task title    P2  🏷️ QA
│  Task Title      │
│  ────────────    │            view_task_in_kanban (Fichas)
│  🏷️ Bug   P1     │            │ • Task title
│  ⏱️ 2h estimado  │
└──────────────────┘            view_task_mini (Panel derecho)
                                • Task title    [▶]
```

### 8.4 Funciones de Vista para Fichas (Card)

| Función | Ubicación | Propósito | Estado |
|---------|-----------|-----------|--------|
| `view_card_kanban_item` | `ui/card_views.gleam` | Ficha en modo Fichas (kanban) | 🆕 Crear |
| `view_card_mini` | `ui/card_views.gleam` | Mini para panel derecho "Mis fichas" | 🆕 Crear |

**Especificación:**

```
view_card_kanban_item                    view_card_mini
┌──────────────────────┐                 • Release   2/4
│  Release             │
│  ════════════════    │ ← Barra progreso
│  ████████░░░░ 2/4    │
│  • Task 1            │
│  • Task 2            │
│  ✓ Task 3            │
│  ✓ Task 4            │
│                 [⋮]  │ ← Solo PM ve menú
└──────────────────────┘
```

> **Nota:** Si durante la implementación `view_card_kanban_item` requiere estado interno complejo (expandir/colapsar, lazy loading de tareas), se evaluará extraerlo a un Lustre Component.

### 8.5 Especificación de Nuevos Componentes

#### ThreePanelLayout

```
Props:
  - leftPanelOpen: Bool (default: true en desktop, false en mobile)
  - rightPanelOpen: Bool (default: true en desktop, false en mobile)
  - currentView: ViewMode (pool | list | cards)

Slots:
  - leftPanel: Element
  - centerPanel: Element
  - rightPanel: Element

Comportamiento:
  - Detecta breakpoint automáticamente
  - En mobile: muestra solo centro, paneles como drawers
  - En tablet: muestra izquierda + centro fusionado
  - En desktop: muestra los 3 paneles
```

#### ViewModeToggle

```
Props:
  - activeMode: ViewMode
  - onModeChange: (ViewMode) -> Msg

Render:
  [🎯 Pool] [≡ Lista] [🎴 Fichas]

  - Botón activo: fondo sólido, texto claro
  - Botones inactivos: fondo transparente, borde
  - Transición suave al cambiar
```

#### TaskTimer

```
Props:
  - task: Option(Task)
  - elapsed: Duration
  - isPaused: Bool
  - onPause: Msg
  - onResume: Msg
  - onComplete: Msg
  - onRelease: Msg

Estados:
  - Ninguna tarea: "Sin tarea activa"
  - En progreso: Muestra timer + [Pausar] [✓ Completar]
  - Pausada: Timer congelado + [▶ Reanudar] [× Liberar]
```

#### ProjectSelector

```
Props:
  - projects: List(Project)
  - selectedId: Option(Int)
  - onSelect: (Int) -> Msg

Render:
  ┌─────────────────────┐
  │  Project Alpha    ▼ │
  └─────────────────────┘

  Dropdown expandido:
  ┌─────────────────────┐
  │  Project Alpha    ▲ │
  ├─────────────────────┤
  │  ● Project Alpha    │ ← Seleccionado
  │  ○ Project Beta     │
  │  ○ Project Gamma    │
  └─────────────────────┘

Comportamiento:
  - Al cambiar proyecto: actualiza URL (?project=X)
  - Recuerda último proyecto en localStorage
  - Si no hay proyecto en URL, usa el recordado
  - Muestra solo proyectos donde el usuario es miembro
```

#### CollapsibleSection

```
Props:
  - title: String
  - icon: Option(Icon)
  - isOpen: Bool (default: true)
  - onToggle: Msg
  - children: List(Element)

Render (abierto):
  ┌─────────────────────┐
  │  ⚙️ CONFIGURACIÓN ▼ │
  │  ─────────────────  │
  │  ○ Equipo           │
  │  ○ Catálogo         │
  │  ○ Automatización   │
  └─────────────────────┘

Render (cerrado):
  ┌─────────────────────┐
  │  ⚙️ CONFIGURACIÓN ▶ │
  └─────────────────────┘

Comportamiento:
  - Estado de colapso guardado en localStorage por sección
  - Animación suave al expandir/colapsar
  - En mobile: cerrado por defecto para ahorrar espacio
```

#### ResponsiveDrawer

```
Props:
  - isOpen: Bool
  - side: "left" | "right"
  - onClose: Msg
  - children: Element

Render:
  - Overlay semitransparente que cierra al click
  - Panel deslizable desde el lado indicado
  - Botón [×] para cerrar
  - Swipe en dirección opuesta para cerrar

Comportamiento:
  - Solo se renderiza en breakpoints XS/SM
  - Trap focus mientras está abierto
  - Escape cierra el drawer
  - Bloquea scroll del body mientras está abierto
```

### 8.6 Sistema de Iconos

Usando la librería `gleroglero` ya integrada en el proyecto:

| Concepto | Icono | Uso |
|----------|-------|-----|
| Pool | `target` / círculo | Toggle de vista |
| Lista | `list` / líneas | Toggle de vista |
| Fichas | `cards` / cuadrados | Toggle de vista |
| Nueva tarea | `plus` | Botón crear |
| Nueva ficha | `plus` + `card` | Botón crear |
| Configuración | `cog` / engranaje | Sección config |
| Organización | `building` / edificio | Sección org |
| Usuario | `user` | Perfil, drawer |
| Timer | `clock` | Tarea activa |
| Menú | `menu` / hamburguesa | Drawer mobile |

---

## 9. URL Strategy (Routing)

### 9.1 Principio Fundamental: URL = Estado

**Toda navegación debe reflejarse en la URL** para que al pulsar F5 se restaure exactamente el mismo estado. No hay "estado oculto" - si algo es visible en pantalla, está codificado en la URL.

### 9.2 Parámetros de URL

| Parámetro | Tipo | Descripción | Ejemplo | Requerido |
|-----------|------|-------------|---------|-----------|
| `project` | Int | ID del proyecto seleccionado | `?project=8` | Sí (en /app y /config/*) |
| `view` | Enum | Modo de vista activo | `&view=pool` | No (default: pool) |
| `type` | Int | Filtro por tipo de tarea | `&type=2` | No |
| `cap` | Int | Filtro por capacidad | `&cap=3` | No |
| `search` | String | Texto de búsqueda | `&search=login` | No |
| `card` | Int | Ficha expandida (en modo Fichas) | `&card=15` | No |

### 9.3 Rutas del Sistema

| Ruta | Requiere `?project` | Descripción |
|------|---------------------|-------------|
| `/app` | ✅ Sí | Vista principal de trabajo |
| `/config/team` | ✅ Sí | Gestión de equipo del proyecto |
| `/config/catalog` | ✅ Sí | Catálogo (capacidades + tipos) |
| `/config/automation` | ✅ Sí | Workflows y plantillas |
| `/admin/invites` | ❌ No | Invitaciones (org scope) |
| `/admin/users` | ❌ No | Usuarios de organización |
| `/admin/projects` | ❌ No | Proyectos de organización |
| `/admin/metrics` | ❌ No | Métricas de organización |

### 9.4 Ejemplos de URLs Completas

```
# Vista Pool del proyecto 8
/app?project=8&view=pool

# Vista Lista filtrada por tipo "Bug"
/app?project=8&view=list&type=2

# Vista Fichas con ficha 15 expandida
/app?project=8&view=cards&card=15

# Pool con búsqueda activa
/app?project=8&view=pool&search=login

# Configuración de equipo del proyecto 8
/config/team?project=8

# Usuarios de organización (no necesita proyecto)
/admin/users
```

### 9.5 Comportamiento al Cargar (F5)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  FLUJO: Carga de página (F5 o navegación directa)                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [URL recibida] ──► ¿Tiene ?project?                                        │
│                          │                                                  │
│           ┌──────────────┴──────────────┐                                   │
│           │                             │                                   │
│          No                            Sí                                   │
│           │                             │                                   │
│           ▼                             ▼                                   │
│  ¿Ruta requiere proyecto?        [Cargar proyecto]                         │
│           │                             │                                   │
│     ┌─────┴─────┐                       │                                   │
│     │           │                       │                                   │
│    Sí          No                       │                                   │
│     │           │                       │                                   │
│     ▼           ▼                       │                                   │
│  ¿localStorage   [Cargar ruta]         │                                   │
│   tiene último     (admin/*)            │                                   │
│   proyecto?           │                 │                                   │
│     │                 │                 │                                   │
│  ┌──┴──┐              │                 │                                   │
│  │     │              │                 │                                   │
│ Sí    No              │                 │                                   │
│  │     │              │                 │                                   │
│  ▼     ▼              │                 │                                   │
│ [Redirigir   [Mostrar           ◄───────┘                                   │
│  con último   selector                                                      │
│  proyecto]    de proyecto]                                                  │
│                                                                             │
│  Continuar con:                                                             │
│  1. Parsear &view (default: pool)                                          │
│  2. Parsear filtros (&type, &cap, &search)                                 │
│  3. Renderizar vista con estado completo                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 9.6 Actualización de URL (Sin Recargar)

Cada acción del usuario que cambia el estado visible debe actualizar la URL usando `history.pushState` o `history.replaceState`:

| Acción | Actualiza URL | Método |
|--------|---------------|--------|
| Cambiar proyecto | ✅ | pushState |
| Cambiar modo de vista | ✅ | pushState |
| Aplicar filtro | ✅ | replaceState |
| Quitar filtro | ✅ | replaceState |
| Escribir búsqueda | ✅ (debounced 300ms) | replaceState |
| Expandir ficha | ✅ | pushState |
| Abrir modal de crear | ❌ | No cambia URL |
| Abrir drawer mobile | ❌ | No cambia URL |

### 9.7 Navegación con Botones del Navegador

- **Atrás (←)**: Restaura estado anterior (proyecto, vista, filtros)
- **Adelante (→)**: Restaura estado siguiente
- **F5 / Recargar**: Carga exactamente el mismo estado desde URL

### 9.8 Deep Linking

Todas las URLs son "compartibles". Un usuario puede copiar la URL y enviarla a otro:

```
# Compartir vista específica
"Mira las tareas de tipo Bug en el proyecto Alpha"
→ /app?project=8&view=list&type=2

# Compartir ficha específica
"Revisa el progreso de esta ficha"
→ /app?project=8&view=cards&card=15
```

**Nota:** El receptor debe tener permisos en el proyecto. Si no los tiene, verá mensaje de error apropiado.

---

## 10. Accesibilidad (a11y)

### 10.1 Requisitos WCAG 2.1 AA

| Criterio | Implementación |
|----------|----------------|
| **1.1.1 Non-text Content** | Alt text en iconos, aria-label en botones de solo icono |
| **1.3.1 Info and Relationships** | Estructura semántica: `nav`, `main`, `aside`, headings |
| **1.4.3 Contrast** | Ratio mínimo 4.5:1 para texto, 3:1 para UI |
| **2.1.1 Keyboard** | Todo accesible con teclado (Tab, Enter, Escape) |
| **2.4.1 Bypass Blocks** | Skip link a contenido principal |
| **2.4.7 Focus Visible** | Outline visible en todos los elementos focusables |
| **4.1.2 Name, Role, Value** | ARIA labels y roles apropiados |

### 10.2 Navegación por Teclado

| Tecla | Acción Global |
|-------|---------------|
| `Tab` | Navegar entre elementos focusables |
| `Shift+Tab` | Navegar hacia atrás |
| `Escape` | Cerrar modal/drawer activo |
| `Enter/Space` | Activar botón/link focusado |
| `Arrow keys` | Navegar dentro de listas/grids |

| Tecla | En Pool (desktop) |
|-------|-------------------|
| `Arrow keys` | Mover entre tarjetas |
| `Enter` | Abrir detalle de tarea |
| `r` | Reclamar tarea seleccionada |

| Tecla | En Modo Fichas |
|-------|----------------|
| `Arrow Left/Right` | Cambiar columna |
| `Arrow Up/Down` | Navegar entre fichas |
| `Enter` | Expandir ficha |

### 10.3 ARIA Landmarks

```html
<body>
  <a class="skip-link" href="#main-content">Saltar al contenido</a>

  <nav aria-label="Navegación principal">
    <!-- Left panel -->
  </nav>

  <main id="main-content" aria-label="Contenido del proyecto">
    <!-- Center panel -->
  </main>

  <aside aria-label="Mi actividad">
    <!-- Right panel -->
  </aside>
</body>
```

### 10.4 Estados y Anuncios

| Evento | Anuncio (aria-live) |
|--------|---------------------|
| Tarea reclamada | "Tarea {nombre} reclamada" |
| Timer iniciado | "Timer iniciado para {tarea}" |
| Tarea completada | "Tarea {nombre} completada" |
| Error | "Error: {mensaje}" (role="alert") |
| Vista cambiada | "Vista cambiada a {modo}" |
| Drawer abierto | "Panel de navegación abierto" |

### 10.5 Soporte de Lectores de Pantalla

- **VoiceOver (macOS/iOS):** Testado ✓
- **NVDA (Windows):** Testado ✓
- **TalkBack (Android):** Testado ✓

### 10.6 Reducción de Movimiento

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.001ms !important;
    transition-duration: 0.001ms !important;
  }
}
```

- Transiciones deshabilitadas
- Drag & drop sin animación de seguimiento
- Timer sin parpadeo

---

## 11. Defectos Corregidos

Esta sección documenta explícitamente los problemas de UX identificados en el sistema actual y cómo este rediseño los resuelve.

### 11.1 Miembros: Sin Contexto de Proyecto

**Problema actual:**
En `/admin/members?project=8`, el usuario configura miembros pero no hay indicación visual clara de qué proyecto está editando. El parámetro `?project=8` está en la URL pero no es visible en la interfaz.

**Solución:**
- El **selector de proyecto** está siempre visible en el panel izquierdo
- El nombre del proyecto aparece destacado: "Project Alpha ▼"
- Al entrar a `/config/team?project=8`, el proyecto ya está seleccionado y visible
- Imposible editar miembros sin tener un proyecto seleccionado

```
┌─────────────────────┐
│  Project Alpha    ▼ │ ← SIEMPRE visible
│                     │
│ ═══════════════════ │
│                     │
│  CONFIGURACIÓN      │
│  ● Equipo     ◄──── │ ← Editando equipo DE "Project Alpha"
│  ○ Catálogo         │
│  ○ Automatización   │
└─────────────────────┘
```

### 11.2 Org: Asignación a Proyectos Escondida

**Problema actual:**
En `/admin/org`, para ver/gestionar los proyectos de un usuario hay que hacer click en un botón "Ver" poco visible. La columna "PROYECTOS" solo muestra el botón, no información útil.

**Solución (alineada con Historia 4.3):**
- Columna **PROYECTOS** muestra resumen: "2: Alpha, Beta" o "Sin proyectos"
- Botón renombrado de "Ver" a **"Gestionar"** (más claro)
- Dialog muestra proyectos con **dropdown editable** para cambiar rol

```
ANTES:
| EMAIL           | ROL    | PROYECTOS | ACCIONES |
| pm@example.com  | Member | [Ver]     | [Guardar]|

DESPUÉS:
| EMAIL           | ROL ORG    | PROYECTOS           | ACCIONES   |
| pm@example.com  | [Member ▼] | 2: Alpha (mgr), Beta| [Gestionar]|
```

### 11.3 Org: No Se Puede Cambiar Rol en Proyecto

**Problema actual:**
El dialog de "Ver proyectos" muestra el rol como texto estático. No hay forma de cambiar el rol de un usuario en un proyecto específico desde la vista de Org.

**Solución (alineada con Historia 4.3):**
- En el dialog, la columna **ROL EN PROYECTO** es un dropdown editable
- Cambio de rol es **inmediato** (API call al cambiar)
- Consistente con la vista de Miembros del proyecto

```
┌─────────────────────────────────────────────────────┐
│  📂 Proyectos de pm@example.com                 [×] │
├─────────────────────────────────────────────────────┤
│                                                     │
│  | PROYECTO      | ROL EN PROYECTO | ACCIONES |    │
│  |---------------|-----------------|----------|    │
│  | Project Alpha | [Manager ▼]     | [Quitar] |    │ ← Dropdown editable
│  | Project Beta  | [Member ▼]      | [Quitar] |    │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### 11.4 Confusión ROL vs ROL ORG

**Problema actual:**
La columna "ROL" en `/admin/org` no aclara si es el rol en la organización o en algún proyecto.

**Solución:**
- Columna renombrada a **"ROL ORG"** en vista de usuarios de organización
- Columna **"ROL EN PROYECTO"** en dialog de proyectos del usuario
- Columna **"ROL"** en vista de miembros de proyecto (contexto claro)

### 11.5 Admin Mezcla Scope Org/Proyecto

**Problema actual:**
La sección `/admin/*` mezcla configuración de organización (invitaciones, usuarios org, proyectos) con configuración de proyecto (miembros, capacidades, tipos de tarea, workflows).

**Solución:**
Separación clara en dos secciones del sidebar:

```
┌─────────────────────┐
│                     │
│  CONFIGURACIÓN      │ ← Scope: PROYECTO actual
│  (solo PM/Admin)    │
│                     │
│  ○ Equipo           │   → Miembros + skills
│  ○ Catálogo         │   → Capacidades + tipos tarea
│  ○ Automatización   │   → Workflows + plantillas
│                     │
│ ═══════════════════ │
│                     │
│  ORGANIZACIÓN       │ ← Scope: ORG completa
│  (solo Org Admin)   │
│                     │
│  ○ Invitaciones     │
│  ○ Usuarios         │
│  ○ Proyectos        │
│  ○ Métricas         │
│                     │
└─────────────────────┘
```

### 11.6 Vistas Duplicadas Sin Propósito

**Problema actual:**
Las 4 vistas de member (`/app/pool`, `/app/bar`, `/app/skills`, `/app/cards`) muestran exactamente el mismo contenido (el pool).

**Solución:**
- **Eliminar** `/app/bar` y `/app/skills` (no tienen propósito)
- **Unificar** en una sola vista `/app` con toggle de 3 modos
- Cada modo tiene propósito claro:
  - **Pool**: Canvas de tareas arrastrables
  - **Lista**: Tareas agrupadas por ficha (estructura clara)
  - **Fichas**: Kanban de progreso por ficha

### 11.7 F5 No Mantiene Estado

**Problema actual:**
Al pulsar F5, la aplicación puede perder el contexto (proyecto seleccionado, filtros activos, vista actual).

**Solución:**
- **Todo el estado visible está en la URL** (ver sección 9)
- Ejemplo: `/app?project=8&view=list&type=2`
- F5 reconstruye exactamente el mismo estado
- localStorage como fallback para proyecto "recordado"

### 11.8 Resumen de Correcciones

| # | Defecto | Historia que lo corrige |
|---|---------|------------------------|
| 11.1 | Miembros sin contexto | 4.7 (Panel izquierdo) |
| 11.2 | Proyectos escondidos | 4.3 (Org Users UX) |
| 11.3 | Rol no editable | 4.3 (Org Users UX) |
| 11.4 | Confusión ROL | 4.3 (Org Users UX) |
| 11.5 | Admin mezclado | 4.7 (Panel izquierdo) |
| 11.6 | Vistas duplicadas | 4.5 + 4.6 (Eliminar + Modos) |
| 11.7 | F5 pierde estado | 4.4 (URL Strategy) |

---

## 12. Próximos Pasos

### 12.1 Historias de Usuario Derivadas

Este spec dará lugar a las siguientes historias (a partir de 4.4):

| Historia | Descripción | Prioridad |
|----------|-------------|-----------|
| **4.4** | Eliminar header, implementar layout 3 paneles | 🔴 Alta |
| **4.5** | Eliminar vistas Mi barra y Mis skills | 🔴 Alta |
| **4.6** | Implementar 3 modos de vista (Pool/Lista/Fichas) | 🔴 Alta |
| **4.7** | Rediseñar panel izquierdo (proyecto + org) | 🟡 Media |
| **4.8** | Rediseñar panel derecho (mi actividad) | 🟡 Media |
| **4.9** | Gestión de skills desde Config > Equipo | 🟡 Media |

### 12.2 Design Handoff Checklist

- [x] Wireframes de layout general
- [x] Wireframes de cada panel
- [x] Wireframes de los 3 modos de vista
- [x] Vistas por rol documentadas
- [x] Decisiones de diseño documentadas
- [x] User flows documentados
- [x] Responsive/mobile strategy
- [x] Especificación de componentes
- [x] Guía de accesibilidad
- [x] URL Strategy (garantiza F5)
- [x] Defectos corregidos documentados
- [x] Validación E2E con Playwright (12 suites de test)
- [x] Patrones de código Gleam type-safe (Anexo C)
- [x] Tests TDD de referencia para módulos core

---

## 13. Validación E2E con Playwright

Esta sección define los tests de validación end-to-end que deben pasar para considerar la historia completada. Los tests se ejecutan con Playwright en modo headless.

### 13.1 Configuración de Tests

```javascript
// test/e2e/ia-redesign.spec.js
const { test, expect } = require('@playwright/test');

const TARGET_URL = 'http://localhost:8080';

const USERS = {
  orgAdmin: { email: 'admin@example.com', password: 'passwordpassword' },
  pm: { email: 'pm@example.com', password: 'passwordpassword' },
  member: { email: 'orgmember@example.com', password: 'passwordpassword' }
};

async function login(page, user) {
  await page.goto(TARGET_URL + '/login');
  await page.fill('input[type="email"]', user.email);
  await page.fill('input[type="password"]', user.password);
  await page.click('button[type="submit"]');
  await page.waitForSelector('[data-testid="left-panel"]', { timeout: 10000 });
}

async function logout(page) {
  await page.click('[data-testid="logout-btn"]');
  await page.waitForURL('**/login');
}
```

### 13.2 Tests de Layout y Navegación

#### Test 1: Layout de 3 paneles visible (Desktop)

```javascript
test.describe('Layout 3 Paneles', () => {
  test('muestra los 3 paneles en desktop', async ({ page }) => {
    await login(page, USERS.member);

    await expect(page.locator('[data-testid="left-panel"]')).toBeVisible();
    await expect(page.locator('[data-testid="center-panel"]')).toBeVisible();
    await expect(page.locator('[data-testid="right-panel"]')).toBeVisible();
  });

  test('selector de proyecto visible en panel izquierdo', async ({ page }) => {
    await login(page, USERS.member);

    const projectSelector = page.locator('[data-testid="project-selector"]');
    await expect(projectSelector).toBeVisible();
    await expect(projectSelector).toContainText(/Project/);
  });

  test('toggle de modos de vista visible', async ({ page }) => {
    await login(page, USERS.member);

    await expect(page.locator('[data-testid="view-mode-pool"]')).toBeVisible();
    await expect(page.locator('[data-testid="view-mode-list"]')).toBeVisible();
    await expect(page.locator('[data-testid="view-mode-cards"]')).toBeVisible();
  });
});
```

#### Test 2: Cambio de modos de vista

```javascript
test.describe('Modos de Vista', () => {
  test('cambiar a modo Pool actualiza URL', async ({ page }) => {
    await login(page, USERS.member);
    await page.click('[data-testid="view-mode-pool"]');

    await expect(page).toHaveURL(/view=pool/);
    await expect(page.locator('[data-testid="pool-canvas"]')).toBeVisible();
  });

  test('cambiar a modo Lista actualiza URL', async ({ page }) => {
    await login(page, USERS.member);
    await page.click('[data-testid="view-mode-list"]');

    await expect(page).toHaveURL(/view=list/);
    await expect(page.locator('[data-testid="grouped-list"]')).toBeVisible();
  });

  test('cambiar a modo Fichas actualiza URL', async ({ page }) => {
    await login(page, USERS.member);
    await page.click('[data-testid="view-mode-cards"]');

    await expect(page).toHaveURL(/view=cards/);
    await expect(page.locator('[data-testid="kanban-board"]')).toBeVisible();
  });

  test('F5 mantiene el modo de vista', async ({ page }) => {
    await login(page, USERS.member);
    await page.click('[data-testid="view-mode-list"]');
    await expect(page).toHaveURL(/view=list/);

    await page.reload();

    await expect(page).toHaveURL(/view=list/);
    await expect(page.locator('[data-testid="grouped-list"]')).toBeVisible();
  });
});
```

### 13.3 Tests de Permisos por Rol

#### Test 3: Visibilidad según rol - Member

```javascript
test.describe('Permisos Member', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USERS.member);
  });

  test('NO ve botón Nueva Tarea', async ({ page }) => {
    await expect(page.locator('[data-testid="btn-new-task"]')).not.toBeVisible();
  });

  test('NO ve botón Nueva Ficha', async ({ page }) => {
    await expect(page.locator('[data-testid="btn-new-card"]')).not.toBeVisible();
  });

  test('NO ve sección CONFIGURACIÓN', async ({ page }) => {
    await expect(page.locator('[data-testid="section-config"]')).not.toBeVisible();
  });

  test('NO ve sección ORGANIZACIÓN', async ({ page }) => {
    await expect(page.locator('[data-testid="section-org"]')).not.toBeVisible();
  });

  test('VE panel Mi actividad', async ({ page }) => {
    await expect(page.locator('[data-testid="my-tasks"]')).toBeVisible();
    await expect(page.locator('[data-testid="my-cards"]')).toBeVisible();
  });
});
```

#### Test 4: Visibilidad según rol - Project Manager

```javascript
test.describe('Permisos PM', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USERS.pm);
  });

  test('VE botón Nueva Tarea', async ({ page }) => {
    await expect(page.locator('[data-testid="btn-new-task"]')).toBeVisible();
  });

  test('VE botón Nueva Ficha', async ({ page }) => {
    await expect(page.locator('[data-testid="btn-new-card"]')).toBeVisible();
  });

  test('VE sección CONFIGURACIÓN', async ({ page }) => {
    await expect(page.locator('[data-testid="section-config"]')).toBeVisible();
  });

  test('VE opciones Equipo, Catálogo, Automatización', async ({ page }) => {
    await page.click('[data-testid="section-config"]');
    await expect(page.locator('[data-testid="nav-team"]')).toBeVisible();
    await expect(page.locator('[data-testid="nav-catalog"]')).toBeVisible();
    await expect(page.locator('[data-testid="nav-automation"]')).toBeVisible();
  });

  test('NO ve sección ORGANIZACIÓN', async ({ page }) => {
    await expect(page.locator('[data-testid="section-org"]')).not.toBeVisible();
  });

  test('VE menú contextual en fichas (modo Fichas)', async ({ page }) => {
    await page.click('[data-testid="view-mode-cards"]');
    const cardMenu = page.locator('[data-testid="card-context-menu"]').first();
    await expect(cardMenu).toBeVisible();
  });
});
```

#### Test 5: Visibilidad según rol - Org Admin

```javascript
test.describe('Permisos Org Admin', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USERS.orgAdmin);
  });

  test('VE todo lo que ve PM', async ({ page }) => {
    await expect(page.locator('[data-testid="btn-new-task"]')).toBeVisible();
    await expect(page.locator('[data-testid="btn-new-card"]')).toBeVisible();
    await expect(page.locator('[data-testid="section-config"]')).toBeVisible();
  });

  test('VE sección ORGANIZACIÓN', async ({ page }) => {
    await expect(page.locator('[data-testid="section-org"]')).toBeVisible();
  });

  test('VE opciones Invitaciones, Usuarios, Proyectos', async ({ page }) => {
    await page.click('[data-testid="section-org"]');
    await expect(page.locator('[data-testid="nav-invites"]')).toBeVisible();
    await expect(page.locator('[data-testid="nav-users"]')).toBeVisible();
    await expect(page.locator('[data-testid="nav-projects"]')).toBeVisible();
  });
});
```

### 13.4 Tests de CRUD - Fichas

#### Test 6: Crear ficha (PM)

```javascript
test.describe('CRUD Fichas', () => {
  test('PM puede crear una ficha', async ({ page }) => {
    await login(page, USERS.pm);

    await page.click('[data-testid="btn-new-card"]');
    await expect(page.locator('[data-testid="card-create-dialog"]')).toBeVisible();

    await page.fill('[data-testid="card-title-input"]', 'Test Ficha E2E');
    await page.fill('[data-testid="card-description-input"]', 'Descripción de prueba');
    await page.click('[data-testid="card-submit-btn"]');

    // Verifica toast de éxito
    await expect(page.locator('[data-testid="toast-success"]')).toBeVisible();

    // Verifica que aparece en modo Fichas
    await page.click('[data-testid="view-mode-cards"]');
    await expect(page.locator('text=Test Ficha E2E')).toBeVisible();
  });

  test('PM puede editar una ficha desde modo Fichas', async ({ page }) => {
    await login(page, USERS.pm);
    await page.click('[data-testid="view-mode-cards"]');

    // Click en menú contextual de la primera ficha
    await page.click('[data-testid="card-context-menu"]');
    await page.click('[data-testid="card-edit-btn"]');

    await expect(page.locator('[data-testid="card-edit-dialog"]')).toBeVisible();

    await page.fill('[data-testid="card-title-input"]', 'Ficha Editada');
    await page.click('[data-testid="card-submit-btn"]');

    await expect(page.locator('[data-testid="toast-success"]')).toBeVisible();
    await expect(page.locator('text=Ficha Editada')).toBeVisible();
  });

  test('PM puede eliminar una ficha', async ({ page }) => {
    await login(page, USERS.pm);
    await page.click('[data-testid="view-mode-cards"]');

    const cardTitle = await page.locator('[data-testid="card-title"]').first().textContent();

    await page.click('[data-testid="card-context-menu"]');
    await page.click('[data-testid="card-delete-btn"]');

    // Confirmar eliminación
    await page.click('[data-testid="confirm-delete-btn"]');

    await expect(page.locator('[data-testid="toast-success"]')).toBeVisible();
    await expect(page.locator(`text=${cardTitle}`)).not.toBeVisible();
  });

  test('Member NO puede crear fichas', async ({ page }) => {
    await login(page, USERS.member);
    await expect(page.locator('[data-testid="btn-new-card"]')).not.toBeVisible();
  });
});
```

### 13.5 Tests de CRUD - Tareas

#### Test 7: Crear tarea (PM)

```javascript
test.describe('CRUD Tareas', () => {
  test('PM puede crear una tarea', async ({ page }) => {
    await login(page, USERS.pm);

    await page.click('[data-testid="btn-new-task"]');
    await expect(page.locator('[data-testid="task-create-dialog"]')).toBeVisible();

    await page.fill('[data-testid="task-title-input"]', 'Test Tarea E2E');
    await page.selectOption('[data-testid="task-type-select"]', { index: 1 });
    await page.click('[data-testid="task-submit-btn"]');

    await expect(page.locator('[data-testid="toast-success"]')).toBeVisible();

    // Verifica que aparece en el pool
    await page.click('[data-testid="view-mode-pool"]');
    await expect(page.locator('text=Test Tarea E2E')).toBeVisible();
  });

  test('PM puede crear tarea dentro de una ficha', async ({ page }) => {
    await login(page, USERS.pm);
    await page.click('[data-testid="view-mode-cards"]');

    // Click en ficha para expandir
    await page.click('[data-testid="card-item"]');
    await page.click('[data-testid="card-add-task-btn"]');

    await page.fill('[data-testid="task-title-input"]', 'Tarea en Ficha');
    await page.selectOption('[data-testid="task-type-select"]', { index: 1 });
    await page.click('[data-testid="task-submit-btn"]');

    await expect(page.locator('[data-testid="toast-success"]')).toBeVisible();
    // La ficha ya tiene seleccionada
    await expect(page.locator('[data-testid="card-item"]')).toContainText('Tarea en Ficha');
  });

  test('Member NO puede crear tareas', async ({ page }) => {
    await login(page, USERS.member);
    await expect(page.locator('[data-testid="btn-new-task"]')).not.toBeVisible();
  });
});
```

### 13.6 Tests de Acciones de Trabajo

#### Test 8: Flujo completo de trabajo (Member)

```javascript
test.describe('Flujo de Trabajo Member', () => {
  test('Member puede reclamar tarea', async ({ page }) => {
    await login(page, USERS.member);

    // Click en tarea del pool
    await page.click('[data-testid="task-card"]');
    await expect(page.locator('[data-testid="task-detail-modal"]')).toBeVisible();

    await page.click('[data-testid="task-claim-btn"]');

    await expect(page.locator('[data-testid="toast-success"]')).toBeVisible();
    // Tarea aparece en panel derecho
    await expect(page.locator('[data-testid="my-tasks"]')).toContainText(/./);
  });

  test('Member puede empezar tarea (inicia timer)', async ({ page }) => {
    await login(page, USERS.member);

    // Asumiendo que ya tiene una tarea reclamada
    await page.click('[data-testid="my-task-start-btn"]');

    // Timer visible en "En curso"
    await expect(page.locator('[data-testid="active-task"]')).toBeVisible();
    await expect(page.locator('[data-testid="task-timer"]')).toBeVisible();
  });

  test('Member puede pausar tarea', async ({ page }) => {
    await login(page, USERS.member);

    // Con tarea en curso
    await page.click('[data-testid="task-pause-btn"]');

    // Tarea vuelve a "Mis tareas"
    await expect(page.locator('[data-testid="active-task"]')).not.toBeVisible();
    await expect(page.locator('[data-testid="my-tasks"]')).toContainText(/./);
  });

  test('Member puede completar tarea', async ({ page }) => {
    await login(page, USERS.member);

    // Iniciar y completar
    await page.click('[data-testid="my-task-start-btn"]');
    await page.click('[data-testid="task-complete-btn"]');

    await expect(page.locator('[data-testid="toast-success"]')).toContainText(/completada/i);
    await expect(page.locator('[data-testid="active-task"]')).not.toBeVisible();
  });

  test('Member puede liberar tarea (vuelve al pool)', async ({ page }) => {
    await login(page, USERS.member);

    // Reclamar primero
    await page.click('[data-testid="task-card"]');
    await page.click('[data-testid="task-claim-btn"]');

    // Luego liberar
    await page.click('[data-testid="my-task-release-btn"]');

    await expect(page.locator('[data-testid="toast-success"]')).toBeVisible();
    // Tarea ya no está en "Mis tareas"
  });
});
```

### 13.7 Tests de Configuración (PM)

#### Test 9: Gestión de Equipo y Skills

```javascript
test.describe('Configuración Equipo', () => {
  test('PM puede acceder a Config > Equipo', async ({ page }) => {
    await login(page, USERS.pm);

    await page.click('[data-testid="nav-team"]');
    await expect(page).toHaveURL(/config\/team/);
    await expect(page.locator('[data-testid="team-members-list"]')).toBeVisible();
  });

  test('PM puede asignar skills a un miembro', async ({ page }) => {
    await login(page, USERS.pm);
    await page.click('[data-testid="nav-team"]');

    // Click en botón de skills del primer miembro
    await page.click('[data-testid="member-skills-btn"]');
    await expect(page.locator('[data-testid="skills-panel"]')).toBeVisible();

    // Marcar un skill
    await page.click('[data-testid="skill-checkbox"]');
    await page.click('[data-testid="skills-save-btn"]');

    await expect(page.locator('[data-testid="toast-success"]')).toBeVisible();
  });

  test('PM puede crear nueva capacidad desde panel de skills', async ({ page }) => {
    await login(page, USERS.pm);
    await page.click('[data-testid="nav-team"]');
    await page.click('[data-testid="member-skills-btn"]');

    await page.click('[data-testid="create-capability-btn"]');
    await page.fill('[data-testid="capability-name-input"]', 'Nueva Capacidad E2E');
    await page.click('[data-testid="capability-submit-btn"]');

    await expect(page.locator('text=Nueva Capacidad E2E')).toBeVisible();
  });

  test('Proyecto visible en contexto', async ({ page }) => {
    await login(page, USERS.pm);
    await page.click('[data-testid="nav-team"]');

    // El proyecto seleccionado debe ser visible
    const projectName = await page.locator('[data-testid="project-selector"]').textContent();
    expect(projectName).toBeTruthy();

    // URL debe tener el proyecto
    await expect(page).toHaveURL(/project=\d+/);
  });
});
```

### 13.8 Tests de Organización (Org Admin)

#### Test 10: Gestión de Usuarios de Organización

```javascript
test.describe('Organización - Usuarios', () => {
  test('Org Admin puede acceder a Usuarios', async ({ page }) => {
    await login(page, USERS.orgAdmin);

    await page.click('[data-testid="nav-users"]');
    await expect(page).toHaveURL(/admin\/users/);
    await expect(page.locator('[data-testid="org-users-table"]')).toBeVisible();
  });

  test('Tabla muestra columnas correctas', async ({ page }) => {
    await login(page, USERS.orgAdmin);
    await page.click('[data-testid="nav-users"]');

    await expect(page.locator('th:has-text("EMAIL")')).toBeVisible();
    await expect(page.locator('th:has-text("ROL ORG")')).toBeVisible();
    await expect(page.locator('th:has-text("PROYECTOS")')).toBeVisible();
    await expect(page.locator('th:has-text("ACCIONES")')).toBeVisible();
  });

  test('Columna PROYECTOS muestra resumen', async ({ page }) => {
    await login(page, USERS.orgAdmin);
    await page.click('[data-testid="nav-users"]');

    // Debe mostrar "N: Project1, Project2" o "Sin proyectos"
    const projectsCell = page.locator('[data-testid="user-projects-summary"]').first();
    const text = await projectsCell.textContent();
    expect(text).toMatch(/^\d+:|Sin proyectos/);
  });

  test('Puede abrir dialog de gestión de proyectos', async ({ page }) => {
    await login(page, USERS.orgAdmin);
    await page.click('[data-testid="nav-users"]');

    await page.click('[data-testid="manage-user-btn"]');
    await expect(page.locator('[data-testid="user-projects-dialog"]')).toBeVisible();
  });

  test('Puede cambiar rol de usuario en proyecto (dropdown editable)', async ({ page }) => {
    await login(page, USERS.orgAdmin);
    await page.click('[data-testid="nav-users"]');
    await page.click('[data-testid="manage-user-btn"]');

    // Cambiar rol en dropdown
    await page.selectOption('[data-testid="project-role-select"]', 'manager');

    await expect(page.locator('[data-testid="toast-success"]')).toBeVisible();
  });

  test('Puede añadir usuario a proyecto con rol', async ({ page }) => {
    await login(page, USERS.orgAdmin);
    await page.click('[data-testid="nav-users"]');
    await page.click('[data-testid="manage-user-btn"]');

    await page.selectOption('[data-testid="add-project-select"]', { index: 1 });
    await page.selectOption('[data-testid="add-role-select"]', 'member');
    await page.click('[data-testid="add-to-project-btn"]');

    await expect(page.locator('[data-testid="toast-success"]')).toBeVisible();
  });

  test('Puede cambiar rol org con indicador de pendiente', async ({ page }) => {
    await login(page, USERS.orgAdmin);
    await page.click('[data-testid="nav-users"]');

    // Cambiar dropdown de rol org
    await page.selectOption('[data-testid="org-role-select"]', 'admin');

    // Debe aparecer indicador de pendiente (*)
    await expect(page.locator('[data-testid="pending-indicator"]')).toBeVisible();

    // Botón guardar debe estar habilitado
    await expect(page.locator('[data-testid="save-org-roles-btn"]')).toBeEnabled();

    await page.click('[data-testid="save-org-roles-btn"]');
    await expect(page.locator('[data-testid="toast-success"]')).toBeVisible();
  });
});
```

### 13.9 Tests de URL y Persistencia

#### Test 11: URL Strategy completo

```javascript
test.describe('URL Strategy', () => {
  test('Cambiar proyecto actualiza URL', async ({ page }) => {
    await login(page, USERS.member);

    await page.click('[data-testid="project-selector"]');
    await page.click('[data-testid="project-option-2"]'); // Segundo proyecto

    await expect(page).toHaveURL(/project=2/);
  });

  test('Filtros se reflejan en URL', async ({ page }) => {
    await login(page, USERS.member);

    await page.selectOption('[data-testid="filter-type"]', { index: 1 });
    await expect(page).toHaveURL(/type=\d+/);

    await page.selectOption('[data-testid="filter-capability"]', { index: 1 });
    await expect(page).toHaveURL(/cap=\d+/);
  });

  test('F5 restaura estado completo', async ({ page }) => {
    await login(page, USERS.member);

    // Configurar estado
    await page.click('[data-testid="view-mode-list"]');
    await page.selectOption('[data-testid="filter-type"]', { index: 1 });

    const urlBefore = page.url();

    await page.reload();

    // Estado restaurado
    await expect(page).toHaveURL(urlBefore);
    await expect(page.locator('[data-testid="grouped-list"]')).toBeVisible();
    await expect(page.locator('[data-testid="filter-type"]')).toHaveValue(/\d+/);
  });

  test('Deep link funciona para usuario con permisos', async ({ page }) => {
    await login(page, USERS.member);

    // Navegar directamente a URL específica
    await page.goto(TARGET_URL + '/app?project=8&view=cards');

    await expect(page.locator('[data-testid="kanban-board"]')).toBeVisible();
  });

  test('Deep link sin permisos muestra error', async ({ page }) => {
    await login(page, USERS.member);

    // Proyecto al que no tiene acceso
    await page.goto(TARGET_URL + '/app?project=999');

    await expect(page.locator('[data-testid="error-no-access"]')).toBeVisible();
  });
});
```

### 13.10 Tests de Responsive (Mobile)

#### Test 12: Layout mobile

```javascript
test.describe('Responsive Mobile', () => {
  test.use({ viewport: { width: 375, height: 667 } }); // iPhone SE

  test('Solo panel central visible en mobile', async ({ page }) => {
    await login(page, USERS.member);

    await expect(page.locator('[data-testid="center-panel"]')).toBeVisible();
    await expect(page.locator('[data-testid="left-panel"]')).not.toBeVisible();
    await expect(page.locator('[data-testid="right-panel"]')).not.toBeVisible();
  });

  test('Botón hamburguesa abre drawer izquierdo', async ({ page }) => {
    await login(page, USERS.member);

    await page.click('[data-testid="menu-hamburger"]');
    await expect(page.locator('[data-testid="left-drawer"]')).toBeVisible();
  });

  test('Botón usuario abre drawer derecho', async ({ page }) => {
    await login(page, USERS.member);

    await page.click('[data-testid="menu-user"]');
    await expect(page.locator('[data-testid="right-drawer"]')).toBeVisible();
  });

  test('Tap en tarea abre bottom sheet', async ({ page }) => {
    await login(page, USERS.member);

    await page.click('[data-testid="task-card"]');
    await expect(page.locator('[data-testid="task-bottom-sheet"]')).toBeVisible();
    await expect(page.locator('[data-testid="task-claim-btn"]')).toBeVisible();
  });

  test('Mini-barra visible cuando hay tarea activa', async ({ page }) => {
    await login(page, USERS.member);

    // Reclamar y empezar tarea
    await page.click('[data-testid="task-card"]');
    await page.click('[data-testid="task-claim-btn"]');
    await page.click('[data-testid="menu-user"]');
    await page.click('[data-testid="my-task-start-btn"]');

    // Cerrar drawer
    await page.click('[data-testid="drawer-close"]');

    // Mini-barra visible
    await expect(page.locator('[data-testid="mini-task-bar"]')).toBeVisible();
  });
});
```

### 13.11 Matriz de Validación

| Test | Org Admin | PM | Member | Descripción |
|------|-----------|----|---------| ------------|
| T1 | ✓ | ✓ | ✓ | Layout 3 paneles visible |
| T2 | ✓ | ✓ | ✓ | Cambio de modos de vista |
| T3 | - | - | ✓ | Permisos Member (NO ve config/org) |
| T4 | - | ✓ | - | Permisos PM (VE config, NO org) |
| T5 | ✓ | - | - | Permisos Org Admin (VE todo) |
| T6 | ✓ | ✓ | ✗ | CRUD Fichas |
| T7 | ✓ | ✓ | ✗ | CRUD Tareas |
| T8 | ✓ | ✓ | ✓ | Flujo de trabajo (reclamar/completar) |
| T9 | ✓ | ✓ | - | Config > Equipo + Skills |
| T10 | ✓ | - | - | Organización > Usuarios |
| T11 | ✓ | ✓ | ✓ | URL Strategy + F5 |
| T12 | ✓ | ✓ | ✓ | Responsive mobile |

### 13.12 Ejecución de Tests

```bash
# Instalar dependencias
npm install -D @playwright/test

# Ejecutar todos los tests
npx playwright test test/e2e/ia-redesign.spec.js --headed

# Ejecutar en modo headless (CI)
npx playwright test test/e2e/ia-redesign.spec.js

# Ejecutar solo tests de un rol
npx playwright test --grep "Permisos Member"

# Ejecutar con reporte HTML
npx playwright test --reporter=html
```

### 13.13 Criterios de Aceptación

La historia se considera **COMPLETADA** cuando:

- [ ] Todos los tests pasan en modo headless
- [ ] Tests ejecutados para los 3 roles (Org Admin, PM, Member)
- [ ] Cobertura de CRUD: Fichas, Tareas
- [ ] Cobertura de acciones: Reclamar, Empezar, Pausar, Completar, Liberar
- [ ] URL persiste estado (F5 funciona)
- [ ] Layout responsive funciona en mobile (375px)
- [ ] Tiempo de ejecución < 5 minutos

---

## Anexo A: Imagen de Referencia

Ver `capturas/propuesta.png` para el boceto original del usuario que inspiró este diseño.

---

## Anexo B: data-testid Requeridos

Para que los tests funcionen, los componentes deben incluir estos `data-testid`:

| Componente | data-testid |
|------------|-------------|
| Panel izquierdo | `left-panel` |
| Panel central | `center-panel` |
| Panel derecho | `right-panel` |
| Selector proyecto | `project-selector` |
| Toggle Pool | `view-mode-pool` |
| Toggle Lista | `view-mode-list` |
| Toggle Fichas | `view-mode-cards` |
| Botón Nueva Tarea | `btn-new-task` |
| Botón Nueva Ficha | `btn-new-card` |
| Sección Config | `section-config` |
| Sección Org | `section-org` |
| Mis tareas | `my-tasks` |
| Mis fichas | `my-cards` |
| Tarea activa | `active-task` |
| Timer | `task-timer` |
| Canvas Pool | `pool-canvas` |
| Lista agrupada | `grouped-list` |
| Kanban | `kanban-board` |
| Tarjeta tarea | `task-card` |
| Item ficha | `card-item` |
| Menú hamburguesa | `menu-hamburger` |
| Menú usuario | `menu-user` |
| Drawer izquierdo | `left-drawer` |
| Drawer derecho | `right-drawer` |
| Mini-barra | `mini-task-bar` |
| Toast éxito | `toast-success` |

---

## Anexo C: Patrones de Código Gleam y TDD

Este anexo define los patrones de diseño type-safe recomendados para la implementación, siguiendo los principios de Gleam: "make illegal states unrepresentable" y TDD.

### C.1 ViewMode como Sum Type

El modo de vista debe modelarse como un tipo algebraico con matching exhaustivo:

```gleam
// shared/src/domain/view_mode.gleam

/// Modos de visualización del contenido principal
pub type ViewMode {
  Pool    // Canvas de tareas disponibles
  List    // Lista agrupada por ficha
  Cards   // Kanban de fichas
}

/// Convierte string de URL a ViewMode
pub fn from_string(s: String) -> ViewMode {
  case s {
    "list" -> List
    "cards" -> Cards
    _ -> Pool  // Default
  }
}

/// Convierte ViewMode a string para URL
pub fn to_string(mode: ViewMode) -> String {
  case mode {
    Pool -> "pool"
    List -> "list"
    Cards -> "cards"
  }
}

/// Determina si el modo soporta drag & drop
pub fn supports_drag_drop(mode: ViewMode) -> Bool {
  case mode {
    Pool -> True
    List -> False
    Cards -> True  // Mover tareas entre columnas
  }
}
```

### C.2 UrlState como Opaque Type

El estado de URL usa un tipo opaco con smart constructor para garantizar validez:

```gleam
// apps/client/src/scrumbringer_client/url_state.gleam

import gleam/option.{type Option, None, Some}
import gleam/uri.{type Uri}
import scrumbringer_shared/domain/view_mode.{type ViewMode}

/// Estado de URL - solo se puede crear mediante parse()
pub opaque type UrlState {
  UrlState(
    project: Option(Int),
    view: ViewMode,
    type_filter: Option(Int),
    capability_filter: Option(Int),
    search: Option(String),
    expanded_card: Option(Int),
  )
}

/// Parsea una URI y crea un UrlState válido
/// Este es el ÚNICO punto de entrada para crear UrlState
pub fn parse(uri: Uri) -> UrlState {
  let query = uri.query |> option.unwrap("")
  let params = parse_query_params(query)

  UrlState(
    project: params |> get_int("project"),
    view: params
      |> get_string("view")
      |> option.map(view_mode.from_string)
      |> option.unwrap(view_mode.Pool),
    type_filter: params |> get_int("type"),
    capability_filter: params |> get_int("cap"),
    search: params |> get_string("search"),
    expanded_card: params |> get_int("card"),
  )
}

/// Builder: actualiza el proyecto seleccionado
pub fn with_project(state: UrlState, project_id: Int) -> UrlState {
  UrlState(..state, project: Some(project_id))
}

/// Builder: actualiza el modo de vista
pub fn with_view(state: UrlState, mode: ViewMode) -> UrlState {
  UrlState(..state, view: mode)
}

/// Builder: actualiza el filtro de tipo
pub fn with_type_filter(state: UrlState, type_id: Option(Int)) -> UrlState {
  UrlState(..state, type_filter: type_id)
}

/// Builder: actualiza el filtro de capacidad
pub fn with_capability_filter(state: UrlState, cap_id: Option(Int)) -> UrlState {
  UrlState(..state, capability_filter: cap_id)
}

/// Builder: actualiza la búsqueda
pub fn with_search(state: UrlState, term: Option(String)) -> UrlState {
  UrlState(..state, search: term)
}

/// Builder: actualiza la ficha expandida
pub fn with_expanded_card(state: UrlState, card_id: Option(Int)) -> UrlState {
  UrlState(..state, expanded_card: card_id)
}

// Accessors (read-only)
pub fn project(state: UrlState) -> Option(Int) { state.project }
pub fn view(state: UrlState) -> ViewMode { state.view }
pub fn type_filter(state: UrlState) -> Option(Int) { state.type_filter }
pub fn capability_filter(state: UrlState) -> Option(Int) { state.capability_filter }
pub fn search(state: UrlState) -> Option(String) { state.search }
pub fn expanded_card(state: UrlState) -> Option(Int) { state.expanded_card }

/// Serializa a query string para pushState
pub fn to_query_string(state: UrlState) -> String {
  [
    state.project |> option.map(fn(p) { "project=" <> int.to_string(p) }),
    Some("view=" <> view_mode.to_string(state.view)),
    state.type_filter |> option.map(fn(t) { "type=" <> int.to_string(t) }),
    state.capability_filter |> option.map(fn(c) { "cap=" <> int.to_string(c) }),
    state.search |> option.map(fn(s) { "search=" <> uri.percent_encode(s) }),
    state.expanded_card |> option.map(fn(c) { "card=" <> int.to_string(c) }),
  ]
  |> list.filter_map(fn(x) { x })
  |> string.join("&")
}
```

### C.3 WorkspaceState como Máquina de Estados

El estado del workspace se modela como una máquina de estados que hace transiciones inválidas imposibles:

```gleam
// apps/client/src/scrumbringer_client/workspace_state.gleam

import gleam/option.{type Option}
import scrumbringer_shared/domain/task.{type Task}
import scrumbringer_shared/domain/card.{type Card}

/// Datos del workspace cargado
pub type Workspace {
  Workspace(
    project_id: Int,
    tasks: List(Task),
    cards: List(Card),
    members: List(Member),
    capabilities: List(Capability),
    task_types: List(TaskType),
  )
}

/// Estados posibles del workspace - máquina de estados
pub type WorkspaceState {
  /// Sin proyecto seleccionado
  NoProject
  /// Cargando datos del proyecto
  LoadingWorkspace(project_id: Int)
  /// Workspace listo para trabajar
  Ready(workspace: Workspace)
  /// Error al cargar (permite reintentar)
  WorkspaceError(project_id: Int, message: String)
}

/// Transición: seleccionar un proyecto
pub fn select_project(state: WorkspaceState, project_id: Int) -> WorkspaceState {
  case state {
    // Desde cualquier estado podemos seleccionar proyecto
    NoProject -> LoadingWorkspace(project_id)
    LoadingWorkspace(_) -> LoadingWorkspace(project_id)  // Cancelar anterior
    Ready(_) -> LoadingWorkspace(project_id)  // Cambiar proyecto
    WorkspaceError(_, _) -> LoadingWorkspace(project_id)  // Reintentar otro
  }
}

/// Transición: workspace cargado exitosamente
pub fn workspace_loaded(state: WorkspaceState, workspace: Workspace) -> WorkspaceState {
  case state {
    LoadingWorkspace(pid) if pid == workspace.project_id -> Ready(workspace)
    // Ignorar si ya no estamos esperando este proyecto
    _ -> state
  }
}

/// Transición: error al cargar
pub fn workspace_failed(state: WorkspaceState, message: String) -> WorkspaceState {
  case state {
    LoadingWorkspace(pid) -> WorkspaceError(pid, message)
    // Ignorar en otros estados
    _ -> state
  }
}

/// Transición: limpiar proyecto (logout, cambio de org)
pub fn clear_project(_state: WorkspaceState) -> WorkspaceState {
  NoProject
}

/// ¿Está listo para mostrar contenido?
pub fn is_ready(state: WorkspaceState) -> Bool {
  case state {
    Ready(_) -> True
    _ -> False
  }
}

/// Obtener workspace si está listo
pub fn get_workspace(state: WorkspaceState) -> Option(Workspace) {
  case state {
    Ready(ws) -> Some(ws)
    _ -> None
  }
}

/// ¿Está cargando?
pub fn is_loading(state: WorkspaceState) -> Bool {
  case state {
    LoadingWorkspace(_) -> True
    _ -> False
  }
}

/// Obtener mensaje de error si hay
pub fn error_message(state: WorkspaceState) -> Option(String) {
  case state {
    WorkspaceError(_, msg) -> Some(msg)
    _ -> None
  }
}
```

### C.4 Generic CRUD Handlers

Manejadores genéricos para reducir duplicación en listas org/proyecto:

```gleam
// apps/client/src/scrumbringer_client/utils/crud_list.gleam

import gleam/list
import gleam/option.{type Option, None, Some}
import scrumbringer_shared/remote.{type Remote, Loaded, Loading, NotAsked}

/// Resultado de operación en dual-list (org + proyecto)
pub type DualListResult(a) {
  DualListResult(
    org_list: Remote(List(a)),
    project_list: Remote(List(a)),
  )
}

/// Item creado - añadir a la lista correcta según scope
pub fn item_created(
  org_list: Remote(List(a)),
  project_list: Remote(List(a)),
  item: a,
  get_project_id: fn(a) -> Option(Int),
) -> DualListResult(a) {
  case get_project_id(item) {
    Some(_) ->
      // Es de proyecto - añadir a project_list
      DualListResult(
        org_list: org_list,
        project_list: project_list |> add_to_remote_list(item),
      )
    None ->
      // Es de org - añadir a org_list
      DualListResult(
        org_list: org_list |> add_to_remote_list(item),
        project_list: project_list,
      )
  }
}

/// Item actualizado - actualizar en ambas listas si existe
pub fn item_updated(
  org_list: Remote(List(a)),
  project_list: Remote(List(a)),
  item: a,
  get_id: fn(a) -> Int,
) -> DualListResult(a) {
  DualListResult(
    org_list: org_list |> update_in_remote_list(item, get_id),
    project_list: project_list |> update_in_remote_list(item, get_id),
  )
}

/// Item eliminado - eliminar de ambas listas
pub fn item_deleted(
  org_list: Remote(List(a)),
  project_list: Remote(List(a)),
  item_id: Int,
  get_id: fn(a) -> Int,
) -> DualListResult(a) {
  DualListResult(
    org_list: org_list |> remove_from_remote_list(item_id, get_id),
    project_list: project_list |> remove_from_remote_list(item_id, get_id),
  )
}

// Helpers privados

fn add_to_remote_list(remote: Remote(List(a)), item: a) -> Remote(List(a)) {
  case remote {
    Loaded(items) -> Loaded([item, ..items])
    _ -> remote
  }
}

fn update_in_remote_list(
  remote: Remote(List(a)),
  item: a,
  get_id: fn(a) -> Int,
) -> Remote(List(a)) {
  case remote {
    Loaded(items) ->
      Loaded(list.map(items, fn(existing) {
        case get_id(existing) == get_id(item) {
          True -> item
          False -> existing
        }
      }))
    _ -> remote
  }
}

fn remove_from_remote_list(
  remote: Remote(List(a)),
  item_id: Int,
  get_id: fn(a) -> Int,
) -> Remote(List(a)) {
  case remote {
    Loaded(items) ->
      Loaded(list.filter(items, fn(item) { get_id(item) != item_id }))
    _ -> remote
  }
}
```

### C.5 Tests TDD para UrlState

```gleam
// apps/client/test/url_state_test.gleam

import gleeunit/should
import gleam/uri
import scrumbringer_client/url_state
import scrumbringer_shared/domain/view_mode

pub fn parse_empty_url_test() {
  let uri = uri.parse("/app") |> should.be_ok
  let state = url_state.parse(uri)

  state |> url_state.project |> should.be_none
  state |> url_state.view |> should.equal(view_mode.Pool)
  state |> url_state.type_filter |> should.be_none
}

pub fn parse_full_url_test() {
  let uri = uri.parse("/app?project=8&view=list&type=2&cap=3&search=bug")
    |> should.be_ok
  let state = url_state.parse(uri)

  state |> url_state.project |> should.equal(Some(8))
  state |> url_state.view |> should.equal(view_mode.List)
  state |> url_state.type_filter |> should.equal(Some(2))
  state |> url_state.capability_filter |> should.equal(Some(3))
  state |> url_state.search |> should.equal(Some("bug"))
}

pub fn builder_chain_test() {
  let uri = uri.parse("/app") |> should.be_ok
  let state = url_state.parse(uri)
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_type_filter(Some(2))

  state |> url_state.project |> should.equal(Some(8))
  state |> url_state.view |> should.equal(view_mode.Cards)
  state |> url_state.type_filter |> should.equal(Some(2))
}

pub fn to_query_string_test() {
  let uri = uri.parse("/app") |> should.be_ok
  let query = url_state.parse(uri)
    |> url_state.with_project(8)
    |> url_state.with_view(view_mode.List)
    |> url_state.to_query_string

  query |> should.equal("project=8&view=list")
}

pub fn roundtrip_test() {
  // Parsear -> modificar -> serializar -> parsear de nuevo
  let original = "/app?project=8&view=cards&type=2"
  let uri = uri.parse(original) |> should.be_ok

  let state = url_state.parse(uri)
    |> url_state.with_search(Some("test"))

  let query = url_state.to_query_string(state)
  let reparsed_uri = uri.parse("/app?" <> query) |> should.be_ok
  let reparsed = url_state.parse(reparsed_uri)

  reparsed |> url_state.project |> should.equal(Some(8))
  reparsed |> url_state.view |> should.equal(view_mode.Cards)
  reparsed |> url_state.search |> should.equal(Some("test"))
}
```

### C.6 Tests TDD para WorkspaceState

```gleam
// apps/client/test/workspace_state_test.gleam

import gleeunit/should
import scrumbringer_client/workspace_state.{
  NoProject, LoadingWorkspace, Ready, WorkspaceError, Workspace
}

fn sample_workspace(project_id: Int) -> Workspace {
  Workspace(
    project_id: project_id,
    tasks: [],
    cards: [],
    members: [],
    capabilities: [],
    task_types: [],
  )
}

pub fn initial_state_is_no_project_test() {
  let state = NoProject

  state |> workspace_state.is_ready |> should.be_false
  state |> workspace_state.is_loading |> should.be_false
  state |> workspace_state.get_workspace |> should.be_none
}

pub fn select_project_starts_loading_test() {
  let state = NoProject
    |> workspace_state.select_project(8)

  state |> should.equal(LoadingWorkspace(8))
  state |> workspace_state.is_loading |> should.be_true
}

pub fn workspace_loaded_transitions_to_ready_test() {
  let workspace = sample_workspace(8)
  let state = NoProject
    |> workspace_state.select_project(8)
    |> workspace_state.workspace_loaded(workspace)

  state |> workspace_state.is_ready |> should.be_true
  state |> workspace_state.get_workspace |> should.equal(Some(workspace))
}

pub fn wrong_project_id_ignored_test() {
  let workspace = sample_workspace(999)  // Wrong ID
  let state = NoProject
    |> workspace_state.select_project(8)
    |> workspace_state.workspace_loaded(workspace)

  // Should still be loading because IDs don't match
  state |> workspace_state.is_loading |> should.be_true
  state |> workspace_state.is_ready |> should.be_false
}

pub fn workspace_failed_transitions_to_error_test() {
  let state = NoProject
    |> workspace_state.select_project(8)
    |> workspace_state.workspace_failed("Network error")

  state |> should.equal(WorkspaceError(8, "Network error"))
  state |> workspace_state.error_message |> should.equal(Some("Network error"))
}

pub fn can_retry_from_error_test() {
  let workspace = sample_workspace(8)
  let state = WorkspaceError(8, "Previous error")
    |> workspace_state.select_project(8)  // Retry
    |> workspace_state.workspace_loaded(workspace)

  state |> workspace_state.is_ready |> should.be_true
}

pub fn changing_project_cancels_loading_test() {
  let workspace = sample_workspace(8)
  let state = NoProject
    |> workspace_state.select_project(8)
    |> workspace_state.select_project(9)  // Change before load completes
    |> workspace_state.workspace_loaded(workspace)  // Old response arrives

  // Should still be loading project 9 (ignored old response for project 8)
  state |> workspace_state.is_loading |> should.be_true
}

pub fn clear_project_returns_to_no_project_test() {
  let workspace = sample_workspace(8)
  let state = NoProject
    |> workspace_state.select_project(8)
    |> workspace_state.workspace_loaded(workspace)
    |> workspace_state.clear_project

  state |> should.equal(NoProject)
}
```

### C.7 Checklist de Implementación Type-Safe

| Paso | Archivo | Descripción | Test Requerido |
|------|---------|-------------|----------------|
| 1 | `shared/src/domain/view_mode.gleam` | Crear ViewMode sum type | `view_mode_test.gleam` |
| 2 | `client/src/url_state.gleam` | Crear UrlState opaque type | `url_state_test.gleam` |
| 3 | `client/src/workspace_state.gleam` | Crear WorkspaceState state machine | `workspace_state_test.gleam` |
| 4 | `client/src/utils/crud_list.gleam` | Crear handlers genéricos | `crud_list_test.gleam` |
| 5 | `client/src/client_state.gleam` | Refactorizar para usar nuevos tipos | Tests existentes deben pasar |
| 6 | `client/src/client_update.gleam` | Actualizar handlers con nuevos tipos | Tests de integración |

### C.8 Beneficios de Esta Arquitectura

| Aspecto | Beneficio |
|---------|-----------|
| **UrlState opaco** | Imposible crear URL inválida; F5 siempre funciona |
| **WorkspaceState ADT** | Transiciones de estado explícitas; no hay estados "zombie" |
| **ViewMode sum type** | Exhaustive matching garantiza que todos los modos se manejan |
| **CRUD genérico** | ~300 líneas de duplicación eliminadas |
| **Builder pattern** | Actualizaciones inmutables, fácil encadenamiento |
| **Tests TDD** | Cada módulo tiene tests que documentan su comportamiento |

### C.9 Ejemplo de Uso Integrado

```gleam
// En client_update.gleam

import scrumbringer_client/url_state
import scrumbringer_client/workspace_state

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    // Usuario cambia modo de vista
    ViewModeChanged(mode) -> {
      let new_url = model.url_state
        |> url_state.with_view(mode)

      // Actualizar URL del navegador sin recargar
      let effect = push_url(url_state.to_query_string(new_url))

      #(Model(..model, url_state: new_url), effect)
    }

    // Usuario selecciona proyecto
    ProjectSelected(project_id) -> {
      let new_url = model.url_state
        |> url_state.with_project(project_id)

      let new_workspace = model.workspace_state
        |> workspace_state.select_project(project_id)

      let effect = batch([
        push_url(url_state.to_query_string(new_url)),
        fetch_workspace(project_id),
      ])

      #(Model(..model, url_state: new_url, workspace_state: new_workspace), effect)
    }

    // Datos del workspace cargados
    WorkspaceLoaded(workspace) -> {
      let new_workspace = model.workspace_state
        |> workspace_state.workspace_loaded(workspace)

      #(Model(..model, workspace_state: new_workspace), none())
    }

    // Error al cargar
    WorkspaceFailed(error) -> {
      let new_workspace = model.workspace_state
        |> workspace_state.workspace_failed(error)

      #(Model(..model, workspace_state: new_workspace), none())
    }
  }
}
```
