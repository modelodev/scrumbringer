# Matriz de Entidades, Permisos y Navegación

**Autor:** Sally (UX Expert)
**Fecha:** 2026-01-22
**Propósito:** Análisis exhaustivo para definir la navegación del shell unificado

---

## 1. Inventario de Entidades

### Entidades del Sistema

| Entidad | Scope | Descripción |
|---------|-------|-------------|
| **Org** | Organización | Configuración de la organización |
| **OrgInviteLink** | Organización | Links de invitación para nuevos usuarios |
| **OrgUser** | Organización | Usuarios de la organización y sus roles |
| **Project** | Organización | Proyectos dentro de la organización |
| **ProjectMember** | Proyecto | Miembros de un proyecto y sus roles |
| **Capability** | Proyecto | Capacidades/skills disponibles en un proyecto |
| **MemberCapability** | Proyecto | Capacidades asignadas a un miembro |
| **TaskType** | Proyecto | Tipos de tarea (Bug, Feature, Task) |
| **Card** | Proyecto | Fichas/épicas que agrupan tareas |
| **Workflow** | Proyecto | Flujos de automatización |
| **Rule** | Workflow | Reglas dentro de un workflow |
| **TaskTemplate** | Proyecto | Plantillas de tareas predefinidas |
| **Task** | Proyecto | Tareas individuales |
| **WorkSession** | Usuario | Sesiones de trabajo (timer) |
| **TaskNote** | Tarea | Notas en tareas |
| **Metrics** | Org/Proyecto | Métricas de rendimiento |
| **RuleMetrics** | Org/Proyecto | Métricas de ejecución de reglas |

---

## 2. Matriz de Permisos por Rol

### Leyenda
- ✅ = CRUD completo (Create, Read, Update, Delete)
- 📖 = Solo lectura (Read)
- ➕ = Solo crear (Create)
- ✏️ = Crear y editar propios (Create own, Update own)
- 🔗 = Asignar/desasignar (Link/Unlink)
- ❌ = Sin acceso

### 2.1 Member (Miembro de Proyecto)

| Entidad | Permiso | Operaciones | Notas |
|---------|---------|-------------|-------|
| Project | 📖 | Ver proyectos donde es miembro | Solo sus proyectos |
| Task | ✏️ | Ver todas, crear, editar propias | Solo del proyecto |
| Task.claim | ✅ | Reclamar/liberar tareas | Solo disponibles |
| Task.complete | ✅ | Completar tareas propias | Solo reclamadas |
| TaskNote | ✏️ | Ver todas, crear, editar propias | Solo en tareas visibles |
| WorkSession | ✅ | Gestionar sus sesiones | Solo propias |
| Card | 📖 | Ver fichas | Solo del proyecto |
| Capability | 📖 | Ver capacidades | Solo del proyecto |
| MemberCapability | 📖 | Ver sus capacidades asignadas | Solo propias |
| TaskType | 📖 | Ver tipos de tarea | Solo del proyecto |
| TaskTemplate | 📖 | Ver plantillas | Para crear tareas |
| Metrics (propias) | 📖 | Ver sus métricas | /me/metrics |

**Navegación Member:**
```
/app
├── Pool/Lista/Fichas (trabajo)
├── Mis tareas (panel derecho)
├── Mis fichas (panel derecho)
└── Mi perfil (panel derecho)
```

---

### 2.2 PM (Project Manager)

| Entidad | Permiso | Operaciones | Notas |
|---------|---------|-------------|-------|
| Project | 📖 | Ver proyectos donde es PM | Solo como manager |
| **ProjectMember** | ✅ | CRUD miembros del proyecto | Añadir/quitar/cambiar rol |
| **MemberCapability** | 🔗 | Asignar capacidades a miembros | De su proyecto |
| **Capability** | ✅ | CRUD capacidades | Solo su proyecto |
| **TaskType** | ✅ | CRUD tipos de tarea | Solo su proyecto |
| **Card** | ✅ | CRUD fichas | Solo su proyecto |
| **Workflow** | ✅ | CRUD workflows | Solo su proyecto |
| **Rule** | ✅ | CRUD reglas | En workflows propios |
| **TaskTemplate** | ✅ | CRUD plantillas | Solo su proyecto |
| Task | ✅ | CRUD todas las tareas | Del proyecto |
| TaskNote | ✅ | CRUD todas las notas | Del proyecto |
| WorkSession | ✅ | Gestionar sus sesiones | Solo propias |
| Metrics (proyecto) | 📖 | Ver métricas del proyecto | /projects/:id/metrics |
| RuleMetrics | 📖 | Ver métricas de reglas | Del proyecto |

**Lo que NO puede hacer un PM:**
- ❌ Crear/eliminar proyectos
- ❌ Invitar usuarios a la organización
- ❌ Ver/editar configuración de la organización
- ❌ Ver métricas de otros proyectos
- ❌ Ver usuarios de la organización (solo del proyecto)

**Navegación PM:**
```
/app
├── Pool/Lista/Fichas (trabajo)
├── Mis tareas (panel derecho)
├── Mis fichas (panel derecho)
└── Mi perfil (panel derecho)

/config (sidebar izquierdo, sección CONFIGURACIÓN)
├── /config/members        → Miembros del proyecto
│   ├── Lista de miembros
│   ├── [+ Añadir miembro] (buscar en org users)
│   ├── Cambiar rol (dropdown)
│   ├── Asignar capacidades (modal)
│   └── [Quitar] (confirmar)
│
├── /config/capabilities   → Capacidades
│   ├── Lista de capacidades
│   ├── [+ Crear capacidad]
│   ├── [Editar]
│   └── [Eliminar]
│
├── /config/task-types     → Tipos de tarea
│   ├── Lista de tipos
│   ├── [+ Crear tipo]
│   ├── [Editar]
│   └── [Eliminar]
│
├── /config/cards          → Fichas
│   ├── Lista de fichas
│   ├── [+ Crear ficha]
│   ├── [Editar]
│   └── [Eliminar]
│
├── /config/workflows      → Automatizaciones
│   ├── Lista de workflows
│   ├── [+ Crear workflow]
│   ├── → Reglas del workflow
│   │   ├── [+ Crear regla]
│   │   ├── [Editar]
│   │   └── [Eliminar]
│   └── [Eliminar workflow]
│
├── /config/templates      → Plantillas de tarea
│   ├── Lista de plantillas
│   ├── [+ Crear plantilla]
│   ├── [Editar]
│   └── [Eliminar]
│
└── /config/rule-metrics   → Métricas de reglas (solo lectura)
    └── Vista de métricas del proyecto
```

---

### 2.3 Org Admin (Administrador de Organización)

| Entidad | Permiso | Operaciones | Notas |
|---------|---------|-------------|-------|
| **Org** | ✅ | Editar configuración org | Nombre, etc. |
| **OrgInviteLink** | ✅ | CRUD links de invitación | Crear, regenerar, eliminar |
| **OrgUser** | ✅ | Ver todos los usuarios | Cambiar rol org |
| **OrgUser.projects** | 🔗 | Asignar usuarios a proyectos | Con cualquier rol |
| **Project** | ✅ | CRUD proyectos | Crear, editar, eliminar |
| ProjectMember | ✅ | CRUD miembros (cualquier proyecto) | Acceso implícito |
| MemberCapability | 🔗 | Asignar capacidades | Cualquier proyecto |
| Capability | ✅ | CRUD capacidades | Cualquier proyecto |
| TaskType | ✅ | CRUD tipos de tarea | Cualquier proyecto |
| Card | ✅ | CRUD fichas | Cualquier proyecto |
| Workflow | ✅ | CRUD workflows | Cualquier proyecto |
| Rule | ✅ | CRUD reglas | Cualquier proyecto |
| TaskTemplate | ✅ | CRUD plantillas | Cualquier proyecto |
| Task | ✅ | CRUD todas las tareas | Cualquier proyecto |
| **Metrics (org)** | 📖 | Ver métricas de toda la org | Overview + por proyecto |
| **RuleMetrics (org)** | 📖 | Ver métricas de reglas org | Todos los proyectos |

**Navegación Org Admin:**
```
/app
├── Pool/Lista/Fichas (trabajo)
├── Mis tareas (panel derecho)
├── Mis fichas (panel derecho)
└── Mi perfil (panel derecho)

/config (sidebar izquierdo, sección CONFIGURACIÓN)
├── /config/members        → Miembros del proyecto seleccionado
├── /config/capabilities   → Capacidades del proyecto
├── /config/task-types     → Tipos de tarea del proyecto
├── /config/cards          → Fichas del proyecto
├── /config/workflows      → Automatizaciones del proyecto
├── /config/templates      → Plantillas del proyecto
└── /config/rule-metrics   → Métricas de reglas (proyecto)

/org (sidebar izquierdo, sección ORGANIZACIÓN)
├── /org/invites           → Links de invitación
│   ├── Lista de invitaciones
│   ├── [+ Crear invitación]
│   ├── [Copiar link]
│   ├── [Regenerar]
│   └── [Eliminar]
│
├── /org/settings          → Configuración de organización
│   └── Formulario de edición
│
├── /org/users             → Usuarios de la organización
│   ├── Lista de usuarios
│   ├── Cambiar rol org (dropdown Admin/Member)
│   ├── → Ver proyectos del usuario
│   │   ├── Lista de proyectos asignados
│   │   ├── [+ Asignar a proyecto]
│   │   ├── Cambiar rol en proyecto
│   │   └── [Quitar de proyecto]
│   └── [Eliminar de org] (confirmar)
│
├── /org/projects          → Proyectos
│   ├── Lista de proyectos
│   ├── [+ Crear proyecto]
│   ├── [Editar]
│   └── [Eliminar] (confirmar)
│
├── /org/metrics           → Métricas de organización
│   ├── Overview (resumen)
│   └── Por proyecto (drill-down)
│
└── /org/rule-metrics      → Métricas de reglas (org-wide)
    └── Todos los proyectos
```

---

## 3. Flujos de Navegación Detallados

### 3.1 Flujo: PM asigna capacidad a un miembro

```
1. PM está en /app (Pool view)
2. Click "Equipo" en sidebar → Carga /config/members en panel central
3. Ve lista de miembros con sus roles
4. Click en icono "Capacidades" de un miembro
5. Se abre modal con:
   - Capacidades del proyecto (checkboxes)
   - Capacidades ya asignadas (checked)
6. Marca/desmarca capacidades
7. Click "Guardar"
8. Modal se cierra, miembro actualizado
```

**Wireframe:**
```
┌─ Panel Central ─────────────────────────────────────────────┐
│ 👥 MIEMBROS - Project Alpha                  [+ Añadir]     │
├─────────────────────────────────────────────────────────────┤
│ USUARIO           │ ROL        │ CAPACIDADES │ ACCIONES     │
├───────────────────┼────────────┼─────────────┼──────────────┤
│ admin@example.com │ [Manager▼] │ 3 caps      │ [⚙️] [🗑️]    │
│ pm@example.com    │ [Manager▼] │ 2 caps      │ [⚙️] [🗑️]    │
│ member@example.com│ [Miembro▼] │ 1 cap       │ [⚙️] [🗑️]    │
└─────────────────────────────────────────────────────────────┘
         ↓ Click [⚙️]
┌─ Modal: Capacidades de member@example.com ──────────────────┐
│                                                              │
│   [✓] Frontend                                               │
│   [ ] Backend                                                │
│   [ ] QA                                                     │
│   [ ] DevOps                                                 │
│                                                              │
│                              [Cancelar] [Guardar]            │
└──────────────────────────────────────────────────────────────┘
```

---

### 3.2 Flujo: Org Admin añade usuario a un proyecto

```
1. Admin está en /app
2. Click "Usuarios" en sidebar → Carga /org/users
3. Ve lista de usuarios de la org
4. Click en "Ver proyectos" de un usuario
5. Carga /org/users/:id/projects
6. Ve proyectos donde está el usuario
7. Click [+ Asignar a proyecto]
8. Modal con proyectos disponibles
9. Selecciona proyecto y rol
10. Click "Asignar"
```

**Wireframe:**
```
┌─ Panel Central ─────────────────────────────────────────────┐
│ 👤 PROYECTOS DE member@example.com           [+ Asignar]    │
│ ← Volver a usuarios                                         │
├─────────────────────────────────────────────────────────────┤
│ PROYECTO        │ ROL          │ DESDE        │ ACCIONES    │
├─────────────────┼──────────────┼──────────────┼─────────────┤
│ Project Alpha   │ [Miembro ▼]  │ hace 5 días  │ [🗑️]        │
│ Project Beta    │ [Manager ▼]  │ hace 2 días  │ [🗑️]        │
└─────────────────────────────────────────────────────────────┘
         ↓ Click [+ Asignar]
┌─ Modal: Asignar a proyecto ─────────────────────────────────┐
│                                                              │
│   Proyecto                                                   │
│   ┌──────────────────────────────────────────────────────┐  │
│   │ Project Gamma                                      ▼ │  │
│   └──────────────────────────────────────────────────────┘  │
│                                                              │
│   Rol en el proyecto                                         │
│   ( ) Manager                                                │
│   (●) Miembro                                                │
│                                                              │
│                              [Cancelar] [Asignar]            │
└──────────────────────────────────────────────────────────────┘
```

---

### 3.3 Flujo: PM crea una ficha con tareas desde plantilla

```
1. PM en /app (Pool view)
2. Click "Fichas" en sidebar → /config/cards
3. Click [+ Crear ficha]
4. Modal de creación:
   - Nombre de la ficha
   - Opción: "Crear desde plantilla"
5. Selecciona plantilla
6. Se crean tareas automáticamente
7. Ficha aparece en lista
```

---

### 3.4 Flujo: Member reclama y trabaja en una tarea

```
1. Member en /app/pool
2. Ve tareas disponibles
3. Click en tarea → Se abre detalle en panel derecho
4. Click [Reclamar]
5. Tarea aparece en "Mis tareas" (panel derecho)
6. Click [▶ Empezar] → Timer comienza
7. Trabaja...
8. Click [✓ Completar]
9. Tarea sale de "Mis tareas"
```

---

## 4. Propuesta de Estructura de URLs

### URLs Nuevas (Shell Unificado)

```
# Trabajo (todos los roles)
/app                        → Pool view (default)
/app?view=list              → List view
/app?view=cards             → Kanban fichas
/app?project=17             → Proyecto específico
/app?project=17&view=list   → Combinado

# Configuración de proyecto (PM + Org Admin)
/config/members             → Miembros del proyecto
/config/capabilities        → Capacidades
/config/task-types          → Tipos de tarea
/config/cards               → Fichas (CRUD, no kanban)
/config/workflows           → Workflows
/config/workflows/:id       → Reglas de un workflow
/config/templates           → Plantillas de tarea
/config/metrics             → Métricas del proyecto (futuro)
/config/rule-metrics        → Métricas de reglas

# Organización (solo Org Admin)
/org/invites                → Invitaciones
/org/settings               → Configuración org
/org/users                  → Usuarios de la org
/org/users/:id/projects     → Proyectos de un usuario
/org/projects               → Proyectos (CRUD)
/org/metrics                → Métricas de org
/org/rule-metrics           → Métricas de reglas org
```

### URLs a Deprecar (Redirects)

```
/admin/invites       → /org/invites
/admin/org           → /org/settings
/admin/projects      → /org/projects
/admin/metrics       → /org/metrics
/admin/rule-metrics  → /org/rule-metrics (o /config/rule-metrics según contexto)
/admin/members       → /config/members
/admin/capabilities  → /config/capabilities
/admin/task-types    → /config/task-types
/admin/cards         → /config/cards
/admin/workflows     → /config/workflows
/admin/templates     → /config/templates
```

---

## 5. Sidebar Unificado por Rol

### 5.1 Member

```
┌──────────────────────────┐
│ Project Alpha        [▼] │
├──────────────────────────┤
│ TRABAJO                  │
│ ┌──────────────────────┐ │
│ │   + Nueva tarea      │ │
│ └──────────────────────┘ │
├──────────────────────────┤
│ (sin más secciones)      │
└──────────────────────────┘
```

### 5.2 PM

```
┌──────────────────────────┐
│ Project Alpha        [▼] │
├──────────────────────────┤
│ TRABAJO                  │
│ ┌──────────────────────┐ │
│ │   + Nueva tarea      │ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │   + Nueva ficha      │ │
│ └──────────────────────┘ │
├──────────────────────────┤
│ CONFIGURACIÓN        [▾] │
│   👥 Equipo              │
│   🎯 Capacidades         │
│   🏷️ Tipos de tarea      │
│   📋 Fichas              │
│   ⚡ Automatizaciones    │
│   📄 Plantillas          │
│   📊 Métricas de reglas  │
└──────────────────────────┘
```

### 5.3 Org Admin

```
┌──────────────────────────┐
│ Project Alpha        [▼] │
├──────────────────────────┤
│ TRABAJO                  │
│ ┌──────────────────────┐ │
│ │   + Nueva tarea      │ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │   + Nueva ficha      │ │
│ └──────────────────────┘ │
├──────────────────────────┤
│ CONFIGURACIÓN        [▾] │
│   👥 Equipo              │
│   🎯 Capacidades         │
│   🏷️ Tipos de tarea      │
│   📋 Fichas              │
│   ⚡ Automatizaciones    │
│   📄 Plantillas          │
│   📊 Métricas de reglas  │
├──────────────────────────┤
│ ORGANIZACIÓN         [▾] │
│   ✉️ Invitaciones    (2) │
│   🏢 Configuración       │
│   👤 Usuarios            │
│   📁 Proyectos       (3) │
│   📈 Métricas org        │
│   📊 Métricas reglas org │
└──────────────────────────┘
```

---

## 6. Resumen de Cambios Necesarios

### 6.1 Cambios de Arquitectura

| Cambio | Descripción | Impacto |
|--------|-------------|---------|
| **Shell unificado** | Un solo layout 3 paneles para toda la app | Alto |
| **Nuevas rutas /config** | Migrar CRUD de proyecto a nuevas URLs | Medio |
| **Nuevas rutas /org** | Migrar CRUD de org a nuevas URLs | Medio |
| **Redirects /admin** | Mantener backwards compatibility | Bajo |
| **Carga en panel central** | CRUD carga en panel central, no página nueva | Alto |
| **Persistencia de contexto** | Proyecto seleccionado persiste en config/org | Medio |

### 6.2 Componentes a Crear/Migrar

| Componente | Estado Actual | Migración |
|------------|---------------|-----------|
| MembersView | En admin/view.gleam | Extraer a config/members.gleam |
| CapabilitiesView | En admin/view.gleam | Extraer a config/capabilities.gleam |
| TaskTypesView | En admin/view.gleam | Extraer a config/task_types.gleam |
| CardsView | En admin/view.gleam | Extraer a config/cards.gleam |
| WorkflowsView | En admin/view.gleam | Extraer a config/workflows.gleam |
| TemplatesView | En admin/view.gleam | Extraer a config/templates.gleam |
| InvitesView | En admin/view.gleam | Extraer a org/invites.gleam |
| OrgSettingsView | En admin/view.gleam | Extraer a org/settings.gleam |
| OrgUsersView | Nuevo | Crear org/users.gleam |
| OrgProjectsView | Nuevo | Crear org/projects.gleam |
| OrgMetricsView | En admin/view.gleam | Extraer a org/metrics.gleam |
| RuleMetricsView | En admin/view.gleam | Extraer, duplicar para config y org |

---

## 7. Matriz de Visibilidad de Acciones

### En el Panel Central (según vista)

| Vista | Member | PM | Org Admin |
|-------|--------|-----|-----------|
| Pool/Lista/Fichas | Ver, reclamar, completar | + Editar todas, eliminar | = PM |
| /config/members | ❌ | Ver, añadir, cambiar rol, quitar, asignar caps | = PM |
| /config/capabilities | ❌ | CRUD | = PM |
| /config/task-types | ❌ | CRUD | = PM |
| /config/cards | ❌ | CRUD | = PM |
| /config/workflows | ❌ | CRUD (y reglas) | = PM |
| /config/templates | ❌ | CRUD | = PM |
| /config/rule-metrics | ❌ | Ver (proyecto) | Ver (proyecto) |
| /org/invites | ❌ | ❌ | CRUD |
| /org/settings | ❌ | ❌ | Editar |
| /org/users | ❌ | ❌ | Ver, cambiar rol org, ver proyectos |
| /org/users/:id/projects | ❌ | ❌ | Asignar, cambiar rol, quitar |
| /org/projects | ❌ | ❌ | CRUD |
| /org/metrics | ❌ | ❌ | Ver |
| /org/rule-metrics | ❌ | ❌ | Ver (org-wide) |

---

**Documento preparado por Sally (UX Expert)**
*"Design for Real Scenarios - Consider edge cases, errors, and loading states"*
