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

ARTIFACT_REGISTRY_HOST="docker.pkg-berlin-build0.goog"
LOCAL_IMAGE_NAME="tax-office-app"
LOCAL_IMAGE_TAG="latest"
LOCAL_IMAGE="${LOCAL_IMAGE_NAME}:${LOCAL_IMAGE_TAG}"
REMOTE_IMAGE_TAG="latest"
APP_CONTEXT_PATH="../app/."

REMOTE_IMAGE="${ARTIFACT_REGISTRY_HOST}/${GCP_PROJECT_ID/://}/${AR_REPO_NAME}/${LOCAL_IMAGE_NAME}:${REMOTE_IMAGE_TAG}"

# --- Execution Steps ---
echo "=========================================="
echo "0. Docker Daemon Check"
echo "=========================================="
if ! docker info &>/dev/null; then
    echo "❌ Error: Cannot connect to the Docker daemon or permission denied."
    echo "🚨 ACTION REQUIRED: If you see 'permission denied', run 'sudo usermod -aG docker $USER' and then 'newgrp docker' or re-login."
    exit 1
fi

echo "1. Explicitly logging in to Artifact Registry host: ${ARTIFACT_REGISTRY_HOST}"
if ! gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin "${ARTIFACT_REGISTRY_HOST}"; then
    echo "Error: Failed to explicitly log in to Docker registry."
    exit 1
fi
echo "Docker authentication configured successfully."

echo "2. Building local Docker image: ${LOCAL_IMAGE} from context: ${APP_CONTEXT_PATH}"
if ! docker build -t "${LOCAL_IMAGE}" "${APP_CONTEXT_PATH}"; then
    echo "Error: Failed to build Docker image."
    exit 1
fi
echo "Image built successfully."

echo "3. Tagging local image ${LOCAL_IMAGE} with remote path: ${REMOTE_IMAGE}"
if ! docker tag "${LOCAL_IMAGE}" "${REMOTE_IMAGE}"; then
    echo "Error: Failed to tag Docker image."
    exit 1
fi
echo "Image tagged successfully."

echo "4. Pushing image to Artifact Registry..."
if ! docker push "${REMOTE_IMAGE}"; then
    echo "Error: Failed to push Docker image to ${ARTIFACT_REGISTRY_HOST}."
    exit 1
fi
echo "Image push successful! Remote image is available at: ${REMOTE_IMAGE}"
