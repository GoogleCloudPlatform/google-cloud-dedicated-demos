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

gcloud_delete_with_retry() {
    local max_retries=6
    local delay=10

    local count=1
    while [ "$count" -le "$max_retries" ]; do
        if "$@"; then
            return 0
        fi
        echo "    - [Attempt $count/$max_retries] Command failed. Retrying in ${delay}s..." >&2
        sleep "$delay"
        count=$((count + 1))
    done
    echo "    - [WARNING] Resource removal did not complete cleanly or resource did not exist." >&2
    return 0
}

delete_k8s_resources_with_retry() {
    local max_retries=5
    local delay=10

    local count=1
    while [ "$count" -le "$max_retries" ]; do
        echo "  - [Attempt $count/$max_retries] Executing: $*"
        if "$@"; then
            return 0
        fi
        echo "  - Warning: Command failed. Retrying in ${delay}s..."
        sleep "$delay"
        count=$((count + 1))
    done
    echo "  - [WARNING] Kubernetes resource removal timed out or resource did not exist." >&2
    return 0
}

# 1. Set your fixed defaults first
K8sNAMESPACE="monitor-ns"
VPCNetwork="monitoring-vpc"

# 2. Attempt to read from Terraform. If it succeeds AND is not empty, override the default.
if TF_OUT=$(terraform -chdir="$TF_DIR" output -raw k8s_namespace 2>/dev/null) && [[ -n "$TF_OUT" ]]; then
    K8sNAMESPACE="$TF_OUT"
fi

if TF_OUT=$(terraform -chdir="$TF_DIR" output -raw vpc 2>/dev/null) && [[ -n "$TF_OUT" ]]; then
    VPCNetwork="$TF_OUT"
fi

echo "--- Starting GKE & Kubernetes Workloads Uninstallation ---"

echo "1. Cleaning Gateway Resources..."
echo "  - Deleting Gateway and HTTPRoutes from cluster..."
delete_k8s_resources_with_retry kubectl delete gateway grafana-gateway -n "$K8sNAMESPACE" --ignore-not-found --wait
delete_k8s_resources_with_retry kubectl delete httproute -n "$K8sNAMESPACE" -l "app.kubernetes.io/name=grafana" --ignore-not-found
delete_k8s_resources_with_retry kubectl delete httproute grafana-route grafana-http-redirect -n "$K8sNAMESPACE" --ignore-not-found

echo "  - Finding NEGs..."
NEGS=$(gcloud compute network-endpoint-groups list --filter="name ~ '.*$K8sNAMESPACE-grafana.*'" --format="value(name, zone.basename())" 2>/dev/null)
if [[ -n "$NEGS" ]]; then
    while read -r name zone; do
        echo gcloud compute network-endpoint-groups delete "$name" --zone="$zone"
        gcloud_delete_with_retry gcloud compute network-endpoint-groups delete "$name" --zone="$zone" --quiet
    done <<< "$NEGS"
else
    echo "  - No NEGs found."
fi

echo "  - Finding Routes..."
ROUTES=$(gcloud compute routes list --filter="nextHopGateway = 'default-internet-gateway' AND network = '$VPCNetwork'" --format="value(name)" 2>/dev/null)
if [[ -n "$ROUTES" ]]; then
    while read -r name; do
        echo gcloud compute routes delete "$name"
        gcloud_delete_with_retry gcloud compute routes delete "$name" --quiet
    done <<< "$ROUTES"
else
    echo "  - No routes found."
fi

echo ""
echo "2. Uninstalling Apps deployments..."

echo "  - Uninstalling Beacon App..."
if helm status monitoring-beacon -n "$K8sNAMESPACE" >/dev/null 2>&1; then
    helm uninstall monitoring-beacon --namespace "$K8sNAMESPACE"
fi

echo "  - Uninstalling Sensor App..."
if helm status monitoring-sensor -n "$K8sNAMESPACE" >/dev/null 2>&1; then
    helm uninstall monitoring-sensor --namespace "$K8sNAMESPACE"
fi

echo ""
echo "3. Uninstalling Kubernetes Helm wrapper charts..."

echo "  - Uninstalling kube-state-metrics..."
if helm status kube-state-metrics -n "$K8sNAMESPACE" >/dev/null 2>&1; then
  helm uninstall kube-state-metrics --namespace "$K8sNAMESPACE"
fi

echo "  - Uninstalling fluent-bit..."
if helm status fluent-bit -n "$K8sNAMESPACE" >/dev/null 2>&1; then
  helm uninstall fluent-bit --namespace "$K8sNAMESPACE"
fi

echo "  - Uninstalling OpenTelemetry..."
if helm status opentelemetry-stack -n "$K8sNAMESPACE" >/dev/null 2>&1; then
  helm uninstall opentelemetry-stack --namespace "$K8sNAMESPACE"
fi

echo "  - Uninstalling mimir..."
if helm status mimir -n "$K8sNAMESPACE" >/dev/null 2>&1; then
  if ! helm uninstall mimir --namespace "$K8sNAMESPACE" --timeout 5m; then
      echo "Mimir uninstall timed out or failed. Retrying uninstall..."
      sleep 10
      helm uninstall mimir --namespace "$K8sNAMESPACE" --timeout 5m
  fi
fi

echo "  - Uninstalling loki..."
if helm status loki -n "$K8sNAMESPACE" >/dev/null 2>&1; then
  if ! helm uninstall loki --namespace "$K8sNAMESPACE" --timeout 5m; then
      echo "Loki uninstall timed out or failed. Retrying uninstall..."
      sleep 10
      helm uninstall loki --namespace "$K8sNAMESPACE" --timeout 5m
  fi
fi
echo "  - Uninstalling grafana..."
if helm status grafana -n "$K8sNAMESPACE" >/dev/null 2>&1; then
  helm uninstall grafana --namespace "$K8sNAMESPACE"
fi

echo ""
echo "4. Uninstalling PKI and cert-manager..."

echo "  - Uninstalling PKI ClusterIssuers..."
if helm status pki -n cert-manager >/dev/null 2>&1; then
  helm uninstall pki --namespace cert-manager --wait
fi

echo "  - Uninstalling cert-manager..."
if helm status cert-manager -n cert-manager >/dev/null 2>&1; then
  helm uninstall cert-manager --namespace cert-manager --wait
fi

if kubectl get namespace cert-manager >/dev/null 2>&1; then
  kubectl delete namespace cert-manager --wait --ignore-not-found
fi

echo ""
echo "--- GKE & Kubernetes Workloads Uninstallation Complete ---"
