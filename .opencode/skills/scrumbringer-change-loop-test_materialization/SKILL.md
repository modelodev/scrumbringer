# Skill: scrumbringer-change-loop-test_materialization

Use this skill only for workflow `scrumbringer_change_loop` step `test_materialization`.

Execution contract:

- Dependencies already satisfied: test_design
- Required inputs: test_design_contract, interaction_review_contract
- Required outputs: test_materialization_contract
- Context mode: `isolated`
- Done criteria: P0 tests from the agreed test design are materialized on disk at explicit paths, their current red/green status is explicit, and implementation cannot proceed with missing or only-theoretical test coverage for the main risk surface
- Source asset lineage: `scrumbringer.change_loop`

Artifact contract details:

- `test_materialization_contract`: emit a durable contract artifact before completing the step

## Embedded capabilities

### bmad-qa

Missing runtime source for `bmad-qa`.

### bmad-dev

Missing runtime source for `bmad-dev`.

Return at least:

- `status`
- `executive_summary`
- `artifacts[]`
- `risks[]`
