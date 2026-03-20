# Workflow Decisions (ADR-lite)

Registro de decisiones clave del workflow y su evolución.

## Formato

- **ID**: WFD-XXX
- **Fecha**: YYYY-MM-DD
- **Estado**: proposed | accepted | superseded | rejected
- **Decisión**: resumen de una línea
- **Contexto**: problema que resuelve
- **Alternativas consideradas**: lista breve
- **Impacto**: qué cambia en práctica
- **Seguimiento**: métricas o señales de éxito

---

## WFD-001
- **Fecha**: 2026-02-23
- **Estado**: accepted
- **Decisión**: Desactivar BMAD en runtime y arrancar workflow propio bootstrap.
- **Contexto**: evitar interferencias durante diseño y depuración del nuevo workflow.
- **Alternativas consideradas**:
  - Mantener BMAD en paralelo
  - Eliminación progresiva parcial
- **Impacto**:
  - `opencode.jsonc` simplificado a `wf-orchestrator`
  - BMAD conservado como snapshot legacy
- **Seguimiento**:
  - menor ruido en ejecución
  - claridad en trazabilidad de fases

## WFD-002
- **Fecha**: 2026-02-23
- **Estado**: accepted
- **Decisión**: Mantener snapshot de seguridad pre-remoción de BMAD.
- **Contexto**: conservar capacidad de rollback y referencia histórica.
- **Alternativas consideradas**:
  - borrar BMAD sin snapshot
  - mantener BMAD activo
- **Impacto**:
  - snapshot en `docs/legacy/bmad/2026-02-23-pre-bmad-removal/`
  - tag git `workflow-pre-bmad-removal`
- **Seguimiento**:
  - posibilidad de comparar/mejorar sin pérdida de conocimiento

## WFD-005
- **Fecha**: 2026-03-20
- **Estado**: accepted
- **Decisión**: sustituir el experimento `scrumbringer_greenfield` por `scrumbringer_change_loop@0.3.0` añadiendo un step estructural `interaction_review`.
- **Contexto**: el baseline manual produjo una UI funcional pero con mala discoverability; además, el workflow previo no era una buena base de comparación semver para el CLI actual de AWO.
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
