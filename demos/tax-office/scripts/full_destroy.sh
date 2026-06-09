#!/usr/bin/env bash
#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$BASE_DIR/terraform"

echo "Uninstalling Helm release..."
helm uninstall tax-office -n tax-office-ns || true

# Terraform unable to remove subnetwork, because it used by NEG created by GKE
# Ingress. Wait until in will be relesed.
echo "Waiting for 5 minutes (300 seconds) for GKE Ingress resources (like NEGs) to be fully deprovisioned by the GKE controller..."
sleep 300

if [ -d "$TF_DIR/.terraform" ]; then
    echo "Running terraform destroy..."
    (cd "$TF_DIR" && terraform destroy -auto-approve)
fi

# 1. Determine the data file path (Source of Truth: terraform/terraform.tfvars)
TFVARS_FILE="$TF_DIR/terraform.tfvars"
DEFAULT_FILE_PATH="$BASE_DIR/app/data_generator/tax_office_data.csv"
DATA_FILE_PATH=""

if [ -f "$TFVARS_FILE" ]; then
    # Extract value from tfvars, removing quotes and whitespace
    EXTRACTED_PATH=$(grep -E '^\s*data_file_location\s*=' "$TFVARS_FILE" | cut -d'"' -f2 | xargs 2>/dev/null || true)

    if [[ -n $EXTRACTED_PATH && $EXTRACTED_PATH != "REPLACE_ME" ]]; then
        # If path is relative (e.g. starting with ../ or ./), resolve it relative to the terraform directory
        if [[ $EXTRACTED_PATH == .* ]]; then
            DATA_FILE_PATH=$(cd "$TF_DIR" && realpath -m "$EXTRACTED_PATH" 2>/dev/null || true)
        else
            DATA_FILE_PATH="$EXTRACTED_PATH"
        fi
    fi
fi

# Fallback to default if not found or still REPLACE_ME
DATA_FILE_PATH="${DATA_FILE_PATH:-$DEFAULT_FILE_PATH}"

# 2. Delete the file if it exists
if [ -f "$DATA_FILE_PATH" ]; then
    echo "Removing generated data file: $DATA_FILE_PATH"
    rm -f "$DATA_FILE_PATH"
fi

echo "Cleaning up local deployment secrets..."
rm -f "$BASE_DIR/k8s/helm/deployment-secrets.yaml"

rm -rf "$BASE_DIR/scripts/.venv"
