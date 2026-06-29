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

GCP_PROJECT_ID="${GCP_PROJECT_ID:-$(terraform -chdir="$TF_DIR" output -raw project_id)}"
GCP_REGION="${GCP_REGION:-$(terraform -chdir="$TF_DIR" output -raw region)}"
GKE_CLUSTER_NAME="${GKE_CLUSTER_NAME:-$(terraform -chdir="$TF_DIR" output -raw gke_cluster_name)}"
UNIVERSE_DOMAIN="${UNIVERSE_DOMAIN:-$(terraform -chdir="$TF_DIR" output -raw universe_domain)}"

gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" --dns-endpoint --region "$GCP_REGION" --project "$GCP_PROJECT_ID" >/dev/null 2>&1

export TF_SQL_INSTANCE=$(terraform -chdir="$TF_DIR" output -raw sql_instance_name)
export TF_DB_NAME=$(terraform -chdir="$TF_DIR" output -raw claims_database_name)
export TF_BUCKET=$(terraform -chdir="$TF_DIR" output -raw claims_document_bucket)
export TF_SQL_DNS_NAME=$(terraform -chdir="$TF_DIR" output -raw sql_dns_name)

DOCKER_REPO=$(terraform -chdir="$TF_DIR" output -raw docker_repo_prefix)
SA_EMAIL=$(terraform -chdir="$TF_DIR" output -raw gcp_service_account_email)
MODEL_HOST=$(terraform -chdir="$TF_DIR" output -raw model_host)

echo "Creating Kubernetes base infrastructure secret..."
kubectl create namespace insurance-ns --dry-run=client -o yaml | kubectl apply -f -
kubectl delete secret insurance-demo-secrets -n insurance-ns --ignore-not-found 2>/dev/null || true
kubectl create secret generic insurance-demo-secrets -n insurance-ns \
    --from-literal=MODEL_HOST="http://llm-service:8000" \
    --from-literal=MODEL_NAME="google/gemma-3-27b-it" \
    --from-literal=CLAIMS_DATABASE_NAME="${TF_DB_NAME}" \
    --from-literal=PROJECT="${GCP_PROJECT_ID}" \
    --from-literal=REGION="${GCP_REGION}" \
    --from-literal=SQL_INSTANCE_NAME="${TF_SQL_INSTANCE}" \
    --from-literal=DATABASE_PORT="5432" \
    --from-literal=CLAIMS_DOCUMENTS_BUCKET="${TF_BUCKET}" \
    --from-literal=UNIVERSE_DOMAIN="${UNIVERSE_DOMAIN}"

echo "Fetching kube-dns IP address for Sovereign DNS resolution..."
KUBE_DNS_IP=$(kubectl get svc kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}')

echo "Deploying applications and platforms via unified Helm chart..."
helm upgrade --install insurance-app "$BASE_DIR/k8s/helm" \
    --namespace insurance-ns --create-namespace \
    -f "$BASE_DIR/k8s/helm/values.yaml" \
    -f "$BASE_DIR/k8s/helm/deployment-secrets.yaml" \
    --set insuranceApp.image.repository="$DOCKER_REPO/insurance-demo-showroom-app" \
    --set insuranceApp.proxyImage="$DOCKER_REPO/cloud-sql-proxy:2.15" \
    --set insuranceApp.pgImage="$DOCKER_REPO/postgres:15" \
    --set insuranceApp.gcloudImage="$DOCKER_REPO/google-cloud-cli:slim" \
    --set global.universeDomain="$UNIVERSE_DOMAIN" \
    --set global.projectId="$GCP_PROJECT_ID" \
    --set global.region="$GCP_REGION" \
    --set global.sqlInstanceName="$TF_SQL_INSTANCE" \
    --set global.bucket="$TF_BUCKET" \
    --set global.databaseName="$TF_DB_NAME" \
    --set jupyter.sqlDnsName="$TF_SQL_DNS_NAME" \
    --set insuranceApp.serviceAccount.gcpServiceAccountEmail="$SA_EMAIL" \
    --set dnsConfig.nameservers[0]="${KUBE_DNS_IP}"

echo "Waiting for DB init job to complete successfully..."
kubectl wait --for=condition=complete job/db-init-job -n insurance-ns --timeout=300s || true
echo "✅ DB init job successfully executed."

echo "Waiting for services to receive LoadBalancer IPs..."
while :; do
    APP_IP=$(kubectl get service insurance-demo-showroom-service -n insurance-ns -o=jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    JUPYTER_IP=$(kubectl get service insurance-demo-jupyter-service -n insurance-ns -o=jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    LLM_IP=$(kubectl get service llm-service -n insurance-ns -o=jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

    if [[ -n $APP_IP && -n $JUPYTER_IP && -n $LLM_IP ]]; then
        printf "\n🚀 Web Showroom Dashboard: http://%s:8080\n🪐 JupyterLab Platform:    http://%s\n🧠 vLLM Gemma Service:     http://%s:8000\n" "$APP_IP" "$JUPYTER_IP" "$LLM_IP"
        break
    fi
    sleep 10
done
