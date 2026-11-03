# Infrastructure & Local Dev

## Running locally (from the root `README.md`)

**Full stack in Docker** — from the repo root:

```bash
docker compose up -d --build
```

The root `compose.yaml` `include`s `infra/compose.yaml` and adds `loci-server`
(built from `loci-backend/`, Spring profile `stage`) and `loci-web` (built from
`loci-frontend/`, served by nginx on host port `4200`). Both compose files use the
project name `loci`, so they share the same volumes.

**Backend/frontend on the host:**

```bash
cd loci-backend
cp .env.example .env
mvn spring-boot:run
```

```bash
cd loci-frontend
npm install
npm run start
```

The backend defaults to Spring profile **`dev`** (`application.yml` →
`spring.profiles.active: dev`), which points at the services below running via
`infra/compose.yaml`. Bring that infra up separately, e.g.:

```bash
cd infra
docker compose up -d
```

## Local infrastructure services (`infra/compose.yaml`)

| Service | Image | Host port(s) | Purpose |
|---|---|---|---|
| `loci-db` | `postgres:18.1` | `5432` | Primary datastore |
| `loci-pgadmin` | `dpage/pgadmin4:9.11` | `81` (→80) | DB admin UI |
| `loci-auth` (Keycloak) | `quay.io/keycloak/keycloak:26.0.0` | `9090` (→8080) | OIDC/OAuth2 identity provider, admin console |
| `loci-mq` (RabbitMQ) | `rabbitmq:3.12-management-alpine` | `5672` (AMQP), `15672` (mgmt UI), `61613` (STOMP relay) | STOMP relay / broker for WebSocket fan-out |
| Prometheus | `prom/prometheus:v2.45.0` | `9092` (→9090) | Metrics scraping |
| Grafana | `grafana/grafana:10.0.0` | `3000` | Metrics dashboards (pre-provisioned datasource/dashboards in `infra/grafana/`) |
| `loci-minio` | `minio/minio:RELEASE.2025-09-07…` | `9000` (S3 API), `9001` (console) | Object storage for media |
| `loci-minio-client` (`mc`) | `minio/mc:…` | — | One-shot bucket bootstrap for MinIO |

Frontend/backend URLs during local dev (from the root README):

| Service | URL |
|---|---|
| App (Angular) | http://localhost:4200 |
| Keycloak admin | http://localhost:9090 |
| MinIO console | http://localhost:9001 |

`infra/README.md` notes two setup helpers:
- `./backups/backup.sql` — DB seed data, applied automatically when `loci-db` starts with an empty volume (re-import with `infra/scripts/migrate-db-import.sh`)
- `./keycloak-data/import/` — pre-built Keycloak realm/users, imported on Keycloak startup

## Spring profiles

Defined under `loci-backend/src/main/resources/`:

| File | Used for |
|---|---|
| `application.yml` | Shared defaults (active profile = `dev`, caching = Caffeine, multipart limits 100MB, virtual threads enabled) |
| `application-dev.yml` | Local development — RabbitMQ relay at `localhost:61613` by default |
| `application-stage.yml` | Staging — RabbitMQ relay host/port from environment (`STOMP_RELAY_HOST`/`STOMP_RELAY_PORT`) |
| `application-prod.yml` | Production configuration |

The STOMP relay type is switchable per environment:
`stomp.relay.type: rabbitmq | inmemory` (see
`common/websocket/infrastructure/primary/broker/`).

## Database migrations

Managed by **Flyway** (`loci-backend/src/main/resources/db/migrations/`):
- `V1__baseline.sql` — full schema (see [Data Model](05-data-model.md))
- Seed data for local dev lives in `infra/backups/backup.sql` (not a Flyway migration)

Root README mentions running `mvn flyway:baseline` / `mvn flyway:migrate` explicitly
(commented out in the quick-start — Spring Boot also auto-runs pending Flyway
migrations on startup when the Flyway starter is on the classpath, unless
`spring.flyway.enabled` is disabled).

## CI

Per the root README's tech list, **Jenkins** drives CI (`loci-backend/Jenkinsfile`,
`loci-frontend/Jenkinsfile`: compile, test, package; Docker build/push stages are
commented out).

## Observability

- **Metrics**: Spring Boot Actuator + Micrometer, exported in Prometheus format and
  scraped by the local Prometheus container (`infra/prometheus/`), visualized in
  the pre-provisioned Grafana dashboards (`infra/grafana/dashboards/`).
- **Admin**: `spring-boot-admin-starter-client` registers the backend with a Spring
  Boot Admin server (server dependency is present but commented out in `pom.xml` —
  enable it to get a live admin UI).
- **Structured logs**: `logstash-logback-encoder` for JSON-formatted logs, plus a
  custom `RequestTraceLogFilter` / `LoggingAspect` (`common/log/`) for
  request-scoped tracing and method-level execution-time logging
  (`@LogExecutionTime`, `@Loggable`).
