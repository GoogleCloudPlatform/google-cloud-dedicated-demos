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

KUSTOMIZE_BASE="../k8s/tax-office-base"
COMPUTECLASS_FILE="../k8s/tax-office-base/vllm/computeclass.yaml"

# Ensure GKE cluster details are available
if [ -z "$GKE_CLUSTER_NAME" ] || [ -z "$GKE_REGION" ] || [ -z "$GCP_PROJECT_ID" ]; then
    echo "Error: GKE_CLUSTER_NAME, GKE_REGION, or GCP_PROJECT_ID are missing."
    echo "Did deploy_infra.sh run successfully and export variables?"
    exit 1
fi

echo "=========================================="
echo "1. Configuring kubectl for GKE cluster: ${GKE_CLUSTER_NAME}"
echo "=========================================="
if ! gcloud container clusters get-credentials "${GKE_CLUSTER_NAME}" --dns-endpoint --region "${GKE_REGION}" --project "${GCP_PROJECT_ID}"; then
    echo "Error: Failed to get GKE cluster credentials."
    exit 1
fi
echo "kubectl configured successfully."

echo "=========================================="
echo "2. Applying Kubernetes manifests using Kustomize"
echo "=========================================="

echo "Applying ComputeClass manifest from: ${COMPUTECLASS_FILE}..."
if ! kubectl apply -f "$COMPUTECLASS_FILE"; then
    echo "Error: Failed to apply ComputeClass manifest at ${COMPUTECLASS_FILE}."
    exit 1
fi
echo "✅ ComputeClass applied successfully."

if [ -d "$KUSTOMIZE_BASE" ]; then
    echo "Applying Kustomize base from: ${KUSTOMIZE_BASE}..."
    if ! kubectl apply -k "$KUSTOMIZE_BASE"; then
        echo "Error: Failed to apply Kustomize base at ${KUSTOMIZE_BASE}."
        exit 1
    fi
    echo "✅ All resources defined in kustomization.yaml applied successfully."
else
    echo "Error: Kustomize base directory ${KUSTOMIZE_BASE} not found."
    echo "Please ensure the directory structure includes a 'tax-office-base' directory."
    exit 1
fi

echo "=========================================="
echo "GKE application deployment initiated."
echo "Waiting for LoadBalancer IP address..."
echo "=========================================="

# Wait for LoadBalancer IP address (check up to 5 minutes)
APP_EXTERNAL_IP=""
JUPYTER_EXTERNAL_IP=""

for i in {1..30}; do
    # Use -n tax-office-ns to ensure we look in the correct namespace
    APP_EXTERNAL_IP=$(kubectl get service tax-office-app-service -n tax-office-ns -o=jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    JUPYTER_EXTERNAL_IP=$(kubectl get service jupyter-notebook-service -n tax-office-ns -o=jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

    if [ -n "${APP_EXTERNAL_IP}" ] && [ -n "${JUPYTER_EXTERNAL_IP}" ]; then
        echo "✅ External IPs assigned after $((i * 10)) seconds!"
        break
    fi
    echo "Still waiting for LoadBalancer IPs... (Check ${i}/30)"
    sleep 10
done

if [ -z "${APP_EXTERNAL_IP}" ] || [ -z "${JUPYTER_EXTERNAL_IP}" ]; then
    echo "Timed out waiting for LoadBalancer IPs. Check your GKE services."
    exit 1
fi

echo "=========================================="
echo "Deployment Endpoints"
echo "=========================================="
echo "Tax Office Dashboard: http://${APP_EXTERNAL_IP}"
echo "Jupyter Notebook:    http://${JUPYTER_EXTERNAL_IP}"
echo "Dashboard Login: demo / demobq"
