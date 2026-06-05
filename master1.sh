#!/usr/bin/env bash
# ==============================================================================
# MASTER DEVOPS AUTOMATION SCRIPT
# Concepts: Defensive coding, Traps, Pre-flight checks, Arrays, Loops, & JQ
# ==============================================================================
set -euo pipefail

# --- 1. GLOBAL VARIABLES & CONFIG ---
REQUIRED_APPS=("docker" "jq")
ENV_TARGET=${1:-"dev"}
LOCKFILE="/tmp/pipeline-${ENV_TARGET}.lock"
CONFIG_FILE="config.json"

# --- 2. THE SAFETY NET (SIGNAL TRAP) ---
cleanup() {
  echo "🧹 [CLEANUP] Script execution finished or interrupted. Removing lock file..." >&2
  if [[ -f "$LOCKFILE" ]]; then
    rm -f "$LOCKFILE"
    echo "🗑️ [CLEANUP] Successfully removed $LOCKFILE" >&2
  fi
}
# Register safety net to catch normal exits, errors (ERR), or user cancellations (SIGINT)
trap cleanup EXIT ERR SIGINT

# --- 3. PRE-FLIGHT VALIDATIONS ---
echo "🚀 [INIT] Starting deployment preparation for environment: $ENV_TARGET"

# Check for active concurrent builds using our lockfile
if [[ -f "$LOCKFILE" ]]; then
  echo "❌ [ERROR] A deployment for $ENV_TARGET is already running!" >&2
  exit 1
fi
touch "$LOCKFILE"

# Loop through our required tools array to ensure the runner has them installed
echo "🔍 [CHECK] Validating required system tools..."
for APP in "${REQUIRED_APPS[@]}"; do
  if ! command -v "$APP" &> /dev/null; then
    echo "❌ [ERROR] Required tool '$APP' is missing from the system path." >&2
    exit 1
  fi
done

# Verify the config file exists before trying to read it
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ [ERROR] Configuration file '$CONFIG_FILE' not found!" >&2
  exit 1
fi

# --- 4. CONFIGURATION PARSING (JQ) ---
echo "📊 [DATA] Extracting cloud configuration details..."
INSTANCE_SIZE=$(jq -r ".environments.${ENV_TARGET}" "$CONFIG_FILE")

# Defensive validation on the parsed data
if [[ "$INSTANCE_SIZE" == "null" ]]; then
  echo "❌ [ERROR] Environment '$ENV_TARGET' does not exist in $CONFIG_FILE" >&2
  exit 1
fi

# --- 5. EXECUTION LAYER ---
echo "✅ [SUCCESS] All pre-flight checks passed seamlessly."
echo "⚙️ [EXECUTE] Provisioning a $INSTANCE_SIZE instance for $ENV_TARGET..."

# (Your Docker or Terraform commands would run right here)

echo "🎉 [FINISH] Script completed successfully."