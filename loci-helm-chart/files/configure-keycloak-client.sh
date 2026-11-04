#!/bin/bash
# Allow the frontend client to redirect back to PUBLIC_URL (runs on every install/upgrade).
set -euo pipefail
KCADM=/opt/keycloak/bin/kcadm.sh
export HOME=/tmp

until $KCADM config credentials --server http://loci-auth:8080 --realm master \
    --user "$KEYCLOAK_ADMIN" --password "$KEYCLOAK_ADMIN_PASSWORD" >/dev/null 2>&1; do
  echo "Waiting for Keycloak..."; sleep 5
done

ID=$($KCADM get clients -r "$REALM" -q clientId="$CLIENT_ID" --fields id --format csv --noquotes)
$KCADM update "clients/$ID" -r "$REALM" \
  -s "redirectUris=[\"http://localhost:4200/*\",\"${PUBLIC_URL}/*\"]" \
  -s "attributes.\"post.logout.redirect.uris\"=http://localhost:4200/*##${PUBLIC_URL}/*"
echo "Client '$CLIENT_ID' accepts ${PUBLIC_URL}"
