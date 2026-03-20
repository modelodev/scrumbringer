# Scrumbringer AWO Validation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reiniciar el workflow AWO de `scrumbringer` para usar el repo como banco de pruebas real y decidir con evidencia si AWO aporta valor operativo al evolucionar producto y workflow a la vez.

**Architecture:** Se trata `scrumbringer` como sandbox controlado: primero se congela y archiva el workflow experimental actual, luego se sustituye por un workflow brownfield mínimo orientado a cambios reales de producto, y finalmente se ejecuta un bucle repetible de pilotos `baseline manual vs AWO` con scorecard. El workflow nuevo debe optimizar claridad, depuración y evolución, no “ceremonia”.

**Tech Stack:** AWO (`.awo/awo.yaml`, `.awo/workflows/*`), runtime OpenCode (`.opencode/*` generado), documentación Markdown (`docs/workflow/*`, `docs/plans/*`), Git para snapshot/rollback.

---

### Task 1: Congelar el estado actual antes de romper nada

**Files:**
- Create: `docs/workflow/archive/2026-03-20-scrumbringer_greenfield-v0.2.0-design.toml`
- Create: `docs/workflow/archive/2026-03-20-opencode-manifest.json`
- Create: `docs/workflow/archive/2026-03-20-opencode-mapping.json`
- Modify: `docs/workflow/CHANGELOG.md`

**Step 1: Crear la carpeta de archivo si no existe**

Run:
```bash
mkdir -p docs/workflow/archive
```
Expected: directory `docs/workflow/archive` exists.

**Step 2: Copiar el workflow fuente actual al archivo**

Run:
```bash
cp .awo/workflows/scrumbringer_greenfield/workflow.toml \
  docs/workflow/archive/2026-03-20-scrumbringer_greenfield-v0.2.0-design.toml
```
Expected: archived TOML exists and still contains `id = "scrumbringer_greenfield"` and `version = "0.2.0-design"`.

**Step 3: Copiar el manifest runtime actual al archivo**

Run:
```bash
cp .awo/generated/opencode/manifest.json \
  docs/workflow/archive/2026-03-20-opencode-manifest.json
```
Expected: archived manifest exists and still references `scrumbringer_greenfield`.

**Step 4: Copiar el mapping runtime actual al archivo**

Run:
```bash
cp .awo/generated/opencode/mapping.json \
  docs/workflow/archive/2026-03-20-opencode-mapping.json
```
Expected: archived mapping exists and still maps `project_brief/story_design/story_implementation/story_qa`.

**Step 5: Añadir entrada de changelog anunciando el experimento destructivo controlado**

Add this block near the top of `docs/workflow/CHANGELOG.md`:

```md
## 2026-03-20

### Changed
- `scrumbringer` pasa a usarse como sandbox de validación AWO con permiso explícito para resetear el workflow fuente.
- Se archiva el workflow experimental `scrumbringer_greenfield@0.2.0-design` antes de sustituirlo.

### References
- WFD-003
```

**Step 6: Commit**

```bash
git add docs/workflow/archive/2026-03-20-scrumbringer_greenfield-v0.2.0-design.toml \
  docs/workflow/archive/2026-03-20-opencode-manifest.json \
  docs/workflow/archive/2026-03-20-opencode-mapping.json \
  docs/workflow/CHANGELOG.md
git commit -m "chore(workflow): archive current awo experiment before reset"
```

---

### Task 2: Escribir el marco de evaluación para decidir kill / continue

**Files:**
- Create: `docs/workflow/awo-evaluation-rubric.md`
- Create: `docs/workflow/pilots/2026-03-20-pilot-000-baseline-template.md`
- Modify: `docs/workflow/DECISIONS.md`

**Step 1: Crear carpeta de pilotos si no existe**

Run:
```bash
mkdir -p docs/workflow/pilots
```
Expected: directory `docs/workflow/pilots` exists.

**Step 2: Crear la rúbrica de evaluación**

Write `docs/workflow/awo-evaluation-rubric.md` with this minimum content:

```md
# AWO Evaluation Rubric

## Pregunta a responder
¿AWO mejora la evolución real de `scrumbringer` frente a trabajar a pelo?

## Criterios (puntuar 1-5)
1. Claridad del siguiente paso
2. Detección temprana de omisiones
3. Depuración cuando algo falla
4. Repetibilidad entre iteraciones
5. Overhead neto (invertido: 5 = poco overhead)

## Regla de decisión
- CONTINUE: media >= 4 y ningún criterio crítico por debajo de 3
- ITERATE: media entre 3 y 3.9
- KILL/PIVOT: media < 3 o AWO no mejora frente a baseline manual

## Evidencia mínima por piloto
- cambio pedido
- baseline manual resumido
- corrida AWO resumida
- tiempo total
- problemas detectados por cada enfoque
- artefactos útiles generados
- decisión final
```

**Step 3: Crear plantilla de piloto baseline-vs-AWO**

Write `docs/workflow/pilots/2026-03-20-pilot-000-baseline-template.md` with this minimum content:

```md
# Pilot Template — Baseline vs AWO

## Change request

## Baseline manual
- enfoque:
- tiempo:
- errores/omisiones detectados:
- puntos confusos:

## AWO
- workflow usado:
- run_id:
- tiempo:
- errores/omisiones detectados:
- evidencia útil:

## Scorecard
- claridad del siguiente paso:
- detección temprana:
- depuración:
- repetibilidad:
- overhead neto:

## Veredicto
- continue | iterate | kill/pivot
- motivo:
```

**Step 4: Registrar la decisión de convertir `scrumbringer` en sandbox AWO**

Append this decision to `docs/workflow/DECISIONS.md`:

```md
## WFD-003
- **Fecha**: 2026-03-20
- **Estado**: accepted
- **Decisión**: Usar `scrumbringer` como sandbox principal para validar o refutar la propuesta de valor de AWO.
- **Contexto**: el workflow actual es de pruebas y puede resetearse sin coste alto; necesitamos evidencia en repo real, no discusión abstracta.
- **Alternativas consideradas**:
  - seguir iterando el workflow actual
  - evaluar AWO en un repo juguete
  - posponer validación hasta tener más producto
- **Impacto**:
  - se permite sustituir por completo el workflow fuente actual
  - cada cambio de producto relevante puede disparar un piloto `baseline vs AWO`
  - la continuidad del proyecto AWO queda condicionada a scorecards repetibles
- **Seguimiento**:
  - al menos 3 pilotos reales
  - una decisión explícita `continue / iterate / kill`
```

**Step 5: Commit**

```bash
git add docs/workflow/awo-evaluation-rubric.md \
  docs/workflow/pilots/2026-03-20-pilot-000-baseline-template.md \
  docs/workflow/DECISIONS.md
git commit -m "docs(workflow): define awo evaluation rubric and pilot template"
```

---

### Task 3: Sustituir el workflow actual por un bucle brownfield mínimo

**Files:**
- Modify: `.awo/awo.yaml`
- Create: `.awo/workflows/scrumbringer_change_loop/workflow.toml`
- Modify: `docs/workflow/CONSTITUTION.md`

**Step 1: Cambiar el workflow habilitado en `.awo/awo.yaml`**

Replace:
```yaml
workflows:
  enabled: [scrumbringer_greenfield]
```
with:
```yaml
workflows:
  enabled: [scrumbringer_change_loop]
```

**Step 2: Crear el nuevo workflow fuente mínimo**

Write `.awo/workflows/scrumbringer_change_loop/workflow.toml` with this initial content:

```toml
id = "scrumbringer_change_loop"
version = "0.1.0"

[metadata]
namespace = "scrumbringer"
principal_asset = "scrumbringer.change_loop"

[budget]
tokens_hint = 16000

[[steps]]
id = "change_brief"
kind = "llm-subagent"
depends_on = []
inputs = []
outputs = ["change_brief_contract"]
skill_refs = ["bmad-po"]
context_mode = "shared"
done_criteria = ["change scope, constraints and acceptance strategy are explicit"]
verification_steps = []

[[steps]]
id = "impact_scan"
kind = "llm-subagent"
depends_on = ["change_brief"]
inputs = ["change_brief_contract"]
outputs = ["impact_scan_contract"]
skill_refs = ["bmad-po"]
context_mode = "shared"
done_criteria = ["files, risks, tests and UX impact are explicit"]
verification_steps = []

[[steps]]
id = "implement_change"
kind = "llm-subagent"
depends_on = ["impact_scan"]
inputs = ["impact_scan_contract"]
outputs = ["implementation_contract"]
skill_refs = ["bmad-dev"]
context_mode = "isolated"
done_criteria = ["minimal code change and tests are implemented"]
verification_steps = []

[[steps]]
id = "verify_change"
kind = "llm-subagent"
depends_on = ["implement_change"]
inputs = ["implementation_contract"]
outputs = ["verification_contract"]
skill_refs = ["bmad-qa"]
context_mode = "isolated"
done_criteria = ["tests, regressions and UX checks are reviewed"]
verification_steps = []

[[steps]]
id = "workflow_retro"
kind = "llm-subagent"
depends_on = ["verify_change"]
inputs = ["verification_contract"]
outputs = ["workflow_delta_contract"]
skill_refs = ["bmad-po"]
context_mode = "shared"
done_criteria = ["workflow improvement or kill signal is explicit"]
verification_steps = []
```

**Step 3: Endurecer la constitución con una regla de validación de valor**

Append this principle to `docs/workflow/CONSTITUTION.md` under `## Principios`:

```md
13. **Valor o muerte**: si el workflow no mejora claridad, depuración o repetibilidad frente a baseline manual, se simplifica o se elimina.
```

**Step 4: Verificar formato del nuevo workflow**

Run:
```bash
sed -n '1,220p' .awo/workflows/scrumbringer_change_loop/workflow.toml
```
Expected: five steps in this order: `change_brief -> impact_scan -> implement_change -> verify_change -> workflow_retro`.

**Step 5: Commit**

```bash
git add .awo/awo.yaml .awo/workflows/scrumbringer_change_loop/workflow.toml docs/workflow/CONSTITUTION.md
git commit -m "feat(workflow): replace greenfield experiment with brownfield change loop"
```

---

### Task 4: Regenerar runtime AWO y comprobar que el nuevo flujo vive de verdad

**Files:**
- Create: `docs/workflow/pilots/2026-03-20-pilot-001-bootstrap.md`
- Read: `.awo/generated/opencode/manifest.json`
- Read: `.awo/generated/opencode/mapping.json`
- Read: `.opencode/skills/*`

**Step 1: Validar el workflow fuente**

Run:
```bash
awo validate --target opencode --wf scrumbringer_change_loop --scope source --explain
```
Expected: successful validation for source scope; no unknown workflow id.

**Step 2: Construir artefactos generados**

Run:
```bash
awo build --target opencode --wf scrumbringer_change_loop
```
Expected: compiled assets under `.awo/generated/opencode/workflows/scrumbringer_change_loop/`.

**Step 3: Revisar el manifest generado**

Run:
```bash
cat .awo/generated/opencode/manifest.json
```
Expected: `workflow_bundles` now reference `scrumbringer_change_loop` instead of `scrumbringer_greenfield`.

**Step 4: Aplicar el runtime a OpenCode**

Run:
```bash
awo apply --target opencode --wf scrumbringer_change_loop
```
Expected: `.opencode/commands/awo-*.md` refreshed and new `.opencode/skills/scrumbringer-change-loop-*` created.

**Step 5: Verificar mapping runtime**

Run:
```bash
cat .awo/generated/opencode/mapping.json
```
Expected: runtime step mapping contains `change-brief`, `impact-scan`, `implement-change`, `verify-change`, `workflow-retro`.

**Step 6: Registrar bootstrap del nuevo workflow**

Write `docs/workflow/pilots/2026-03-20-pilot-001-bootstrap.md` with this minimum content:

```md
# Pilot 001 — AWO Bootstrap

- workflow_id: `scrumbringer_change_loop`
- source validation: PASS/FAIL
- build: PASS/FAIL
- apply: PASS/FAIL
- runtime skills created:
- notable friction:
- immediate next step:
```

**Step 7: Commit**

```bash
git add .awo/awo.yaml \
  .awo/workflows/scrumbringer_change_loop/workflow.toml \
  .awo/generated/opencode/manifest.json \
  .awo/generated/opencode/mapping.json \
  .opencode/agents/awo-runtime.md \
  .opencode/commands/awo-help.md \
  .opencode/commands/awo-run.md \
  .opencode/commands/awo-step.md \
  .opencode/commands/awo-approve.md \
  .opencode/skills \
  docs/workflow/pilots/2026-03-20-pilot-001-bootstrap.md
git commit -m "feat(workflow): bootstrap brownfield awo runtime for scrumbringer"
```

---

### Task 5: Ejecutar el primer piloto real sobre un cambio de producto pequeño

**Files:**
- Create: `docs/workflow/pilots/2026-03-20-pilot-002-task-title-edit.md`
- Modify: `docs/workflow/DECISIONS.md`
- Read: `.awo/runs/*`

**Step 1: Crear el piloto para el cambio real inicial**

Write `docs/workflow/pilots/2026-03-20-pilot-002-task-title-edit.md` with this initial content:

```md
# Pilot 002 — Edit task title from task detail modal

## Change request
Permitir editar el título/nombre de una task desde el modal de detalle, con guardar/cancelar, Enter/Escape y validación visible.

## Baseline manual
- enfoque:
- tiempo:
- errores/omisiones detectados:
- puntos confusos:

## AWO
- workflow usado: `scrumbringer_change_loop`
- run_id:
- tiempo:
- errores/omisiones detectados:
- evidencia útil:

## Scorecard
- claridad del siguiente paso:
- detección temprana:
- depuración:
- repetibilidad:
- overhead neto:

## Veredicto
- continue | iterate | kill/pivot
- motivo:
```

**Step 2: Ejecutar baseline manual corto y rellenar el bloque correspondiente**

Run in OpenCode/manual flow without `/awo-*`.
Expected: a short factual baseline exists in the pilot doc before using AWO.

**Step 3: Ejecutar el workflow AWO sobre el mismo cambio**

Run in OpenCode:
```text
/awo-help scrumbringer_change_loop
/awo-run scrumbringer_change_loop Permitir editar el título de una task desde el modal de detalle con UX mínima clara y validación visible.
```
Expected: a new run under `.awo/runs/<run_id>/` with `run-envelope.json` and one step-report per executed step.

**Step 4: Inspeccionar evidencia y completar scorecard**

Run:
```bash
find .awo/runs -maxdepth 3 -type f | sort | tail -50
```
Expected: latest run files are visible and pilot doc is filled with a concrete verdict.

**Step 5: Si el scorecard sale mal, registrar señal de kill/pivot; si sale regular, registrar delta de workflow**

Append a short note to `docs/workflow/DECISIONS.md` under a new entry `WFD-004` only after the pilot verdict exists.

Template:
```md
## WFD-004
- **Fecha**: 2026-03-20
- **Estado**: proposed
- **Decisión**: [continuar iterando | pivotar a debugger-only | matar el experimento]
- **Contexto**: resultado del piloto 002 sobre edición de título.
- **Alternativas consideradas**:
  - continuar sin cambios
  - simplificar workflow
  - abandonar AWO para este repo
- **Impacto**:
  - [explicar en 2-3 bullets]
- **Seguimiento**:
  - próximo piloto o criterio de cierre
```

**Step 6: Commit**

```bash
git add docs/workflow/pilots/2026-03-20-pilot-002-task-title-edit.md docs/workflow/DECISIONS.md .awo/runs
git commit -m "docs(workflow): record first scrumbringer awo value pilot"
```

---

### Task 6: Instalar el bucle de evolución del workflow después de cada cambio real

**Files:**
- Create: `docs/workflow/experiment-loop.md`
- Modify: `docs/workflow/CHANGELOG.md`

**Step 1: Crear el documento del bucle operativo**

Write `docs/workflow/experiment-loop.md` with this minimum content:

```md
# Scrumbringer AWO Experiment Loop

1. Elegir un cambio real pequeño.
2. Ejecutar baseline manual breve.
3. Ejecutar `/awo-run` con el mismo cambio.
4. Leer evidencia `.awo/runs/*`.
5. Puntuar rúbrica.
6. Decidir: keep / simplify / kill.
7. Si cambia el workflow, actualizar `workflow.toml`, `DECISIONS.md` y `CHANGELOG.md`.
```

**Step 2: Añadir al changelog una sección permanente de evolución experimental**

Add this line under the 2026-03-20 entry in `docs/workflow/CHANGELOG.md`:

```md
- Se establece un bucle explícito baseline-vs-AWO para cada cambio pequeño de producto usado como piloto.
```

**Step 3: Commit**

```bash
git add docs/workflow/experiment-loop.md docs/workflow/CHANGELOG.md
git commit -m "docs(workflow): add recurring experiment loop for awo validation"
```

---

Plan complete and saved to `docs/plans/2026-03-20-scrumbringer-awo-validation.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
