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
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# 1. Determine the data file path (Source of Truth: terraform/terraform.tfvars)
TFVARS_FILE="$BASE_DIR/terraform/terraform.tfvars"
DEFAULT_FILE_PATH="$BASE_DIR/app/data_generator/tax_office_data.csv"
DATA_FILE_PATH=""

if [ -f "$TFVARS_FILE" ]; then
    # Extract value from tfvars, removing quotes and whitespace
    EXTRACTED_PATH=$(grep -E '^\s*data_file_location\s*=' "$TFVARS_FILE" | cut -d'"' -f2 | xargs)

    if [[ -n $EXTRACTED_PATH && $EXTRACTED_PATH != "REPLACE_ME" ]]; then
        # If path is relative (e.g. starting with ../ or ./), resolve it relative to the terraform directory
        if [[ $EXTRACTED_PATH == .* ]]; then
            DATA_FILE_PATH=$(cd "$BASE_DIR/terraform" && realpath -m "$EXTRACTED_PATH")
        else
            DATA_FILE_PATH="$EXTRACTED_PATH"
        fi
    fi
fi

# Fallback to default if not found or still REPLACE_ME
DATA_FILE_PATH="${DATA_FILE_PATH:-$DEFAULT_FILE_PATH}"

# 2. Check if file exists (Task 6)
if [ -f "$DATA_FILE_PATH" ]; then
    echo "Data file already exists at: $DATA_FILE_PATH"
    echo "Skipping generation."
    exit 0
fi

echo "Data file not found. Starting generation process..."

# 3. Environment setup
VENV_DIR="$BASE_DIR/scripts/.venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

echo "Installing requirements..."
pip install --no-cache-dir --require-hashes -r "$BASE_DIR/app/requirements.txt"

# 4. Generate data
echo "Generating data to: $DATA_FILE_PATH"
mkdir -p "$(dirname "$DATA_FILE_PATH")"
python3 "$BASE_DIR/app/data_generator/generate_tax_data.py" --output "$DATA_FILE_PATH"
