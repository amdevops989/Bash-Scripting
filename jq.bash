#! /bin/bash

set -euo pipefail 

ENV=${1:-"dev"}

instance_type=$(jq -r ".environments.${ENV}" config.json)

echo "Deploying to $ENV using instance type: $instance_type"
