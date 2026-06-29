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

GCP_PROJECT_ID="${GCP_PROJECT_ID:-$(terraform -chdir="$TF_DIR" output -raw project_id)}"
REGISTRY_HOST="${REGISTRY_HOST:-$(terraform -chdir="$TF_DIR" output -raw docker_registry_host)}"
DOCKER_REPO="${DOCKER_REPO:-$(terraform -chdir="$TF_DIR" output -raw docker_repo_prefix)}"

echo "Mirroring required base container images to internal TPC registry..."
# docker info >/dev/null
gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin "$REGISTRY_HOST"

PROXY_DOCKER_IMAGE="$DOCKER_REPO/cloud-sql-proxy:2.15"
PG_DOCKER_IMAGE="$DOCKER_REPO/postgres:15"
GCLOUD_DOCKER_IMAGE="$DOCKER_REPO/google-cloud-cli:slim"
APP_DOCKER_IMAGE="$DOCKER_REPO/insurance-demo-showroom-app:latest"

docker pull gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.15
docker tag gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.15 "$PROXY_DOCKER_IMAGE"
docker push "$PROXY_DOCKER_IMAGE"

docker pull postgres:15
docker tag postgres:15 "$PG_DOCKER_IMAGE"
docker push "$PG_DOCKER_IMAGE"

docker pull gcr.io/google.com/cloudsdktool/google-cloud-cli:slim
docker tag gcr.io/google.com/cloudsdktool/google-cloud-cli:slim "$GCLOUD_DOCKER_IMAGE"
docker push "$GCLOUD_DOCKER_IMAGE"

echo "Building and pushing Insurance web showroom image..."
docker build -t insurance-demo-showroom-app:latest "$BASE_DIR/app"
docker tag insurance-demo-showroom-app:latest "$APP_DOCKER_IMAGE"
docker push "$APP_DOCKER_IMAGE"
echo "✅ Base images mirrored and application image successfully pushed."
