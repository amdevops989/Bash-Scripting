#!/usr/bin/env bash
set -euo pipefail

APP="docker"
ENV_TARGET=${1:-"dev"}
LOCKFILE="/tmp/cluster.lock"

# 1. Define the cleanup function (The Safety Net)
cleanup() {
  echo "🧹 Cleaning up... removing lock file." >&2
  rm -f "$LOCKFILE"
}

# 2. Register the trap to run the cleanup function on EXIT
trap cleanup EXIT

echo "Checking Preflight apps!"

# 3. Create the temporary lock file
touch "$LOCKFILE"

if ! command -v "$APP" &> /dev/null; then
  echo " ERROR: $APP is not installed..." >&2
  exit 1
fi

echo "env target is: $ENV_TARGET"
echo "All Checks passed"