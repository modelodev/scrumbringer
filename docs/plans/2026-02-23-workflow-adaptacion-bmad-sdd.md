# Adaptación Workflow IA (BMAD + SDD) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrar un workflow IA reutilizable en `scrumbringer` usando la base BMAD existente y añadiendo un patrón orquestador/subagentes tipo SDD sin romper el flujo actual.

**Architecture:** Se mantiene BMAD como capa de orquestación documental (roles y workflows YAML) y se añade una capa SDD operativa para ejecución por fases con contrato de salida estructurado. La integración se hace de forma incremental (piloto -> adopción -> endurecimiento) para minimizar riesgo.

**Tech Stack:** OpenCode (`opencode.jsonc`), prompts Markdown (`.bmad-core/agents/*.md`), workflows YAML (`.bmad-core/workflows/*.yaml`), documentación en `docs/`.

---

### Task 1: Auditoría mínima de integración

**Files:**
- Read: `opencode.jsonc`
- Read: `.bmad-core/core-config.yaml`
- Read: `.bmad-core/workflows/brownfield-fullstack.yaml`
- Read: `.bmad-core/agents/bmad-orchestrator.md`
- Create: `docs/workflow/adaptacion-auditoria.md`

**Step 1: Documentar estado actual de agentes y workflows**

Registrar:
- agentes BMAD disponibles,
- workflows activos,
- comandos `bmad:tasks:*`,
- convenciones de salida actuales.

**Step 2: Ejecutar checklist de huecos respecto al workflow objetivo**

Checklist:
- [ ] ¿Hay delegado real con subagentes?
- [ ] ¿Hay contrato de salida estructurado obligatorio?
- [ ] ¿Hay memoria persistente operativa?
- [ ] ¿Hay quality gate reproducible por fase?

**Step 3: Commit**

```bash
git add docs/workflow/adaptacion-auditoria.md
git commit -m "docs(workflow): auditoria inicial bmad vs sdd"
```

---

### Task 2: Definir workflow híbrido en YAML (sin tocar ejecución todavía)

**Files:**
- Create: `.bmad-core/workflows/hybrid-sdd-fullstack.yaml`
- Modify: `.bmad-core/agent-teams/team-fullstack.yaml`
- Modify: `docs/index.md`

**Step 1: Crear workflow híbrido**

Incluir secuencia base:
- explore -> propose -> spec/design -> tasks -> apply -> verify -> archive
- con rutas condicionales para brownfield pequeño vs mayor.

**Step 2: Añadirlo al bundle fullstack**

Actualizar `team-fullstack.yaml` para incluir el nuevo workflow.

**Step 3: Indexar docs**

Agregar referencia en `docs/index.md` al workflow híbrido.

**Step 4: Commit**

```bash
git add .bmad-core/workflows/hybrid-sdd-fullstack.yaml .bmad-core/agent-teams/team-fullstack.yaml docs/index.md
git commit -m "feat(workflow): añadir workflow híbrido bmad+sdd"
```

---

### Task 3: Añadir agente orquestador SDD en OpenCode (piloto)

**Files:**
- Modify: `opencode.jsonc`
- Create: `.bmad-core/agents/sdd-orchestrator-lite.md`

**Step 1: Crear prompt del orquestador piloto**

Debe contener:
- modo delegate-only,
- mapeo de fases,
- política de persistencia (`none|openspec|engram`),
- contrato de salida obligatorio.

**Step 2: Registrar agente en OpenCode**

Añadir `agent.sdd-orchestrator-lite` en `opencode.jsonc` con tools mínimas (`read`, `write`, `edit`, `bash` si procede).

**Step 3: Commit**

```bash
git add .bmad-core/agents/sdd-orchestrator-lite.md opencode.jsonc
git commit -m "feat(opencode): registrar sdd-orchestrator-lite piloto"
```

---

### Task 4: Crear skills de fase (primer lote)

**Files:**
- Create: `skills/sdd-explore/SKILL.md`
- Create: `skills/sdd-propose/SKILL.md`
- Create: `skills/sdd-spec/SKILL.md`
- Create: `skills/sdd-design/SKILL.md`

**Step 1: Escribir skills con contrato uniforme**

Cada skill debe devolver:
- `status`
- `executive_summary`
- `artifacts[]`
- `next_recommended[]`
- `risks[]`

**Step 2: Definir persistencia por modo**

- `none`: no escribir artefactos
- `openspec`: escribir archivos en `openspec/changes/...`
- `engram`: devolver refs persistidas

**Step 3: Commit**

```bash
git add skills/sdd-explore/SKILL.md skills/sdd-propose/SKILL.md skills/sdd-spec/SKILL.md skills/sdd-design/SKILL.md
git commit -m "feat(skills): lote inicial sdd (explore/propose/spec/design)"
```

---

### Task 5: Crear skills de ejecución y quality gate

**Files:**
- Create: `skills/sdd-tasks/SKILL.md`
- Create: `skills/sdd-apply/SKILL.md`
- Create: `skills/sdd-verify/SKILL.md`
- Create: `skills/sdd-archive/SKILL.md`

**Step 1: Implementar contrato por criticidad y gate**

`verify` debe clasificar hallazgos en:
- `CRITICAL` (bloquea)
- `WARNING`
- `SUGGESTION`

**Step 2: Añadir regla de bloqueo en archive**

`archive` no avanza con CRITICAL abiertos.

**Step 3: Commit**

```bash
git add skills/sdd-tasks/SKILL.md skills/sdd-apply/SKILL.md skills/sdd-verify/SKILL.md skills/sdd-archive/SKILL.md
git commit -m "feat(skills): lote ejecución sdd (tasks/apply/verify/archive)"
```

---

### Task 6: Endurecer contrato de salida (anti-hallucination)

**Files:**
- Create: `docs/workflow/salida-estructurada-schema.md`
- Modify: `.bmad-core/agents/sdd-orchestrator-lite.md`

**Step 1: Definir schema JSON canónico**

Ejemplo:
```json
{
  "status": "ok|warning|blocked|failed",
  "executive_summary": "string",
  "artifacts": [{"name":"string","store":"none|openspec|engram","ref":"string|null"}],
  "next_recommended": ["string"],
  "risks": ["string"]
}
```

**Step 2: Añadir política de reintento**

Si la salida no cumple schema:
1) pedir reformateo
2) segundo intento con ejemplo mínimo
3) marcar `blocked` si vuelve a fallar.

**Step 3: Commit**

```bash
git add docs/workflow/salida-estructurada-schema.md .bmad-core/agents/sdd-orchestrator-lite.md
git commit -m "docs(workflow): schema de salida y politica de reintento"
```

---

### Task 7: Piloto real sobre una story existente

**Files:**
- Modify: `docs/stories/<story-piloto>.md`
- Create: `docs/workflow/piloto-resultado.md`

**Step 1: Seleccionar story pequeña**

Elegir una con alcance limitado y bajo riesgo.

**Step 2: Ejecutar flujo completo**

explore -> propose -> spec/design -> tasks -> apply -> verify -> archive

**Step 3: Capturar métricas del piloto**

- tiempo total,
- retrabajo,
- incidencias de formato,
- utilidad de artifacts.

**Step 4: Commit**

```bash
git add docs/workflow/piloto-resultado.md docs/stories/<story-piloto>.md
git commit -m "docs(workflow): resultado piloto workflow híbrido"
```

---

### Task 8: Decisión de adopción

**Files:**
- Create: `docs/workflow/adr-adopcion-hibrido.md`
- Modify: `docs/index.md`

**Step 1: Registrar ADR**

Decidir:
- adoptar,
- adoptar con restricciones,
- o descartar.

**Step 2: Publicar ruta oficial en índice**

Actualizar `docs/index.md` con “workflow recomendado” para el equipo.

**Step 3: Commit**

```bash
git add docs/workflow/adr-adopcion-hibrido.md docs/index.md
git commit -m "docs(workflow): decision de adopcion del workflow hibrido"
```
