# Pilot 006 — Workflow 0.4.0 with Browser Acceptance

## Change request
Editar título + descripción de una task desde el modal de detalle, con guardar/cancelar, validación visible y teclado razonable.

## Workflow under test
- wf_id: `scrumbringer_change_loop`
- version: `0.4.0`
- structural changes vs `0.3.0`:
  - added `test_design`
  - added `browser_acceptance`

## Goal of this rerun
Cerrar mejor el gap entre:
- análisis de interacción
- estrategia de tests
- verificación interna
- aceptación funcional real en navegador

## Run evidence
- run_id: `run_1774008174`
- observed outcome: `stalled_then_manually-recovered`
- `test_design` completed and produced contract output
- `implement_change` / `verify_change` / `browser_acceptance` did not complete cleanly inside the original run path

## What improved vs 0.3.0
- `test_design` obligó a explicitar happy path, validación, permisos/auth, teclado, regresiones y edge cases antes de implementar.
- `browser_acceptance` como idea resultó correcta: el experimento volvió a obligar a comprobar la app real en `https://localhost:8443` con datos seed.
- El ciclo acabó encontrando el problema funcional importante de fondo y no solo el riesgo UX: el `403 Forbidden` al guardar.

## What went wrong

### 1. `test_design` produjo diseño, no test ejecutable
- Se generó `.awo/runs/run_1774008174/artifacts/test_design_contract.md`.
- Pero el test esperado no quedó materializado automáticamente en disco de forma válida.
- El workflow no tenía un handoff duro entre “diseñar tests” y “tener tests P0 reales listos para mandar”.

### 2. TDD quedó en intención, no en enforcement
- El contrato hablaba de red-green-refactor.
- En la práctica no hubo garantía de:
  - tests escritos en paths concretos
  - fase roja explícita
  - bloqueo real de implementación si faltaba test materializado

### 3. Hubo demasiadas interrupciones operativas
- El agente OpenCode/ACP sufrió reconexiones y pérdida de continuidad visible.
- La primera browser acceptance se atascó por intentar escribir un helper fuera del repo (`/tmp`) y topar con permisos.
- `awo apply` ya venía mostrando fricción por drift en runtime gestionado.
- Resultado: demasiado tiempo en coordinación/recuperación y no en validación del cambio.

### 4. `verify_change` seguía siendo demasiado optimista
- Permitía la sensación de progreso aunque el riesgo de auth/permissions aún no estaba verdaderamente resuelto.
- La aceptación real seguía llegando demasiado tarde para descubrir que Available tasks devolvían `403` al guardar.

### 5. `interaction_review` mejoró discoverability, pero no micro-usabilidad
- Sí ayudó con discoverability y patrón de interacción.
- No captó una inconsistencia semántica visible en el resultado final:
  - vista: `Tarjeta` + `Descripción`
  - edición: `Título` + `Descripción`
  - post-save: vuelve a `Tarjeta` + `Descripción`
- Eso indica que faltó revisar mejor consistencia de labels, copy y transiciones de estado.

## Root causes behind the “constant stumbling” feeling
- handoffs demasiado blandos entre steps
- falta de pruebas ejecutables antes de implementar
- cobertura real insuficiente de permisos/auth
- separación insuficiente entre “evidencia de diseño” y “evidencia de ejecución”
- fricción operativa innecesaria en la integración OpenCode/ACP/browser tooling

## Interim verdict on workflow 0.4.0
- **No es suficiente** para dar por cerrado el problema.
- **Sí mejora** respecto a `0.3.0`, porque ya empuja a pensar tests y navegador real.
- Pero necesita una evolución adicional antes del siguiente rerun.

## Proposed workflow delta for 0.5.0
1. Añadir un step estructural entre `test_design` e `implement_change`:
   - `test_materialization` (o equivalente)
   - objetivo: convertir contrato de tests en tests P0 reales en disco y dejar explícita la fase roja/estado inicial
2. Endurecer `interaction_review` para exigir:
   - consistencia de naming/copy entre view/edit/save
   - claridad de transición de estado
   - chequeo mínimo de micro-usabilidad
3. Endurecer `verify_change` para exigir:
   - comandos exactos ejecutados
   - qué riesgos P0 quedaron cubiertos y cuáles no
   - si permisos/auth están cubiertos por tests o dependen de browser acceptance
4. Endurecer `browser_acceptance` para exigir:
   - scripts y artefactos dentro del repo
   - observaciones UX además de fallos funcionales
   - target explícito `https://localhost:8443`

## Measurement consequence
El siguiente rerun debe repetir exactamente la misma feature desde código de producto limpio para poder medir si `0.5.0`:
- reduce interrupciones
- materializa mejor TDD
- detecta antes gaps de permisos/auth
- detecta mejor inconsistencias UX/copy
- deja mejor evidencia para decidir `continue / pivot / kill`
