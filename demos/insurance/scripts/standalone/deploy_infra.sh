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

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="$BASE_DIR/terraform"

echo "Deploying Terraform infrastructure..."
cd "$TF_DIR"

terraform init -input=false
terraform apply -auto-approve -input=false

export GCP_PROJECT_ID=$(terraform output -raw project_id)
export GCP_REGION=$(terraform output -raw region)
export GKE_CLUSTER_NAME=$(terraform output -raw gke_cluster_name)
export AR_REPO_NAME=$(terraform output -raw artifact_repository_id)
export GCS_BUCKET_NAME=$(terraform output -raw claims_document_bucket)
export UNIVERSE_DOMAIN=$(terraform output -raw universe_api_domain)

cd - >/dev/null
echo "✅ Infrastructure deployment successful."
