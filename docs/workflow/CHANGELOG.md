# Workflow Changelog

Todos los cambios del workflow propio deben registrarse aquí.

Formato recomendado por entrada:
- fecha
- tipo: Added | Changed | Deprecated | Removed | Fixed
- resumen
- archivos afectados
- referencia a decisión (`WFD-XXX`)

---

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
