# ScrumBringer Architecture

ScrumBringer is a Gleam monorepo with a Lustre client, a Wisp/Mist HTTP server,
a shared domain package, and PostgreSQL persistence.

## System Shape

- `apps/client`: Lustre TEA application compiled to JavaScript.
- `apps/server`: Gleam/BEAM HTTP API and business workflows.
- `shared`: domain types, API contracts, and helpers reused by client and server.
- `db`: dbmate migrations and generated schema snapshot.
- `packages`: local support packages used by the apps.

## Product Model

- Work belongs to a project.
- Cards are planning and delivery containers. Cards can be nested with
  `parent_card_id` and move through `draft`, `active`, and `closed`.
- Tasks are the pullable work units. Active execution is represented by
  `available`, `claimed`, and `closed`.
- Claiming is pull-based: users claim work for themselves; the product avoids
  direct task assignment.
- Capabilities and task types describe what kind of work a task needs.
- Automations create follow-up work from workflow rules and task templates, but
  they still create available work in the Pool rather than assigning it.
- Notes and activity records preserve operational context.

## Runtime Boundaries

- The server is the source of truth for auth, authorization, state transitions,
  invariants, and persistence.
- The client owns presentation state, filters, drag interactions, optimistic UI,
  and API orchestration.
- Shared code must stay target-neutral and cannot import client or server
  modules.
- Database invariants live in migrations/schema; generated SQL must not be
  edited by hand.

## Current References

- [Tech stack](architecture/tech-stack.md)
- [Source tree](architecture/source-tree.md)
- [Data model](architecture/data-model.md)
- [Coding standards](architecture/coding-standards.md)
- [Responsive system](architecture/responsive.md)
- [Lustre components](architecture/lustre-components.md)
- [No-legacy rules](no-legacy-rules.md)
