#! /bin/bash

set -euo pipefail

NAME=${1:-"REDA"}

if [[ $NAME == "root" ]]; then
  echo "ERROR: login in with root is forbiden!" >&2
  exit 1
fi

echo "Hello $NAME"

SERVICES=("API" "FRONTEND" "REDIS")

echo " Starting Svc Health checks...."

for SERVICE in "${SERVICES[@]}"; do
  echo "$SERVICE is ok"
  if [[ "$SERVICE" == "REDIS" ]]; then
   echo "WARN: service $SERVICE is taking too long to respond." >&2
  fi
done

echo "ALL Checks Complete!"