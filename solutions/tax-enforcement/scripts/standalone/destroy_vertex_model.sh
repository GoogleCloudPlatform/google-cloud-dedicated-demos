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

GCP_PROJECT_ID="${GCP_PROJECT_ID:-$(terraform -chdir="$TF_DIR" output -raw project_id 2>/dev/null || gcloud config get-value core/project 2>/dev/null || true)}"
VERTEX_REGION="${VERTEX_REGION:-${REGION:-$(terraform -chdir="$TF_DIR" output -raw region 2>/dev/null || gcloud config get-value ai/region 2>/dev/null || gcloud config get-value compute/region 2>/dev/null || true)}}"

if [[ -z "$GCP_PROJECT_ID" || -z "$VERTEX_REGION" ]]; then
    rm -f "$BASE_DIR/.vertex_endpoint_id"
    exit 0
fi

ENDPOINT_IDS=$(gcloud ai endpoints list \
    --region="$VERTEX_REGION" \
    --project="$GCP_PROJECT_ID" \
    --filter="displayName:mistral-medium-endpoint OR displayName~^mistral" \
    --format="value(name.basename())" 2>/dev/null || true)

for ENDPOINT_ID in $ENDPOINT_IDS; do
    [[ -z "$ENDPOINT_ID" ]] && continue
    DEPLOYED_MODEL_IDS=$(gcloud ai endpoints describe "$ENDPOINT_ID" \
        --region="$VERTEX_REGION" \
        --project="$GCP_PROJECT_ID" \
        --format="value(deployedModels[].id)" 2>/dev/null || true)

    for DEPLOYED_MODEL_ID in $DEPLOYED_MODEL_IDS; do
        [[ -z "$DEPLOYED_MODEL_ID" ]] && continue
        echo "Undeploying model $DEPLOYED_MODEL_ID from endpoint $ENDPOINT_ID..."
        gcloud ai endpoints undeploy-model "$ENDPOINT_ID" \
            --region="$VERTEX_REGION" \
            --project="$GCP_PROJECT_ID" \
            --deployed-model-id="$DEPLOYED_MODEL_ID" \
            --quiet 2>/dev/null || true
    done

    echo "Deleting endpoint $ENDPOINT_ID..."
    gcloud ai endpoints delete "$ENDPOINT_ID" \
        --region="$VERTEX_REGION" \
        --project="$GCP_PROJECT_ID" \
        --quiet 2>/dev/null || true
done

MODEL_IDS=$(gcloud ai models list \
    --region="$VERTEX_REGION" \
    --project="$GCP_PROJECT_ID" \
    --format="value(name.basename())" 2>/dev/null || true)

for MODEL_ID in $MODEL_IDS; do
    [[ -z "$MODEL_ID" ]] && continue
    echo "Deleting Gemini Platform model $MODEL_ID..."
    gcloud ai models delete "$MODEL_ID" \
        --region="$VERTEX_REGION" \
        --project="$GCP_PROJECT_ID" \
        --quiet 2>/dev/null || true
done

rm -f "$BASE_DIR/.vertex_endpoint_id"
