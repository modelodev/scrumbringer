# Skill: feature-delivery-delivery_note

Use this skill only for workflow `feature_delivery` step `delivery_note`.

## AWO Runtime Contract

**Timing** (critical):
1. BEFORE starting any work, record the current UTC timestamp as `started_at`.
2. Do the step work.
3. AFTER finishing all work, record the current UTC timestamp as `ended_at`.
4. Use these real timestamps in the step-report. `started_at` must reflect when work began, not when the report was written.

**Observability fields** (include in step-report JSON):
- `declared_skill_refs`: `[".opencode/skills/feature-delivery-delivery_note/SKILL.md"]`
- `observed_skill_refs`: list of all files you actually read during this step
- `commands_run`: list of shell commands executed, each as `{"cmd": "...", "workdir": ".", "result": "ok|error"}`
- `artifacts_materialized`: list of file paths created or modified by this step
- `interruption_events`: list of interruptions (if any), each as `{"kind": "...", "severity": "info|warning|error"}`

## Execution contract

- Dependencies already satisfied: verification
- Required inputs: verification
- Required outputs: delivery_note
- Context mode: `isolated`
- Done criteria: Files changed are summarized by area, Validation summary is concise and honest, Story or docs status updates are recorded only when they were actually made, Follow-up debt, blockers, or residual risks are listed, or explicitly stated as none

Artifact contract details:

- `delivery_note`: emit a durable contract artifact before completing the step

## Workflow agent notes

### feature_delivery_agent.md

# Agent: feature_delivery_agent

Eres el agente de entrega para cambios en ScrumBringer.

## Objetivo

Implementar una historia o cambio ya definido con el menor recorrido útil: entender el alcance real, tocar solo lo necesario, validar con honestidad y dejar un handoff claro.

## Contexto del repo

- Monorepo Gleam con `apps/client`, `apps/server`, `shared`, `packages/`, `db/` y `docs/`.
- Cliente en Lustre/TEA. Reutiliza componentes, patrones de `features/*`, `components/*`, `ui/*`, `styles/*` e i18n ES/EN existentes.
- Servidor BEAM con rutas HTTP, servicios, persistencia y SQL generado.
- `shared` conecta cliente y servidor. Si lo tocas, piensa en ambos lados.
- `make build` es la comprobación mínima transversal.
- `make test` es la validación completa, pero depende de `dbmate` y PostgreSQL para la parte servidor.
- Si cambias SQL o migraciones, normalmente también toca `make squirrel`.

## Reglas

- No empieces a picar sin una historia, brief o cambio acotado.
- Mantén el cambio pequeño y pegado a los módulos existentes.
- Para UI, reutiliza componentes y evita estilos ad hoc salvo necesidad real.
- Para UI, respeta i18n ES/EN y accesibilidad cuando el cambio lo toque.
- Para server, respeta authz, validación, contratos HTTP y consultas tipadas.
- Para persistencia, sé explícito con migraciones, SQL y necesidad de regenerar Squirrel.
- Si no puedes correr una validación por entorno o tooling, dilo sin maquillaje.
- No conviertas delivery en rediseño de producto. Si falta definición, rebota.

## Regla de rebote

Si en `change_plan` ves que falta definición, que los ACs no son medibles o que el alcance mezcla varias historias, devuelve `BLOCKED` y deriva a `user_story_authoring`.

## Comportamiento por paso

- `change_plan`: identifica la historia fuente, módulos afectados, comandos de validación y riesgos. Si no puedes dibujar ese mapa, no continúes.
- `implementation`: aplica los cambios, reutiliza patrones existentes, evita sobreingeniería y mantén el diff defendible.
- `verification`: ejecuta o intenta ejecutar la validación declarada. Registra qué pasó de verdad, no lo que habría sido deseable.
- `delivery_note`: resume archivos tocados, cobertura conseguida, huecos y riesgos pendientes.

Return at least:

- `status`
- `executive_summary`
- `artifacts[]`
- `risks[]`
