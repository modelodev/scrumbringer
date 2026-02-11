# Source Tree

> **Version:** 1.0
> **Parent:** [Architecture](../architecture.md)

---

## Project Structure

Because ScrumBringer is **client/server** (Lustre TEA client + Gleam API server), the repository is organized as a monorepo with two Gleam apps and one shared package.

```
scrumbringer/
├── .bmad-core/                  # BMAD methodology files
├── .ai/                         # Session handoff + notes
├── docs/                        # Documentation
│   ├── brief.md
│   ├── architecture.md
│   ├── architecture/
│   ├── prd/
│   └── stories/
│
├── apps/
│   ├── client/                  # Lustre app (Gleam → JavaScript)
│   │   ├── gleam.toml           # target = "javascript"
│   │   ├── src/
│   │   │   ├── scrumbringer_client.gleam
│   │   │   └── scrumbringer_client/
│   │   │       ├── features/
│   │   │       ├── client_state/
│   │   │       ├── components/
│   │   │       ├── ui/
│   │   │       ├── styles/
│   │   │       ├── i18n/
│   │   │       └── helpers/
│   │   └── test/
│   │
│   └── server/                  # HTTP API (Gleam → Erlang/BEAM)
│       ├── gleam.toml           # target = "erlang"
│       ├── src/
│       │   ├── main.gleam
│       │   ├── scrumbringer_server.gleam
│       │   └── scrumbringer_server/
│       │       ├── web/
│       │       ├── http/
│       │       ├── services/
│       │       └── persistence/
│       └── test/
│
├── shared/                      # Shared domain types/helpers (reused by client and server)
│   ├── gleam.toml
│   ├── src/
│   │   ├── domain/
│   │   └── helpers/
│   └── test/
│
├── db/
│   └── migrations/              # dbmate migrations
├── docker-compose.yml           # Local PostgreSQL
├── database.yml                 # dbmate config
└── README.md
```

---

## Key Directories

### `apps/client/`

Lustre UI application (Gleam → JavaScript). Recommended responsibilities:
- UI composition (`features/`, `components/`, `ui/`)
- Client-side state (filters, drag interactions, optimistic transitions)
- API client and decoding of server responses

Client FFI layout (isolated by domain, referenced via `client_ffi.gleam`):

```
apps/client/src/scrumbringer_client/
├── client_ffi.gleam
├── cookies.ffi.mjs
├── date.ffi.mjs
├── device.ffi.mjs
├── dom.ffi.mjs
├── keyboard.ffi.mjs
├── navigation.ffi.mjs
└── url.ffi.mjs
```

### `apps/server/`

Gleam HTTP API (Gleam → Erlang/BEAM). Recommended responsibilities:
- Authentication and authorization
- Business rules (claim required to edit, no direct assignment)
- Command validation and optimistic concurrency (`version`)
- Data access layer via Squirrel + Postgres driver

### `shared/`

Shared domain types and helper functions reused by both targets.

### `db/migrations/`

Database migrations managed by dbmate:
- Sequential numbering
- One change per file
- Both up and down migrations

---

## Module Dependencies

```
           apps/client (Lustre TEA)
                    │
                    ▼
                 shared

           apps/server (HTTP API)
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
      shared         apps/server/persistence + services
```

**Rules (recommended):**
- Client imports `shared` types (and its own UI modules)
- Server imports `shared` types and owns persistence/query code
- `shared` must not depend on client/server modules
- No circular dependencies allowed

---

## Configuration Files

### `apps/client/gleam.toml`

```toml
name = "scrumbringer_client"
version = "0.1.0"
target = "javascript"

[dependencies]
gleam_stdlib = "~> 0.68"
gleam_javascript = "~> 1.0"
gleam_json = "~> 3.0"
gleam_http = "~> 4.3"
lustre = "~> 5.0"
lustre_http = { path = "../../packages/lustre_http" }
shared = { path = "../../shared" }

[dev-dependencies]
gleeunit = "~> 1.0"
lustre_dev_tools = "~> 2.0"
```

### `apps/server/gleam.toml`

```toml
name = "scrumbringer_server"
version = "0.1.0"
target = "erlang"

[dependencies]
gleam_stdlib = "0.68.1"
wisp = "2.1.1"
mist = "5.0.4"
pog = "~> 4.0"
gleam_http = "4.3.0"
gleam_json = "3.1.0"
gleam_crypto = "~> 1.0"
shared = { path = "../../shared" }

[dev-dependencies]
gleeunit = "~> 1.0"
squirrel = "~> 4.0"
```

### `docker-compose.yml`

```yaml
version: '3.8'
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: scrumbringer
      POSTGRES_PASSWORD: scrumbringer
      POSTGRES_DB: scrumbringer_dev
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

### `database.yml` (dbmate)

```yaml
development:
  url: postgres://scrumbringer:scrumbringer@localhost:5432/scrumbringer_dev?sslmode=disable
  migrations_dir: db/migrations

test:
  url: postgres://scrumbringer:scrumbringer@localhost:5432/scrumbringer_test?sslmode=disable
  migrations_dir: db/migrations
```

---

## Build & Run Commands

```bash
# Database
docker-compose up -d

dbmate up

# Client (apps/client)
gleam run -m lustre/dev

gleam test

gleam format

# Server (apps/server)
gleam run

gleam test

gleam format

# Production (example)
# - build client bundle and serve via CDN/static hosting
# - deploy server as BEAM release + connect to PostgreSQL
```
