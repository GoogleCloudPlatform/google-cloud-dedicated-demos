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
# uninstall.sh

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# Helper functions
gcloud_delete_with_retry() {
    local max_retries=6 # Defaults to 6 retries
    local delay=10 # Defaults to 10 seconds delay

    # $@ allows you to pass any gcloud command and its arguments
    local count=1
    while [ "$count" -le "$max_retries" ]; do
        if "$@"; then
            return 0
        fi
        echo "    - [Attempt $count/$max_retries] Command failed. Retrying in ${delay}s..." >&2
        sleep "$delay"
        count=$((count + 1))
    done
    echo "    - [ERROR] Command failed after $max_retries attempts: $@" >&2
    echo " Skipped. Please manually remove this item (or resources did not exist)."
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
    echo "  - [ERROR] Command failed after $max_retries attempts: $*" >&2
    echo " Skipped. Please manually remove these resources (or resources did not exist)."
    return 0
}

# Define working variables with robust script-relative paths
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEMO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TF_DIR="$DEMO_DIR/terraform"
TF_K8sNAMESPACE=$(terraform -chdir="$TF_DIR" output -raw k8s_namespace)
TF_VPC=$(terraform -chdir="$TF_DIR" output -raw vpc)
K8sNAMESPACE=${TF_K8sNAMESPACE:-"monitor-ns"}
VPCNetwork=${TF_VPC:-"monitoring-vpc"}

echo "--- Starting Infrastructure Uninstallation ---"

# Uninstall Gateway & networking resources
echo ""
echo "1. Cleaning Gateway Resources..."

# Delete Gateway resources so GKE Gateway controller detaches backend services and NEGs
echo "  - Deleting Gateway and HTTPRoutes from cluster..."
delete_k8s_resources_with_retry kubectl delete gateway grafana-gateway -n "$K8sNAMESPACE" --ignore-not-found --wait
delete_k8s_resources_with_retry kubectl delete httproute -n "$K8sNAMESPACE" -l "app.kubernetes.io/name=grafana" --ignore-not-found
delete_k8s_resources_with_retry kubectl delete httproute grafana-route grafana-http-redirect -n "$K8sNAMESPACE" --ignore-not-found

# gcloud delete network-endpoint-groups
echo "  - Finding NEGs..."
NEGS=$(gcloud compute network-endpoint-groups list --filter="name ~ '.*$K8sNAMESPACE-grafana.*'" --format="value(name, zone.basename())")
if [[ -n "$NEGS" ]]; then
    while read -r name zone; do
        echo gcloud compute network-endpoint-groups delete "$name" --zone="$zone"
        gcloud_delete_with_retry gcloud compute network-endpoint-groups delete "$name" --zone="$zone" --quiet
    done <<< "$NEGS"
else
    echo "  - No NEGs found."
fi

# gcloud delete routes
echo "  - Finding Routes..."
ROUTES=$(gcloud compute routes list --filter="nextHopGateway = 'default-internet-gateway' AND network = '$VPCNetwork'" --format="value(name)")
if [[ -n "$ROUTES" ]]; then
    while read -r name; do
        echo gcloud compute routes delete "$name"
        gcloud_delete_with_retry gcloud compute routes delete "$name" --quiet
    done <<< "$ROUTES"
else
    echo "  - No routes found."
fi

# Uninstall Kubernetes Apps deployments
echo ""
echo "2. Uninstalling Apps deployments..."

echo "  - Uninstalling Beacon App..."
if helm status monitoring-beacon -n "$K8sNAMESPACE" > /dev/null 2>&1; then
    helm uninstall monitoring-beacon --namespace "$K8sNAMESPACE"
fi

echo "  - Uninstalling Sensor App..."
if helm status monitoring-sensor -n "$K8sNAMESPACE" > /dev/null 2>&1; then
    helm uninstall monitoring-sensor --namespace "$K8sNAMESPACE"
fi

# Uninstall Kubernetes Helm deployments
echo ""
echo "3. Uninstalling Kubernetes Helm wrapper charts..."

# Helm uninstall for kube-state-metrics
echo "  - Uninstalling kube-state-metrics..."
if helm status kube-state-metrics -n "$K8sNAMESPACE" > /dev/null 2>&1; then
  helm uninstall kube-state-metrics --namespace "$K8sNAMESPACE"
fi

# Helm uninstall for opentelemetry
echo "  - Uninstalling opentelemetry..."
if helm status opentelemetry -n "$K8sNAMESPACE" > /dev/null 2>&1; then
  helm uninstall opentelemetry --namespace "$K8sNAMESPACE"
fi

# Helm uninstall for mimir
echo "  - Uninstalling mimir..."
if helm status mimir -n "$K8sNAMESPACE" > /dev/null 2>&1; then
  if ! helm uninstall mimir --namespace "$K8sNAMESPACE" --timeout 5m; then
      echo "Mimir uninstall timed out or failed. Retrying uninstall..."
      sleep 10
      helm uninstall mimir --namespace "$K8sNAMESPACE" --timeout 5m
  fi
fi

# Helm uninstall for grafana
echo "  - Uninstalling grafana..."
if helm status grafana -n "$K8sNAMESPACE" > /dev/null 2>&1; then
  helm uninstall grafana --namespace "$K8sNAMESPACE"
fi

# Uninstall PKI and cert-manager
echo ""
echo "4. Uninstalling PKI and cert-manager..."

echo "  - Uninstalling PKI ClusterIssuers..."
if helm status pki -n cert-manager > /dev/null 2>&1; then
  helm uninstall pki --namespace cert-manager --wait
fi

echo "  - Uninstalling cert-manager..."
if helm status cert-manager -n cert-manager > /dev/null 2>&1; then
  helm uninstall cert-manager --namespace cert-manager --wait
fi

if kubectl get namespace cert-manager >/dev/null 2>&1; then
  kubectl delete namespace cert-manager --wait --ignore-not-found
fi

# Destroy Terraform-managed infrastructure
echo ""
echo "5. Destroying Terraform infrastructure..."
cd "$TF_DIR" || exit

# Using -auto-approve to skip manual confirmation. Remove if you want to review the plan.
terraform destroy -auto-approve

# Remove any project leftover
echo ""
echo "6. Cleanup leftovers..."

# gcloud delete orphan disks
echo "  - Finding orphan disks..."
DISKs=$(gcloud compute disks list --filter="description:${K8sNAMESPACE}" --format="value(name, zone.basename())")
if [[ -n "$DISKs" ]]; then
    while read -r name zone; do
        echo gcloud compute disks delete "$name" --zone="$zone"
        gcloud_delete_with_retry gcloud compute disks delete "$name" --zone="$zone" --quiet
    done <<< "$DISKs"
else
    echo "  - No orphan disks found."
fi

echo ""
echo "--- Uninstallation Complete ---"
