# Skill: scrumbringer-change-loop-test_design

Use this skill only for workflow `scrumbringer_change_loop` step `test_design`.

Execution contract:

- Dependencies already satisfied: interaction_review
- Required inputs: interaction_review_contract
- Required outputs: test_design_contract
- Context mode: `shared`
- Done criteria: a concrete red-green-refactor test plan is explicit before implementation, covering happy path, validation, auth-permissions, error paths, keyboard interactions, regressions and relevant edge cases
- Source asset lineage: `scrumbringer.change_loop`

Artifact contract details:

- `test_design_contract`: emit a durable contract artifact before completing the step

## Embedded capabilities

### bmad-qa

Missing runtime source for `bmad-qa`.

Return at least:

- `status`
- `executive_summary`
- `artifacts[]`
- `risks[]`
