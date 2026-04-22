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

echo "Starting full Tax Office deployment..."

# --- 0. Data Generation ---
echo "--- STEP 0: Generating Tax Data ---"
source ./standalone/generate_data.sh
if [ $? -ne 0 ]; then exit 1; fi

# --- 1. Infrastructure Deployment ---
echo "--- STEP 1: Deploying Infrastructure (Terraform) ---"
source ./standalone/deploy_infra.sh
if [ $? -ne 0 ]; then exit 1; fi

# --- 2. Application Packaging & Push ---
echo "--- STEP 2: Building and Pushing Docker Image ---"
source ./standalone/deploy_app_image.sh
if [ $? -ne 0 ]; then exit 1; fi

# --- 3. GKE Application Deployment ---
echo "--- STEP 3: Deploying Applications to GKE ---"
source ./standalone/deploy_app_gke.sh
if [ $? -ne 0 ]; then exit 1; fi

echo "🎉 Full deployment finished successfully!"
