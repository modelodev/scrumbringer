# Source Tree

ScrumBringer is organized as a monorepo with two Gleam applications, one shared
package, local support packages, database migrations, scripts, and docs.

```text
scrumbringer/
├── apps/
│   ├── client/                  # Lustre app, target=javascript
│   │   ├── src/scrumbringer_client/
│   │   │   ├── api/             # HTTP client modules
│   │   │   ├── app/             # app bootstrap and routing shell
│   │   │   ├── client_state/    # client model slices
│   │   │   ├── components/      # Lustre components
│   │   │   ├── domain/          # client-only domain helpers
│   │   │   ├── features/        # feature routes, views, updates
│   │   │   ├── helpers/         # reusable client helpers
│   │   │   ├── i18n/            # localized copy
│   │   │   ├── state/           # state helpers
│   │   │   ├── styles/          # CSS
│   │   │   ├── ui/              # reusable UI primitives
│   │   │   └── utils/
│   │   └── test/
│   └── server/                  # Wisp/Mist API, target=erlang
│       ├── src/scrumbringer_server/
│       │   ├── http/            # request handlers and payload mapping
│       │   ├── repository/      # persistence adapters and row mappers
│       │   ├── sql/             # Squirrel source queries
│       │   ├── use_case/        # business workflows and services
│       │   └── web/             # router and web bootstrap
│       └── test/
├── shared/
│   └── src/
│       ├── api/                 # shared API contracts/codecs
│       ├── domain/              # target-neutral domain types
│       └── helpers/
├── packages/                    # local dependencies
├── db/
│   ├── migrations/              # dbmate migrations
│   └── schema.sql               # schema snapshot
├── scripts/                     # development and validation scripts
├── docs/                        # maintained documentation
└── Makefile
```

## Dependency Rules

- `shared` must not depend on `apps/client` or `apps/server`.
- `apps/client` may depend on `shared` and client-local modules.
- `apps/server` may depend on `shared`, `repository`, generated SQL, and
  use-case modules.
- HTTP handlers should map payloads and delegate business rules to use cases.
- Runtime code must not import seed/demo helpers.
