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

# --- Configuration ---
PYTHON_SCRIPT="../app/data_generator/generate_tax_data.py"
OUTPUT_CSV="../terraform/assets/tax_office_data.csv"
VENV_DIR=".venv"
REQUIREMENTS_FILE="../app/requirements.txt"

echo "=========================================="
echo "1. Initializing Python Virtual Environment"
echo "=========================================="

# Check if python3 and venv module are available
if ! command -v python3 &>/dev/null || ! python3 -m venv --help &>/dev/null; then
    echo "❌ Error: 'python3' or 'python3-venv' is not installed or available on PATH."
    echo "Please install Python 3 and the 'venv' module (e.g., sudo apt install python3-venv)."
    exit 1
fi

# Create and activate a virtual environment
if [ ! -d "${VENV_DIR}" ]; then
    echo "Creating virtual environment at ${VENV_DIR}..."
    python3 -m venv "${VENV_DIR}"
fi
source "${VENV_DIR}/bin/activate"
echo "Virtual environment activated."

echo "=========================================="
echo "2. Installing Python Dependencies"
echo "=========================================="

# Check if the requirements file exists
if [ ! -f "${REQUIREMENTS_FILE}" ]; then
    echo "❌ Error: Requirements file not found at ${REQUIREMENTS_FILE}"
    deactivate
    exit 1
fi

# Install required packages using the -r flag for a requirements file
echo "Checking and installing required packages from: ${REQUIREMENTS_FILE}..."

if ! pip install --no-cache-dir --require-hashes -r "${REQUIREMENTS_FILE}"; then
    echo "❌ Error: Failed to install Python dependencies. Check network connection or permissions."
    deactivate
    exit 1
fi
echo "Dependencies installed successfully."

echo "=========================================="
echo "3. Data Generation"
echo "=========================================="

if [ -f "${OUTPUT_CSV}" ]; then
    echo "⚠️ Skipping data generation: Output file already exists at ${OUTPUT_CSV}"
else
    # Run the data generation script only if the file is NOT present
    echo "Running data generation script..."
    if ! python3 "${PYTHON_SCRIPT}" --output "${OUTPUT_CSV}"; then
        echo "❌ Error: Failed to run the Python data generation script."
        deactivate
        exit 1
    fi

    echo "✅ Data generation successful. File created at: ${OUTPUT_CSV}"
fi

echo "=========================================="
echo "4. Cleanup"
echo "=========================================="
deactivate
echo "Virtual environment deactivated."
