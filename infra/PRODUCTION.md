# Production readiness notes

Status: **no production setup exists yet.** `infra/` and the root `compose.yaml` are for
local development only. This file tracks what has to change before deploying to a real
environment. Tick items off as they are done.

Decide first: **where it runs** (managed cloud services vs. a self-hosted VPS vs. Kubernetes).
Most of the items below depend on that choice, so don't write a production compose/manifest
before it's made.

## 1. What in `infra/` must not go to production as-is

- [ ] **Hardcoded credentials** — `admin`/`admin` (Postgres, Keycloak, RabbitMQ, pgAdmin,
      Grafana), `minioadmin`/`minioadmin`. Inject secrets at deploy time; never commit them.
- [ ] **Keycloak runs `start-dev`** — plain HTTP, no hostname enforcement, no caching.
      Production needs `start` with TLS and a fixed `KC_HOSTNAME`.
- [ ] **Keycloak shares the `locidb` database with the app** — give Keycloak its own
      database (separate backups, upgrades, permissions).
- [ ] **`backups/backup.sql` auto-seeds an empty DB** — it contains demo accounts
      (`demo01`…`demo05`, password = username). Production schema comes from Flyway only;
      never seed demo data.
- [ ] **MinIO bucket is `public`** — anyone with a link can download chat files.
      Use private buckets + presigned URLs, or S3 with proper policies.
- [ ] **All service ports are published** (5432, 5672, 15672, 61613, 9000, 9001, 6379, 81,
      3000, 9092). Production should expose only 443 (and 80 → 443 redirect) via the reverse proxy.
- [ ] **Floating image tags** — `cgr.dev/chainguard/minio:latest`. Pin every image version.
- [ ] **`restart: "no"`** everywhere — use `unless-stopped` / orchestrator restart policies.
- [ ] **No TLS** anywhere.

## 2. Backend (`loci-backend`)

- [ ] **`application-prod.yml` is not usable yet:**
  - datasource hardcoded to `jdbc:postgresql://localhost:5432/locidb` with `admin`/`admin`
  - the top-level `flyway.url` is `jdbc:mysql://…` (wrong driver)
  - no Keycloak, RabbitMQ/STOMP relay, or MinIO/S3 settings
  - CORS / `client-base-url` still `http://localhost:4200`
  - actuator `web.exposure.include: "*"` — restrict to `health,info,prometheus`
  - `baseline-on-migrate: true` — decide deliberately; it can hide a wrong target DB
  → Rewrite it to read everything from environment variables (like `application-stage.yml`).
- [ ] **Keycloak admin client** (`KeycloakAdminJavaClient`, user-migration feature) calls
      `keycloak.auth-server-url`, the browser-facing URL. Inside a container network that URL
      may not be reachable — point it at the internal URL or make the two configurable separately.
- [ ] `spring.jpa.show-sql: true` in the stage profile — turn off in production.
- [ ] `Dockerfile` builds on Java 17 images (`maven:3.9-eclipse-temurin-17`,
      `eclipse-temurin:17-jre-jammy`) — keep in sync with `<java.version>` in `pom.xml`.

## 3. Frontend (`loci-frontend`)

- [ ] `nginx/default.conf` proxies `/loci-bucket-01/` to `http://loci-minio:9000` using Docker's
      DNS (`resolver 127.0.0.11`). In production, point it at the real object storage
      (or let the backend return absolute/presigned URLs).
- [ ] `environments.prod.ts` placeholders (`your-prod-domain`, `your-prod-keycloak`) — real
      values come from `env.js`, generated at container start from `API_URL`,
      `SOCKET_ENDPOINT`, `KEYCLOAK_ISSUER`, `KEYCLOAK_REALM`, `KEYCLOAK_CLIENT_ID`.
      Use `wss://` for the socket endpoint.

## 4. Keycloak realm (`infra/keycloak-data/import/loci-realm-realm.json`)

- [ ] Import **only the realm file**, not `loci-realm-users-0.json`.
- [ ] Clients `angular`, `spring`, `migration-service` have **Direct Access Grants (password
      grant) enabled** — disable for production.
- [ ] `angular` client has `webOrigins: ["*"]` and redirect URIs for `localhost` and
      `192.168.1.21` — replace with the production domain only.
- [ ] `bruteForceProtected: false` — enable.
- [ ] `registrationAllowed: true` — confirm this is intended.
- [ ] `sslRequired: external` — use `all` behind TLS.

## 5. Reusable as-is (or nearly)

- `loci-backend/Dockerfile`, `loci-frontend/Dockerfile` — the artifacts that actually get deployed
- Flyway migrations in `loci-backend/src/main/resources/db/migrations/`
- Keycloak realm definition (after the fixes in section 4)
- `infra/prometheus/`, `infra/grafana/` (scrape config and dashboards)
- `infra/rabbitmq/rabbitmq.conf`

## 6. Deployment options (pick one later)

1. **Managed services** (recommended if on a cloud): managed Postgres (RDS / Cloud SQL),
   S3 instead of MinIO, managed RabbitMQ, a dedicated Keycloak instance. Production then
   only runs the two app images plus environment variables.
2. **Self-hosted VPS**: a separate compose file (e.g. `infra/production/compose.yaml`) that uses
   pre-built, version-tagged images, reads secrets from an uncommitted `.env`, runs Keycloak
   with `start`, puts nginx with TLS in front, and seeds nothing.

## 7. CI/CD

- [ ] Both `Jenkinsfile`s only compile, test and package; the Docker build & push stages are
      commented out. Add image build + push (tagged by commit/version) before any deployment.
