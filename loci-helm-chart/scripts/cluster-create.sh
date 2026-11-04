#!/bin/bash
# Create a single-node k3d cluster with Traefik on host ports 80/443 (reachable from the LAN).
set -euo pipefail
CLUSTER="${CLUSTER:-loci}"

if k3d cluster list "$CLUSTER" >/dev/null 2>&1; then
  echo "Cluster '$CLUSTER' already exists"
else
  k3d cluster create "$CLUSTER" \
    --servers 1 --agents 0 \
    -p "80:80@loadbalancer" \
    -p "443:443@loadbalancer" \
    --wait
fi
kubectl config use-context "k3d-$CLUSTER"

# k3s installs Traefik asynchronously; the chart needs its CRDs (Middleware, TLSStore)
echo "Waiting for Traefik CRDs..."
until kubectl get crd middlewares.traefik.io tlsstores.traefik.io >/dev/null 2>&1; do sleep 3; done
kubectl wait --for=condition=established --timeout=120s crd/middlewares.traefik.io crd/tlsstores.traefik.io
