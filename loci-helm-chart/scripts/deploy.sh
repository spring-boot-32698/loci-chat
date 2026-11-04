#!/bin/bash
# Everything in one go: cluster, images, seed, helm release.
# Usage: ./deploy.sh <host>     e.g. ./deploy.sh 192.168.1.5 (this machine's LAN IP)
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
HOST="${1:?Usage: $0 <host>  (LAN IP or hostname users will open)}"
NAMESPACE="${NAMESPACE:-loci}"

"$SCRIPT_DIR/cluster-create.sh"
"$SCRIPT_DIR/build-images.sh"
"$SCRIPT_DIR/seed.sh"
helm upgrade --install loci "$SCRIPT_DIR/.." \
  --namespace "$NAMESPACE" --create-namespace \
  --set host="$HOST" \
  --wait --timeout 15m
