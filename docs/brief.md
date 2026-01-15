# Project Brief: ScrumBringer

> **Versión:** 2.0
> **Fecha:** 2026-01-12
> **Estado:** Revisado - MVP recortado

---

## Executive Summary

**ScrumBringer** es un gestor de tareas ágil basado en **pool compartido con auto-asignación**. Las tareas se "arrojan" a un pool común y los miembros del equipo las "cogen" según sus capacidades.

**Problema:** Las herramientas actuales (Jira, Asana, Trello) asumen asignación directa, generando micro-gestión y cuellos de botella.

**Propuesta de valor:**
- Pool visual con prioridad (tamaño) y antigüedad (decay)
- Auto-asignación nativa - sin campo "Assignee"
- Cada usuario organiza SU vista del pool

**Filosofía:** La plataforma visibiliza, la comunicación humana resuelve.

---

## Problem Statement

Los equipos usan herramientas con modelo "push" (asignación directa) que genera:

1. **Cuello de botella en el asignador** - PM decide todo
2. **Pérdida de autonomía** - developers reciben trabajo, no lo eligen
3. **Backlog estático** - tareas viejas se ven igual que nuevas
4. **Difusión de responsabilidad** - "me lo asignaron" vs "lo elegí"

**Impacto validado:**
- Sistemas Pull reducen tiempos de ciclo ~40% (Lean/Kanban)
- Auto-selección aumenta compromiso (Teoría Autodeterminación)

---

## Proposed Solution

### Pilares

1. **Pool con Auto-Asignación:** Tareas sin "Assignee" hasta que alguien las coge
2. **Gamificación Visual:** Tamaño = prioridad, Decay = antigüedad
3. **Posiciones por Usuario:** Cada uno organiza su vista del pool
4. **Capacidades:** Filtrado por skills

### Diferenciador

| Tradicional | ScrumBringer |
|-------------|--------------|
| Push (asignación) | Pull (auto-selección) |
| Listas estáticas | Pool visual con decay |
| Cualquiera edita | Solo quien tiene la tarea |

---

## Target Users

**Primario:** Equipos ágiles de desarrollo (5-20 personas) frustrados con micro-gestión.

**Roles:**
- Developer: coge tareas, ejecuta
- Tech Lead: crea tareas, ve flujo
- Scrum Master: monitorea salud del pool

---

## MVP Scope v1.0

### IN (MVP)

| Feature | Detalle |
|---------|---------|
| **Crear tarea** | Título, descripción, prioridad, tipo |
| **Tipos de tarea** | Con icono (heroicons o similar) |
| **Capacidades** | Definir skills; usuarios eligen las suyas |
| **Filtros** | Por capacidad y tipo |
| **Pool** | Ver tareas disponibles |
| **Posiciones por usuario** | Cada uno arrastra a su posición |
| **Claim** | Coger tarea del pool |
| **Release** | Devolver tarea al pool |
| **Complete** | Marcar como hecha |
| **Prioridad visual** | Tamaño según prioridad |
| **Decay visual** | Efecto + días por antigüedad |
| **Mi barra** | Tareas cogidas |
| **Notas** | Append-only |
| **Auth** | Email/password |
| **1 org, múltiples proyectos** | Un usuario pertenece a 1 org y puede participar en varios proyectos dentro de esa org |
| **Responsive** | Mobile-friendly |

### OUT (Later)

| Feature | Versión |
|---------|---------|
| Multi-organización | v1.1 |
| Múltiples proyectos | v1.1 |
| Jerarquía (fichas/historias) | v1.1 |
| Workflows/reglas | v1.1+ |
| Sprints | v1.2 |
| Posiciones compartidas | Evaluar post-MVP |
| Integraciones | v1.2+ |

### UI/UX Rules (MVP)

- **Pool** muestra **solo** tareas `available` (libres). Las tareas `claimed`/`completed` no aparecen en el Pool.
- **Mi barra (My Bar)** muestra las tareas **cogidas por mí** y se presenta como **lista ordenada** (no flotante):
  - Orden: `priority` desc → `status` → `created_at` desc.
- **My Skills** es una vista personal (no flotante) con filas alineadas: nombre a la izquierda, checkbox a la derecha.
- En las tarjetas del Pool, los affordances críticos son siempre visibles y usables (aunque la tarjeta sea pequeña):
  - Acción de Claim/Release/Complete (según estado) y el handle de drag.

### Estado Personal: "Now Working" (Servidor)

- El usuario puede tener **0 o 1** tarea **activa** (global, no por proyecto).
- Este estado es **personal** (no cambia `tasks.status`). Sirve para que el usuario sepa con qué está y cuánto tiempo lleva **en la sesión activa**.
- La información se **persiste en servidor** para que sea consistente entre dispositivos (desktop/mobile).
- Acciones personales soportadas (mínimo):
  - `start/resume`: empieza una sesión activa para una tarea claimed.
  - `pause`: termina la sesión activa y **limpia** la tarea activa.
- Regla: hacer `start` en una nueva tarea **reemplaza** la anterior (la anterior deja de estar activa).
- Regla: si el usuario cambia el proyecto activo en la UI, la tarea activa se **desactiva** (limpia).
- Acciones globales relacionadas (ya existentes en tareas claimed): `complete`, `release`.
- **Mobile** requiere UX específica: no se muestra el Pool; solo My Bar + acciones rápidas (start/pause/complete/release) y el cronómetro.

### Acceptance Criteria: No Asignación Directa

- **AC1:** No existe campo "Assignee" en UI
- **AC2:** No existe endpoint para asignar a otro usuario
- **AC3:** Solo el usuario puede hacer Claim para sí mismo
- **AC4:** Para editar tarea (excepto notas), debe estar claimed por ti

---

## Scope Organizacional (MVP)

- Un **usuario pertenece a exactamente 1 organización**.
- Una organización puede tener **múltiples proyectos**.
- Un usuario puede estar en **múltiples proyectos** dentro de su organización.
- **La membresía a proyectos la gestiona un admin** (no auto-join en MVP).

---

## Métricas MVP

| KPI | Target |
|-----|--------|
| **time_to_first_claim** | < 4h (P50) |
| **pool_flow_ratio** | > 0.8 |
| **release_rate** | < 15% |

---

## Decisiones de Arquitectura (P0)

| Decisión | Resultado |
|----------|-----------|
| **Stack** | Cliente Lustre (TEA, `target=javascript`) + API Gleam (BEAM, `target=erlang`) |
| **Posiciones pool** | Por usuario (no compartidas) |
| **Concurrencia** | Server = source of truth (DB), optimistic UI, `version` field |
| **Conflictos claim** | First-write-wins |
| **Auth** | Email/password + JWT cookie + Argon2 |

Ver `docs/architecture.md` para detalles técnicos.

---

## Risks

| Riesgo | Mitigación |
|--------|------------|
| Madurez Lustre | Spike técnico temprano |
| Drag & drop + optimistic sync (client/server) | Optimistic UI + reconciliación por `version` |
| Cherry-picking | Decay visual + comunicación externa |
| Scope creep | MVP disciplinado |

---

## Next Steps

1. **Spike técnico:** Lustre + drag & drop + 100 tareas
2. **Setup proyecto:** Repo, CI, estructura
3. **Implementar auth:** Email/password básico
4. **Pool básico:** CRUD tareas + claim/release
5. **Visual:** Prioridad (tamaño) + decay

---

## Referencias

- `docs/architecture.md` - Arquitectura técnica
- `docs/architecture/tech-stack.md` - Stack tecnológico
- `docs/architecture/data-model.md` - Modelo de datos
- `.bmad-core/` - Documentación original (2016)
