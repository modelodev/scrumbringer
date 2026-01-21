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

## 7. Próximos Pasos

### 6.1 Historias de Usuario Derivadas

Este spec dará lugar a las siguientes historias (a partir de 4.4):

| Historia | Descripción | Prioridad |
|----------|-------------|-----------|
| **4.4** | Eliminar header, implementar layout 3 paneles | 🔴 Alta |
| **4.5** | Eliminar vistas Mi barra y Mis skills | 🔴 Alta |
| **4.6** | Implementar 3 modos de vista (Pool/Lista/Fichas) | 🔴 Alta |
| **4.7** | Rediseñar panel izquierdo (proyecto + org) | 🟡 Media |
| **4.8** | Rediseñar panel derecho (mi actividad) | 🟡 Media |
| **4.9** | Gestión de skills desde Config > Equipo | 🟡 Media |

### 6.2 Design Handoff Checklist

- [x] Wireframes de layout general
- [x] Wireframes de cada panel
- [x] Wireframes de los 3 modos de vista
- [x] Vistas por rol documentadas
- [x] Decisiones de diseño documentadas
- [ ] Responsive/mobile strategy (pendiente)
- [ ] Especificación de componentes (pendiente)
- [ ] Guía de accesibilidad (pendiente)

---

## Anexo: Imagen de Referencia

Ver `capturas/propuesta.png` para el boceto original del usuario que inspiró este diseño.
