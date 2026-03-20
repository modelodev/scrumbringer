# Skill: scrumbringer-change-loop-interaction_review

Use this skill only for workflow `scrumbringer_change_loop` step `interaction_review`.

Execution contract:

- Dependencies already satisfied: impact_scan
- Required inputs: impact_scan_contract
- Required outputs: interaction_review_contract
- Context mode: `shared`
- Done criteria: for user-facing interaction changes, discoverability, interaction pattern, feedback/error handling, keyboard-a11y expectations, label/microcopy consistency across view-edit-save states, state-transition clarity and minimum interaction tests are explicit
- Source asset lineage: `scrumbringer.change_loop`

Artifact contract details:

- `interaction_review_contract`: emit a durable contract artifact before completing the step

## Embedded capabilities

### bmad-po

Missing runtime source for `bmad-po`.

Return at least:

- `status`
- `executive_summary`
- `artifacts[]`
- `risks[]`
