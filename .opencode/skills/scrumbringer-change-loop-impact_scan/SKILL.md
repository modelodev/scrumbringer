# Skill: scrumbringer-change-loop-impact_scan

Use this skill only for workflow `scrumbringer_change_loop` step `impact_scan`.

Execution contract:

- Dependencies already satisfied: change_brief
- Required inputs: change_brief_contract
- Required outputs: impact_scan_contract
- Context mode: `shared`
- Done criteria: files, technical risks, regressions and test surface are explicit
- Source asset lineage: `scrumbringer.change_loop`

Artifact contract details:

- `impact_scan_contract`: emit a durable contract artifact before completing the step

## Embedded capabilities

### bmad-po

Missing runtime source for `bmad-po`.

Return at least:

- `status`
- `executive_summary`
- `artifacts[]`
- `risks[]`
