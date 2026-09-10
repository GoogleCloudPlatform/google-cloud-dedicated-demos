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

echo "--- Starting Application Container Images Build & Push ---"

IMAGE_REGISTRY="${IMAGE_REGISTRY:-$(terraform -chdir="$TF_DIR" output -raw artifact_registry_uri)}"
REGISTRY_HOST="${IMAGE_REGISTRY%%/*}"
APPS_SENSOR_PORT="${APPS_SENSOR_PORT:-8000}"
TAG="${TAG:-latest}"

echo "Authenticating Docker to $REGISTRY_HOST..."
docker info >/dev/null 2>&1
gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin "$REGISTRY_HOST" >/dev/null 2>&1

echo "Building and pushing Beacon image..."
BEACON_LOCAL="beacon-app:$TAG"
BEACON_REMOTE="${IMAGE_REGISTRY}/beacon-app:${TAG}"
docker build -t "$BEACON_LOCAL" "$DEMO_DIR/apps/beacon"
docker tag "$BEACON_LOCAL" "$BEACON_REMOTE"
docker push "$BEACON_REMOTE"

echo "Building and pushing Sensor image..."
SENSOR_LOCAL="sensor-app:$TAG"
SENSOR_REMOTE="${IMAGE_REGISTRY}/sensor-app:${TAG}"
docker build --build-arg PORT="$APPS_SENSOR_PORT" -t "$SENSOR_LOCAL" "$DEMO_DIR/apps/sensor"
docker tag "$SENSOR_LOCAL" "$SENSOR_REMOTE"
docker push "$SENSOR_REMOTE"

echo "--- Application Container Images Build & Push Complete ---"
