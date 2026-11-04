# loci-helm-chart

Helm chart for running Loci on a local Kubernetes cluster ([k3d](https://k3d.io)), reachable from
other devices on the same network at `https://<host>`.

It deploys the backend and frontend (built from this repo) plus their infrastructure:
Postgres, Keycloak, RabbitMQ (STOMP relay), MinIO and Redis. pgAdmin, Prometheus and Grafana
are not included — use `infra/compose.yaml` for those.

## Prerequisites

`docker`, `k3d`, `kubectl`, `helm`. Host ports 80 and 443 must be free (stop any compose
stack that binds them).

## Quick start

```bash
./scripts/deploy.sh 192.168.1.5     # this machine's LAN IP (ip -4 addr)
```

which runs, in order:

| Script | Does |
|---|---|
| `scripts/cluster-create.sh` | k3d cluster `loci`, Traefik on host ports 80/443 |
| `scripts/build-images.sh` | builds `loci-server:dev`, `loci-web:dev` and imports them into the cluster |
| `scripts/seed.sh` | ConfigMaps `loci-db-seed` (from `infra/backups/backup.sql`) and `loci-keycloak-realm` |
| `helm upgrade --install loci . -n loci --set host=<host>` | the release |

Then, on each device (once):
1. Open `http://<host>/ca.crt` and install it as a trusted CA
   - Android: Settings → Security → Encryption & credentials → Install a certificate → CA certificate
   - iOS: install the downloaded profile, then Settings → General → About →
     Certificate Trust Settings → enable "Loci Local CA"
2. Open `https://<host>` — demo accounts `demo01` … `demo05` (password = username)

HTTPS is required: keycloak-js needs `crypto.randomUUID`, which browsers only expose on
`https://` or `localhost`.

## Routing

One origin, served by Traefik (`templates/ingress.yaml`):

| Path | Service |
|---|---|
| `/api/` | `loci-server` (REST + WebSocket) |
| `/realms/`, `/resources/`, `/admin/` | `loci-auth` (Keycloak; admin console at `/admin/`) |
| `/loci-bucket-01/` | `loci-minio` (media: anonymous read by object path, no listing) |
| `/` | `loci-web` |
| `http://<host>/ca.crt` | the local CA; all other plain-HTTP requests redirect to HTTPS |

## Values

See `values.yaml`. The important ones:

| Key | Default | Meaning |
|---|---|---|
| `host` | — (required) | IP or hostname users open; Keycloak issues tokens for `https://<host>` |
| `auth.*` | `admin`/`admin`, `minioadmin` | credentials of the bundled services |
| `tls.generate` | `true` | generate a local CA + server cert (CA secret `loci-ca` is kept across upgrades and uninstall) |
| `tls.existingSecret` | `""` | use your own `kubernetes.io/tls` secret instead |
| `backend.image`, `frontend.image` | `loci-server:dev`, `loci-web:dev` | images imported by `build-images.sh` |
| `postgres.seedConfigMap` | `loci-db-seed` | seed applied when the DB volume is empty; `""` disables |

## Day-to-day

```bash
# Code changed: rebuild, import, restart
./scripts/build-images.sh
kubectl -n loci rollout restart deployment/loci-server deployment/loci-web

# The machine's IP changed: new cert + Keycloak redirect URI; devices keep trusting the same CA
helm upgrade loci . -n loci --reuse-values --set host=<new IP>

# Remove the release (PVCs and the CA secret stay) / the whole cluster
helm uninstall loci -n loci
k3d cluster delete loci
```

## Notes

- Workload/service names are fixed (`loci-db`, `loci-auth`, …): one release per namespace.
- The seed only runs on an empty Postgres volume. To re-seed: uninstall, delete PVC
  `data-loci-db-0`, install again.
- Keycloak shares the `locidb` database with the app (the seed contains both). This and the
  other local-only shortcuts are listed in [`infra/PRODUCTION.md`](../infra/PRODUCTION.md).
