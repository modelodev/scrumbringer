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

## WFD-007
- **Fecha**: 2026-03-20
- **Estado**: accepted
- **Decisión**: reconocer explícitamente que `test_design` por sí solo no cierra el gap diseño→test ejecutable y que el runtime actual sufre fricción operativa suficiente como para sesgar la medición.
- **Contexto**: en `run_1774008174`, el workflow produjo un contrato de tests útil pero no garantizó que el test existiera en disco ni que la fase roja fuera visible. Además, la aceptación en navegador sufrió interrupciones por permisos al escribir fuera del repo y reconexiones ACP/OpenCode.
- **Alternativas consideradas**:
  - tratar el atasco como incidente puntual y no cambiar el workflow
  - resolverlo solo con disciplina manual fuera del workflow
  - cargar más responsabilidad sobre `implement_change` sin nuevo step puente
- **Impacto**:
  - el problema deja de interpretarse como mero fallo de ejecución aislado
  - se justifica medir explícitamente handoffs, materialización de tests y fricción operativa como parte del valor real de AWO
  - la siguiente evolución del workflow debe atacar el puente `test_design -> implement_change` y endurecer la aceptación operacional
- **Seguimiento**:
  - introducir step puente en la siguiente versión
  - medir si disminuyen interrupciones e intervención manual
  - comprobar si los tests P0 quedan materializados antes de implementar

## WFD-008
- **Fecha**: 2026-03-20
- **Estado**: accepted
- **Decisión**: evolucionar `scrumbringer_change_loop` a `0.5.0` añadiendo `test_materialization` y endureciendo `interaction_review`, `verify_change` y `browser_acceptance`.
- **Contexto**: el workflow `0.4.0` ya demostró valor al empujar mejor el diseño de tests y la aceptación real, pero siguió dejando demasiados huecos: TDD declarativo sin enforcement, cobertura insuficiente de permisos/auth, mala observabilidad de riesgos no cubiertos e inconsistencias de copy/estado que pasaron a producción experimental.
- **Alternativas consideradas**:
  - mantener `0.4.0` y confiar en más disciplina humana
  - añadir solo texto a `done_criteria` sin nuevo step estructural
  - mover toda la responsabilidad de calidad a `browser_acceptance`
- **Impacto**:
  - `test_materialization` fuerza a bajar el diseño de tests a archivos reales y a explicitar estado red/green antes de programar
  - `interaction_review` pasa a revisar también consistencia semántica y claridad entre view/edit/save
  - `verify_change` exige evidencia más concreta sobre cobertura real de riesgos P0
  - `browser_acceptance` incorpora disciplina operativa (artefactos dentro del repo) y observaciones UX además de fallos funcionales
- **Seguimiento**:
  - validate/build/apply
  - commit del workflow sin mezclarlo con código de producto
  - reset del cambio de producto y rerun limpio para comparar `0.4.0` vs `0.5.0`
  - reevaluar valor de AWO antes de escalar nuevos desarrollos en OpenCode
