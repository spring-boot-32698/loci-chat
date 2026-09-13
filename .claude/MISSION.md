# Mission: Understanding the Loci codebase

## Why
You just cloned `loci-chat` and need to get productive in it — understand what the
product does (business flow), how it's built (tech stack), and how the pieces fit
together (architecture), so you can read, extend, or maintain the code with
confidence instead of guessing.

## Success looks like
- Can explain, from memory, the lifecycle of a chat message from send to read-receipt (REST fallback vs. STOMP real-time path).
- Can name each bounded context (`identity`, `social`, `discovery`, `conversation`, `groups`, `messaging`, `notification`) and what business capability it owns.
- Can trace a new feature request to the right hexagonal layer (domain vs. application vs. primary/secondary infrastructure) before writing code.
- Can stand the local dev environment up unassisted (Postgres, Keycloak, RabbitMQ, MinIO) and explain what each service is for.

## Constraints
- Learning happens alongside — not instead of — actually working in the repo; lessons should be short and immediately checkable against real source files.
- No stated deadline yet.

## Out of scope (for now)
- Deep Angular/RxJS mastery (frontend is secondary to understanding backend business flow, unless later redirected).
- Keycloak administration internals beyond "how the backend trusts its tokens."
- DevOps/Jenkins pipeline internals.

## Note
This mission was inferred from "I just cloned this source code, I want to know all
about the business flow, technical stack, and diagrams." If the real goal is
different (e.g. preparing to contribute a specific feature, studying Hexagonal/DDD
patterns for use in *other* projects, or an interview/code-review exercise) — say so
and this file will be revised.
