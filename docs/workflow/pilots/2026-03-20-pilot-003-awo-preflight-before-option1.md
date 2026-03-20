# Pilot 003 — AWO Preflight Before Option 1

## Current workflow state
- wf_id: `scrumbringer_greenfield`
- version: `0.2.0-design`
- shape: greenfield-like flow, not brownfield-specific

## CLI evidence
- `awo workflow show scrumbringer_greenfield --json`: PASS
- `awo workflow graph scrumbringer_greenfield --source`: PASS
- `awo build --target opencode --wf scrumbringer_greenfield --json`: PASS
- `awo compare version scrumbringer_greenfield 0.2.0-design 0.3.0 --json`: FAIL because `0.2.0-design` is not semver-compliant

## Interpretation
The current workflow is consumable enough for source inspection/build, but it is still a poor validation target:
- the shape is greenfield-ish instead of brownfield-oriented
- semver-based workflow comparison/migration paths are blocked by `0.2.0-design`
- we still want a structurally different workflow (`interaction_review`) for a better AWO comparison target
