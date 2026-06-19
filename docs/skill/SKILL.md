---
name: scrumbringer-agent
description: Operate Scrumbringer through its Bearer API while preserving the pull-flow philosophy. Use this skill whenever a Codex, OpenCode, or OpenClaw agent needs to inspect or modify Scrumbringer projects, tasks, cards, notes, or card trees; advise users on designing card trees/cards/tasks; or coordinate work with ScrumBringer without using workflows, rules, or templates.
---

# Scrumbringer Agent

Use this skill when an AI agent communicates with Scrumbringer through an API
token. The skill is harness-neutral and is intended for Codex, OpenCode, and
OpenClaw agents.

## Core Philosophy

Scrumbringer is a pull-flow work cockpit. Preserve these rules:

- Make work visible before changing work.
- Do not push-assign tasks to people.
- Do not claim tasks in this initial agent policy.
- Prefer notes and recommendations when a human decision is needed.
- Keep card trees, cards, and tasks shaped for team autonomy.
- Use the smallest API action that creates useful operational signal.

When advising the user:

- **Card Trees** should describe an outcome or delivery slice, not a vague
  backlog bucket.
- **Cards** should group related work that can be understood and reviewed as a
  coherent slice.
- **Tasks** should be small, pullable units with a clear title, useful context,
  priority, and acceptance hints in the description.
- **Notes** should preserve operational context, blockers, external updates,
  and decisions without rewriting history.

## Required Setup

Before any API call, verify:

- `SCRUMBRINGER_BASE_URL` is set, for example `http://127.0.0.1:8443`.
- `SCRUMBRINGER_API_TOKEN` is set to the full `sbt_...` Bearer token.
- Operation-specific business variables are present:
  - project-scoped work: `SCRUMBRINGER_PROJECT_ID`
  - task work: `SCRUMBRINGER_TASK_ID`
  - card work: `SCRUMBRINGER_CARD_ID`
  - card tree work: `SCRUMBRINGER_MILESTONE_ID`
  - task mutations that require optimistic concurrency: current task `version`

Use the helper script first:

```bash
node docs/skill/scripts/scrumbringer-api.mjs preflight
node docs/skill/scripts/scrumbringer-api.mjs preflight SCRUMBRINGER_PROJECT_ID
```

The helper never prints the full token.

Project visibility follows the token project setting. A token with a concrete
project only sees that project. A token created for all projects derives access
from its active grant, so `GET /api/v1/projects` should return current and future
organization projects when the token has `projects:read`.

## References

Read `docs/references/scrumbringer-api.md` before using endpoints you have not
used in the current task. It contains the supported Bearer routes, scopes,
payload examples, and routes intentionally out of scope.

Use `docs/skill/scripts/scrumbringer-api.mjs` for deterministic API calls:

```bash
node docs/skill/scripts/scrumbringer-api.mjs get /api/v1/projects
node docs/skill/scripts/scrumbringer-api.mjs get /api/v1/projects/$SCRUMBRINGER_PROJECT_ID/tasks
node docs/skill/scripts/scrumbringer-api.mjs post /api/v1/tasks/$SCRUMBRINGER_TASK_ID/notes '{"content":"External context..."}'
```

## Operating Workflow

1. **Preflight**
   - Check required env vars.
   - Identify project/resource IDs.
   - Confirm the token has the needed scopes by making the smallest read call.

2. **Inspect before mutation**
   - Read the project/task/card/card tree.
   - Summarize current state in plain language.
   - Identify version numbers before task patch/transition calls.

3. **Apply Scrumbringer philosophy**
   - If work is unclear, propose a better card tree/card/task shape.
   - If a human should choose, write a note or recommend next actions.
   - Do not claim tasks in this initial policy.

4. **Confirm before risky writes**
   Always ask for explicit confirmation before:
   - creating or editing tasks/cards/card trees;
   - deleting cards, card notes, or card trees;
   - patching task fields;
   - calling task `release` or `complete`;
   - any action that could change ownership, state, or visible team planning.

   Do not call task `claim` in this initial policy, even with confirmation.
   Treat it as a documented API capability reserved for a future policy update.

   Confirmation prompt format:

   ```text
   Confirmo antes de operar en Scrumbringer:
   - Base: <base-url>
   - Proyecto/recurso: <ids>
   - Accion: <method path>
   - Payload: <json>
   - Impacto esperado: <effect>
   - Riesgo: <low/medium/high>
   ```

5. **Execute and report**
   - Use the helper script or equivalent HTTP request.
   - Report the final state and relevant IDs.
   - For failures, report status, error code, message, and next safe step.

## Initial Agent Policy

Allowed without confirmation:

- Read projects.
- Read tasks/cards/card trees/notes.
- Draft a proposed task/card/card tree design.
- Recommend a next action.

Allowed only after explicit confirmation:

- Create tasks.
- Create/update/delete cards.
- Create/delete card notes.
- Create/update/delete card trees.
- Add task notes.
- Patch task title/description/card tree.
- Release or complete a task when the user explicitly confirms that the
  integration user should perform that state transition.

Not allowed in this initial policy:

- Claim tasks, autonomously or after confirmation.
- Operate workflows, rules, or task templates.
- Administer users, projects, memberships, API tokens, task types, or
  capabilities through Bearer.
- Use browser session cookies as a substitute for the API token.
- Store or print the full token.

## Response Style

When reporting work, be concise and operational:

- State what was inspected.
- State what changed, with resource IDs.
- State what remains blocked by permissions, missing env vars, or confirmation.
- For design advice, tie recommendations back to pull-flow autonomy.

## Common Examples

List projects:

```bash
node docs/skill/scripts/scrumbringer-api.mjs get /api/v1/projects
```

List tasks in a project:

```bash
node docs/skill/scripts/scrumbringer-api.mjs get /api/v1/projects/$SCRUMBRINGER_PROJECT_ID/tasks
```

Create a task after confirmation:

```bash
node docs/skill/scripts/scrumbringer-api.mjs post /api/v1/projects/$SCRUMBRINGER_PROJECT_ID/tasks \
  '{"title":"Document import failure mode","description":"Capture observed failure, expected behavior, and rollback notes.","priority":3,"type_id":1}'
```

Add a task note after confirmation:

```bash
node docs/skill/scripts/scrumbringer-api.mjs post /api/v1/tasks/$SCRUMBRINGER_TASK_ID/notes \
  '{"content":"External system reported retry success at 2026-06-12T12:40:00Z."}'
```

Create a card tree after confirmation:

```bash
node docs/skill/scripts/scrumbringer-api.mjs post /api/v1/projects/$SCRUMBRINGER_PROJECT_ID/card trees \
  '{"name":"Importer stabilization","description":"Reduce import failure rate and make retry behavior observable."}'
```
