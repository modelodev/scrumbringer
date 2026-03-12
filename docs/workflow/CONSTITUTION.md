# Workflow Constitution (v0.1)

Propósito: definir las reglas no negociables del workflow propio para Scrumbringer.

## Principios

1. **Compiler-driven primero**: en Gleam, los tipos y el compilador son parte del diseño.
2. **TDD estricto**: toda implementación pasa por RED -> GREEN -> REFACTOR.
3. **Casuística obligatoria**: no vale solo happy path; cubrir edge, error, auth, concurrencia y regresión.
4. **Arquitectura adversarial**: toda propuesta técnica relevante se cuestiona al menos una vez.
5. **Contrato de salida único**: cada agente/subagente devuelve un sobre estructurado común.
6. **Trazabilidad explícita**: cada fase deja rastro de entradas, decisiones, artefactos y riesgos.
7. **Calidad antes de velocidad**: no se archiva nada con CRITICAL abierto.
8. **Artefactos pequeños y útiles**: evitar documentos largos sin decisiones accionables.
9. **Sin decisiones implícitas**: toda decisión clave se registra en `DECISIONS.md`.
10. **Workflow versionado**: cualquier cambio del propio workflow se registra en `CHANGELOG.md`.
11. **Modo debug disponible**: cuando esté activo, se amplía el nivel de trazabilidad.
12. **Evolución controlada**: cambios al workflow solo mediante meta-flujo de cambio.

## Gate de calidad mínimo

- Historia en estado GO (checklist de borrador)
- Cobertura de escenarios crítica (incluyendo negativos)
- Verificación con severidades: CRITICAL/WARNING/SUGGESTION
- Resultado final: PASS o FAIL (sin ambigüedad)

## Enmiendas

Toda enmienda de esta constitución requiere:
1) propuesta breve,
2) impacto esperado,
3) piloto o evidencia,
4) registro en `DECISIONS.md` y `CHANGELOG.md`.
