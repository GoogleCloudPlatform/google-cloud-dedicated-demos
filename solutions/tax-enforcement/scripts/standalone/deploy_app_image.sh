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
AR_REPO_NAME="${AR_REPO_NAME:-$(terraform -chdir="$TF_DIR" output -raw app_repository_id)}"
UNIVERSE_DOMAIN="${UNIVERSE_DOMAIN:-$(terraform -chdir="$TF_DIR" output -raw universe_api_domain)}"

# Derive registry host: replace 'apis-' with 'pkg-' in the universe domain if it exists
# Example: apis-berlin-build0.goog -> docker.pkg-berlin-build0.goog
REGISTRY_DOMAIN="${UNIVERSE_DOMAIN/apis-/pkg-}"
REGISTRY_HOST="${REGISTRY_HOST:-docker.$REGISTRY_DOMAIN}"
IMAGE_NAME="tax-office-app"
TAG="latest"

PROJECT_PATH="${GCP_PROJECT_ID/://}"
REMOTE_IMAGE="${REGISTRY_HOST}/${PROJECT_PATH}/${AR_REPO_NAME}/${IMAGE_NAME}:${TAG}"

echo "Building and pushing Docker image to: $REMOTE_IMAGE..."
docker info >/dev/null 2>&1
gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin "$REGISTRY_HOST" >/dev/null 2>&1

docker build -t "$IMAGE_NAME:$TAG" "$BASE_DIR/app"
docker tag "$IMAGE_NAME:$TAG" "$REMOTE_IMAGE"
docker push "$REMOTE_IMAGE"
