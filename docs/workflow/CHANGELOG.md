# Workflow Changelog

Todos los cambios del workflow propio deben registrarse aquí.

Formato recomendado por entrada:
- fecha
- tipo: Added | Changed | Deprecated | Removed | Fixed
- resumen
- archivos afectados
- referencia a decisión (`WFD-XXX`)

---

## 2026-03-20

### Changed
- El baseline manual del piloto 002 se revierte para repetir exactamente la misma petición tras cambiar estructuralmente el workflow y poder comparar evidencia before/after.
- `scrumbringer_change_loop` evoluciona de `0.3.0` a `0.4.0` añadiendo `test_design` y `browser_acceptance` para cerrar mejor el gap entre diseño de tests, verificación interna y aceptación funcional real.

## 2026-02-23

### Added
- Bootstrap del workflow propio (`.wf/WORKFLOW.md`, `.wf/agents/wf-orchestrator.md`).
- Constitución del workflow (`docs/workflow/CONSTITUTION.md`).
- Registro de decisiones (`docs/workflow/DECISIONS.md`).
- Contrato de depuración (`docs/workflow/DEBUG-CONTRACT.md`).

### Changed
- Runtime OpenCode simplificado a un único agente `wf-orchestrator`.

### Deprecated
- Uso activo de BMAD en runtime (se mantiene snapshot legacy para referencia).

### References
- WFD-001
- WFD-002
