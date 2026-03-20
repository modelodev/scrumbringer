# Skill: scrumbringer-change-loop-browser_acceptance

Use this skill only for workflow `scrumbringer_change_loop` step `browser_acceptance`.

Execution contract:

- Dependencies already satisfied: verify_change
- Required inputs: verification_contract, test_design_contract
- Required outputs: browser_acceptance_contract
- Context mode: `isolated`
- Done criteria: for browser-reachable user-facing changes, navigate the real app at https://localhost:8443 using seeded data, execute the critical acceptance path end-to-end and capture functional failures with concrete evidence
- Source asset lineage: `scrumbringer.change_loop`

Artifact contract details:

- `browser_acceptance_contract`: emit a durable contract artifact before completing the step

## Embedded capabilities

### agent-browser

Missing runtime source for `agent-browser`.

### bmad-qa

Missing runtime source for `bmad-qa`.

Return at least:

- `status`
- `executive_summary`
- `artifacts[]`
- `risks[]`
