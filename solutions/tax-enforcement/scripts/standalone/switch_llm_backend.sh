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
# Usage:
#   ./scripts/standalone/switch_llm_backend.sh <both|gemini|vertex|gke> [--teardown-other]
#
# Examples:
#   # Run both Gemini Platform and GKE vLLM simultaneously (default mode):
#   ./scripts/standalone/switch_llm_backend.sh both
#
#   # Switch active backend to GKE vLLM (keeping Gemini Platform alive):
#   ./scripts/standalone/switch_llm_backend.sh gke
#
#   # Switch to GKE vLLM and tear down Gemini Platform endpoint first (to free GPU quota):
#   ./scripts/standalone/switch_llm_backend.sh gke --teardown-other
#
#   # Switch to Gemini Platform and tear down GKE vLLM pod:
#   ./scripts/standalone/switch_llm_backend.sh gemini --teardown-other

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
    cat <<EOF
Usage: $(basename "$0") <both|gemini|vertex|gke> [--teardown-other]

Target Modes:
  both              Ensure both Gemini Platform and GKE vLLM are deployed for instant UI switching (default).
  gemini | vertex   Use Gemini Platform (Model Garden) as active LLM backend.
  gke               Deploy and use GKE vLLM pod (google/gemma-3-27b-it) as active LLM backend.

Options:
  --teardown-other  Deprovision the other LLM backend first to free regional GPU/H100 quota.
  -h, --help        Show this help message.
EOF
}

TARGET_MODE="${1:-}"
TEARDOWN_OTHER="false"

if [[ -z "$TARGET_MODE" || "$TARGET_MODE" == "-h" || "$TARGET_MODE" == "--help" ]]; then
    usage
    exit 0
fi

shift || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --teardown-other|--save-quota)
            TEARDOWN_OTHER="true"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option '$1'"
            usage
            exit 1
            ;;
    esac
    shift
done

if [[ "$TARGET_MODE" == "gemini" || "$TARGET_MODE" == "gemini-platform" ]]; then
    TARGET_MODE="vertex"
fi

if [[ "$TARGET_MODE" != "vertex" && "$TARGET_MODE" != "gke" && "$TARGET_MODE" != "both" ]]; then
    echo "ERROR: Invalid mode '$TARGET_MODE'. Must be 'both', 'gemini' ('vertex'), or 'gke'."
    usage
    exit 1
fi

echo "================================================================================"
echo ">>> Switching LLM Backend to: $TARGET_MODE (teardown-other=$TEARDOWN_OTHER)"
echo "================================================================================"

if [[ "$TARGET_MODE" == "gke" ]]; then
    if [[ "$TEARDOWN_OTHER" == "true" ]]; then
        echo ">>> Teardown requested: Removing Gemini Platform (Model Garden) endpoint to free GPU quota..."
        "$SCRIPT_DIR/destroy_vertex_model.sh"
    fi
    echo ">>> Deploying GKE vLLM pod and switching Tax Office App default backend to 'gke'..."
    LLM_BACKEND="gke" VLLM_ENABLED="true" "$SCRIPT_DIR/deploy_app_gke.sh"

elif [[ "$TARGET_MODE" == "vertex" ]]; then
    KEEP_VLLM="false"
    if [[ "$TEARDOWN_OTHER" == "true" ]]; then
        echo ">>> Teardown requested: Removing GKE vLLM deployment to free GPU quota..."
        kubectl delete deployment vllm-gemma-deployment -n tax-office-ns --ignore-not-found=true 2>/dev/null || true
        KEEP_VLLM="false"
    else
        # Keep GKE vLLM pod running if it was already deployed so UI hot-swap remains instant
        if kubectl get deployment vllm-gemma-deployment -n tax-office-ns >/dev/null 2>&1; then
            echo ">>> Preserving existing GKE vLLM deployment (pass --teardown-other to remove it)."
            KEEP_VLLM="true"
        fi
    fi

    echo ">>> Ensuring Gemini Platform (Model Garden) endpoint is deployed..."
    "$SCRIPT_DIR/deploy_vertex_model.sh"

    echo ">>> Updating Tax Office App on GKE with default backend 'vertex' (Gemini Platform)..."
    LLM_BACKEND="vertex" VLLM_ENABLED="$KEEP_VLLM" "$SCRIPT_DIR/deploy_app_gke.sh"

elif [[ "$TARGET_MODE" == "both" ]]; then
    echo ">>> [1/2] Ensuring Gemini Platform (Model Garden) endpoint is deployed..."
    "$SCRIPT_DIR/deploy_vertex_model.sh"

    echo ">>> [2/2] Deploying GKE vLLM pod alongside Gemini Platform (hot-swap ready in Web UI)..."
    LLM_BACKEND="both" VLLM_ENABLED="true" "$SCRIPT_DIR/deploy_app_gke.sh"
fi

echo ""
echo "================================================================================"
echo ">>> LLM Backend switch to '$TARGET_MODE' complete!"
echo ">>> You can also toggle between 'Gemini Platform' and 'GKE (vLLM)' live in the Web Chat UI."
echo "================================================================================"
