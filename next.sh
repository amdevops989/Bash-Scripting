#!/bin/bash

IMAGE="docker://docker.io/devopsflow999/frontend"

# 1. Use skopeo to list tags and filter for the highest version
LATEST_TAG=$(skopeo list-tags "$IMAGE" | \
  jq -r '.Tags[]' | \
  grep -E '^v[0-9]+\.[0-9]+\.[0-9]+-release$' | \
  sort -V | tail -n 1)

# 2. If no tags found, fallback
if [ -z "$LATEST_TAG" ]; then LATEST_TAG="v1.0.0-release"; fi

# 3. Clean and increment
CLEAN_VERSION=$(echo "$LATEST_TAG" | sed -E 's/v(.*)-release/\1/')
IFS='.' read -r major minor patch <<< "$CLEAN_VERSION"

NEW_VERSION="v${major}.${minor}.$((patch + 1))-release"
echo "Next version: $NEW_VERSION"