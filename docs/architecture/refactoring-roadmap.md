# Refactoring Roadmap
## Scrumbringer Server - Gleam Codebase

> **Version:** 2.0
> **Fecha:** 2026-01-20
> **Arquitecto:** Winston
> **Baseline:** 62 ficheros analizados en `apps/server/src/`
> **Actualizado:** Priorización de tests tras Architect Validation

---

## Resumen Ejecutivo

| Métrica | Valor |
|---------|-------|
| Total de mejoras identificadas | 16 |
| Líneas de código afectadas (est.) | ~2,500 |
| Líneas eliminables por DRY (est.) | ~450 |
| Fases propuestas | **5** (0-4) |
| Duración estimada total | 5-7 sprints |

---

## Principios Guía del Refactoring

1. **Test-First** - **CRÍTICO:** Añadir tests ANTES de refactorizar (Fase 0)
2. **Zero Breaking Changes** - Mantener compatibilidad API en todo momento
3. **Incremental Delivery** - Cada fase entrega valor independiente
4. **Shared-First** - Consolidar en `shared/` antes de refactorizar consumidores

---

## FASE 0: Test Foundation (PREREQUISITO)

**Objetivo:** Establecer red de seguridad de tests antes de cualquier refactoring
**Duración:** 1 sprint
**Riesgo:** Bajo (no modifica código existente)
**Dependencias:** Ninguna
**Prioridad:** 🔴 **CRÍTICA** - Bloquea Fases 1-4

> ⚠️ **ADVERTENCIA:** El Architect Validation Report identificó **CERO tests** en el servidor.
> Ejecutar refactoring sin tests es un riesgo inaceptable de regresiones.

### 0.1 Infraestructura de Testing

**Prioridad:** CRÍTICA
**Impacto:** Habilita todo el refactoring posterior

```
Tareas:
├─ [ ] Verificar configuración gleam test en apps/server/
├─ [ ] Crear estructura de directorios test/
│      apps/server/test/
│      ├─ unit/
│      │   ├─ services/
│      │   └─ http/
│      └─ integration/
├─ [ ] Añadir dependencias de test si es necesario
├─ [ ] Crear helper test/support/test_helpers.gleam
│      - Factory functions para crear datos de test
│      - Mock de pog.Connection si es necesario
├─ [ ] Verificar CI ejecuta tests (make test)
└─ [ ] Documentar patrón de testing en CONTRIBUTING.md
```

---

### 0.2 Tests de Critical Path (Claim/Release/Complete)

**Prioridad:** CRÍTICA
**Impacto:** Protege el flujo principal de negocio

```
Tareas:
├─ [ ] test/unit/services/tasks_db_test.gleam
│      - test "claim_task succeeds for available task"
│      - test "claim_task fails for already claimed task"
│      - test "claim_task fails with version mismatch"
│      - test "release_task succeeds for claimer"
│      - test "release_task fails for non-claimer"
│      - test "complete_task succeeds for claimer"
│      - test "complete_task fails for non-claimer"
├─ [ ] test/integration/task_lifecycle_test.gleam
│      - test "full lifecycle: create → claim → complete"
│      - test "full lifecycle: create → claim → release → claim"
└─ [ ] Verificar tests pasan en CI
```

---

### 0.3 Tests de Authorization

**Prioridad:** ALTA
**Impacto:** Protege lógica de permisos que será refactorizada en Fase 1

```
Tareas:
├─ [ ] test/unit/http/auth_test.gleam
│      - test "require_current_user returns user for valid session"
│      - test "require_current_user returns error for invalid session"
├─ [ ] test/unit/services/projects_db_test.gleam
│      - test "is_project_member returns true for member"
│      - test "is_project_member returns false for non-member"
│      - test "is_project_admin returns true for admin"
│      - test "is_project_admin returns false for member"
└─ [ ] Verificar tests pasan en CI
```

---

### 0.4 Tests de Workflows (área de mayor complejidad)

**Prioridad:** ALTA
**Impacto:** Protege lógica compleja que será refactorizada en Fases 2-3

```
Tareas:
├─ [ ] test/unit/services/workflows_db_test.gleam
│      - test "create_workflow succeeds with valid data"
│      - test "create_workflow fails for duplicate name"
│      - test "update_workflow succeeds for existing workflow"
│      - test "set_active_cascade deactivates children"
│      - test "delete_workflow fails if has rules"
├─ [ ] test/unit/services/rules_engine_test.gleam
│      - test "evaluate_rule applies matching rule"
│      - test "evaluate_rule skips inactive rule"
│      - test "evaluate_rule handles idempotent suppression"
└─ [ ] Verificar tests pasan en CI
```

---

### 0.5 Tests de JSON Helpers (código a extraer en Fase 1)

**Prioridad:** MEDIA
**Impacto:** Documenta comportamiento esperado antes de mover código

```
Tareas:
├─ [ ] test/unit/presenters_test.gleam
│      - test "option_int_json returns null for None"
│      - test "option_int_json returns int for Some"
│      - test "option_string_json returns null for None"
│      - test "option_string_json returns string for Some"
├─ [ ] test/unit/mappers_test.gleam
│      - test "int_to_option returns None for 0"
│      - test "int_to_option returns Some for non-zero"
│      - test "string_to_option returns None for empty"
│      - test "string_to_option returns Some for non-empty"
└─ [ ] Verificar tests pasan en CI
```

---

### Milestone Fase 0

- [ ] Estructura `test/` creada y documentada
- [ ] **≥15 tests** cubriendo critical path
- [ ] CI ejecuta tests automáticamente
- [ ] Test coverage de:
  - [ ] Task lifecycle (claim/release/complete)
  - [ ] Authorization (project member/admin)
  - [ ] Workflows CRUD
  - [ ] JSON helpers

**Gate:** Fase 0 DEBE completarse antes de iniciar Fase 1.

---

## FASE 1: Fundamentos DRY

**Objetivo:** Eliminar duplicación crítica y establecer módulos compartidos
**Duración:** 1-2 sprints
**Riesgo:** Bajo (con tests de Fase 0)
**Dependencias:** **Fase 0 completada**

### 1.1 Crear `shared/src/helpers/json.gleam`

**Prioridad:** ALTA
**Impacto:** 5+ ficheros, ~60 líneas eliminadas

```
Tareas:
├─ [ ] Crear módulo shared/src/helpers/json.gleam
├─ [ ] Implementar option_to_json(value, encoder)
├─ [ ] Implementar option_int_json(value)
├─ [ ] Implementar option_string_json(value)
├─ [ ] Añadir tests unitarios en shared/test/
├─ [ ] Migrar http/tasks/presenters.gleam (hacer imports públicos)
├─ [ ] Migrar http/workflows.gleam
├─ [ ] Migrar http/task_templates.gleam
├─ [ ] Eliminar funciones duplicadas locales
├─ [ ] Ejecutar tests de Fase 0 (regression check)
└─ [ ] Verificar build + tests
```

**Ficheros a modificar:**
- `http/workflows.gleam` - eliminar líneas 507-518
- `http/task_templates.gleam` - eliminar líneas 429-441
- `http/tasks/presenters.gleam` - re-exportar desde shared

---

### 1.2 Crear `shared/src/helpers/option.gleam`

**Prioridad:** ALTA
**Impacto:** 7+ ficheros, ~80 líneas eliminadas

```
Tareas:
├─ [ ] Crear módulo shared/src/helpers/option.gleam
├─ [ ] Implementar int_to_option(value) // 0 → None
├─ [ ] Implementar string_to_option(value) // "" → None
├─ [ ] Documentar el comportamiento con advertencias sobre valores legítimos
├─ [ ] Añadir tests unitarios
├─ [ ] Migrar services/rules_db.gleam
├─ [ ] Migrar services/rules_engine.gleam
├─ [ ] Migrar services/workflows_db.gleam
├─ [ ] Migrar services/rule_metrics_db.gleam
├─ [ ] Migrar persistence/tasks/mappers.gleam
├─ [ ] Migrar services/task_types_db.gleam
├─ [ ] Migrar services/org_invite_links_db.gleam
├─ [ ] Ejecutar tests de Fase 0 (regression check)
└─ [ ] Verificar build + tests
```

---

### 1.3 Crear `http/authorization.gleam`

**Prioridad:** ALTA
**Impacto:** 4+ ficheros, ~100 líneas eliminadas

```
Tareas:
├─ [ ] Crear módulo http/authorization.gleam
├─ [ ] Implementar require_scoped_admin(db, user, org_id, project_id)
├─ [ ] Implementar require_resource_admin(db, user, resource) genérico
├─ [ ] Añadir tests unitarios
├─ [ ] Migrar http/workflows.gleam (require_workflow_admin)
├─ [ ] Migrar http/task_templates.gleam (require_template_admin)
├─ [ ] Migrar services/workflows/authorization.gleam
├─ [ ] Eliminar funciones duplicadas
├─ [ ] Ejecutar tests de Fase 0 (regression check)
└─ [ ] Verificar build + tests
```

**Interfaz propuesta:**

```gleam
pub fn require_scoped_admin(
  db: pog.Connection,
  user: StoredUser,
  org_id: Int,
  project_id: Option(Int),
) -> Result(#(Int, Option(Int)), wisp.Response)
```

---

### 1.4 Unificar `single_query_value`

**Prioridad:** MEDIA
**Impacto:** 2 ficheros, ~20 líneas eliminadas

```
Tareas:
├─ [ ] Mover a http/query_helpers.gleam o shared
├─ [ ] Migrar http/tasks/filters.gleam
├─ [ ] Migrar http/task_positions.gleam
└─ [ ] Verificar build
```

---

### Milestone Fase 1

- [ ] `shared/src/helpers/json.gleam` en uso
- [ ] `shared/src/helpers/option.gleam` en uso
- [ ] `http/authorization.gleam` en uso
- [ ] Build pasa sin warnings
- [ ] **Todos los tests de Fase 0 siguen pasando**
- [ ] ~260 líneas de código eliminadas

---

## FASE 2: Type Safety

**Objetivo:** Eliminar sentinel values y fortalecer el sistema de tipos
**Duración:** 1-2 sprints
**Riesgo:** Medio
**Dependencias:** Fase 1 completada

### 2.1 Crear tipo `FieldUpdate(a)` para updates parciales

**Prioridad:** ALTA
**Impacto:** Elimina `"__unset__"` y `-1` como sentinelas

```
Tareas:
├─ [ ] Crear shared/src/domain/field_update.gleam
│      pub type FieldUpdate(a) {
│        Keep           // Campo no enviado
│        Set(a)         // Nuevo valor
│        Clear          // Establecer a null (si aplica)
│      }
├─ [ ] Crear decoder para FieldUpdate
├─ [ ] Añadir tests para FieldUpdate
├─ [ ] Refactorizar http/workflows.gleam update_workflow
├─ [ ] Refactorizar http/task_templates.gleam update_template
├─ [ ] Refactorizar http/rules.gleam update handlers
├─ [ ] Actualizar services/workflows/types.gleam (eliminar unset_string)
├─ [ ] Actualizar services/workflows/validation.gleam
├─ [ ] Ejecutar tests de Fase 0 (regression check)
└─ [ ] Verificar build + tests
```

**Antes (problemático):**

```gleam
use name <- decode.optional_field("name", "__unset__", decode.string)
case name { "__unset__" -> ... }
```

**Después (type-safe):**

```gleam
use name <- decode.optional_field("name", Keep, field_update_decoder(decode.string))
case name { Keep -> ... | Set(value) -> ... }
```

---

### 2.2 Mover `CardState` a shared/domain

**Prioridad:** MEDIA
**Impacto:** Compartir tipos entre cliente y servidor

```
Tareas:
├─ [ ] Crear shared/src/domain/card_state.gleam
├─ [ ] Mover CardState { Pendiente, EnCurso, Cerrada }
├─ [ ] Mover derive_card_state function
├─ [ ] Mover state_to_string function
├─ [ ] Actualizar services/cards_db.gleam para importar
├─ [ ] Actualizar cliente si existe
└─ [ ] Verificar build
```

---

### 2.3 Usar `ResourceType` ADT consistentemente

**Prioridad:** MEDIA
**Impacto:** Eliminar validación string manual

```
Tareas:
├─ [ ] Asegurar ResourceType exportado desde rules_engine.gleam
├─ [ ] Refactorizar services/rules_db.gleam
│      - Eliminar string_to_resource_type
│      - Usar ResourceType directamente
├─ [ ] Actualizar HTTP handlers para parsear a ResourceType
└─ [ ] Verificar build
```

---

### Milestone Fase 2

- [ ] Cero uso de `"__unset__"` en codebase
- [ ] Cero uso de `-1` como "no enviado"
- [ ] `CardState` en shared/domain
- [ ] Type coverage mejorado
- [ ] **Todos los tests siguen pasando**

---

## FASE 3: Arquitectura HTTP

**Objetivo:** Simplificar handlers y reducir pyramid of doom
**Duración:** 1 sprint
**Riesgo:** Medio
**Dependencias:** Fase 1, Fase 2 completadas

### 3.1 Crear middleware pattern con `use`

**Prioridad:** ALTA
**Impacto:** Reducir anidamiento de 7 a 2-3 niveles

```
Tareas:
├─ [ ] Crear http/middleware.gleam
├─ [ ] Implementar require_auth como callback
│      pub fn require_auth(req, ctx, next: fn(StoredUser) -> Response)
├─ [ ] Implementar parse_int_param como callback
├─ [ ] Implementar require_csrf como callback
├─ [ ] Documentar patrón de uso
├─ [ ] Añadir tests para middleware
├─ [ ] Refactorizar http/workflows.gleam handlers
├─ [ ] Refactorizar http/task_templates.gleam handlers
├─ [ ] Refactorizar http/rules.gleam handlers
├─ [ ] Ejecutar tests de Fase 0 (regression check)
└─ [ ] Verificar build + tests
```

**Patrón objetivo:**

```gleam
fn handle_update(req, ctx, workflow_id) {
  use user <- middleware.require_auth(req, ctx)
  use workflow_id <- middleware.parse_int(workflow_id, "workflow_id")
  use <- middleware.require_csrf(req)
  use workflow <- get_workflow(db, workflow_id)
  use #(org_id, pid) <- require_admin(db, user, workflow)
  do_update(req, ctx, workflow_id, org_id, pid)
}
```

---

### 3.2 Crear `api.from_result` helper

**Prioridad:** MEDIA
**Impacto:** Reducir boilerplate de error handling

```
Tareas:
├─ [ ] Añadir a http/api.gleam
│      pub fn from_db_result(result, ok_handler)
│      pub fn map_common_errors(error) -> Response
├─ [ ] Documentar mapeo de errores estándar
├─ [ ] Aplicar en handlers existentes
└─ [ ] Verificar build
```

---

### 3.3 Mover lógica de negocio de handlers a servicios

**Prioridad:** MEDIA
**Impacto:** Mejor separación de concerns

```
Tareas:
├─ [ ] Identificar lógica en http/workflows.gleam:310-455
├─ [ ] Mover cascade logic a workflows_db.gleam
├─ [ ] Handler solo debe: parse → validate → call service → format response
└─ [ ] Verificar build + tests
```

---

### Milestone Fase 3

- [ ] Máximo 3 niveles de anidamiento en handlers
- [ ] Middleware pattern documentado y en uso
- [ ] Handlers son thin wrappers sobre servicios
- [ ] **Todos los tests siguen pasando**

---

## FASE 4: SQL y Documentación

**Objetivo:** SQL tipado, constantes consolidadas, documentación completa
**Duración:** 1 sprint
**Riesgo:** Bajo
**Dependencias:** Fases 0-3 completadas

### 4.1 Migrar SQL inline a ficheros .sql

**Prioridad:** MEDIA
**Impacto:** Type safety, mantenibilidad

```
Tareas:
├─ [ ] Crear queries/work_sessions.sql
├─ [ ] Migrar queries de services/work_sessions_db.gleam
├─ [ ] Crear queries/password_resets.sql
├─ [ ] Migrar queries de services/password_resets_db.gleam
├─ [ ] Crear queries/org_invite_links.sql
├─ [ ] Migrar queries de services/org_invite_links_db.gleam
├─ [ ] Ejecutar squirrel para generar tipos
└─ [ ] Verificar build + tests
```

---

### 4.2 Consolidar constantes duplicadas

**Prioridad:** BAJA
**Impacto:** Single source of truth

```
Tareas:
├─ [ ] Mover max_task_title_chars a shared/src/domain/constants.gleam
├─ [ ] Actualizar services/workflows/types.gleam
├─ [ ] Actualizar services/workflows/validation.gleam
└─ [ ] Verificar build
```

---

### 4.3 Añadir documentación de módulo faltante

**Prioridad:** BAJA
**Impacto:** Mantenibilidad

```
Tareas:
├─ [ ] Añadir //// docs a services/rules_db.gleam
├─ [ ] Añadir //// docs a services/rules_engine.gleam
├─ [ ] Revisar funciones pub sin docstrings
└─ [ ] Verificar formato con gleam format
```

---

### 4.4 Ampliar Test Coverage

**Prioridad:** MEDIA
**Impacto:** Confianza a largo plazo

```
Tareas:
├─ [ ] Añadir tests para nuevos módulos creados en Fases 1-3
│      - test/unit/helpers/json_test.gleam
│      - test/unit/helpers/option_test.gleam
│      - test/unit/http/middleware_test.gleam
│      - test/unit/domain/field_update_test.gleam
├─ [ ] Medir coverage y documentar baseline
└─ [ ] CI reporta coverage en PRs
```

---

### Milestone Fase 4

- [ ] Cero SQL inline en servicios
- [ ] Constantes en single source of truth
- [ ] Documentación completa en módulos públicos
- [ ] Test coverage ≥30% en módulos críticos

---

## Diagrama de Dependencias (Actualizado)

```
┌─────────────────────────────────────────────────────────────┐
│              FASE 0: TEST FOUNDATION (BLOQUEANTE)           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Test Infra   │  │ Critical Path│  │ Authorization│      │
│  │              │  │ Tests        │  │ Tests        │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────┬───────────────────────────────────┘
                          │ GATE: ≥15 tests passing
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                        FASE 1                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ json.gleam   │  │ option.gleam │  │authorization │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                        FASE 2                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │FieldUpdate   │  │ CardState    │  │ ResourceType │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                        FASE 3                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ middleware   │  │ api.from_    │  │ service      │      │
│  │              │  │ result       │  │ extraction   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                        FASE 4                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ SQL files    │  │ Constants    │  │ Documentation│      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## Métricas de Éxito (Actualizado)

| Fase | Métrica | Target |
|------|---------|--------|
| **0** | **Tests passing** | **≥ 15** |
| **0** | **CI ejecuta tests** | **Sí** |
| 1 | Líneas duplicadas eliminadas | ≥ 250 |
| 2 | Sentinel values eliminados | 100% |
| 3 | Max nesting en handlers | ≤ 3 |
| 4 | Test coverage módulos nuevos | ≥ 80% |
| **Global** | Tiempo build | Sin regresión |
| **Global** | Warnings del compilador | 0 |
| **Global** | Tests passing | 100% (siempre) |

---

## Riesgos y Mitigaciones (Actualizado)

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| **Regresiones sin tests** | ~~Alta~~ Baja | ~~Alto~~ Bajo | **Fase 0 añade tests primero** |
| Breaking changes en API | Media | Alto | Feature flags, versioning |
| Scope creep | Alta | Medio | Fases estrictas, no gold-plating |
| Conflictos de merge | Media | Bajo | PRs pequeños, comunicación |

---

## Siguiente Paso Recomendado (ACTUALIZADO)

**Comenzar con Fase 0.1** - Crear infraestructura de testing

1. Verificar `gleam test` funciona en `apps/server/`
2. Crear estructura `test/unit/` y `test/integration/`
3. Implementar primer test: `test "claim_task succeeds for available task"`

> ⚠️ **NO iniciar Fase 1 hasta completar Fase 0.**
> El refactoring sin tests es una receta para regresiones.

---

## Changelog

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.0 | 2026-01-20 | Roadmap inicial con 4 fases |
| **2.0** | **2026-01-20** | **Añadida Fase 0 (Test Foundation) como prerequisito tras Architect Validation** |
