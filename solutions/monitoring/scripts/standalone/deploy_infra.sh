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

# Define working variables with robust script-relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TF_DIR="$DEMO_DIR/terraform"

echo "--- Starting Infrastructure Installation ---"

echo "1. Initializing Terraform Infrastructure Deploy..."
cd "$TF_DIR"
terraform init -input=false

echo "2. Applying Terraform configuration..."
terraform apply -auto-approve -input=false

echo "--- Infrastructure Installation Complete ---"

cd - >/dev/null
