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
KUSTOMIZE_BASE="../k8s/tax-office-base"

echo "=========================================="
echo "1. Cleaning up GKE Kubernetes resources using Kustomize"
echo "=========================================="

kubectl delete -k "${KUSTOMIZE_BASE}" 2>/dev/null || echo "K8s resources already deleted or cluster unreachable, continuing cleanup..."

echo "=========================================="
echo "2. Destroying all infrastructure with Terraform"
echo "=========================================="
cd "${TERRAFORM_DIR}" || exit 1

read -r -p "Are you sure you want to destroy ALL resources? This is irreversible. Type 'yes' to proceed: " confirm

if [[ $confirm != "yes" ]]; then
    echo "Aborted destruction."
    exit 0
fi

if ! terraform destroy -auto-approve; then
    echo "Error: Terraform destroy failed."
    exit 1
fi
echo "Infrastructure successfully destroyed."

cd - >/dev/null

echo "=========================================="
echo "3. Cleaning up local data"
echo "=========================================="
rm -f ../terraform/assets/tax_office_data.csv
echo "Local data artifact removed."

echo "🔥 All cloud resources and local artifacts have been destroyed."
