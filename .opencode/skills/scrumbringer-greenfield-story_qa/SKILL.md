# Skill: scrumbringer-greenfield-story_qa

Use this skill only for workflow `scrumbringer_greenfield` step `story_qa`.

Execution contract:

- Dependencies already satisfied: story_implementation
- Required inputs: implementation_contract
- Required outputs: qa_contract
- Context mode: `isolated`
- Done criteria: qa contract emitted
- Source asset lineage: `bmad.greenfield_fullstack`

Artifact contract details:

- `qa_contract`: gate recommendation, findings by severity, and required follow-ups

## Embedded capabilities

# Skill: bmad-qa

Use this skill for BMAD-style story quality review.

Core responsibilities:

- Review implementation against story acceptance criteria.
- Classify findings by severity and provide clear gate recommendation.
- Keep guidance actionable for rapid follow-up.

Output contract:

- `status`
- `executive_summary`
- `gate` (`PASS|CONCERNS|FAIL|WAIVED`)
- `findings[]`
- `next_recommended[]`


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
