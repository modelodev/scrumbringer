# ScrumBringer - Architecture Document

> **Version:** 1.0
> **Date:** 2026-01-12
> **Status:** MVP Definition

---

## Overview

ScrumBringer adopts a **traditional client/server architecture**:

- **Client:** Lustre (TEA) compiled to JavaScript (`target=javascript`) for the interactive UI (drag & drop, filters, optimistic UX).
- **Server:** Gleam on the BEAM (`target=erlang`) exposing an HTTP API (`/api/v1`), implementing all business rules, and persisting state in PostgreSQL.

This resolves the key constraint identified in `.ai/handoff.md`: Lustre 4.x is not “server-driven UI”; it is primarily a client-side TEA framework (with optional SSR patterns).

### Key Principles

1. **Server as Source of Truth** - Persistent state and permissions are enforced on the server
2. **Optimistic UI** - Client can predict outcomes; server validates and returns authoritative state
3. **First-Write-Wins + Versioning** - Concurrent mutations use optimistic concurrency with a `version` field
4. **Pull-Based Flow** - Users claim tasks for themselves; no direct assignment

---

## Architecture Pattern: Lustre Client + Gleam API

```
┌─────────────────────────────────────────────────────────┐
│                      Browser                             │
│  ┌─────────────────────────────────────────────────┐   │
│  │               Lustre App (TEA)                  │   │
│  │  - State: UI state + cached data                │   │
│  │  - Optimistic interactions                      │   │
│  │  - Calls API (JSON)                             │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                          │ HTTPS (JSON)
                          ▼
┌─────────────────────────────────────────────────────────┐
│                 Gleam API (BEAM / Erlang)                │
│  - Auth (JWT cookie)                                     │
│  - Authorization (claim-required edits)                  │
│  - Command validation + optimistic concurrency            │
│  - Data access via Squirrel/gleam_pgo                    │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                     PostgreSQL                           │
│  - Persistent storage                                    │
│  - Migrations via dbmate                                 │
└─────────────────────────────────────────────────────────┘
```

**Realtime (optional, post-MVP):** WebSocket/SSE for pool updates. MVP can work with request/response + periodic refresh.

---

## Sharded Documentation

| Document | Description |
|----------|-------------|
| [Tech Stack](architecture/tech-stack.md) | Technology choices and rationale |
| [Data Model](architecture/data-model.md) | Entities, commands, events |
| [API Contract](architecture/api-contract.md) | HTTP endpoints, auth, errors |
| [Coding Standards](architecture/coding-standards.md) | Gleam conventions and patterns |
| [Source Tree](architecture/source-tree.md) | Project structure |

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Runtime | Client/Server (Lustre TEA + Gleam API) | Matches Lustre’s model; keeps Gleam ecosystem |
| Positions | Per-user (not shared) | Avoid real-time sync complexity in MVP |
| Concurrency | Optimistic UI + `version` field | Good UX with conflict detection |
| Claim conflicts | First-write-wins | Simple, fair, predictable |
| Auth | Email/password + JWT cookie + Argon2 | Standard, secure, no external deps |

---

## Non-Functional Requirements

### Performance
- Pool render: < 100ms for 200 tasks
- Claim latency: < 200ms P95
- Initial load: < 3s on 3G

### Security
- Argon2id for password hashing
- JWT in HttpOnly cookies
- CSRF protection via SameSite
- Input validation on all endpoints

### Scalability (MVP)
- Single PostgreSQL instance
- Vertical scaling on BEAM VM
- Target: 50 concurrent users, 5000 tasks

---

## References

- [Project Brief](brief.md)
- [Lustre Documentation](https://hexdocs.pm/lustre)
- [Squirrel Documentation](https://hexdocs.pm/squirrel)
