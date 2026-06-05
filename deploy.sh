#!/usr/bin/env bash
# ==============================================================================
# DEVOPS ENGINE: LIVE REGISTRY SCRAING & CONTAINER BUILDER
# ==============================================================================
set -euo pipefail

# --- 1. CONFIGURATION ---
DOCKER_USER="devopsflow999"          # Replace with your exact Docker Hub username
IMAGE_NAME="core-api"
REGISTRY_URL="https://hub.docker.com/v2/repositories/${DOCKER_USER}/${IMAGE_NAME}/tags/?page_size=100"

# --- 2. PRE-FLIGHT VALIDATION ---
echo "🔍 Running pre-flight system check..."
for TOOL in curl jq docker; do
  if ! command -v "$TOOL" &> /dev/null; then
    echo "❌ CRITICAL ERROR: Required tool '$TOOL' is missing." >&2
    exit 1
  fi
done

# --- 3. FETCH & PARSE LIVE TAGS FROM DOCKER HUB ---
echo "🌐 Querying Docker Hub for active production tags..."
API_RESPONSE=$(curl -s "$REGISTRY_URL")

# Check if the repository exists or if it's completely brand new
IS_EMPTY=$(echo "$API_RESPONSE" | jq -r '.results | length')

if [[ "$IS_EMPTY" -eq 0 ]]; then
  echo "⚠️ Repository appears empty or brand new. Initializing baseline tag at v1.0.0"
  LATEST_TAG="v1.0.0"
else
  # Filter out the "latest" keyword and isolate the highest version tag
  LATEST_TAG=$(echo "$API_RESPONSE" | jq -r '.results[].name' | grep -v "latest" | head -n 1)
  echo "📡 Live version discovered on Docker Hub: $LATEST_TAG"
fi

# --- 4. PARSE & INCREMENT LOGIC (AWK) ---
# Strip the leading 'v' if it exists to clean up string for parsing
CLEAN_TAG="${LATEST_TAG#v}"

MAJOR=$(echo "$CLEAN_TAG" | awk -F. '{print $1}')
MINOR=$(echo "$CLEAN_TAG" | awk -F. '{print $2}')
PATCH=$(echo "$CLEAN_TAG" | awk -F. '{print $3}')

# Increment the patch version by 1
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="v${MAJOR}.${MINOR}.${NEW_PATCH}"

echo "🚀 Next targeted production tag calculated as: $NEW_VERSION"

# --- 5. BUILD & DISTRIBUTION LAYER ---
echo "🔨 Compiling optimized layers for Node.js image..."
docker build -t "${DOCKER_USER}/${IMAGE_NAME}:${NEW_VERSION}" .

echo "🏷️ Appending 'latest' marker to current layer context..."
docker tag "${DOCKER_USER}/${IMAGE_NAME}:${NEW_VERSION}" "${DOCKER_USER}/${IMAGE_NAME}:latest"

echo "📤 Syncing layers to Docker Hub registry..."
docker push "${DOCKER_USER}/${IMAGE_NAME}:${NEW_VERSION}"
docker push "${DOCKER_USER}/${IMAGE_NAME}:latest"

echo "🎉 Deployment pipeline finalized successfully for $NEW_VERSION"