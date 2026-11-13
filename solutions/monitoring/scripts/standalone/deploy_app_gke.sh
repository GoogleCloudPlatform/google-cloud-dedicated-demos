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
VM_DIR="$DEMO_DIR/scripts/gce"
K8s_DIR="$DEMO_DIR/k8s/helm"
PKI_DIR="$K8s_DIR/pki"
DEFAULTS_FILE="$TF_DIR/defaults.yaml"

# Helper function to wait for an existing Certificate to become Ready, describing it on failure.
# No existence polling needed: each Certificate is created synchronously by the preceding helm upgrade.
wait_for_certificate_ready() {
    local cert_name="$1" namespace="$2" timeout="${3:-120}"
    if ! kubectl wait --for=condition=Ready "certificate/$cert_name" -n "$namespace" --timeout="${timeout}s"; then
        kubectl describe certificate "$cert_name" -n "$namespace" >&2
        return 1
    fi
}

# Helper function to install or upgrade a Helm release and wait until it is ready.
# Extra helm flags are passed through; a later --namespace overrides the default one.
# Fast failures (under 2 minutes) are retried: on a fresh Autopilot cluster the API server
# can briefly fail to reach webhooks ("No agent available") while the first node connects.
# Slow failures, such as a --wait timeout, are not retried.
helm_deploy() {
    local release="$1" chart="$2" attempt start
    shift 2
    for attempt in 1 2 3 4 5; do
        echo "Deploying $release..."
        start=$SECONDS
        if helm upgrade --install "$release" "$chart" \
            --namespace "$K8sNAMESPACE" \
            --create-namespace \
            --wait \
            --timeout 10m \
            --cleanup-on-fail \
            "$@"; then
            return 0
        fi
        if [ "$attempt" -eq 5 ] || [ $((SECONDS - start)) -ge 120 ]; then
            echo "[ERROR] Failed to deploy $release (attempt $attempt/5)." >&2
            return 1
        fi
        echo "Deploying $release failed after $((SECONDS - start))s (attempt $attempt/5), retrying in 15 seconds..."
        sleep 15
    done
}

echo "--- Starting Cluster Components & Applications Installation ---"

# Global & Terraform Information (one terraform call; environment variables still override)
TF_OUTPUTS="$(terraform -chdir="$TF_DIR" output -json)"
tf_output() {
    jq -r --arg name "$1" '.[$name].value // error("Terraform output \($name) not found")' <<<"$TF_OUTPUTS"
}
PROJECT_ID="${PROJECT_ID:-$(tf_output project_id)}"
REGION="${REGION:-$(tf_output region)}"
UNIVERSE_API_DOMAIN="${UNIVERSE_API_DOMAIN:-$(tf_output universe_api_domain)}"
CLUSTER_NAME="${CLUSTER_NAME:-$(tf_output cluster)}"
STORAGE_BUCKET="${STORAGE_BUCKET:-$(tf_output storage_bucket)}"
MIMIR_STORAGE_BUCKET="${MIMIR_STORAGE_BUCKET:-$(tf_output mimir_storage_bucket)}"
LOKI_STORAGE_BUCKET="${LOKI_STORAGE_BUCKET:-$(tf_output loki_storage_bucket)}"
GRAFANA_SA="${GRAFANA_SA:-$(tf_output grafana_sa_email)}"
MIMIR_SA="${MIMIR_SA:-$(tf_output mimir_sa_email)}"
LOKI_SA="${LOKI_SA:-$(tf_output loki_sa_email)}"
OTEL_SA="${OTEL_SA:-$(tf_output otel_sa_email)}"
IMAGE_REGISTRY="${IMAGE_REGISTRY:-$(tf_output artifact_registry_uri)}"
K8sNAMESPACE="${K8sNAMESPACE:-$(tf_output k8s_namespace)}"
GCE_VM_NAME="${GCE_VM_NAME:-$(tf_output gce_logging_vm_name)}"
GCE_VM_ZONE="${GCE_VM_ZONE:-$(tf_output gce_zone)}"
MIMIR_GATEWAY_IP="${MIMIR_GATEWAY_IP:-$(tf_output mimir_gateway_ip)}"
LOKI_GATEWAY_IP="${LOKI_GATEWAY_IP:-$(tf_output loki_gateway_ip)}"
GRAFANA_GATEWAY_IP="${GRAFANA_GATEWAY_IP:-$(tf_output grafana_gateway_ip)}"
GRAFANA_GATEWAY_IP_NAME="${GRAFANA_GATEWAY_IP_NAME:-$(tf_output grafana_gateway_ip_name)}"

# Helm & Applications Constants
CERT_MANAGER_DIR="$K8s_DIR/cert-manager-wrapper"
GRAFANA_DIR="$K8s_DIR/grafana-wrapper"
MIMIR_DIR="$K8s_DIR/mimir-wrapper"
LOKI_DIR="$K8s_DIR/loki-wrapper"
OTEL_DIR="$K8s_DIR/opentelemetry-wrapper"
FLUENT_BIT_DIR="$K8s_DIR/fluent-bit-wrapper"
KUBE_STATE_DIR="$K8s_DIR/kube-state-metrics-wrapper"
APPS_DIR="$K8s_DIR/apps"

BEACON_IMAGE="${IMAGE_REGISTRY}/beacon-app:latest"
SENSOR_IMAGE="${IMAGE_REGISTRY}/sensor-app:latest"

# Generated files are real files (not <(...)), so helm_deploy retries can read them again.
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Checking Grafana settings in defaults.yaml..."
python3 "$DEMO_DIR/scripts/helpers/grafana_values.py" "$DEFAULTS_FILE" >"$WORK_DIR/grafana-values.json"
sed "s/user-monitoring-ns/$K8sNAMESPACE/g" "$GRAFANA_DIR/dashboards/logs-gke.json" >"$WORK_DIR/logs-gke.json"

echo "Getting cluster credentials..."
gcloud container clusters get-credentials "$CLUSTER_NAME" --dns-endpoint --region "$REGION" --project "$PROJECT_ID"

# Note: keep It. Should be added or it will fail on first run
# --force-update refreshes each repo index once, so the builds below can use --skip-refresh.
echo "Adding Helm repositories and building chart dependencies..."
helm repo add --force-update jetstack https://charts.jetstack.io
helm repo add --force-update grafana-community https://grafana-community.github.io/helm-charts
helm repo add --force-update grafana https://grafana.github.io/helm-charts
helm repo add --force-update open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add --force-update prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add --force-update fluent https://fluent.github.io/helm-charts

for chart in "$K8s_DIR"/*/; do
    if [ -f "$chart/Chart.lock" ]; then
        helm dependency build --skip-refresh "$chart"
    fi
done

# The ServiceMonitor CRD comes with opentelemetry-wrapper, so cert-manager starts without its ServiceMonitor.
helm_deploy cert-manager "$CERT_MANAGER_DIR" --namespace cert-manager \
  --set cert-manager.prometheus.servicemonitor.enabled=false

helm_deploy pki "$PKI_DIR" --namespace cert-manager

echo "Waiting for Root CA certificate..."
wait_for_certificate_ready sovereign-root-ca cert-manager 120

# OpenTelemetry phase 1: operator and Prometheus Operator CRDs only (collector and operator ServiceMonitor disabled).
helm_deploy opentelemetry-stack "$OTEL_DIR" \
  --set collector.enabled=false \
  --set opentelemetry-operator.manager.serviceMonitor.enabled=false

# The ServiceMonitor CRD now exists: enable the cert-manager ServiceMonitor.
# Pass it explicitly: an upgrade without any values reuses the previous release's values (enabled=false).
echo "Enabling cert-manager ServiceMonitor..."
helm_deploy cert-manager "$CERT_MANAGER_DIR" --namespace cert-manager \
  --set cert-manager.prometheus.servicemonitor.enabled=true

# fluent-bit needs to be at the top or else it will time out if deployed later.
helm_deploy fluent-bit "$FLUENT_BIT_DIR"

# OpenTelemetry phase 2: enable the collector (chart default) and the operator ServiceMonitor.
helm_deploy opentelemetry-stack "$OTEL_DIR" \
  --set opentelemetry-operator.manager.serviceMonitor.enabled=true \
  --set "serviceAccount.annotations.iam\.gke\.io/gcp-service-account=$OTEL_SA"

if [ -n "$GCE_VM_NAME" ]; then
  echo "Managing certificates for the VM"
  echo "Waiting for OpenTelemetry Certificate..."
  wait_for_certificate_ready otel-collector-vm-tls "$K8sNAMESPACE" 120

  # Extract, decode and upload the CA certificate, TLS certificate and TLS private key
  echo "Uploading OTel Collector VM certificates to gs://${STORAGE_BUCKET}/vm-certs/..."
  VM_TLS_SECRET="$(kubectl get secret otel-collector-vm-tls-secret -n "$K8sNAMESPACE" -o json)"
  for key in ca.crt tls.crt tls.key; do
    jq -j --arg key "$key" '.data[$key] | @base64d' <<<"$VM_TLS_SECRET" |
      gcloud storage cp - "gs://${STORAGE_BUCKET}/vm-certs/${key}"
  done

  echo "Uploading Fluent Bit package to gs://${STORAGE_BUCKET}/software/vm-fluentbit/..."
  gcloud storage cp "$VM_DIR/fluent-bit.deb" "$VM_DIR/fluent-bit.deb.sha256" "gs://${STORAGE_BUCKET}/software/vm-fluentbit/"

  echo "Uploading Requirements.txt to gs://${STORAGE_BUCKET}/software/vm-libraries/..."
  gcloud storage cp "$VM_DIR/requirements.txt" "gs://${STORAGE_BUCKET}/software/vm-libraries/"

  echo "Reseting $GCE_VM_NAME"
  gcloud compute instances reset "$GCE_VM_NAME" --zone="$GCE_VM_ZONE"
fi

GATEWAY_URL="https://${GRAFANA_GATEWAY_IP}"

helm_deploy grafana "$GRAFANA_DIR" \
    --values "$GRAFANA_DIR/dashboards.yaml" \
    --values "$GRAFANA_DIR/alerts.yaml" \
    --values "$WORK_DIR/grafana-values.json" \
    --set-file "grafana.dashboards.default.beacon-demo-app.json=$GRAFANA_DIR/dashboards/beacon-demo-app.json" \
    --set-file "grafana.dashboards.default.vm.json=$GRAFANA_DIR/dashboards/vm.json" \
    --set-file "grafana.dashboards.default.logs-gke.json=$WORK_DIR/logs-gke.json" \
    --set "grafana.serviceAccount.annotations.iam\.gke\.io/gcp-service-account=$GRAFANA_SA" \
    --set "grafana.env.GCP_PROJECT_ID=$PROJECT_ID" \
    --set "grafana.env.GOOGLE_CLOUD_UNIVERSE_DOMAIN=$UNIVERSE_API_DOMAIN" \
    --set "grafana.env.GF_SERVER_ROOT_URL=$GATEWAY_URL" \
    --set "gateway.addressName=$GRAFANA_GATEWAY_IP_NAME"

echo "Waiting for the Grafana Gateway to use the reserved IP $GRAFANA_GATEWAY_IP..."
kubectl wait --for=jsonpath='{.status.addresses[0].value}'="$GRAFANA_GATEWAY_IP" gateway/grafana-gateway -n "$K8sNAMESPACE" --timeout=300s

helm_deploy mimir "$MIMIR_DIR" \
  --values "$MIMIR_DIR/tls-values.yaml" \
  --set "mimirDistributed.serviceAccount.annotations.iam\.gke\.io/gcp-service-account=$MIMIR_SA" \
  --set "mimirDistributed.global.extraEnv[0].name=GOOGLE_CLOUD_UNIVERSE_DOMAIN" \
  --set "mimirDistributed.global.extraEnv[0].value=$UNIVERSE_API_DOMAIN" \
  --set "mimirDistributed.mimir.structuredConfig.common.storage.gcs.bucket_name=$MIMIR_STORAGE_BUCKET" \
  --set "mimirDistributed.gateway.service.loadBalancerIP=$MIMIR_GATEWAY_IP"

helm_deploy loki "$LOKI_DIR" \
  --values "$LOKI_DIR/tls-values.yaml" \
  --set "loki.serviceAccount.annotations.iam\.gke\.io/gcp-service-account=$LOKI_SA" \
  --set "loki.global.extraEnv[0].name=GOOGLE_CLOUD_UNIVERSE_DOMAIN" \
  --set "loki.global.extraEnv[0].value=$UNIVERSE_API_DOMAIN" \
  --set "loki.loki.storage.bucketNames.chunks=$LOKI_STORAGE_BUCKET" \
  --set "loki.loki.storage.bucketNames.ruler=$LOKI_STORAGE_BUCKET" \
  --set "loki.gateway.service.loadBalancerIP=$LOKI_GATEWAY_IP"

helm_deploy kube-state-metrics "$KUBE_STATE_DIR"

echo "--- Starting Demo Applications Installation ---"

helm_deploy monitoring-beacon "$APPS_DIR/beacon" \
  --set beacon.image="$BEACON_IMAGE"

helm_deploy monitoring-sensor "$APPS_DIR/sensor" \
  --set sensor.image="$SENSOR_IMAGE"

echo ""
echo "--- Starting Verification---"

echo "Verifying all Certificates in $K8sNAMESPACE are Ready..."
kubectl wait --for=condition=Ready certificate --all -n "$K8sNAMESPACE" --timeout=120s

echo ""
echo "--- Installation Summary ---"
echo "Installed Helm charts:"
helm list -A
echo ""
echo "All pods in $K8sNAMESPACE:"
kubectl get pods -n "$K8sNAMESPACE"
echo ""
echo "Grafana URL: $GATEWAY_URL"

if [ -n "$GCE_VM_NAME" ]; then
  echo "GCE VM Name: $GCE_VM_NAME"
fi

echo ""
echo "--- Cluster Components & Applications Installation Complete ---"
