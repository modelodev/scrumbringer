# Skill: scrumbringer-greenfield-story_design

Use this skill only for workflow `scrumbringer_greenfield` step `story_design`.

Execution contract:

- Dependencies already satisfied: project_brief
- Required inputs: project_brief_contract
- Required outputs: story_design_contract
- Context mode: `shared`
- Done criteria: story design contract emitted
- Source asset lineage: `bmad.greenfield_fullstack`

Artifact contract details:

- `story_design_contract`: implementable story, acceptance criteria, test intent, and dependencies

## Embedded capabilities

# Skill: bmad-po

Use this skill for BMAD-style product ownership in compressed flow steps.

Core responsibilities:

- Convert vague intent into a concise project brief.
- Produce implementation-ready story design with testable acceptance criteria.
- Keep scope minimal and value-first.

Output contract:

- `status`
- `executive_summary`
- `artifacts[]`
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
