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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TF_DIR="$DEMO_DIR/terraform"
K8s_DIR="$DEMO_DIR/k8s/helm"
PKI_DIR="$K8s_DIR/pki"
DEFAULTS_FILE="$TF_DIR/defaults.yaml"

# Helper function to parse Grafana settings from defaults.yaml in a single Python execution
load_grafana_config() {
    if [ ! -f "$DEFAULTS_FILE" ]; then
        echo "[ERROR] Configuration file '$DEFAULTS_FILE' not found." >&2
        exit 1
    fi

    eval $(python3 -c "
import yaml
with open('$DEFAULTS_FILE') as f:
    cfg = yaml.safe_load(f) or {}

g = cfg.get('grafana', {})
o = g.get('oauth', {})

print(f'GRAFANA_USER=\"{g.get(\"admin_user\", \"\")}\"')
print(f'GRAFANA_PASSWORD=\"{g.get(\"admin_password\", \"\")}\"')
print(f'GRAFANA_DISABLE_LOGIN_FORM=\"{g.get(\"disable_login_form\", True)}\"')
print(f'GRAFANA_ENABLE_OAUTH_LOGIN=\"{o.get(\"enable\", True)}\"')
print(f'GRAFANA_CLIENT_ID=\"{o.get(\"client_id\", \"\")}\"')
print(f'GRAFANA_CLIENT_SECRET=\"{o.get(\"client_secret\", \"\")}\"')
print(f'GRAFANA_OAUTH_PROVIDER_URL=\"{o.get(\"provider_url\", \"\")}\"')
")
}

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
        echo "  - [ERROR] Certificate '$cert_name' did not reach Ready state within ${timeout}s." >&2
        echo "  - Describing Certificate '$cert_name' for debugging:" >&2
        kubectl describe certificate "$cert_name" -n "$namespace" >&2
        return 1
    fi
}

echo "--- Starting Cluster Components & Applications Installation ---"

# Global & Terraform Information
PROJECT_ID="${PROJECT_ID:-$(terraform -chdir="$TF_DIR" output -raw project_id)}"
REGION="${REGION:-$(terraform -chdir="$TF_DIR" output -raw region)}"
UNIVERSE_API_DOMAIN="${UNIVERSE_API_DOMAIN:-$(terraform -chdir="$TF_DIR" output -raw universe_api_domain)}"
CLUSTER_NAME="${CLUSTER_NAME:-$(terraform -chdir="$TF_DIR" output -raw cluster)}"
STORAGE_BUCKET="${STORAGE_BUCKET:-$(terraform -chdir="$TF_DIR" output -raw storage_bucket)}"
GRAFANA_SA="${GRAFANA_SA:-$(terraform -chdir="$TF_DIR" output -raw grafana_sa_email)}"
MIMIR_SA="${MIMIR_SA:-$(terraform -chdir="$TF_DIR" output -raw mimir_sa_email)}"
LOKI_SA="${LOKI_SA:-$(terraform -chdir="$TF_DIR" output -raw loki_sa_email)}"
OTEL_SA="${OTEL_SA:-$(terraform -chdir="$TF_DIR" output -raw otel_sa_email)}"
IMAGE_REGISTRY="${IMAGE_REGISTRY:-$(terraform -chdir="$TF_DIR" output -raw artifact_registry_uri)}"
K8sNAMESPACE="${K8sNAMESPACE:-$(terraform -chdir="$TF_DIR" output -raw k8s_namespace)}"
GCE_VM_NAME="${GCE_VM_NAME:-$(terraform -chdir="$TF_DIR" output -raw gce_logging_vm_name)}"
GCE_VM_ZONE="${GCE_VM_ZONE:-$(terraform -chdir="$TF_DIR" output -raw gce_zone)}"

# Helm & Applications Constants
APPS_SENSOR_PORT="8000"
CERT_MANAGER_DIR="$K8s_DIR/cert-manager-wrapper"
GRAFANA_DIR="$K8s_DIR/grafana-wrapper"
MIMIR_DIR="$K8s_DIR/mimir-wrapper"
LOKI_DIR="$K8s_DIR/loki-wrapper"
OTEL_DIR="$K8s_DIR/opentelemetry-wrapper"
FLUENT_BIT_DIR="$K8s_DIR/fluent-bit-wrapper"
KUBE_STATE_DIR="$K8s_DIR/kube-state-metrics-wrapper"
APPS_DIR="$K8s_DIR/apps"
GRAFANA_MIMIR_URL="https://mimir-gateway.$K8sNAMESPACE.svc.cluster.local:443/prometheus"
GRAFANA_LOKI_URL="https://loki-gateway.$K8sNAMESPACE.svc.cluster.local:443"
APPS_BEACON_OTELENDPOINT="https://collector-with-ta-collector.$K8sNAMESPACE.svc.cluster.local:4318/v1/metrics"

echo ""
echo "--- Starting Cluster Components Installation ---"

BEACON_IMAGE="${IMAGE_REGISTRY}/beacon-app:latest"
SENSOR_IMAGE="${IMAGE_REGISTRY}/sensor-app:latest"

echo "Getting cluster credentials..."
gcloud container clusters get-credentials "$CLUSTER_NAME" --dns-endpoint --region "$REGION" --project "$PROJECT_ID"

echo "Creating/Reusing working namespace..."
if ! kubectl get namespace "$K8sNAMESPACE" >/dev/null 2>&1; then
    kubectl create namespace "$K8sNAMESPACE"
fi

# Note: keep It. Should be added or it will fail on first run
echo "Adding repos dependencies..."
helm repo add jetstack https://charts.jetstack.io
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add fluent https://fluent.github.io/helm-charts

echo "Building Helm chart dependencies..."
helm dependency build "$CERT_MANAGER_DIR"
helm dependency build "$GRAFANA_DIR"
helm dependency build "$MIMIR_DIR"
helm dependency build "$LOKI_DIR"
helm dependency build "$OTEL_DIR"
helm dependency build "$FLUENT_BIT_DIR"
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
PKI_SUCCESS=0
for i in {1..10}; do
  if helm upgrade --install pki "$PKI_DIR" --namespace cert-manager --wait; then
    PKI_SUCCESS=1
    echo "Webhook ready!..."
    break
  fi
  echo "Webhook warming up, retrying in 5 seconds ($i/10)..."
  sleep 5
done

if [ "$PKI_SUCCESS" -ne 1 ]; then
  echo "[ERROR] Failed to deploy PKI ClusterIssuers after 10 retries." >&2
  exit 1
fi

echo "Waiting for Root CA certificate..."
wait_for_certificate_ready sovereign-root-ca cert-manager 120

# fluent-bit needs to be at the top or else it will time out if deployed later.
echo "Installing fluent-bit log collector..."
helm upgrade --install fluent-bit "$FLUENT_BIT_DIR" \
  --namespace "$K8sNAMESPACE" \
  --values "$FLUENT_BIT_DIR/values.yaml" \
  --set "fluent-bit.env[0].name=OTEL_COLLECTOR_HOST" \
  --set "fluent-bit.env[0].value=collector-with-ta-collector.$K8sNAMESPACE.svc.cluster.local" \
  --wait \
  --timeout 7m \
  --cleanup-on-fail

echo "fluent-bit verification..."
kubectl get pods,svc -n "$K8sNAMESPACE"

echo "Waiting for Fluent Bit Certificate..."
wait_for_certificate_ready fluent-bit-tls "$K8sNAMESPACE" 120

echo "Retrieving Grafana details from defaults.yaml..."
load_grafana_config

# Validate required Grafana admin credentials
if [ -z "$GRAFANA_USER" ]; then
    echo "[ERROR] 'grafana.admin_user' is missing or empty in $DEFAULTS_FILE." >&2
    exit 1
fi

if [ -z "$GRAFANA_PASSWORD" ]; then
    echo "[ERROR] 'grafana.admin_password' is missing or empty in $DEFAULTS_FILE." >&2
    exit 1
fi

# Validate OAuth parameters if OAuth is enabled
if [ "$GRAFANA_ENABLE_OAUTH_LOGIN" = "True" ] || [ "$GRAFANA_ENABLE_OAUTH_LOGIN" = "true" ]; then
    if [ -z "$GRAFANA_CLIENT_ID" ] || [ "$GRAFANA_CLIENT_ID" = "iam-client-id" ]; then
        echo "[ERROR] OAuth is enabled but 'grafana.oauth.client_id' is missing or unset in $DEFAULTS_FILE." >&2
        exit 1
    fi
    if [ -z "$GRAFANA_CLIENT_SECRET" ] || [ "$GRAFANA_CLIENT_SECRET" = "iam-client-secret" ]; then
        echo "[ERROR] OAuth is enabled but 'grafana.oauth.client_secret' is missing or unset in $DEFAULTS_FILE." >&2
        exit 1
    fi
    if [ -z "$GRAFANA_OAUTH_PROVIDER_URL" ] || [ "$GRAFANA_OAUTH_PROVIDER_URL" = "iam-oauth-provider-url" ]; then
        echo "[ERROR] OAuth is enabled but 'grafana.oauth.provider_url' is missing or unset in $DEFAULTS_FILE." >&2
        exit 1
    fi
fi

GRAFANA_AUTH_URL="${GRAFANA_OAUTH_PROVIDER_URL}/protocol/openid-connect/auth"
GRAFANA_TOKEN_URL="${GRAFANA_OAUTH_PROVIDER_URL}/protocol/openid-connect/token"
GRAFANA_API_URL="${GRAFANA_OAUTH_PROVIDER_URL}/protocol/openid-connect/userinfo"
GRAFANA_MIMIR_DATASOURCE_URL="mimir-gateway.$K8sNAMESPACE.svc.cluster.local"
GRAFANA_LOKI_DATASOURCE_URL="loki-gateway.$K8sNAMESPACE.svc.cluster.local"

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
    --set "grafana.env.GRAFANA_LOKI_URL=$GRAFANA_LOKI_URL" \
    --set "grafana.env.GRAFANA_LOKI_SERVER_NAME=$GRAFANA_LOKI_DATASOURCE_URL" \
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
    GATEWAY_IP=$(kubectl get gateway grafana-gateway -n "$K8sNAMESPACE" -o jsonpath='{.status.addresses[0].value}')
    if [ -z "$GATEWAY_IP" ]; then
      echo "IP not assigned yet. Retrying in 20 seconds... ($((MAX_RETRIES - RETRY_COUNT)) attempts left)"
      sleep 20
      RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
done

if [ -z "$GATEWAY_IP" ]; then
  echo "[ERROR] Failed to retrieve Gateway IP for Grafana after $MAX_RETRIES attempts." >&2
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

MIMIR_GATEWAY_IP=$(terraform -chdir="$TF_DIR" output -raw mimir_gateway_ip)

echo "Installing mimir..."
helm upgrade --install mimir "$MIMIR_DIR" \
  --namespace "$K8sNAMESPACE" \
  --values "$MIMIR_DIR/values.yaml" \
  --values "$MIMIR_DIR/tls-values.yaml" \
  --set "mimir-distributed.serviceAccount.annotations.iam\.gke\.io/gcp-service-account=$MIMIR_SA" \
  --set "mimir-distributed.global.extraEnv[0].name=GOOGLE_CLOUD_UNIVERSE_DOMAIN" \
  --set "mimir-distributed.global.extraEnv[0].value=$UNIVERSE_API_DOMAIN" \
  --set "mimir-distributed.mimir.structuredConfig.common.storage.gcs.bucket_name=$STORAGE_BUCKET" \
  --set "mimir-distributed.gateway.service.loadBalancerIP=$MIMIR_GATEWAY_IP" \
  --wait \
  --timeout 10m \
  --cleanup-on-fail

echo "Waiting for Mimir Certificate..."
wait_for_certificate_ready mimir-gateway-tls "$K8sNAMESPACE" 120

echo "mimir verification..."
kubectl get pods,svc -n "$K8sNAMESPACE"

echo "OpenTelemetry operator and Prometheus Operator CRDs installation..."
helm upgrade --install opentelemetry-stack "$OTEL_DIR" \
  --namespace "$K8sNAMESPACE" \
  --set collector.enabled=false \
  --set admissionWebhooks.certManager.enabled=true \
  --set admissionWebhooks.autoGenerateCert.enabled=false \
  --wait \
  --cleanup-on-fail

echo "opentelemetry verification..."
kubectl get pods,svc -n "$K8sNAMESPACE"

echo "Installing loki..."
helm upgrade --install loki "$LOKI_DIR" \
  --namespace "$K8sNAMESPACE" \
  --values "$LOKI_DIR/values.yaml" \
  --values "$LOKI_DIR/tls-values.yaml" \
  --set "loki.serviceAccount.annotations.iam\.gke\.io/gcp-service-account=$LOKI_SA" \
  --set "loki.global.extraEnv[0].name=GOOGLE_CLOUD_UNIVERSE_DOMAIN" \
  --set "loki.global.extraEnv[0].value=$UNIVERSE_API_DOMAIN" \
  --set "loki.loki.storage.bucketNames.chunks=$STORAGE_BUCKET" \
  --set "loki.loki.storage.bucketNames.ruler=$STORAGE_BUCKET" \
  --set "loki.loki.storage.bucketNames.admin=$STORAGE_BUCKET" \
  --set "loki.loki.storage.gcs.bucket_name=$STORAGE_BUCKET" \
  --wait \
  --timeout 7m \
  --cleanup-on-fail

echo "Waiting for Loki Certificate..."
wait_for_certificate_ready loki-gateway-tls "$K8sNAMESPACE" 120

echo "loki verification..."
kubectl get pods,svc -n "$K8sNAMESPACE"

echo "Installing kube-state-metrics..."
helm upgrade --install kube-state-metrics "$KUBE_STATE_DIR" \
  --namespace "$K8sNAMESPACE" \
  --wait \
  --timeout 7m \
  --cleanup-on-fail

echo "kube-state-metrics verification..."
kubectl get pods,svc -n "$K8sNAMESPACE"

echo "OpenTelemetry collector installation..."
helm upgrade --install opentelemetry-stack "$OTEL_DIR" \
  --namespace "$K8sNAMESPACE" \
  --set collector.enabled=true \
  --set "serviceAccount.annotations.iam\.gke\.io/gcp-service-account=$OTEL_SA" \
  --wait \
  --cleanup-on-fail

echo "Waiting for OpenTelemetry Certificate..."
wait_for_certificate_ready otel-collector-vm-tls "$K8sNAMESPACE" 120

if [ -n "$GCE_VM_NAME" ]; then
  # Extract, Decode, and Upload CA Certificate
  echo "Download certificates for OTel Collector - CA Certificate"
  kubectl get secret otel-collector-vm-tls-secret -n "$K8sNAMESPACE" \
    -o jsonpath="{.data.ca\.crt}" | base64 -d | gcloud storage cp - gs://${STORAGE_BUCKET}/vm-certs/ca.crt

  # Extract, Decode, and Upload TLS Certificate
  echo "Download certificates for OTel Collector - TLS Certificate"
  kubectl get secret otel-collector-vm-tls-secret -n "$K8sNAMESPACE" \
    -o jsonpath="{.data.tls\.crt}" | base64 -d | gcloud storage cp - gs://${STORAGE_BUCKET}/vm-certs/tls.crt

  # Extract, Decode, and Upload TLS Private Key
  echo "Download certificates for OTel Collector - TLS Private Key"
  kubectl get secret otel-collector-vm-tls-secret -n "$K8sNAMESPACE" \
    -o jsonpath="{.data.tls\.key}" | base64 -d | gcloud storage cp - gs://${STORAGE_BUCKET}/vm-certs/tls.key

  echo "Reseting $GCE_VM_NAME"
  gcloud compute instances reset "$GCE_VM_NAME" --zone="$GCE_VM_ZONE"
fi

echo "opentelemetry verification..."
kubectl get pods,svc -n "$K8sNAMESPACE"

echo ""
echo "--- Starting Demo Applications Installation ---"

echo "Installing beacon app... from:$BEACON_IMAGE"
helm upgrade --install monitoring-beacon "$APPS_DIR/beacon" \
  --namespace "$K8sNAMESPACE" \
  --set beacon.image="$BEACON_IMAGE" \
  --set beacon.otelHttpEndpoint="$APPS_BEACON_OTELENDPOINT" \
  --wait \
  --cleanup-on-fail

echo "beacon app verification..."
kubectl get pods,svc -n "$K8sNAMESPACE"

echo "Installing sensor app... from:$SENSOR_IMAGE"
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

if [ -n "$GCE_VM_NAME" ]; then
  echo ""
  echo "--- Standalone GCE VM Logging Status ---"
  echo "GCE VM Name: $GCE_VM_NAME"
fi

echo ""
echo "--- Cluster Components & Applications Installation Complete ---"
