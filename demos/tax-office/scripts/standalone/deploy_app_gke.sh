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

echo "Fetching infrastructure details from Terraform..."
AR_REPO_NAME=$(terraform -chdir="$TF_DIR" output -raw app_repository_id)
DEMO_PASSWORD=$(terraform -chdir="$TF_DIR" output -raw demo_password)
FLASK_SECRET_KEY=$(terraform -chdir="$TF_DIR" output -raw flask_secret_key)
GCP_PROJECT_ID=$(terraform -chdir="$TF_DIR" output -raw project_id)
GCP_PROJECT_NUM=$(terraform -chdir="$TF_DIR" output -raw project_number)
GCP_UNIVERSE_DOMAIN=$(terraform -chdir="$TF_DIR" output -raw universe_api_domain)
GKE_CLUSTER_NAME=$(terraform -chdir="$TF_DIR" output -raw tax_office_cluster_name)
GKE_REGION=$(terraform -chdir="$TF_DIR" output -raw region)
HUGGING_FACE_TOKEN=$(terraform -chdir="$TF_DIR" output -raw hugging_face_token)

echo "Connecting to GKE cluster: $GKE_CLUSTER_NAME..."
gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" --dns-endpoint --region "$GKE_REGION" --project "$GCP_PROJECT_ID"

# Derive registry host: replace 'apis-' with 'pkg-' in the universe domain if it exists
REGISTRY_DOMAIN="${GCP_UNIVERSE_DOMAIN/apis-/pkg-}"
REGISTRY_HOST="${REGISTRY_HOST:-docker.$REGISTRY_DOMAIN}"
IMAGE_NAME="tax-office-app"
TAG="latest"

PROJECT_PATH="${GCP_PROJECT_ID/://}"

TAX_APP_IMAGE_REPO="${REGISTRY_HOST}/${PROJECT_PATH}/${AR_REPO_NAME}/${IMAGE_NAME}"


echo "Fetching kube-dns IP address..."
KUBE_DNS_IP=$(kubectl get svc kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}')

echo "Deploying application with Helm..."
helm upgrade --install tax-office "$BASE_DIR/k8s/helm" \
    --namespace tax-office-ns --create-namespace \
    --set global.projectId="$GCP_PROJECT_ID" \
    --set global.universeDomain="$GCP_UNIVERSE_DOMAIN" \
    --set taxApp.image.repository="$TAX_APP_IMAGE_REPO" \
    --set taxApp.image.tag="$TAG" \
    --set taxApp.flaskSecretKey="$FLASK_SECRET_KEY" \
    --set taxApp.demoPassword="$DEMO_PASSWORD" \
    --set vllm.huggingFaceToken="$HUGGING_FACE_TOKEN" \
    --set dnsConfig.nameservers[0]="${KUBE_DNS_IP}"

echo "Waiting for Ingress IP addresses..."
while :; do
    APP_IP=$(kubectl get ingress tax-app-ingress -n tax-office-ns -o=jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    JUPYTER_IP=$(kubectl get ingress jupyter-ingress -n tax-office-ns -o=jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

    if [[ -n $APP_IP && -n $JUPYTER_IP ]]; then
        printf "\nDeployment complete!\n"
        printf "Jupyter:   http://%s\n" "$JUPYTER_IP"
        printf "Dashboard: http://%s\n" "$APP_IP"
        break
    fi
    echo -n "."
    sleep 10
done
