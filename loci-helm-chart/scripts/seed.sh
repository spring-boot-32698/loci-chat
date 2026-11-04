#!/bin/bash
# Create the ConfigMaps the chart uses to seed an empty database and Keycloak:
#   loci-db-seed         init.sql.gz from infra/backups/backup.sql (schema + realm + demo users)
#   loci-keycloak-realm  realm/users JSON from infra/keycloak-data/import/
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
INFRA="$SCRIPT_DIR/../../infra"
NAMESPACE="${NAMESPACE:-loci}"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
gzip -9 -c "$INFRA/backups/backup.sql" > "$TMP/init.sql.gz"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
# Server-side apply: client-side apply would store the whole file in an annotation (256 KiB limit)
kubectl -n "$NAMESPACE" create configmap loci-db-seed \
  --from-file=init.sql.gz="$TMP/init.sql.gz" --dry-run=client -o yaml \
  | kubectl apply --server-side --force-conflicts -f -
kubectl -n "$NAMESPACE" create configmap loci-keycloak-realm \
  --from-file="$INFRA/keycloak-data/import/" --dry-run=client -o yaml \
  | kubectl apply --server-side --force-conflicts -f -
