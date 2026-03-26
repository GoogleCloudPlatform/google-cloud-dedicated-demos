#!/bin/bash
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

# --- Configuration ---
TERRAFORM_DIR="../terraform"

echo "=========================================="
echo "1. Initializing Terraform"
echo "=========================================="
cd "${TERRAFORM_DIR}" || exit 1

if ! terraform init; then
    echo "Error: Terraform initialization failed."
    exit 1
fi
echo "Terraform initialized successfully."

echo "=========================================="
echo "2. Applying infrastructure changes"
echo "=========================================="
if ! terraform apply -auto-approve; then
    echo "Error: Terraform apply failed."
    exit 1
fi
echo "Infrastructure deployed successfully."

# --- Extract and Export Variables using 'terraform output' ---
echo "=========================================="
echo "3. Exporting output variables"
echo "=========================================="
export GCP_PROJECT_ID=$(terraform output -raw project_id)
export GKE_REGION=$(terraform output -raw region)
export GKE_CLUSTER_NAME=$(terraform output -raw tax_office_cluster_name)
export AR_REPO_NAME=$(terraform output -raw app_repository_id)
export GCS_BUCKET_NAME=$(terraform output -raw tax_office_bucket_name)

cd - >/dev/null

echo "Exported Variables:"
echo "GCP_PROJECT_ID=${GCP_PROJECT_ID}"
echo "GKE_REGION=${GKE_REGION}"
echo "GKE_CLUSTER_NAME=${GKE_CLUSTER_NAME}"
echo "AR_REPO_NAME=${AR_REPO_NAME}"
echo "GCS_BUCKET_NAME=${GCS_BUCKET_NAME}"
