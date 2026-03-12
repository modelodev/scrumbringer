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
