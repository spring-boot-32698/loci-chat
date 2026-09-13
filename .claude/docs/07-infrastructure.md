# Infrastructure & Local Dev

## Running locally (from the root `README.md`)

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
`local-dev/compose.yaml`. Bring that infra up separately, e.g.:

```bash
cd local-dev
docker compose up -d
```

## Local infrastructure services (`local-dev/compose.yaml`)

| Service | Image | Host port(s) | Purpose |
|---|---|---|---|
| `loci-db` | `postgres:18.1` | `5432` | Primary datastore |
| `loci-pgadmin` | `dpage/pgadmin4:9.11` | `81` (→80) | DB admin UI |
| `loci-auth` (Keycloak) | `quay.io/keycloak/keycloak:26.0.0` | `9090` (→8080) | OIDC/OAuth2 identity provider, admin console |
| `loci-mq` (RabbitMQ) | `rabbitmq:3.12-management-alpine` | `5672` (AMQP), `15672` (mgmt UI), `61613` (STOMP relay) | STOMP relay / broker for WebSocket fan-out |
| Prometheus | `prom/prometheus:v2.45.0` | `9092` (→9090) | Metrics scraping |
| Grafana | `grafana/grafana:10.0.0` | `3000` | Metrics dashboards (pre-provisioned datasource/dashboards in `local-dev/grafana/`) |
| `loci-minio` | `minio/minio:RELEASE.2025-09-07…` | `9000` (S3 API), `9001` (console) | Object storage for media |
| `loci-minio-client` (`mc`) | `minio/mc:…` | — | One-shot bucket bootstrap for MinIO |

Frontend/backend URLs during local dev (from the root README):

| Service | URL |
|---|---|
| App (Angular) | http://localhost:4200 |
| Keycloak admin | http://localhost:9090 |
| MinIO console | http://localhost:9001 |

`local-dev/README.md` notes two setup helpers:
- `./backups/backup.sql` — DB seed data (run manually via `local-dev/scripts/migrate-db-import.sh`, not auto-applied by Docker)
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
- `data.sql` — reference/seed data loaded via Spring's standard `data.sql` mechanism

Root README mentions running `mvn flyway:baseline` / `mvn flyway:migrate` explicitly
(commented out in the quick-start — Spring Boot also auto-runs pending Flyway
migrations on startup when the Flyway starter is on the classpath, unless
`spring.flyway.enabled` is disabled).

## Staging / production deployment (`deploy/`)

| Path | Purpose |
|---|---|
| `deploy/staging/compose.yaml` | Compose stack for the staging environment |
| `deploy/staging/.env.staging` | Staging environment variables |
| `deploy/production/` | Reserved for the production compose/env (empty at time of writing — see `.gitkeep`) |

Per the root README's tech list, **Jenkins** drives CI/CD, and per recent commit
history the project uses an **Nginx reverse proxy with TLS termination** in front of
the frontend/backend in these environments (see `loci-frontend/nginx/` and
`deploy/`), plus dynamic per-environment configuration for the CI pipeline.

## Observability

- **Metrics**: Spring Boot Actuator + Micrometer, exported in Prometheus format and
  scraped by the local Prometheus container (`local-dev/prometheus/`), visualized in
  the pre-provisioned Grafana dashboards (`local-dev/grafana/dashboards/`).
- **Admin**: `spring-boot-admin-starter-client` registers the backend with a Spring
  Boot Admin server (server dependency is present but commented out in `pom.xml` —
  enable it to get a live admin UI).
- **Structured logs**: `logstash-logback-encoder` for JSON-formatted logs, plus a
  custom `RequestTraceLogFilter` / `LoggingAspect` (`common/log/`) for
  request-scoped tracing and method-level execution-time logging
  (`@LogExecutionTime`, `@Loggable`).
