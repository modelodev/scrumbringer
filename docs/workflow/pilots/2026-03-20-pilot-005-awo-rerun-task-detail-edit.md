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

## Run evidence
- run_id: `run_1742460000`
- status: `ok`
- started_at: `2026-03-20T10:00:00Z`
- ended_at: `2026-03-20T10:08:30Z`
- budget: `11000 tokens / $0.33`

## What AWO surfaced
- `interaction_review` eligió patrón `toggle edit`
- definió estados, teclado y 7 tests E2E de interacción
- detectó el riesgo `discoverability_tab_blindspot`
- `workflow_retro` recomendó simplificar: 6 pasos era demasiado para una feature pequeña

## Post-run functional finding
- Comprobación manual posterior en `https://localhost:8443`: al editar el nombre y guardar, aparece `Forbidden`
- Interpretación: el workflow mejoró el análisis de interacción, pero la verificación siguió siendo insuficiente para garantizar funcionalidad real end-to-end

## Interim conclusion
- El workflow mejoró respecto al baseline en anticipación del riesgo UX
- AWO aportó trazabilidad, build/apply y evidencia de ejecución
- El flujo todavía falla en aceptación funcional real, así que antes del siguiente rerun conviene:
  - añadir un step de diseño explícito de tests
  - añadir un step de browser acceptance con navegación real sobre el entorno seed
