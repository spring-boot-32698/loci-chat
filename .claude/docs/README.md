# Loci — Documentation

Loci is a real-time messaging (chat) application: 1:1 and group chat, media sharing,
presence, contacts/friends, and notifications — built with Spring Boot (backend) and
Angular (frontend), authenticated via Keycloak, delivered over WebSocket/STOMP.

This folder is the technical + business documentation for engineers who just cloned
the repo and need to get oriented quickly.

## Contents

1. [Overview & Business Domain](01-overview.md) — what the product does, who uses it, core concepts
2. [Technical Stack](02-tech-stack.md) — every technology in the repo and why it's there
3. [Architecture](03-architecture.md) — Hexagonal Architecture, DDD, bounded contexts, module map
4. [Business Flows](04-business-flows.md) — sequence diagrams for auth, messaging, contacts, groups, presence
5. [Data Model](05-data-model.md) — ER diagram and table reference
6. [API Reference](06-api-reference.md) — REST endpoints + WebSocket/STOMP destinations
7. [Infrastructure & Local Dev](07-infrastructure.md) — Docker services, ports, environments, deployment

## Repo map

| Path | What it is |
|---|---|
| `loci-backend/` | Spring Boot 3 backend (Java), Hexagonal/DDD, REST + WebSocket |
| `loci-frontend/` | Angular 20 SPA (chat UI) |
| `loci-api/` | OpenAPI/Stoplight-style REST contract definitions (one folder per resource) |
| `local-dev/` | `compose.yaml` for local infra: Postgres, Keycloak, RabbitMQ, MinIO, Prometheus, Grafana |
| `deploy/` | Staging/production Docker Compose + env files |
| `assets/` | Screenshots/GIFs used in the top-level `README.md` (already-existing architecture diagrams) |

The project's own top-level [`README.md`](../../README.md) has quick-start run instructions
and feature screenshots — this `docs/` folder goes deeper into *how* and *why*.
