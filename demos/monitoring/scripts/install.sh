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
# install.sh

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# Define working variables with robust script-relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$DEMO_DIR/terraform"
K8s_DIR="$DEMO_DIR/k8s/helm"
PKI_DIR="$K8s_DIR/pki"

# Helper function to wait for a certificate to exist and become Ready with retry logic and error diagnostic handling
wait_for_certificate_ready() {
    local cert_name="$1"
    local namespace="$2"
    local timeout="${3:-120}" # Default to 120 seconds
    local max_retries=6
    local retry_delay=10

    echo "Waiting for Certificate '$cert_name' in namespace '$namespace' to be Ready (timeout ${timeout}s)..."

    # 1. Wait for the certificate resource to be created in k8s API
    local exists=0
    for ((i=1; i<=max_retries; i++)); do
        if kubectl get certificate "$cert_name" -n "$namespace" >/dev/null 2>&1; then
            exists=1
            break
        fi
        echo "  - Certificate '$cert_name' not created yet. Waiting ($i/$max_retries)..."
        sleep "$retry_delay"
    done

    if [ "$exists" -eq 0 ]; then
        echo "  - [ERROR] Certificate '$cert_name' was not created in namespace '$namespace' after waiting." >&2
        return 1
    fi

    # 2. Wait for condition=Ready
    if kubectl wait --for=condition=Ready "certificate/$cert_name" -n "$namespace" --timeout="${timeout}s"; then
        echo "  - Certificate '$cert_name' is Ready."
        return 0
    else
        echo "  - [WARNING] Certificate '$cert_name' did not reach Ready state within ${timeout}s." >&2
        echo "  - Describing Certificate '$cert_name' for debugging:" >&2
        kubectl describe certificate "$cert_name" -n "$namespace" >&2 || true
        return 1
    fi
}

echo "--- Starting Infrastructure Installation ---"

# Initialize and apply Terraform
echo "1. Initializing Terraform Infrastructure Deploy..."
cd "$TF_DIR" || exit
terraform init

# Apply Terraform
echo "2. Applying Terraform configuration..."
# Using -auto-approve to skip manual confirmation. Remove if you want to review the plan.
terraform apply -auto-approve

echo ""
echo "--- Getting Terraform, Credentials & Constants Information ---"

#global
PROJECT_ID="$(terraform -chdir="$TF_DIR" output -raw project_id)"
REGION="$(terraform -chdir="$TF_DIR" output -raw region)"
UNIVERSE_API_DOMAIN="$(terraform -chdir="$TF_DIR" output -raw universe_api_domain)"
CLUSTER_NAME="$(terraform -chdir="$TF_DIR" output -raw cluster)"
STORAGE_BUCKET=$(terraform -chdir="$TF_DIR" output -raw storage_bucket)
GRAFANA_SA=$(terraform -chdir="$TF_DIR" output -raw grafana_sa_email)
MIMIR_SA=$(terraform -chdir="$TF_DIR" output -raw mimir_sa_email)
OTEL_SA=$(terraform -chdir="$TF_DIR" output -raw otel_sa_email)

#artifact registry
IMAGE_REGISTRY="$(terraform -chdir="$TF_DIR" output -raw artifact_registry_uri)"
REGISTRY_HOST="${IMAGE_REGISTRY%%/*}"

#apps
APPS_SENSOR_PORT="8000"

#helm constants
K8sNAMESPACE=$(terraform -chdir="$TF_DIR" output -raw k8s_namespace)
CERT_MANAGER_DIR="$K8s_DIR/cert-manager-wrapper"
GRAFANA_DIR="$K8s_DIR/grafana-wrapper"
MIMIR_DIR="$K8s_DIR/mimir-wrapper"
OTEL_DIR="$K8s_DIR/opentelemetry-wrapper"
KUBE_STATE_DIR="$K8s_DIR/kube-state-metrics-wrapper"
APPS_DIR="$K8s_DIR/apps"
KUBE_STATE_REGISTRY="registry.k8s.io"
KUBE_STATE_VERSION="v2.19.1"
OTEL_OTLPHTTPENDPOINT="https://mimir-gateway.$K8sNAMESPACE.svc.cluster.local:443/otlp"
GRAFANA_MIMIR_URL="https://mimir-gateway.$K8sNAMESPACE.svc.cluster.local:443/prometheus"
APPS_BEACON_OTELENDPOINT="https://opentelemetry-opentelemetry-collector.$K8sNAMESPACE.svc.cluster.local:4318/v1/metrics"

echo ""
echo "--- Starting Cluster Components Installation ---"

echo "Getting cluster credentials..."
gcloud container clusters get-credentials "$CLUSTER_NAME" --dns-endpoint --region "$REGION" --project "$PROJECT_ID" >/dev/null 2>&1

echo "Creating/Reusing working namespace..."
kubectl get namespace "$K8sNAMESPACE" &> /dev/null || kubectl create namespace "$K8sNAMESPACE"

echo "Building Helm chart dependencies..."
helm dependency build "$CERT_MANAGER_DIR"
helm dependency build "$GRAFANA_DIR"
helm dependency build "$MIMIR_DIR"
helm dependency build "$OTEL_DIR"
helm dependency build "$KUBE_STATE_DIR"

echo "Installing cert-manager..."
helm upgrade --install cert-manager "$CERT_MANAGER_DIR" \
    --namespace cert-manager \
    --create-namespace \
    --wait \
    --cleanup-on-fail

echo "Waiting for cert-manager deployments to be fully ready..."
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=120s
kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=120s
kubectl wait --for=condition=Available deployment/cert-manager-cainjector -n cert-manager --timeout=120s

echo "Deploying PKI ClusterIssuers..."
# Retry loop to handle transient GKE Konnectivity tunnel / webhook startup timing
for i in {1..5}; do
  if helm upgrade --install pki "$PKI_DIR" --namespace cert-manager --wait; then
    break
  fi
  echo "Webhook warming up, retrying in 5 seconds ($i/5)..."
  sleep 5
done

echo "Waiting for Root CA certificate..."
wait_for_certificate_ready sovereign-root-ca cert-manager 120

echo "Retrieving Grafana details..."
GRAFANA_USER=$(terraform -chdir="$TF_DIR" output -raw grafana_admin_user)
GRAFANA_PASSWORD=$(terraform -chdir="$TF_DIR" output -raw grafana_admin_password)
GRAFANA_CLIENT_ID=$(terraform -chdir="$TF_DIR" output -raw grafana_client_id)
GRAFANA_CLIENT_SECRET=$(terraform -chdir="$TF_DIR" output -raw grafana_client_secret)
GRAFANA_OAUTH_PROVIDER_URL=$(terraform -chdir="$TF_DIR" output -raw grafana_oauth_provider_url)
GRAFANA_AUTH_URL="${GRAFANA_OAUTH_PROVIDER_URL}/protocol/openid-connect/auth"
GRAFANA_TOKEN_URL="${GRAFANA_OAUTH_PROVIDER_URL}/protocol/openid-connect/token"
GRAFANA_API_URL="${GRAFANA_OAUTH_PROVIDER_URL}/protocol/openid-connect/userinfo"
GRAFANA_DISABLE_LOGIN_FORM=$(terraform -chdir="$TF_DIR" output -raw grafana_disable_login_form)
GRAFANA_ENABLE_OAUTH_LOGIN=$(terraform -chdir="$TF_DIR" output -raw grafana_enable_oauth_login)
GRAFANA_MIMIR_DATASOURCE_URL="mimir-gateway.$K8sNAMESPACE.svc.cluster.local"

echo "Installing grafana..."
helm upgrade --install grafana "$GRAFANA_DIR" \
    --namespace "$K8sNAMESPACE" \
    --values "$GRAFANA_DIR/values.yaml" \
    --values "$GRAFANA_DIR/dashboards.yaml" \
    --values "$GRAFANA_DIR/alerts.yaml" \
    --set "grafana.adminUser=$GRAFANA_USER" \
    --set "grafana.adminPassword=$GRAFANA_PASSWORD" \
    --set "grafana.serviceAccount.annotations.iam\.gke\.io/gcp-service-account=$GRAFANA_SA" \
    --set "grafana.env.GRAFANA_MIMIR_URL=$GRAFANA_MIMIR_URL" \
    --set "grafana.env.GRAFANA_MIMIR_SERVER_NAME=$GRAFANA_MIMIR_DATASOURCE_URL" \
    --set "grafana.env.GCP_PROJECT_ID=$PROJECT_ID" \
    --set "grafana.env.GOOGLE_CLOUD_UNIVERSE_DOMAIN=$UNIVERSE_API_DOMAIN" \
    --set "grafana.env.GF_AUTH_DISABLE_LOGIN_FORM=$GRAFANA_DISABLE_LOGIN_FORM" \
    --set "grafana.env.GF_AUTH_GENERIC_OAUTH_ENABLED=$GRAFANA_ENABLE_OAUTH_LOGIN" \
    --set "grafana.env.GF_AUTH_GENERIC_OAUTH_CLIENT_ID=$GRAFANA_CLIENT_ID" \
    --set "grafana.env.GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=$GRAFANA_CLIENT_SECRET" \
    --set "grafana.env.GF_AUTH_GENERIC_OAUTH_AUTH_URL=$GRAFANA_AUTH_URL" \
    --set "grafana.env.GF_AUTH_GENERIC_OAUTH_TOKEN_URL=$GRAFANA_TOKEN_URL" \
    --set "grafana.env.GF_AUTH_GENERIC_OAUTH_API_URL=$GRAFANA_API_URL" \
    --wait \
    --timeout 7m \
    --cleanup-on-fail

echo "Waiting for Grafana Certificate..."
wait_for_certificate_ready grafana-tls "$K8sNAMESPACE" 120

echo "Getting Gateway IP..."
GATEWAY_IP=""
MAX_RETRIES=15
RETRY_COUNT=0
while [ -z "$GATEWAY_IP" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    GATEWAY_IP=$(gcloud compute addresses list --filter="name ~ '.*$K8sNAMESPACE-grafana.*'" --regions="$REGION" --format="value(address)")
    if [ -z "$GATEWAY_IP" ]; then
      echo "IP not assigned yet. Retrying in 20 seconds... ($((MAX_RETRIES - RETRY_COUNT)) attempts left)"
      sleep 20
      RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
done

if [ -z "$GATEWAY_IP" ]; then
  echo "Error: Failed to retrieve Gateway IP for Grafana after $MAX_RETRIES attempts." >&2
  exit 1
fi

echo "IP retrieved successfully: $GATEWAY_IP"
GATEWAY_URL="https://${GATEWAY_IP}"
helm upgrade --install grafana "$GRAFANA_DIR" \
    --namespace "$K8sNAMESPACE" \
    --reuse-values \
    --set "grafana.env.GF_SERVER_ROOT_URL=${GATEWAY_URL}"

echo "grafana verification..."
kubectl get pods,svc -n "$K8sNAMESPACE"

echo "Installing mimir..."
helm upgrade --install mimir "$MIMIR_DIR" \
  --namespace "$K8sNAMESPACE" \
  --values "$MIMIR_DIR/values.yaml" \
  --values "$MIMIR_DIR/tls-values.yaml" \
  --set "mimir-distributed.serviceAccount.annotations.iam\.gke\.io/gcp-service-account=$MIMIR_SA" \
  --set "mimir-distributed.global.extraEnv[0].name=GOOGLE_CLOUD_UNIVERSE_DOMAIN" \
  --set "mimir-distributed.global.extraEnv[0].value=$UNIVERSE_API_DOMAIN" \
  --set "mimir-distributed.mimir.structuredConfig.common.storage.gcs.bucket_name=$STORAGE_BUCKET" \
  --wait \
  --timeout 7m \
  --cleanup-on-fail

echo "Waiting for Mimir Certificate..."
wait_for_certificate_ready mimir-gateway-tls "$K8sNAMESPACE" 120

echo "mimir verification..."
kubectl get pods,svc -n "$K8sNAMESPACE"

echo "Installing kube-state-metrics..."
helm upgrade --install kube-state-metrics "$KUBE_STATE_DIR" \
  --namespace "$K8sNAMESPACE" \
  --set "kube-state-metrics.image.registry=$KUBE_STATE_REGISTRY" \
  --set "kube-state-metrics.image.tag=$KUBE_STATE_VERSION" \
  --wait \
  --timeout 7m \
  --cleanup-on-fail

echo "kube-state-metrics verification..."
kubectl get pods,svc -n "$K8sNAMESPACE"

KUBE_SCRAPE_URL="kube-state-metrics.$K8sNAMESPACE.svc.cluster.local:8080"

echo "Installing opentelemetry..."
helm upgrade --install opentelemetry "$OTEL_DIR" \
  --namespace "$K8sNAMESPACE" \
  --set "opentelemetry-collector.serviceAccount.annotations.iam\.gke\.io/gcp-service-account=$OTEL_SA" \
  --set "opentelemetry-collector.config.exporters.otlphttp\/mimir.endpoint=$OTEL_OTLPHTTPENDPOINT" \
  --set "opentelemetry-collector.global.extraEnv[0].name=KUBE_SCRAPE_URL" \
  --set "opentelemetry-collector.global.extraEnv[0].value=$KUBE_SCRAPE_URL" \
  --wait \
  --timeout 7m \
  --cleanup-on-fail

echo "Waiting for OpenTelemetry Certificate..."
wait_for_certificate_ready otel-collector-tls "$K8sNAMESPACE" 120

echo "opentelemetry verification..."
kubectl get pods,svc -n "$K8sNAMESPACE"

echo ""
echo "--- Starting Demo Applications Installation ---"

echo "Retriving credentials..."
docker info >/dev/null 2>&1
gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin "$REGISTRY_HOST" >/dev/null 2>&1

echo ""
echo "Building Images..."

echo "Beacon Image..."
IMAGE_NAME="beacon-app"
TAG="latest"
REMOTE_IMAGE="${IMAGE_REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "Building and pushing Docker image to: $REMOTE_IMAGE..."
docker build -t "$IMAGE_NAME:$TAG" "$DEMO_DIR/apps/beacon"
docker tag "$IMAGE_NAME:$TAG" "$REMOTE_IMAGE"
docker push "$REMOTE_IMAGE"
BEACON_IMAGE="${REMOTE_IMAGE}"

echo "Installing beacon app..."
helm upgrade --install monitoring-beacon "$APPS_DIR/beacon" \
  --namespace "$K8sNAMESPACE" \
  --set beacon.image="$BEACON_IMAGE" \
  --set beacon.otelHttpEndpoint="$APPS_BEACON_OTELENDPOINT" \
  --wait \
  --cleanup-on-fail

echo "beacon app verification..."
kubectl get pods,svc -n "$K8sNAMESPACE"

echo "Sensor Image..."
IMAGE_NAME="sensor-app"
TAG="latest"
REMOTE_IMAGE="${IMAGE_REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "Building and pushing Docker image to: $REMOTE_IMAGE..."
docker build --build-arg PORT="$APPS_SENSOR_PORT" -t "$IMAGE_NAME:$TAG" "$DEMO_DIR/apps/sensor"
docker tag "$IMAGE_NAME:$TAG" "$REMOTE_IMAGE"
docker push "$REMOTE_IMAGE"
SENSOR_IMAGE="${REMOTE_IMAGE}"

echo "Installing sensor app..."
helm upgrade --install monitoring-sensor "$APPS_DIR/sensor" \
  --namespace "$K8sNAMESPACE" \
  --set sensor.image="$SENSOR_IMAGE" \
  --set sensor.port="$APPS_SENSOR_PORT" \
  --wait \
  --cleanup-on-fail

echo "sensor app verification..."
kubectl get pods,svc -n "$K8sNAMESPACE"

echo ""
echo "--- Starting Verification---"

echo "Verification for $K8sNAMESPACE..."
kubectl get nodes,pods,svc -n "$K8sNAMESPACE"

# Check if GCE logging VM is deployed and display its status
GCE_VM_NAME=$(terraform -chdir="$TF_DIR" output -raw gce_logging_vm_name || echo "")

if [ -n "$GCE_VM_NAME" ]; then
  echo ""
  echo "--- Standalone GCE VM Logging Status ---"
  echo "GCE VM Name: $GCE_VM_NAME"
fi

echo ""
echo "--- Installation Complete ---"
