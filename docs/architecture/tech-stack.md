# Tech Stack

> **Version:** 1.0
> **Parent:** [Architecture](../architecture.md)

---

## Core Stack

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| Language | Gleam | 1.x | Type-safe functional programming |
| Client UI | Lustre | 4.x | TEA UI compiled to JavaScript |
| Server API | Gleam (BEAM) + Wisp/Mist | OTP 26+ | HTTP API + business rules |
| Database | PostgreSQL | 16.x | Persistent storage |
| SQL | Squirrel | 1.x | Type-safe SQL queries (server-side) |
| DB Access | gleam_pgo | 0.11+ | PostgreSQL driver (server-side) |
| Migrations | dbmate | latest | Database schema migrations |

---

## Gleam

**Why Gleam:**
- Type-safe with excellent inference
- Compiles to Erlang (BEAM) or JavaScript
- Simple, explicit, no hidden magic
- Great error messages
- Growing ecosystem

**Key Libraries (indicative):**

**Client (Gleam → JS)**
```toml
[dependencies]
lustre = "~> 4.0"
lustre_dev_tools = "~> 1.0"
gleam_json = "~> 1.0"  # decode API responses
```

**Server (Gleam → Erlang/BEAM)**
```toml
[dependencies]
wisp = "~> 0.14"        # HTTP server
mist = "~> 1.0"         # routing/middleware patterns
squirrel = "~> 1.0"      # typed SQL generation
gleam_pgo = "~> 0.11"    # Postgres driver
gleam_http = "~> 3.0"    # HTTP types
gleam_json = "~> 1.0"    # JSON encoding/decoding
gleam_crypto = "~> 1.0"  # password hashing primitives
```

---

## Lustre (Client TEA)

**Pattern:** Client-side TEA application compiled to JavaScript.

The UI is a Lustre app that:
1. Maintains UI state locally (filters, drag positions in-flight, optimistic transitions)
2. Fetches and mutates data via an HTTP JSON API
3. Reconciles optimistic updates with server responses (including conflict handling)

**Benefits:**
- Uses Lustre as designed (predictable TEA model)
- Works without a long-lived server-driven UI connection
- Clear separation: UI concerns in client, business rules on server

**Trade-offs:**
- Two deployable artifacts (client bundle + server)
- Need explicit API contracts and client-side caching strategy

**Mitigations:**
- Keep server as source of truth; client cache is best-effort
- Use optimistic concurrency (`version`) to detect conflicts
- Add realtime later (SSE/WebSocket) if pool freshness requires it

---

## Squirrel (SQL)

**Pattern:** Type-safe SQL at compile time

```gleam
// queries/tasks.sql
-- name: get_pool_tasks
SELECT id, title, priority, status, created_at
FROM tasks
WHERE status = 'available'
  AND project_id = $1;

// Generated Gleam code provides type-safe function
pub fn get_pool_tasks(db, project_id: Int) -> Result(List(Task), Error)
```

**Benefits:**
- SQL written in SQL (not DSL)
- Compile-time type checking
- No runtime query building overhead

**Limitations:**
- No migrations (use dbmate)
- Learning curve for setup

---

## Database: PostgreSQL

**Why PostgreSQL:**
- Robust, battle-tested
- Excellent Gleam/Erlang drivers
- JSON support for flexibility
- Strong consistency guarantees

**Schema Conventions:**
- `snake_case` for tables and columns
- `id` as primary key (BIGSERIAL)
- `created_at`, `updated_at` timestamps
- `version` field for optimistic concurrency

---

## Authentication

| Component | Technology |
|-----------|------------|
| Password hashing | Argon2id |
| Session tokens | JWT |
| Token storage | HttpOnly cookie |
| CSRF protection | SameSite=Strict |

**Flow:**
1. User submits email/password
2. Server verifies with Argon2
3. Server issues JWT (24h expiry)
4. JWT stored in HttpOnly cookie
5. Subsequent requests include cookie
6. Server validates JWT on each request

---

## Development Tools

| Tool | Purpose |
|------|---------|
| `gleam` | Build, test, format |
| `lustre_dev_tools` | Dev server with hot reload |
| `dbmate` | Database migrations |
| `docker-compose` | Local PostgreSQL |

---

## Deployment (Future)

Target: Single VPS with:
- Gleam release binary
- PostgreSQL (same machine or managed)
- Nginx reverse proxy
- Let's Encrypt SSL

---

## Alternatives Considered

| Choice | Alternative | Why Not |
|--------|-------------|---------|
| Gleam | Elixir | Gleam's type system, learning opportunity |
| Lustre | Phoenix LiveView | Staying in Gleam ecosystem |
| PostgreSQL | SQLite | Multi-connection support needed |
| Squirrel | Raw SQL | Type safety benefits |
| JWT | Sessions | Stateless, simpler for MVP |
