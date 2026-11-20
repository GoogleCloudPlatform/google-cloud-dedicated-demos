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

# Derive registry host: replace 'apis-' with 'pkg-' or 'apis.' with 'registry.' in the universe domain
# Example: apis-berlin-build0.goog -> docker.pkg-berlin-build0.goog
REGISTRY_DOMAIN="${REGISTRY_DOMAIN:-${UNIVERSE_DOMAIN/apis-/pkg-}}"
REGISTRY_DOMAIN="${REGISTRY_DOMAIN/apis./registry.}"
REGISTRY_HOST="${REGISTRY_HOST:-docker.$REGISTRY_DOMAIN}"
IMAGE_NAME="tax-office-app"
TAG="latest"

PROJECT_PATH="${GCP_PROJECT_ID/://}"
REMOTE_IMAGE="${REGISTRY_HOST}/${PROJECT_PATH}/${AR_REPO_NAME}/${IMAGE_NAME}:${TAG}"

echo "Building and pushing Docker image to: $REMOTE_IMAGE..."
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin "$REGISTRY_HOST" >/dev/null 2>&1
    docker build --platform linux/amd64 -t "$IMAGE_NAME:$TAG" "$BASE_DIR/app"
    docker tag "$IMAGE_NAME:$TAG" "$REMOTE_IMAGE"
    docker push "$REMOTE_IMAGE"
else
    STAGE_DIR=$(mktemp -d)
    trap 'rm -rf "$STAGE_DIR" /tmp/app_layer.tar.gz' EXIT
    mkdir -p "$STAGE_DIR/usr/local/lib/python3.12/site-packages" "$STAGE_DIR/app" "$STAGE_DIR/tmp/fastembed_cache"
    pip3 install --platform manylinux_2_28_x86_64 --platform manylinux2014_x86_64 --implementation cp --python-version 3.12 --only-binary=:all: --target "$STAGE_DIR/usr/local/lib/python3.12/site-packages" --no-cache-dir flask werkzeug google-cloud-bigquery google-cloud-storage google-auth requests gunicorn fastembed numpy
    cp -r "$BASE_DIR/app/"* "$STAGE_DIR/app/"
    [[ -d /tmp/fastembed_cache ]] && cp -r /tmp/fastembed_cache/* "$STAGE_DIR/tmp/fastembed_cache/" || true
    tar -C "$STAGE_DIR" -czf /tmp/app_layer.tar.gz .
    gcloud auth print-access-token | crane auth login "$REGISTRY_HOST" -u oauth2accesstoken --password-stdin
    crane append --platform linux/amd64 -b "docker.io/library/python:3.12-slim" -f /tmp/app_layer.tar.gz -t "$REMOTE_IMAGE"
    crane mutate "$REMOTE_IMAGE" --workdir /app --env FLASK_APP=app.py --env FLASK_ENV=production --env PYTHONUNBUFFERED=1 --env FASTEMBED_CACHE_PATH=/tmp/fastembed_cache --cmd "python,app.py"
fi
