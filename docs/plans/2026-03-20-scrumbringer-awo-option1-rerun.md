# Scrumbringer AWO Option 1 Rerun Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Revert the current manual baseline changes in `scrumbringer`, replace the unusable experimental workflow with a semver-valid brownfield workflow that includes a structural `interaction_review` step, and rerun the same feature request through OpenCode + AWO so we can compare before/after evidence.

**Architecture:** Keep the product task constant (edit task title + description from task detail modal) and change the workflow structure in a minimal but observable way. Use AWO both as authoring/runtime tool and as evidence collector: first capture the current failure state (`scrumbringer_greenfield` is not consumable by the current CLI), then build/apply a new semver-valid workflow with one extra structural step, then rerun the same request and compare execution/runtime artifacts.

**Tech Stack:** Git, AWO CLI (`~/bin/awo`), OpenCode runtime assets (`.opencode/*`), workflow source under `.awo/workflows/*`, generated runtime artifacts under `.awo/generated/opencode/*`, Markdown experiment docs under `docs/workflow/*` and `docs/plans/*`.

---

### Task 1: Freeze the current evidence and rollback the manual baseline

**Files:**
- Create: `docs/workflow/pilots/2026-03-20-pilot-002-baseline-manual.md`
- Modify: `docs/workflow/CHANGELOG.md`
- Modify: working tree files listed by `git status --short`

**Step 1: Capture the current dirty tree before reverting**

Run:
```bash
git -C /home/yo/usr/dev/repos/scrumbringer status --short
```
Expected: modified client files for task-detail edit baseline, plus generated `.opencode/*` and `.awo/*` artifacts.

**Step 2: Record the baseline outcome while it is still fresh**

Write `docs/workflow/pilots/2026-03-20-pilot-002-baseline-manual.md` with this minimum content:

```md
# Pilot 002 — Baseline Manual

## Change request
Editar título + descripción de una task desde el modal de detalle, con guardar/cancelar, validación visible y teclado razonable.

## Outcome
- status: implemented_then_reverted_for_awO_rerun
- build: client green
- tests: `apps/client` green (`gleam build`, `gleam test`)
- UX issue found: la UI quedó funcional pero no comunicaba bien que la tarea se pudiera editar

## Key observations
- el cambio técnico era viable y la infraestructura existente bastaba
- el resultado necesitó revisión posterior de discoverability
- esto se considera fallo del workflow/checkpoints, no prueba de valor de AWO todavía

## Files touched during baseline
- apps/client/src/scrumbringer_client/api/tasks.gleam
- apps/client/src/scrumbringer_client/api/tasks/operations.gleam
- apps/client/src/scrumbringer_client/client_state/member/pool.gleam
- apps/client/src/scrumbringer_client/features/pool/dialogs.gleam
- apps/client/src/scrumbringer_client/features/pool/msg.gleam
- apps/client/src/scrumbringer_client/features/pool/update.gleam
- apps/client/src/scrumbringer_client/features/tasks/update.gleam
- apps/client/src/scrumbringer_client/i18n/en.gleam
- apps/client/src/scrumbringer_client/i18n/es.gleam
- apps/client/src/scrumbringer_client/i18n/text.gleam
- apps/client/test/task_detail_edit_test.gleam

## Decision
Revert baseline implementation and rerun the same change after modifying the workflow structurally.
```

**Step 3: Add changelog note explaining why the baseline is being reverted**

Add near the top of `docs/workflow/CHANGELOG.md`:

```md
- El baseline manual del piloto 002 se revierte para repetir exactamente la misma petición tras cambiar estructuralmente el workflow y poder comparar evidencia before/after.
```

**Step 4: Revert only the manual baseline code changes**

Run:
```bash
cd /home/yo/usr/dev/repos/scrumbringer
git restore \
  apps/client/src/scrumbringer_client/api/tasks.gleam \
  apps/client/src/scrumbringer_client/api/tasks/operations.gleam \
  apps/client/src/scrumbringer_client/client_state/member/pool.gleam \
  apps/client/src/scrumbringer_client/features/pool/dialogs.gleam \
  apps/client/src/scrumbringer_client/features/pool/msg.gleam \
  apps/client/src/scrumbringer_client/features/pool/update.gleam \
  apps/client/src/scrumbringer_client/features/tasks/update.gleam \
  apps/client/src/scrumbringer_client/i18n/en.gleam \
  apps/client/src/scrumbringer_client/i18n/es.gleam \
  apps/client/src/scrumbringer_client/i18n/text.gleam
rm -f apps/client/test/task_detail_edit_test.gleam
```
Expected: product code returns to pre-baseline state; docs remain intact.

**Step 5: Verify the rollback is clean enough**

Run:
```bash
git -C /home/yo/usr/dev/repos/scrumbringer status --short
```
Expected: only workflow/docs/generated-runtime drift remains; baseline feature code is gone.

**Step 6: Commit the rollback evidence**

```bash
cd /home/yo/usr/dev/repos/scrumbringer
git add docs/workflow/pilots/2026-03-20-pilot-002-baseline-manual.md docs/workflow/CHANGELOG.md
git commit -m "docs(workflow): record and revert manual baseline before awo rerun"
```

---

### Task 2: Capture the current AWO failure state as pre-change evidence

**Files:**
- Create: `docs/workflow/pilots/2026-03-20-pilot-003-awo-preflight-before-option1.md`
- Read: `.awo/workflows/scrumbringer_greenfield/workflow.toml`

**Step 1: Confirm the current workflow source state**

Run:
```bash
cd /home/yo/usr/dev/repos/scrumbringer
sed -n '1,220p' .awo/workflows/scrumbringer_greenfield/workflow.toml
```
Expected: current workflow id is `scrumbringer_greenfield`, version is `0.2.0-design`, and there is no structural interaction-analysis step.

**Step 2: Capture the fact that current AWO CLI cannot meaningfully consume this workflow**

Run:
```bash
cd /home/yo/usr/dev/repos/scrumbringer
awo workflow show scrumbringer_greenfield --json || true
awo build --target opencode --wf scrumbringer_greenfield --json || true
awo compare version scrumbringer_greenfield 0.2.0-design 0.3.0 --json || true
```
Expected:
- `workflow show` / `build` currently fail for this workflow in the current repo state
- `compare version` fails because `0.2.0-design` is not semver-compliant for AWO versioning features

**Step 3: Write the preflight evidence doc**

Write `docs/workflow/pilots/2026-03-20-pilot-003-awo-preflight-before-option1.md` with this minimum content:

```md
# Pilot 003 — AWO Preflight Before Option 1

## Current workflow state
- wf_id: `scrumbringer_greenfield`
- version: `0.2.0-design`
- shape: greenfield-like flow, not brownfield-specific

## CLI evidence
- `awo workflow show ...`: FAIL
- `awo build ...`: FAIL
- `awo compare version ...`: FAIL because version is not semver-compliant

## Interpretation
The current workflow is not a good AWO validation target for the current CLI/runtime path. We need a semver-valid, structurally observable workflow before measuring AWO seriously.
```

**Step 4: Commit**

```bash
cd /home/yo/usr/dev/repos/scrumbringer
git add docs/workflow/pilots/2026-03-20-pilot-003-awo-preflight-before-option1.md
git commit -m "docs(workflow): capture awo preflight failure state before option1"
```

---

### Task 3: Replace the old experimental workflow with Option 1 (`interaction_review`)

**Files:**
- Modify: `.awo/awo.yaml`
- Create: `.awo/workflows/scrumbringer_change_loop/workflow.toml`
- Modify: `docs/workflow/DECISIONS.md`
- Modify: `docs/workflow/CONSTITUTION.md`

**Step 1: Enable a new workflow id instead of reusing the old greenfield one**

Replace in `.awo/awo.yaml`:
```yaml
workflows:
  enabled: [scrumbringer_greenfield]
```
with:
```yaml
workflows:
  enabled: [scrumbringer_change_loop]
```

**Step 2: Create the new semver-valid workflow source**

Write `.awo/workflows/scrumbringer_change_loop/workflow.toml` with this exact initial content:

```toml
id = "scrumbringer_change_loop"
version = "0.3.0"

[metadata]
namespace = "scrumbringer"
principal_asset = "scrumbringer.change_loop"

[budget]
tokens_hint = 20000

[[steps]]
id = "change_brief"
kind = "llm-subagent"
depends_on = []
inputs = []
outputs = ["change_brief_contract"]
skill_refs = ["bmad-po"]
context_mode = "shared"
done_criteria = ["change scope, constraints, acceptance criteria and success signal are explicit"]
verification_steps = []

[[steps]]
id = "impact_scan"
kind = "llm-subagent"
depends_on = ["change_brief"]
inputs = ["change_brief_contract"]
outputs = ["impact_scan_contract"]
skill_refs = ["bmad-po"]
context_mode = "shared"
done_criteria = ["files, technical risks, regressions and test surface are explicit"]
verification_steps = []

[[steps]]
id = "interaction_review"
kind = "llm-subagent"
depends_on = ["impact_scan"]
inputs = ["impact_scan_contract"]
outputs = ["interaction_review_contract"]
skill_refs = ["bmad-po"]
context_mode = "shared"
done_criteria = ["for user-facing interaction changes, discoverability, interaction pattern, feedback/error handling, keyboard-a11y expectations and minimum interaction tests are explicit"]
verification_steps = []

[[steps]]
id = "implement_change"
kind = "llm-subagent"
depends_on = ["interaction_review"]
inputs = ["interaction_review_contract"]
outputs = ["implementation_contract"]
skill_refs = ["bmad-dev"]
context_mode = "isolated"
done_criteria = ["minimal code change and tests are implemented against the agreed interaction contract"]
verification_steps = []

[[steps]]
id = "verify_change"
kind = "llm-subagent"
depends_on = ["implement_change"]
inputs = ["implementation_contract"]
outputs = ["verification_contract"]
skill_refs = ["bmad-qa"]
context_mode = "isolated"
done_criteria = ["tests, regressions and user-facing interaction clarity are reviewed"]
verification_steps = []

[[steps]]
id = "workflow_retro"
kind = "llm-subagent"
depends_on = ["verify_change"]
inputs = ["verification_contract"]
outputs = ["workflow_delta_contract"]
skill_refs = ["bmad-po"]
context_mode = "shared"
done_criteria = ["workflow improvement signal, keep/simplify/kill recommendation and any missed interaction risk are explicit"]
verification_steps = []
```

**Step 3: Record the workflow decision**

Append to `docs/workflow/DECISIONS.md`:

```md
## WFD-005
- **Fecha**: 2026-03-20
- **Estado**: accepted
- **Decisión**: sustituir el experimento `scrumbringer_greenfield` por `scrumbringer_change_loop@0.3.0` añadiendo un step estructural `interaction_review`.
- **Contexto**: el baseline manual produjo una UI funcional pero con mala discoverability; además, el workflow previo no era un objetivo sano para el CLI actual de AWO.
- **Alternativas consideradas**:
  - solo editar `done_criteria` dentro de steps existentes
  - mantener `scrumbringer_greenfield`
  - introducir una división más agresiva de technical/interaction review
- **Impacto**:
  - AWO tendrá un cambio estructural observable (`delta_steps`, grafo, runtime compilado)
  - el workflow gana un checkpoint generalista de interacción sin acoplarse al modal concreto
  - el mismo cambio de producto se repetirá para comparar baseline manual vs AWO rerun
- **Seguimiento**:
  - rebuild/apply
  - rerun del mismo cambio en OpenCode
  - comparación before/after
```

**Step 4: Harden the constitution minimally**

Append to `docs/workflow/CONSTITUTION.md`:

```md
14. **Interaction-risk explicitness**: cuando un cambio afecte una interacción visible al usuario, el workflow debe hacer explícitos discoverability, feedback/error handling, teclado/a11y y tests mínimos antes de implementación.
```

**Step 5: Verify the source graph**

Run:
```bash
cd /home/yo/usr/dev/repos/scrumbringer
awo workflow show scrumbringer_change_loop --json
awo workflow graph scrumbringer_change_loop --source
```
Expected:
- `workflow show` succeeds
- source graph lists 6 nodes including `interaction_review`

**Step 6: Commit**

```bash
cd /home/yo/usr/dev/repos/scrumbringer
git add .awo/awo.yaml .awo/workflows/scrumbringer_change_loop/workflow.toml docs/workflow/DECISIONS.md docs/workflow/CONSTITUTION.md
git commit -m "feat(workflow): add interaction review step for awo option1 rerun"
```

---

### Task 4: Build/apply the new workflow and capture AWO before/after evidence

**Files:**
- Create: `docs/workflow/pilots/2026-03-20-pilot-004-awo-option1-build-apply.md`
- Read: `.awo/generated/opencode/manifest.json`
- Read: `.awo/generated/opencode/mapping.json`
- Read: `.awo/generated/opencode/workflows/scrumbringer_change_loop/compiled_workflow.json`

**Step 1: Build the workflow and capture the result**

Run:
```bash
cd /home/yo/usr/dev/repos/scrumbringer
awo build --target opencode --wf scrumbringer_change_loop --json
```
Expected: success JSON with `schema_version = awo.build/v1` and a non-empty `inputs_hash`.

**Step 2: Apply the workflow runtime artifacts**

Run:
```bash
cd /home/yo/usr/dev/repos/scrumbringer
awo apply --target opencode --wf scrumbringer_change_loop --json
```
Expected: success JSON; `.opencode/commands/awo-*.md` refreshed and `.opencode/skills/scrumbringer-change-loop-*` present.

**Step 3: Inspect the compiled workflow**

Run:
```bash
cd /home/yo/usr/dev/repos/scrumbringer
cat .awo/generated/opencode/workflows/scrumbringer_change_loop/compiled_workflow.json
```
Expected: six compiled steps including `interaction_review`, with explicit `inputs`, `outputs`, `skill_refs`, `context_mode`, and `done_criteria`.

**Step 4: Write the AWO build/apply evidence note**

Write `docs/workflow/pilots/2026-03-20-pilot-004-awo-option1-build-apply.md` with this minimum content:

```md
# Pilot 004 — AWO Option 1 Build/Apply

## Workflow
- wf_id: `scrumbringer_change_loop`
- version: `0.3.0`
- structural delta: added `interaction_review`

## Build/apply evidence
- `awo workflow show`: PASS
- `awo workflow graph --source`: PASS
- `awo build --target opencode --wf scrumbringer_change_loop --json`: PASS
- `awo apply --target opencode --wf scrumbringer_change_loop --json`: PASS

## Why this matters
This is the first workflow shape in `scrumbringer` that the current AWO CLI can consume cleanly and that gives us an observable structural change to compare.
```

**Step 5: Commit**

```bash
cd /home/yo/usr/dev/repos/scrumbringer
git add .awo/generated/opencode .opencode docs/workflow/pilots/2026-03-20-pilot-004-awo-option1-build-apply.md
git commit -m "chore(workflow): build and apply awo option1 runtime for scrumbringer"
```

---

### Task 5: Rerun the exact same product request through OpenCode using the new workflow

**Files:**
- Create: `docs/workflow/pilots/2026-03-20-pilot-005-awo-rerun-task-detail-edit.md`
- Read: `.awo/runs/*`

**Step 1: Create the rerun pilot shell**

Write `docs/workflow/pilots/2026-03-20-pilot-005-awo-rerun-task-detail-edit.md` with this minimum content:

```md
# Pilot 005 — AWO Rerun After Option 1

## Change request
Editar título + descripción de una task desde el modal de detalle, con guardar/cancelar, validación visible y teclado razonable.

## Workflow under test
- wf_id: `scrumbringer_change_loop`
- version: `0.3.0`
- structural change: added `interaction_review`

## What to compare against baseline
- si el riesgo de discoverability aparece antes
- si la estrategia de tests sale más clara
- si el patrón de interacción queda mejor definido
- cuánto retrabajo se evita o no
- qué evidencia útil deja AWO
```

**Step 2: Run the same request in OpenCode**

Run in OpenCode using the new AWO runtime:
```text
/awo-help scrumbringer_change_loop
/awo-run scrumbringer_change_loop Editar título + descripción de una task desde el modal de detalle, con guardar/cancelar, validación visible y teclado razonable. Prioriza discoverability, patrón de interacción claro y tests mínimos serios.
```
Expected: a fresh run under `.awo/runs/<run_id>/` for `scrumbringer_change_loop`.

**Step 3: Capture AWO runtime evidence**

Run:
```bash
cd /home/yo/usr/dev/repos/scrumbringer
awo runs steps latest --wf scrumbringer_change_loop --target opencode --json
awo runs metrics latest --wf scrumbringer_change_loop --target opencode --json
awo compare run --wf scrumbringer_change_loop --target opencode --base previous --json || true
```
Expected:
- `runs steps` shows the 6-step shape including `interaction_review`
- `runs metrics` reports duration/tokens/cost and step counts
- `compare run` is only meaningful if there are already two AWO runs for the same workflow shape; if not, document the limitation explicitly

**Step 4: Fill the rerun pilot note**

Complete `docs/workflow/pilots/2026-03-20-pilot-005-awo-rerun-task-detail-edit.md` with:
- run id
- actual step outputs observed
- whether `interaction_review` surfaced the discoverability risk early
- tests requested by the workflow
- UX result quality vs baseline
- retrabajo avoided or not
- overhead felt

**Step 5: Commit**

```bash
cd /home/yo/usr/dev/repos/scrumbringer
git add docs/workflow/pilots/2026-03-20-pilot-005-awo-rerun-task-detail-edit.md .awo/runs
git commit -m "docs(workflow): record awo option1 rerun evidence"
```

---

### Task 6: Score workflow value separately from AWO value

**Files:**
- Create: `docs/workflow/pilots/2026-03-20-pilot-006-scorecard.md`
- Modify: `docs/workflow/DECISIONS.md`

**Step 1: Write the two-layer scorecard**

Write `docs/workflow/pilots/2026-03-20-pilot-006-scorecard.md` with this exact structure:

```md
# Pilot 006 — Workflow vs AWO Scorecard

## Workflow value
- detected discoverability risk early? yes/no
- interaction pattern clearer than baseline? yes/no
- test strategy clearer than baseline? yes/no
- retrabajo reduced? yes/no
- overall verdict: continue / revise / fail

## AWO value
- did AWO make the workflow change traceable? yes/no
- did AWO make the structural delta observable? yes/no
- were build/apply/runtime artifacts useful? yes/no
- were `runs metrics` / `runs steps` / `compare run` materially useful? yes/no
- overall verdict: continue / pivot / kill

## Notes
- limitations of current AWO measurement model:
- what was visible only because the workflow changed structurally:
- what still required human judgment outside AWO:
```

**Step 2: Register the decision after the scorecard exists**

Append `WFD-006` to `docs/workflow/DECISIONS.md` only after the scorecard is filled.

Template:

```md
## WFD-006
- **Fecha**: 2026-03-20
- **Estado**: proposed
- **Decisión**: [continue | pivot | kill]
- **Contexto**: comparación entre baseline manual y rerun con `interaction_review`.
- **Impacto**:
  - [2-3 bullets]
- **Seguimiento**:
  - [siguiente acción]
```

**Step 3: Commit**

```bash
cd /home/yo/usr/dev/repos/scrumbringer
git add docs/workflow/pilots/2026-03-20-pilot-006-scorecard.md docs/workflow/DECISIONS.md
git commit -m "docs(workflow): score workflow and awo value after option1 rerun"
```

---

Plan complete and saved to `docs/plans/2026-03-20-scrumbringer-awo-option1-rerun.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
