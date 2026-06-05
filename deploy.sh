#!/usr/bin/env bash
# ==============================================================================
# DEVOPS ENGINE: LIVE REGISTRY SCRAING, CONTAINER BUILDER & INTEGRATION TESTER
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
  
  # Remove the lockfile
  if [[ -f "$LOCKFILE" ]]; then
    rm -f "$LOCKFILE"
    echo "🗑️ [CLEANUP] Lockfile cleared." >&2
  fi

  # Stop and remove the test container if it is still running
  if docker ps -a --format '{{.Names}}' | grep -q "^${TEST_CONTAINER_NAME}$"; then
    echo "🛑 [CLEANUP] Stopping and removing temporary test container..." >&2
    docker rm -f "$TEST_CONTAINER_NAME" &> /dev/null
  fi
}
trap cleanup EXIT ERR SIGINT

# --- 3. PRE-FLIGHT VALIDATION ---
echo "🔍 Running pre-flight system check for environment: [${ENV_TARGET^^}]..."

if [[ -f "$LOCKFILE" ]]; then
  echo "❌ CRITICAL: A build deployment for $ENV_TARGET is already in progress!" >&2
  exit 1
fi
touch "$LOCKFILE"

for TOOL in curl jq docker; do
  if ! command -v "$TOOL" &> /dev/null; then
    echo "❌ CRITICAL ERROR: Required tool '$TOOL' is missing." >&2
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
echo "🚀 Next targeted production tag calculated as: $NEW_VERSION"

# --- 6. BUILD LAYER ---
echo "🔨 Compiling optimized layers for Node.js image..."
docker build --build-arg NODE_ENV="$ENV_TARGET" -t "${DOCKER_USER}/${IMAGE_NAME}:${NEW_VERSION}" .

# --- 7. AUTOMATED INTEGRATION TESTING LAYER ---
echo "🧪 [TEST] Launching container smoke test..."

# Run the newly built image locally using our port mapping rule (Host Port : Container Port)
docker run -d \
  -p "${TEST_PORT}:${TEST_PORT}" \
  --name "$TEST_CONTAINER_NAME" \
  "${DOCKER_USER}/${IMAGE_NAME}:${NEW_VERSION}"

echo "⏳ [TEST] Waiting 3 seconds for Node.js application to initialize..."
sleep 3

echo "📡 [TEST] Sending smoke test payload to http://localhost:${TEST_PORT}/ ..."
# Hit the endpoint. -s makes it silent, -w extracts the HTTP response code
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${TEST_PORT}/" || echo "000")

if [[ "$HTTP_STATUS" -eq 200 ]]; then
  echo "✅ [TEST PASSED] Container responded with HTTP 200 OK!"
  # Safely remove the test container now that it passed so we free up the host port
  docker rm -f "$TEST_CONTAINER_NAME" &> /dev/null
else
  echo "❌ [TEST FAILED] App returned HTTP status: $HTTP_STATUS instead of 200." >&2
  exit 1
fi

# --- 7.2. VULNERABILITY SCANNING LAYER (TRIVY) ---

echo "🛡️ [SCAN] Scanning container layers for vulnerabilities with Trivy..."

# --exit-code 1 means: if a CRITICAL vulnerability is found, crash the script right here.
# --severity CRITICAL isolates severe security threats only, preventing false alarms.
if ! trivy image --exit-code 1 --severity CRITICAL "$FULL_IMAGE_TAG"; then
  echo "❌ [SCAN FAILED] Critical vulnerabilities detected! Blocking registry push." >&2
  exit 1
fi

echo "✅ [SCAN PASSED] No critical vulnerabilities found."

# --- 8. DISTRIBUTION LAYER ---
echo "🏷️ Appending 'latest' marker to current layer context..."
docker tag "${DOCKER_USER}/${IMAGE_NAME}:${NEW_VERSION}" "${DOCKER_USER}/${IMAGE_NAME}:latest"

echo "📤 Syncing layers to Docker Hub registry..."
docker push "${DOCKER_USER}/${IMAGE_NAME}:${NEW_VERSION}"
docker push "${DOCKER_USER}/${IMAGE_NAME}:latest"

echo "🎉 Deployment pipeline finalized successfully for $NEW_VERSION"