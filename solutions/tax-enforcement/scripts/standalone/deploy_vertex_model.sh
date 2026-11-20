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
VERTEX_REGION="${VERTEX_REGION:-${REGION:-$(terraform -chdir="$TF_DIR" output -raw region)}}"
UNIVERSE_DOMAIN="${UNIVERSE_DOMAIN:-${GOOGLE_CLOUD_UNIVERSE_DOMAIN:-$(terraform -chdir="$TF_DIR" output -raw universe_api_domain)}}"

MODEL_ID="${VERTEX_MODEL_ID:-publishers/mistralai/models/mistral-medium-3.5-128b@v1}"
MACHINE_TYPE="${VERTEX_MACHINE_TYPE:-a3-highgpu-2g-nolssd}"
ACCELERATOR_TYPE="${VERTEX_ACCELERATOR_TYPE:-NVIDIA_H100_80GB}"
ACCELERATOR_COUNT="${VERTEX_ACCELERATOR_COUNT:-2}"
ENDPOINT_DISPLAY_NAME="${VERTEX_ENDPOINT_DISPLAY_NAME:-mistral-medium-endpoint}"

echo "Checking for existing Gemini Platform endpoint '$ENDPOINT_DISPLAY_NAME' in '$VERTEX_REGION'..."
EXISTING_ENDPOINT_IDS=$(gcloud ai endpoints list \
    --region="$VERTEX_REGION" \
    --project="$GCP_PROJECT_ID" \
    --filter="displayName:${ENDPOINT_DISPLAY_NAME} OR displayName~^mistral" \
    --format="value(name.basename())" 2>/dev/null || true)

for ep_id in $EXISTING_ENDPOINT_IDS; do
    [[ -z "$ep_id" ]] && continue
    DEPLOYED=$(gcloud ai endpoints describe "$ep_id" \
        --region="$VERTEX_REGION" \
        --project="$GCP_PROJECT_ID" \
        --format="value(deployedModels[].id)" 2>/dev/null || true)
    if [[ -n "$DEPLOYED" ]]; then
        echo "Reusing existing active endpoint '$ENDPOINT_DISPLAY_NAME' ($ep_id)."
        echo "$ep_id" > "$BASE_DIR/.vertex_endpoint_id"
        exit 0
    fi
done

AIPLATFORM_HOST="${VERTEX_REGION}-aiplatform.${UNIVERSE_DOMAIN:-googleapis.com}"
MODEL_SUFFIX=$(date +%s | tail -c 7)
CUSTOM_MODEL_NAME="${VERTEX_MODEL_DISPLAY_NAME:-mistral-${MODEL_SUFFIX}}"

PAYLOAD=$(cat <<EOF
{
  "publisherModelName": "${MODEL_ID}",
  "modelConfig": {
    "acceptEula": true,
    "modelDisplayName": "${CUSTOM_MODEL_NAME}",
    "modelUserId": "${CUSTOM_MODEL_NAME}"
  },
  "endpointConfig": {
    "endpointDisplayName": "${ENDPOINT_DISPLAY_NAME}",
    "dedicatedEndpointDisabled": true
  },
  "deployConfig": {
    "dedicatedResources": {
      "machineSpec": {
        "machineType": "${MACHINE_TYPE}",
        "acceleratorType": "${ACCELERATOR_TYPE}",
        "acceleratorCount": ${ACCELERATOR_COUNT}
      },
      "minReplicaCount": 1,
      "maxReplicaCount": 1
    }
  }
}
EOF
)

echo "Deploying '${MODEL_ID}' on '${MACHINE_TYPE}' via Gemini Platform Model Garden..."
TOKEN=$(gcloud auth print-access-token)
RESP=$(curl -s -X POST \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "X-Goog-User-Project: ${GCP_PROJECT_ID}" \
    -H "Content-Type: application/json" \
    "https://${AIPLATFORM_HOST}/v1beta1/projects/${GCP_PROJECT_ID}/locations/${VERTEX_REGION}:deploy" \
    -d "$PAYLOAD")

OP_NAME=$(python3 -c 'import sys, json; print(json.loads(sys.stdin.read() or "{}").get("name", ""))' <<< "$RESP")
if [[ -z "$OP_NAME" ]]; then
    echo "ERROR: Failed to start Model Garden deploy operation: $RESP"
    exit 1
fi

echo "Deploy operation started: $OP_NAME"
ELAPSED=0
while [[ $ELAPSED -lt 1800 ]]; do
    sleep 15
    ELAPSED=$((ELAPSED + 15))
    TOKEN=$(gcloud auth print-access-token)
    OP_STATUS=$(curl -s \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "X-Goog-User-Project: ${GCP_PROJECT_ID}" \
        "https://${AIPLATFORM_HOST}/v1beta1/${OP_NAME}")

    STATE=$(python3 -c '
import sys, json
d = json.loads(sys.stdin.read() or "{}")
if not d.get("done"):
    print("RUNNING")
elif "error" in d:
    print("ERROR|" + d["error"].get("message", "Unknown error"))
else:
    print("DONE|" + d.get("response", {}).get("endpoint", ""))
' <<< "$OP_STATUS")

    if [[ "$STATE" == "RUNNING" ]]; then
        echo "  [${ELAPSED}s] Deployment in progress..."
    elif [[ "$STATE" == DONE\|* ]]; then
        ENDPOINT_ID=$(basename "${STATE#DONE|}")
        echo "$ENDPOINT_ID" > "$BASE_DIR/.vertex_endpoint_id"
        echo "Gemini Platform endpoint deployed: $ENDPOINT_ID"
        exit 0
    else
        echo "ERROR: Deployment failed: ${STATE#ERROR|}"
        exit 1
    fi
done

echo "ERROR: Timed out waiting for operation $OP_NAME"
exit 1
