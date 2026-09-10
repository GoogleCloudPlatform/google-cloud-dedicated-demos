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

TF_K8sNAMESPACE=""
if terraform -chdir="$TF_DIR" output k8s_namespace >/dev/null 2>&1; then
    TF_K8sNAMESPACE=$(terraform -chdir="$TF_DIR" output -raw k8s_namespace)
fi
K8sNAMESPACE="${K8sNAMESPACE:-${TF_K8sNAMESPACE:-monitor-ns}}"

echo "--- Destroying Terraform Infrastructure ---"

if [ -d "$TF_DIR" ]; then
    echo "Running terraform destroy..."
    cd "$TF_DIR"
    terraform destroy -auto-approve
fi

echo ""
echo "Cleaning leftovers..."
echo "  - Finding orphan disks..."
DISKs=$(gcloud compute disks list --filter="description:${K8sNAMESPACE}" --format="value(name, zone.basename())" 2>/dev/null)
if [[ -n "$DISKs" ]]; then
    while read -r name zone; do
        echo gcloud compute disks delete "$name" --zone="$zone"
        gcloud_delete_with_retry gcloud compute disks delete "$name" --zone="$zone" --quiet
    done <<< "$DISKs"
else
    echo "  - No orphan disks found."
fi

echo "--- Terraform Infrastructure Destroy Complete ---"
