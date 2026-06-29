# Tech Stack

## Runtime

| Layer | Technology | Purpose |
| --- | --- | --- |
| Language | Gleam | Shared language for client, server, and domain packages. |
| Client | Lustre 5.x | TEA UI compiled to JavaScript. |
| Server | Gleam on BEAM with Wisp/Mist | HTTP API and business workflows. |
| Database | PostgreSQL 16 | Persistent storage. |
| Migrations | dbmate | Database migration management. |
| SQL generation | Squirrel 4.x | Typed query generation for server persistence. |
| DB access | pog 4.x | Runtime PostgreSQL access. |

## Packages

- `apps/client`: `target = "javascript"`, uses Lustre, `lustre_http`, `plinth`,
  `gleroglero`, `modem`, and `shared`.
- `apps/server`: `target = "erlang"`, uses Wisp, Mist, pog, Argon2, `birl`,
  `envoy`, and `shared`.
- `shared`: target-neutral domain/API package used by both apps.

## Local Tooling

- Gleam 1.14.x is expected for this repository.
- `gleeunit` is the standard test runner.
- `lustre_dev_tools` supports client tests and development.
- `squirrel` is a server dev dependency used to generate typed SQL modules.
