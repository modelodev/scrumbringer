# Skill: scrumbringer-change-loop-workflow_retro

Use this skill only for workflow `scrumbringer_change_loop` step `workflow_retro`.

Execution contract:

- Dependencies already satisfied: verify_change
- Required inputs: verification_contract
- Required outputs: workflow_delta_contract
- Context mode: `shared`
- Done criteria: workflow improvement signal, keep/simplify/kill recommendation and any missed interaction risk are explicit
- Source asset lineage: `scrumbringer.change_loop`

Artifact contract details:

- `workflow_delta_contract`: emit a durable contract artifact before completing the step

## Embedded capabilities

### bmad-po

Missing runtime source for `bmad-po`.

Return at least:

- `status`
- `executive_summary`
- `artifacts[]`
- `risks[]`
