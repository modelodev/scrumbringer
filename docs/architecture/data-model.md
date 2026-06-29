# Data Model

The canonical schema lives in `db/schema.sql` and the dbmate migrations in
`db/migrations/`. This document only records the current domain shape and the
invariants that are easy to lose when reading SQL directly.

## Core Entities

- `organizations`: tenant boundary.
- `users`: organization users with `member` or `admin` org role.
- `projects`: project workspaces inside an organization.
- `project_members`: project access and project role.
- `capabilities`: project-scoped skill/capability labels.
- `project_member_capabilities`: capability configuration per project member.
- `task_types`: project-scoped task classification, optionally linked to a
  capability.
- `cards`: delivery containers; may be nested through `parent_card_id`.
- `tasks`: pullable work units; normally linked to a card through `card_id`.
- `notes`, `task_notes`, `card_notes`: shared note body plus task/card links.
- `workflows`, `rules`, `task_templates`, `rule_executions`: automation model.
- `api_tokens`, `integration_users`: Bearer API access for integrations.
- `audit_events`: immutable operational events for task/card/note/due-date
  activity.

## State Model

Cards use `execution_state`:

- `draft`: prepared but not claimable through its tasks.
- `active`: opens its task leaves to the Pool.
- `closed`: terminal state for the card branch.

Tasks use `execution_state`:

- `available`: visible work in the Pool.
- `claimed`: pulled by a user.
- `closed`: terminal state.

Task close reasons are `done`, `manually_closed`, and `closed_by_ancestor`.
Card close reasons are `rollup` and `manually_closed`.

## Card And Task Invariants

- A card can contain child cards or tasks, but not both.
- A claimed task must belong to an active card lineage.
- Closing or moving cards must not leave claimed descendant tasks in an invalid
  lineage.
- Card parent links cannot create cycles.
- Cross-project card/task relationships are rejected.
- Available root tasks are tolerated by the data model for migration and edge
  cases, but normal product flows should create card-scoped tasks.

## Concurrency And History

- Tasks carry a `version` for optimistic concurrency on mutations and lifecycle
  transitions.
- Task/card view tables track per-user read state.
- Audit events and rule executions provide operational history; they should be
  preferred over destructive rewrites when preserving context matters.
