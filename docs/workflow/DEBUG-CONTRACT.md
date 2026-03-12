# Debug Contract (v0.1)

Define la salida de trazabilidad cuando el coordinador opera en modo debug.

## Niveles

- **normal**: resultado + siguiente paso
- **debug**: resultado + trazabilidad completa por fase

## Sobre de salida mínimo (siempre)

```json
{
  "status": "ok|warning|blocked|failed",
  "executive_summary": "string",
  "artifacts": [
    { "name": "string", "ref": "string|null", "store": "none|file|memory" }
  ],
  "next_recommended": ["string"],
  "risks": ["string"]
}
```

## Campos extra obligatorios en modo debug

```json
{
  "trace": {
    "phase": "string",
    "agent": "string",
    "input_refs": ["path|id|url"],
    "actions": ["string"],
    "decisions": ["string"],
    "alternatives": ["string"],
    "validation": {
      "checks_run": ["string"],
      "checks_failed": ["string"]
    },
    "duration_ms": 0
  }
}
```

## Reglas

1. Si falta un campo obligatorio, el coordinador pide reformateo.
2. Máximo 2 reintentos de reformato antes de marcar `blocked`.
3. Los `input_refs` deben apuntar a artefactos reales, no texto libre ambiguo.
4. `actions` describe hechos ejecutados, no intenciones.
5. `decisions` y `alternatives` son obligatorios en fases de diseño.
6. Si hay `CRITICAL`, `status` no puede ser `ok`.

## Política de visibilidad

- En **normal**, ocultar `trace` salvo que se pida.
- En **debug**, mostrar `trace` completo por cada fase.
