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
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$BASE_DIR/terraform"

if command -v kubectl >/dev/null 2>&1; then
    echo "Attempting to clean up Kubernetes resources..."
    helm uninstall insurance-app -n insurance-ns 2>/dev/null || true
    kubectl delete job db-init-job -n insurance-ns --ignore-not-found 2>/dev/null || true
    kubectl delete secret insurance-demo-secrets -n insurance-ns --ignore-not-found 2>/dev/null || true
    kubectl delete namespace insurance-ns --ignore-not-found 2>/dev/null || true

    echo "Waiting for 5 minutes (300 seconds) for GKE network resources to fully deprovision..."
    sleep 300
fi

if [ -d "$TF_DIR" ]; then
    GCP_PROJECT_ID=$(terraform -chdir="$TF_DIR" output -raw project_id 2>/dev/null || true)
    GCS_BUCKET=$(terraform -chdir="$TF_DIR" output -raw claims_document_bucket 2>/dev/null || true)

    if [[ -n $GCS_BUCKET ]]; then
        echo "Emptying GCS Bucket contents..."
        gcloud storage rm --recursive "gs://$GCS_BUCKET/**" 2>/dev/null || true
    fi

    echo "Running terraform destroy..."
    (
        cd "$TF_DIR"
        terraform state rm google_sql_user.postgres 2>/dev/null || true
        terraform state rm google_sql_user.iam_service_account_user 2>/dev/null || true
        terraform destroy -auto-approve
    )
fi
echo "✅ Complete uninstallation and infrastructure teardown successful."
