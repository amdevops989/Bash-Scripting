#!/usr/bin/env bash
set -euo pipefail

# 1. Pull current state file from AWS S3
aws s3 cp s3://production-pipeline-bucket/version.env ./version.env

# 2. Extract the full raw version string using awk (splits on '=')
# If the file contains 'APP_VERSION=v2.4.11', this grabs 'v2.4.11'
RAW_VERSION=$(grep "APP_VERSION" version.env | awk -F= '{print $2}')

# 3. Clean the 'v' out so it's just pure numbers (2.4.11)
CLEAN_VERSION="${RAW_VERSION#v}"

# 4. Extract individual numbers using awk (splits on '.')
MAJOR=$(echo "$CLEAN_VERSION" | awk -F. '{print $1}')
MINOR=$(echo "$CLEAN_VERSION" | awk -F. '{print $2}')
PATCH=$(echo "$CLEAN_VERSION" | awk -F. '{print $3}')

# 5. Math: Increment the patch digit
NEW_PATCH=$((PATCH + 1))
NEXT_VERSION="v${MAJOR}.${MINOR}.${NEW_PATCH}" # Result: v2.4.12

# 6. Swap old string with new string in the file using sed
sed -i "s/APP_VERSION=$RAW_VERSION/APP_VERSION=$NEXT_VERSION/g" version.env

# 7. Upload back to AWS S3
aws s3 cp ./version.env s3://production-pipeline-bucket/version.env

echo "State upgraded successfully from $RAW_VERSION to $NEXT_VERSION"