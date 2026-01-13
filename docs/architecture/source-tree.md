# Source Tree

> **Version:** 1.0
> **Parent:** [Architecture](../architecture.md)

---

## Project Structure

Because ScrumBringer is **client/server** (Lustre TEA client + Gleam API server), the recommended repository layout is a small monorepo with two Gleam apps and a shared domain package.

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
│   │   │   ├── main.gleam
│   │   │   ├── pages/
│   │   │   └── components/
│   │   └── test/
│   │
│   └── server/                  # HTTP API (Gleam → Erlang/BEAM)
│       ├── gleam.toml           # target = "erlang"
│       ├── src/
│       │   ├── main.gleam
│       │   ├── http/
│       │   ├── services/
│       │   ├── queries/
│       │   └── types/
│       └── test/
│
├── packages/
│   └── domain/                  # Shared types/validation (compiles to both targets)
│       ├── gleam.toml
│       └── src/
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
- UI composition (`pages/`, `components/`)
- Client-side state (filters, drag interactions, optimistic transitions)
- API client and decoding of server responses

### `apps/server/`

Gleam HTTP API (Gleam → Erlang/BEAM). Recommended responsibilities:
- Authentication and authorization
- Business rules (claim required to edit, no direct assignment)
- Command validation and optimistic concurrency (`version`)
- Data access layer via Squirrel + Postgres driver

### `packages/domain/`

Shared domain types and validation rules that can be reused by both targets.

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
            packages/domain

           apps/server (HTTP API)
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
packages/domain           apps/server/queries (Squirrel)
```

**Rules (recommended):**
- Client imports `packages/domain` types (and its own UI modules)
- Server imports `packages/domain` types, and owns persistence/query code
- `packages/domain` must not depend on client/server modules
- No circular dependencies allowed

---

## Configuration Files

### `apps/client/gleam.toml`

```toml
name = "scrumbringer_client"
version = "0.1.0"
target = "javascript"

[dependencies]
gleam_stdlib = "~> 0.34"
lustre = "~> 4.0"
gleam_json = "~> 1.0"

[dev-dependencies]
gleeunit = "~> 1.0"
lustre_dev_tools = "~> 1.0"
```

### `apps/server/gleam.toml`

```toml
name = "scrumbringer_server"
version = "0.1.0"
target = "erlang"

[dependencies]
gleam_stdlib = "~> 0.34"
wisp = "~> 0.14"
mist = "~> 1.0"
squirrel = "~> 1.0"
gleam_pgo = "~> 0.11"
gleam_http = "~> 3.0"
gleam_json = "~> 1.0"
gleam_crypto = "~> 1.0"

[dev-dependencies]
gleeunit = "~> 1.0"
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
