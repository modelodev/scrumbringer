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

**Filosofía:** La plataforma visibiliza, la comunicación humana resuelve. La unidad atómica es la tarea; fichas y procesos son implícitos y derivan de reglas y estados de tareas.

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

### Diferenciador core

- Pull real: sin asignación directa, el equipo auto-selecciona y asume responsabilidad.
- Pool vivo: prioridad + decay visual evita backlog muerto y mantiene foco en flujo.
- Trabajo real visible: separa “en curso” vs “claimed” vs “disponible” para claridad operativa.
- Minimalismo documental: tarjetas y tareas con texto breve y/o enlaces para forzar uso de sistemas externos.
- Motor de reglas: no se modelan procesos; solo reglas que reaccionan a cambios de estado de tareas y crean nuevas tareas.
- Estado implícito de fichas: el estado de una ficha se deriva del estado de sus tareas, no se gestiona aparte.

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
| **Motor de reglas** | Reglas que reaccionan a cambios de estado de tareas y crean nuevas tareas |
| **Estado implícito de fichas** | Estado de ficha derivado del estado de sus tareas |

### OUT (Later)

| Feature | Versión |
|---------|---------|
| Multi-organización | v1.1 |
| Múltiples proyectos | v1.1 |
| Jerarquía (fichas/historias) | v1.1 |
| Workflows/reglas | Implementado |
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

### Estado Personal: "Now Working" / Time Tracking (Servidor)

- El usuario puede tener **0..N** tareas **en curso** (“Now Working”) simultáneamente (global, no por proyecto).
- Este estado sigue siendo **personal** (no cambia `tasks.status`), pero habilita derivar un estado **por tarea** (p.ej. `ongoing`) para comunicar “hay alguien trabajando ahora mismo” y **quién**.
- Regla de negocio (cerrada): una tarea solo puede estar **claimed por 1 usuario**; por tanto, **solo** el claimer puede iniciar trabajo en esa tarea.
- La información se **persiste en servidor** para que sea consistente entre dispositivos (desktop/mobile).
- Acciones personales soportadas (mínimo):
  - `start/resume`: inicia (o reanuda) trabajo en una tarea **claimed por el usuario**.
  - `pause`: pausa trabajo en **esa** tarea.
- Regla: hacer `start` en una tarea **NO** reemplaza ni pausa automáticamente otras tareas en curso del usuario.
- Regla: cambiar de proyecto en la UI **NO** debe “limpiar” automáticamente el trabajo en curso (es global); la UI puede filtrar/mostrar la lista por proyecto si lo necesita.
- Acciones globales relacionadas (ya existentes en tareas claimed): `complete`, `release`.
- **Implicación UX (MVP):** “Now Working” debe soportar **múltiples entradas** (lista), no solo una tarjeta:
  - Desktop: HUD/panel con lista de tareas en curso + cronómetro por tarea.
  - Mobile: no se muestra el Pool; solo My Bar + lista Now Working + acciones rápidas (start/pause/complete/release).

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

### Diferencial de métricas por diseño del flujo

- **Pull medible**: claim/release/complete capturan el comportamiento real de auto-selección.
- **Trabajo real vs asignado**: sesiones activas permiten distinguir “en curso” de “claimed”.
- **Diagnóstico granular**: métricas por proyecto y por tarea (claim_count, release_count, first_claim_at).
- **Calidad del flujo**: time_to_first_claim y pool_flow_ratio como señales directas de salud del pool.

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
