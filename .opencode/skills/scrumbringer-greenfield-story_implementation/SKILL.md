# Skill: scrumbringer-greenfield-story_implementation

Use this skill only for workflow `scrumbringer_greenfield` step `story_implementation`.

Execution contract:

- Dependencies already satisfied: story_design
- Required inputs: story_design_contract
- Required outputs: implementation_contract
- Context mode: `isolated`
- Done criteria: implementation contract emitted
- Source asset lineage: `bmad.greenfield_fullstack`

Artifact contract details:

- `implementation_contract`: changed files, tests run, and unresolved delivery risks

## Embedded capabilities

# Skill: bmad-dev

Use this skill for BMAD-style story implementation.

Core responsibilities:

- Implement the story in small, verifiable increments.
- Run required tests and report concrete evidence.
- Emit an implementation contract with changed files and unresolved issues.

Output contract:

- `status`
- `executive_summary`
- `artifacts[]`
- `validation[]`
- `risks[]`


## Workflow agent notes

### analyst.md

# analyst

Produce `project-brief.md` from project concept, optionally including brainstorming and market-research prompts.


### architect.md

# architect

Author `fullstack-architecture.md` from PRD and UX specification with implementation guidance.


### dev.md

# dev

Implement approved story scope and update implementation evidence for review.


### pm.md

# pm

Generate and maintain `prd.md`, including reconciliation after architecture feedback.


### po.md

# po

Validate planning artifacts, shard documents, and govern closure criteria.


### qa.md

# qa

Perform optional quality review and emit actionable findings before closure.


### sm.md

# sm

Create implementation-ready stories from sharded PRD and architecture artifacts.


### ux_expert.md

# ux_expert

Create `front-end-spec.md` and optional AI UI generation prompt artifacts.

Return at least:

- `status`
- `executive_summary`
- `artifacts[]`
- `risks[]`
