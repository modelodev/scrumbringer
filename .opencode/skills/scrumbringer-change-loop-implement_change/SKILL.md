# Skill: scrumbringer-change-loop-implement_change

Use this skill only for workflow `scrumbringer_change_loop` step `implement_change`.

Execution contract:

- Dependencies already satisfied: test_materialization
- Required inputs: interaction_review_contract, test_design_contract, test_materialization_contract
- Required outputs: implementation_contract
- Context mode: `isolated`
- Done criteria: minimal code change and tests are implemented against the agreed interaction contract and the materialized test surface
- Source asset lineage: `scrumbringer.change_loop`

Artifact contract details:

- `implementation_contract`: changed files, tests run, and unresolved delivery risks

## Embedded capabilities

### bmad-dev

Missing runtime source for `bmad-dev`.

Return at least:

- `status`
- `executive_summary`
- `artifacts[]`
- `risks[]`
