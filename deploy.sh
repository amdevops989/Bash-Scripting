#!/usr/bin/env bash
# ==============================================================================
# ULTIMATE DEVOPS ENGINE: BUILD, TEST, SCAN, AND DISTRIBUTION PIPELINE
# ==============================================================================
set -euo pipefail

# --- 1. CONFIGURATION & ENVIRONMENT ---
DOCKER_USER="devopsflow999"
IMAGE_NAME="core-api"
ENV_TARGET=${1:-"dev"}

REGISTRY_URL="https://hub.docker.com/v2/repositories/${DOCKER_USER}/${IMAGE_NAME}/tags/?page_size=100"
LOCKFILE="/tmp/${IMAGE_NAME}-${ENV_TARGET}.lock"
TEST_CONTAINER_NAME="core-api-test-runner"
TEST_PORT="3000"

# --- 2. THE SAFETY NET (SIGNAL TRAP) ---
cleanup() {
  echo "🧹 [CLEANUP] Tearing down resources..." >&2
  
  if [[ -f "$LOCKFILE" ]]; then
    rm -f "$LOCKFILE"
    echo "🗑️ [CLEANUP] Lockfile cleared." >&2
  fi

  if docker ps -a --format '{{.Names}}' | grep -q "^${TEST_CONTAINER_NAME}$"; then
    echo "🛑 [CLEANUP] Stopping and removing temporary test container..." >&2
    docker rm -f "$TEST_CONTAINER_NAME" &> /dev/null
  fi
}
trap cleanup EXIT ERR SIGINT

# --- 3. PRE-FLIGHT VALIDATION ---
echo "🔍 Running pre-flight system check..."

if [[ -f "$LOCKFILE" ]]; then
  echo "❌ CRITICAL: A build deployment for $ENV_TARGET is already in progress!" >&2
  exit 1
fi
touch "$LOCKFILE"

# Added 'trivy' to the required tools checklist
for TOOL in curl jq docker trivy; do
  if ! command -v "$TOOL" &> /dev/null; then
    echo "❌ CRITICAL ERROR: Required tool '$TOOL' is missing from host." >&2
    exit 1
  fi
done

# --- 4. FETCH & PARSE LIVE TAGS FROM DOCKER HUB ---
echo "🌐 Querying Docker Hub for active production tags..."
API_RESPONSE=$(curl -s "$REGISTRY_URL")
IS_EMPTY=$(echo "$API_RESPONSE" | jq -r '.results | length')

if [[ "$IS_EMPTY" -eq 0 ]]; then
  echo "⚠️ Repository appears empty. Initializing baseline tag at v1.0.0"
  LATEST_TAG="v1.0.0"
else
  LATEST_TAG=$(echo "$API_RESPONSE" | jq -r '.results[].name' | grep -v "latest" | head -n 1)
  echo "📡 Live version discovered on Docker Hub: $LATEST_TAG"
fi

# --- 5. PARSE & INCREMENT LOGIC (AWK) ---
CLEAN_TAG="${LATEST_TAG#v}"
MAJOR=$(echo "$CLEAN_TAG" | awk -F. '{print $1}')
MINOR=$(echo "$CLEAN_TAG" | awk -F. '{print $2}')
PATCH=$(echo "$CLEAN_TAG" | awk -F. '{print $3}')

NEW_PATCH=$((PATCH + 1))
NEW_VERSION="v${MAJOR}.${MINOR}.${NEW_PATCH}"
FULL_IMAGE_TAG="${DOCKER_USER}/${IMAGE_NAME}:${NEW_VERSION}"
echo "🚀 Next targeted production tag calculated as: $NEW_VERSION"

# --- 6. BUILD LAYER ---
echo "🔨 Compiling optimized layers for Node.js image..."
docker build --build-arg NODE_ENV="$ENV_TARGET" -t "$FULL_IMAGE_TAG" .

# --- 7. AUTOMATED INTEGRATION TESTING LAYER ---
echo "🧪 [TEST] Launching container smoke test..."
docker run -d -p "${TEST_PORT}:${TEST_PORT}" --name "$TEST_CONTAINER_NAME" "$FULL_IMAGE_TAG"

echo "⏳ [TEST] Waiting 3 seconds for app initialization..."
sleep 3

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${TEST_PORT}/" || echo "000")

if [[ "$HTTP_STATUS" -eq 200 ]]; then
  echo "✅ [TEST PASSED] Container responded with HTTP 200 OK!"
  docker rm -f "$TEST_CONTAINER_NAME" &> /dev/null
else
  echo "❌ [TEST FAILED] App returned HTTP status: $HTTP_STATUS instead of 200." >&2
  exit 1
fi

# --- 8. VULNERABILITY SCANNING LAYER (TRIVY) ---

echo "🛡️ [SCAN] Scanning container layers for vulnerabilities with Trivy..."

# --exit-code 1 means: if a CRITICAL vulnerability is found, crash the script right here.
# --severity CRITICAL isolates severe security threats only, preventing false alarms.
if ! trivy image --exit-code 1 --severity CRITICAL "$FULL_IMAGE_TAG"; then
  echo "❌ [SCAN FAILED] Critical vulnerabilities detected! Blocking registry push." >&2
  exit 1
fi

echo "✅ [SCAN PASSED] No critical vulnerabilities found."

# --- 9. DISTRIBUTION LAYER ---
echo "🏷️ Appending 'latest' marker to current layer context..."
docker tag "$FULL_IMAGE_TAG" "${DOCKER_USER}/${IMAGE_NAME}:latest"

echo "📤 Syncing layers to Docker Hub registry..."
docker push "$FULL_IMAGE_TAG"
docker push "${DOCKER_USER}/${IMAGE_NAME}:latest"

echo "🎉 Deployment pipeline finalized successfully for $NEW_VERSION"