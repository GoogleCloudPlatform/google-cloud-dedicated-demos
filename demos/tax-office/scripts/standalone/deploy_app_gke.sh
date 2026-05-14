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

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="$BASE_DIR/terraform"

GKE_CLUSTER_NAME="${GKE_CLUSTER_NAME:-$(terraform -chdir="$TF_DIR" output -raw tax_office_cluster_name)}"
GKE_REGION="${GKE_REGION:-$(terraform -chdir="$TF_DIR" output -raw region)}"
GCP_PROJECT_ID="${GCP_PROJECT_ID:-$(terraform -chdir="$TF_DIR" output -raw project_id)}"

gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" --dns-endpoint --region "$GKE_REGION" --project "$GCP_PROJECT_ID" >/dev/null 2>&1

kubectl apply -f "$BASE_DIR/k8s/vllm/computeclass.yaml"
kubectl apply -k "$BASE_DIR/k8s"

echo "Injecting environment variables into deployment..."
DATASET_ID=$(terraform -chdir="$TF_DIR" output -raw dataset_id)
TAX_TABLE_ID=$(terraform -chdir="$TF_DIR" output -raw tax_table_id)
POLICY_TABLE_ID=$(terraform -chdir="$TF_DIR" output -raw policy_table_id)
POLICY_EMBEDDINGS_TABLE_ID=$(terraform -chdir="$TF_DIR" output -raw policy_embeddings_table_id)
UNIVERSE_DOMAIN=$(terraform -chdir="$TF_DIR" output -raw universe_api_domain)
PROJECT_ID=$(terraform -chdir="$TF_DIR" output -raw project_id)
AR_REPO_NAME=$(terraform -chdir="$TF_DIR" output -raw app_repository_id)

# Derive registry host: replace 'apis-' with 'pkg-' in the universe domain if it exists
REGISTRY_DOMAIN="${UNIVERSE_DOMAIN/apis-/pkg-}"
REGISTRY_HOST="${REGISTRY_HOST:-docker.$REGISTRY_DOMAIN}"
IMAGE_NAME="tax-office-app"
TAG="latest"

PROJECT_PATH="${PROJECT_ID/://}"
REMOTE_IMAGE="${REGISTRY_HOST}/${PROJECT_PATH}/${AR_REPO_NAME}/${IMAGE_NAME}:${TAG}"

echo "Updating deployment image to: $REMOTE_IMAGE"
kubectl set image deployment/tax-office-app-deployment tax-office-container="$REMOTE_IMAGE" -n tax-office-ns

kubectl set env deployment/tax-office-app-deployment -n tax-office-ns \
    DATASET_ID="$DATASET_ID" \
    TAX_TABLE_ID="$TAX_TABLE_ID" \
    POLICY_TABLE_ID="$POLICY_TABLE_ID" \
    POLICY_EMBEDDINGS_TABLE_ID="$POLICY_EMBEDDINGS_TABLE_ID" \
    UNIVERSE_DOMAIN="$UNIVERSE_DOMAIN" \
    PROJECT_ID="$PROJECT_ID"

kubectl set env deployment/jupyter-notebook -n tax-office-ns \
    DATASET_ID="$DATASET_ID" \
    TAX_TABLE_ID="$TAX_TABLE_ID" \
    POLICY_TABLE_ID="$POLICY_TABLE_ID" \
    POLICY_EMBEDDINGS_TABLE_ID="$POLICY_EMBEDDINGS_TABLE_ID" \
    UNIVERSE_DOMAIN="$UNIVERSE_DOMAIN" \
    PROJECT_ID="$PROJECT_ID"

while :; do
    APP_IP=$(kubectl get ingress tax-app-ingress -n tax-office-ns -o=jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    JUPYTER_IP=$(kubectl get ingress jupyter-ingress -n tax-office-ns -o=jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

    if [[ -n $APP_IP && -n $JUPYTER_IP ]]; then
        printf "Jupyter:   http://%s\nDashboard: http://%s\n" "$JUPYTER_IP" "$APP_IP"
        break
    fi
    sleep 10
done
