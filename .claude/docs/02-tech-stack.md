# Technical Stack

## Backend — `loci-backend/`

| Concern | Technology | Notes |
|---|---|---|
| Language / runtime | Java, **Spring Boot 3.5.3** | Build via Maven (`pom.xml`); a `build.gradle` also exists but Maven is the primary/documented path (see root `README.md`) |
| Web | `spring-boot-starter-web` | REST controllers ("Resources") |
| Real-time | `spring-boot-starter-websocket` + `spring-security-messaging` + **STOMP** | `/ws/*` endpoints; `stomp-websocket`, `sockjs-client` on the wire format |
| Message broker (STOMP relay) | **RabbitMQ** (`spring-boot-starter-amqp`) or in-memory broker | Switchable via `stomp.relay.type` = `rabbitmq` \| `inmemory` (`RabbitMQWebSocketBrokerAutoConfiguration` / `InMemoryWebSocketBrokerAutoConfiguration`) |
| Security / AuthN-Z | `spring-boot-starter-security`, `spring-boot-starter-oauth2-resource-server`, **Keycloak** (`keycloak-core`, `keycloak-admin-client`) | Backend is an OAuth2 Resource Server validating Keycloak-issued JWTs |
| Persistence | `spring-boot-starter-data-jpa`, **PostgreSQL** (runtime driver), **Flyway** (`flyway-core`, `flyway-database-postgresql`) | Schema is migration-driven (`src/main/resources/db/migrations`) |
| Caching | `spring-boot-starter-cache`, **Caffeine** (local), **Redis** (`spring-boot-starter-data-redis`, distributed) | Used for presence/id-translation caches (see `common/cache`, `core/identity/.../CacheUser*Repository`) |
| Object storage | **MinIO** (S3-compatible, `minio` SDK) + AWS `s3` SDK v2, with a `LocalObjectStorage` fallback | Media attachments (`common/store`) |
| Mapping / boilerplate | **MapStruct**, **ModelMapper**, **Lombok**, **Jilt** (builder generator) | Domain ⇄ Entity ⇄ REST DTO mapping across hexagonal layers |
| API docs | **springdoc-openapi** (`/swagger-ui`) | Auto-generated OpenAPI from REST controllers |
| Observability | **Micrometer + Prometheus** registry, **Spring Boot Actuator**, **Spring Boot Admin** client, **Logstash Logback Encoder** (JSON logs) | Scraped by the Prometheus/Grafana stack in `local-dev/` |
| Ops tooling | **Spring Shell** (`spring-shell-starter`) | CLI command for user migration (`UserMigrationShellCommand`) |
| Testing | `spring-boot-starter-test`, `spring-security-test`, **H2** (in-memory DB for tests) | |
| Code quality (build-time) | Checkstyle, PMD, SpotBugs Maven plugins; ProGuard plugin (present, likely for optional shrinking/obfuscation) | |
| Misc | `prettytime` (human-friendly timestamps), `javafaker` (test/demo data), `spring-dotenv` (`.env` support) | |

## Frontend — `loci-frontend/`

| Concern | Technology |
|---|---|
| Framework | **Angular 20** (RxJS-based SPA), NgModules with lazy-loaded feature modules |
| Auth | **keycloak-angular** + **keycloak-js** (OIDC login, token refresh) |
| Real-time | **`@stomp/rx-stomp`** (RxJS-flavored STOMP client) over **SockJS** (`sockjs-client`) |
| UI | **Angular Material**, **Tailwind CSS**, **FontAwesome** + **Lucide** icon sets |
| Dates | `date-fns` |
| Tooling | Angular CLI/build, ESLint + `angular-eslint`, Prettier, Husky + `lint-staged` (pre-commit), Karma/Jasmine for unit tests |
| Dev workflow | `ng serve --proxy-config proxy.conf.json` — proxies API/WS calls to the backend during local dev |

## Contract-first API — `loci-api/`

A directory tree mirroring the REST resource hierarchy (`auth/`, `conversations/`,
`contact-requests/`, `groups/`, `users/`, …) with its own `package.json` — this is a
**Stoplight Studio**-style OpenAPI project used to design/document the REST contract
independently of the backend implementation (springdoc-openapi generates the *actual*
implementation-driven spec at runtime; `loci-api/` is the contract-first counterpart).

## Infrastructure — `local-dev/`, `deploy/`

| Service | Image | Purpose |
|---|---|---|
| **PostgreSQL 18** | `postgres:18.1` | Primary datastore |
| **pgAdmin** | `dpage/pgadmin4` | DB admin UI (local dev only) |
| **Keycloak** | `quay.io/keycloak/keycloak:26.0.0` | Identity provider / OAuth2 authorization server |
| **RabbitMQ** (management) | `rabbitmq:3.12-management-alpine` | STOMP relay / message broker for WebSocket fan-out |
| **MinIO** + `mc` client | `minio/minio`, `minio/mc` | S3-compatible object storage for media |
| **Prometheus** | `prom/prometheus:v2.45.0` | Metrics scraping |
| **Grafana** | `grafana/grafana:10.0.0` | Metrics dashboards |
| **Nginx** | (`loci-frontend/nginx`, `deploy/`) | Reverse proxy / TLS termination, static frontend hosting in staging/production |
| **Jenkins** | (per root README) | CI/CD |

Local dev is orchestrated with `local-dev/compose.yaml`; staging has its own
`deploy/staging/compose.yaml` + `.env.staging`. See
[Infrastructure & Local Dev](07-infrastructure.md) for ports and setup.

## Why this stack, in one line each

- **Spring Boot + Hexagonal/DDD**: keeps business logic (domain) independent of
  frameworks (web, JPA, WebSocket), making the "core" testable and swappable.
- **Keycloak**: offloads authentication/authorization to a dedicated, standards-based
  IdP instead of hand-rolling password/session management.
- **STOMP over WebSocket (+ RabbitMQ relay)**: pub/sub messaging semantics
  (topics/queues) needed for group broadcast and per-user delivery, with RabbitMQ as
  the production-grade broker and an in-memory broker for simple/local runs.
- **MinIO**: S3-compatible object storage that runs locally in Docker, so the media
  pipeline is developed against the same API surface used in the cloud (AWS S3 SDK is
  also wired in as an alternative adapter).
- **Angular + RxStomp**: reactive front-end that maps naturally onto a
  WebSocket/STOMP push model.
