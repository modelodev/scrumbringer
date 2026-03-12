# Workflow Propio por Fases Concretas Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Diseñar e implantar un workflow propio, ligero y entendible paso a paso, cubriendo flujos concretos (historia, desarrollo, sprint, bug/mejora, evolución del workflow y decisiones clave).

**Architecture:** Construcción incremental con artefactos de gobernanza primero (constitución + decisiones), luego flujos operativos (story/dev/bug/sprint) y por último meta-flujo de cambios al propio workflow. Cada flujo tendrá contrato de entrada/salida, checklist y quality gate.

**Tech Stack:** OpenCode (`opencode.jsonc`), prompts/agents (`.wf/agents`), skills (`skills/*`), documentación (`docs/workflow`, `docs/plans`, `docs/stories`).

---

### Task 1: Fundamentos de gobernanza (constitución + decisiones)

**Files:**
- Create: `docs/workflow/CONSTITUTION.md`
- Create: `docs/workflow/DECISIONS.md`
- Create: `docs/workflow/CHANGELOG.md`
- Create: `docs/workflow/DEBUG-CONTRACT.md`

**Step 1: Crear constitución mínima (10-12 reglas)**

Reglas de oro: claridad, TDD estricto, edge cases obligatorios, no acciones externas sin validación, trazabilidad por fases.

**Step 2: Crear registro de decisiones**

Formato tipo ADR-lite: `fecha | decisión | contexto | alternativas | impacto`.

**Step 3: Crear contrato de depuración**

Campos mínimos por fase: `phase`, `agent`, `input_refs`, `actions`, `artifacts`, `risks`, `duration`.

**Step 4: Commit**

```bash
git add docs/workflow/CONSTITUTION.md docs/workflow/DECISIONS.md docs/workflow/CHANGELOG.md docs/workflow/DEBUG-CONTRACT.md
git commit -m "docs(workflow): bootstrap governance and debug contract"
```

---

### Task 2: Flujo 1 — Creación de historia

**Files:**
- Create: `docs/workflow/flows/flow-story-creation.md`
- Create: `docs/workflow/templates/story-template-lite.md`
- Create: `docs/workflow/checklists/story-draft-checklist-lite.md`

**Step 1: Definir flujo de creación de historia**

Entradas: objetivo + contexto + constraints.
Salida: historia `Draft` completa y trazable.

**Step 2: Definir plantilla de historia lite**

Secciones: Story, AC, Tasks, Dev Notes, Testing, Risks, File List.

**Step 3: Definir checklist draft (GO/NO-GO)**

Validar completitud, referencias, testabilidad, edge/error scenarios.

**Step 4: Commit**

```bash
git add docs/workflow/flows/flow-story-creation.md docs/workflow/templates/story-template-lite.md docs/workflow/checklists/story-draft-checklist-lite.md
git commit -m "docs(workflow): add story creation flow and draft checklist"
```

---

### Task 3: Flujo 2 — Desarrollo de historia (con agentes TDD)

**Files:**
- Create: `docs/workflow/flows/flow-story-development.md`
- Create: `skills/tdd-cases/SKILL.md`
- Create: `skills/tdd-implementer/SKILL.md`
- Create: `skills/architect-adversarial/SKILL.md`
- Create: `skills/verify-gate/SKILL.md`

**Step 1: Definir secuencia operativa**

`spec -> tdd-cases -> tdd-implementer -> architect-adversarial -> verify-gate`.

**Step 2: Definir skill tdd-cases**

Matriz obligatoria: happy path + edge + error + auth + concurrency + regression.

**Step 3: Definir skill tdd-implementer**

Ciclo obligatorio RED -> GREEN -> REFACTOR por cada AC.

**Step 4: Definir skill architect-adversarial**

Ronda de rebata máxima 2 iteraciones por entrega.

**Step 5: Definir verify-gate**

Severidades: `CRITICAL/WARNING/SUGGESTION` y veredicto `PASS|FAIL`.

**Step 6: Commit**

```bash
git add docs/workflow/flows/flow-story-development.md skills/tdd-cases/SKILL.md skills/tdd-implementer/SKILL.md skills/architect-adversarial/SKILL.md skills/verify-gate/SKILL.md
git commit -m "feat(workflow): story development flow with tdd and adversarial review"
```

---

### Task 4: Flujo 3 — Diseño de sprint

**Files:**
- Create: `docs/workflow/flows/flow-sprint-design.md`
- Create: `docs/workflow/templates/sprint-template-lite.md`
- Create: `docs/workflow/checklists/sprint-readiness-checklist.md`

**Step 1: Definir entradas/salidas del sprint**

Entradas: backlog priorizado + capacidad + dependencias.
Salida: sprint con objetivos, historias, riesgos y definición de corte.

**Step 2: Crear plantilla sprint lite**

Campos: Goal, Scope, Out-of-scope, Capacity, Risks, Exit criteria.

**Step 3: Crear checklist de readiness**

Bloquear sprint si hay historias sin AC testables o dependencias no resueltas.

**Step 4: Commit**

```bash
git add docs/workflow/flows/flow-sprint-design.md docs/workflow/templates/sprint-template-lite.md docs/workflow/checklists/sprint-readiness-checklist.md
git commit -m "docs(workflow): sprint design flow and readiness checklist"
```

---

### Task 5: Flujo 4 — Bug/Mejora rápida

**Files:**
- Create: `docs/workflow/flows/flow-bug-improvement.md`
- Create: `docs/workflow/templates/bug-template-lite.md`
- Create: `docs/workflow/checklists/bug-triage-checklist.md`

**Step 1: Definir fast-lane**

Camino corto con clasificación: `bug crítico | bug normal | mejora UX`.

**Step 2: Definir plantilla de bug**

Campos: impacto, reproducción, hipótesis, fix plan, pruebas de no-regresión.

**Step 3: Definir checklist triage**

Validar severidad, alcance, reproducibilidad y rollback.

**Step 4: Commit**

```bash
git add docs/workflow/flows/flow-bug-improvement.md docs/workflow/templates/bug-template-lite.md docs/workflow/checklists/bug-triage-checklist.md
git commit -m "docs(workflow): bug/improvement fast-lane"
```

---

### Task 6: Flujo 5 — Cambios al propio workflow (meta-flujo)

**Files:**
- Create: `docs/workflow/flows/flow-workflow-change.md`
- Create: `docs/workflow/checklists/workflow-change-checklist.md`

**Step 1: Definir protocolo de cambio**

Cualquier cambio de agente/skill/flujo requiere: propuesta, impacto, piloto, decisión.

**Step 2: Definir checklist de cambio**

Validar compatibilidad, migración, docs, rollback, comunicación.

**Step 3: Commit**

```bash
git add docs/workflow/flows/flow-workflow-change.md docs/workflow/checklists/workflow-change-checklist.md
git commit -m "docs(workflow): meta-flow for changing the workflow itself"
```

---

### Task 7: Integración con OpenCode mínima (sin magia)

**Files:**
- Modify: `opencode.jsonc`
- Modify: `.wf/agents/wf-orchestrator.md`
- Create: `docs/workflow/flows/index.md`

**Step 1: Registrar flujo operativo en orquestador**

Añadir mapeo explícito de comandos humanos a flujos.

**Step 2: Activar modo debug opcional**

`debug on/off` para salida enriquecida con trazabilidad.

**Step 3: Indexar flujos**

Crear índice único de flujos y estado (draft/active/deprecated).

**Step 4: Commit**

```bash
git add opencode.jsonc .wf/agents/wf-orchestrator.md docs/workflow/flows/index.md
git commit -m "feat(workflow): wire minimal flow routing into wf orchestrator"
```

---

### Task 8: Piloto controlado y retrospectiva

**Files:**
- Modify: `docs/stories/<story-piloto>.md`
- Create: `docs/workflow/pilots/pilot-001-story-dev.md`
- Modify: `docs/workflow/DECISIONS.md`

**Step 1: Ejecutar un piloto completo**

Aplicar flujo Story Creation + Story Development en una historia pequeña real.

**Step 2: Medir y registrar**

Métricas: tiempo, retrabajo, fallos de contrato, cobertura edge cases.

**Step 3: Decidir ajustes**

Registrar en DECISIONS qué se mantiene, qué cambia y por qué.

**Step 4: Commit**

```bash
git add docs/workflow/pilots/pilot-001-story-dev.md docs/workflow/DECISIONS.md docs/stories/<story-piloto>.md
git commit -m "docs(workflow): pilot 001 results and decision updates"
```
