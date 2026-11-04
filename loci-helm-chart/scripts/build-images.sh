#!/bin/bash
# Build the backend/frontend images from source and load them into the k3d cluster.
set -euo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOT="$SCRIPT_DIR/../.."
CLUSTER="${CLUSTER:-loci}"
TAG="${TAG:-dev}"

docker build -t "loci-server:$TAG" "$ROOT/loci-backend"
docker build -t "loci-web:$TAG" "$ROOT/loci-frontend"
k3d image import -c "$CLUSTER" "loci-server:$TAG" "loci-web:$TAG"
