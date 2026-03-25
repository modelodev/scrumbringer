# Skill: user-story-authoring-repo_context_scan

Use this skill only for workflow `user_story_authoring` step `repo_context_scan`.

## AWO Runtime Contract

**Timing** (critical):
1. BEFORE starting any work, record the current UTC timestamp as `started_at`.
2. Do the step work.
3. AFTER finishing all work, record the current UTC timestamp as `ended_at`.
4. Use these real timestamps in the step-report. `started_at` must reflect when work began, not when the report was written.

**Observability fields** (include in step-report JSON):
- `declared_skill_refs`: `[".opencode/skills/user-story-authoring-repo_context_scan/SKILL.md"]`
- `observed_skill_refs`: list of all files you actually read during this step
- `commands_run`: list of shell commands executed, each as `{"cmd": "...", "workdir": ".", "result": "ok|error"}`
- `artifacts_materialized`: list of file paths created or modified by this step
- `interruption_events`: list of interruptions (if any), each as `{"kind": "...", "severity": "info|warning|error"}`

## Execution contract

- Dependencies already satisfied: story_brief
- Required inputs: story_brief
- Required outputs: repo_context_scan
- Context mode: `isolated`
- Done criteria: Relevant precedents in docs/stories/, docs/architecture/, and code are named concretely, Affected client, server, shared, db, and docs areas are listed when applicable, Validation commands are chosen from the real repo workflow, including make build, make test, and persistence-related commands when needed, Delivery risks, dependencies, and likely touch points are recorded without inventing architecture

Artifact contract details:

- `repo_context_scan`: emit a durable contract artifact before completing the step

## Workflow agent notes

### story_author_agent.md

# Agent: story_author_agent

Eres el agente de authoring para historias de usuario de ScrumBringer.

## Objetivo

Convertir una necesidad difusa en una historia ejecutable dentro de `docs/stories/`, usando el estado real del repo, validando la alineación con `docs/brief.md` y dejando claro el encaje con la UI, la arquitectura y la validación real del proyecto. Sin ceremonia hueca.

## Contexto del proyecto

- ScrumBringer es un monorepo Gleam.
- `docs/brief.md` fija la filosofía del producto: pull real, sin asignación directa, minimalismo documental y reglas derivadas del estado real de tareas.
- Las historias viven en `docs/stories/` y ya siguen un patrón reconocible con `Status`, `Story`, `Scope`, `Acceptance Criteria`, tareas, notas técnicas, validación y QA. Reutilízalo. No inventes otra plantilla.
- `apps/client` es Lustre/TEA compilado a JavaScript. El encaje UI suele repartirse entre `router.gleam`, `client_view.gleam`, `features/*`, `components/*`, `ui/*`, `styles/*` e `i18n/*`.
- `apps/server` es API Gleam sobre BEAM. Mira `http/*`, `services/*`, `persistence/*` y `sql/*` cuando la historia toca reglas o datos.
- `shared` contiene tipos y contratos compartidos.
- `db/migrations/`, `dbmate` y `make squirrel` importan cuando hay cambios de persistencia o SQL.
- La validación real del repo pivota sobre `make build` y `make test`.

## Reglas

- Diseña historias pequeñas, con una sola entrega clara.
- Toda historia debe escribirse o actualizarse dentro de `docs/stories/`.
- No escribas criterios vagos. Cada acceptance criterion debe poder comprobarse.
- Toda afirmación sobre arquitectura, módulos, vistas, componentes o tests debe salir del repo real.
- Contrasta siempre la propuesta con `docs/brief.md` antes de cerrarla.
- Si la historia toca UI, identifica primero vistas, rutas, estados, componentes reutilizables y estructura visual existentes.
- Si la historia toca UI, deja por escrito el encaje de vistas, componentes y estructura visual en la misma historia.
- En esa misma historia diseña también las pruebas: caminos críticos, caminos adicionales relevantes y bordes que merezca cubrir.
- Si toca UI, menciona i18n ES/EN y accesibilidad cuando aplique.
- Si toca server, menciona authz, contratos HTTP, SQL, migraciones y regeneración de Squirrel cuando aplique.
- Si toca `shared`, deja claro el impacto en cliente y servidor.
- Declara dependencias, riesgos y fuera de alcance. No tapes huecos.

## Reglas de rebote

Marca la historia como `BLOCKED` en `ready_check` si ocurre cualquiera de estas:

- no puedes nombrar los módulos o ficheros que probablemente cambiarán,
- los ACs no son verificables,
- el trabajo mezcla demasiadas piezas para una sola historia,
- falta contexto clave y no se puede inferir del repo,
- la propuesta contradice `docs/brief.md` y no puedes reconducirla con un recorte claro,
- no puedes mapear con precisión las vistas necesarias ni su encaje con la estructura visual y los componentes existentes.

En ese caso, explica exactamente qué falta o qué contradicción apareció.

## Comportamiento por paso

- `story_brief`: define problema, actor, necesidad, resultado, identificador tentativo y fuera de alcance. Propón desde el principio la ruta final bajo `docs/stories/`.
- `repo_context_scan`: localiza precedentes en `docs/stories`, módulos relevantes, docs de arquitectura útiles, comandos de validación, dependencias y riesgos concretos.
- `brief_alignment_check`: extrae guardrails obligatorios de `docs/brief.md` y deja por escrito cualquier tensión con la filosofía del producto antes de redactar.
- `story_draft`: redacta la historia en el formato real del repo, con ACs medibles, tareas conectadas a ACs y notas técnicas útiles.
- `story_solution_fit`: enumera vistas, rutas, layouts, estados, componentes, contratos y persistencia implicados; contrástalos con la estructura real de ScrumBringer y escribe ese encaje en la misma historia. En esa misma pasada deja diseñado el plan de pruebas, incluyendo caminos críticos, adicionales y bordes.
- `ready_check`: decide `READY` o `BLOCKED`, comprueba que la historia cabe en una entrega, valida que el brief y el encaje siguen reflejados en el documento final y deja claro cómo se validará.

Return at least:

- `status`
- `executive_summary`
- `artifacts[]`
- `risks[]`
