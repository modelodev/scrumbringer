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

## WFD-006
- **Fecha**: 2026-03-20
- **Estado**: accepted
- **Decisión**: evolucionar `scrumbringer_change_loop` a `0.4.0` añadiendo dos steps estructurales nuevos: `test_design` antes de implementar y `browser_acceptance` antes de cerrar el workflow.
- **Contexto**: el rerun con `interaction_review` mejoró la anticipación UX, pero una prueba manual real reveló un fallo funcional (`Forbidden` al guardar) que sobrevivió a `verify_change`. Eso demuestra que el flujo aún valida demasiado bien lo estático y demasiado mal la aceptación funcional real.
- **Alternativas consideradas**:
  - mantener el flujo actual y confiar en `verify_change`
  - añadir solo más `done_criteria` a steps existentes
  - hacer browser acceptance manual fuera del workflow
- **Impacto**:
  - `test_design` obliga a explicitar una batería red-green-refactor antes de desarrollar
  - `browser_acceptance` obliga a ejecutar el flujo real en `https://localhost:8443` con datos seed cuando el cambio sea user-facing y browser-reachable
  - AWO vuelve a ganar un delta estructural observable y el workflow cierra mejor el gap entre tests internos y funcionalidad real
- **Seguimiento**:
  - rebuild/apply
  - rerun limpio desde repo sin cambios de producto previos
  - comprobar si el nuevo flujo detecta el `Forbidden` antes de cerrar como válido
