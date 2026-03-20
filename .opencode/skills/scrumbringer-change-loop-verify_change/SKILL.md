# Skill: scrumbringer-change-loop-verify_change

Use this skill only for workflow `scrumbringer_change_loop` step `verify_change`.

Execution contract:

- Dependencies already satisfied: implement_change
- Required inputs: implementation_contract, test_design_contract, test_materialization_contract
- Required outputs: verification_contract
- Context mode: `isolated`
- Done criteria: exact commands run, tests added or updated, covered vs uncovered P0 risks, auth-permissions coverage status and user-facing interaction clarity are reviewed against the expected test design
- Source asset lineage: `scrumbringer.change_loop`

Artifact contract details:

- `verification_contract`: emit a durable contract artifact before completing the step

## Embedded capabilities

### bmad-qa

Missing runtime source for `bmad-qa`.

Return at least:

- `status`
- `executive_summary`
- `artifacts[]`
- `risks[]`
