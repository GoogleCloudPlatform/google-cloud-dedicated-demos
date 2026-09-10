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

set -euo pipefail

# --- LOGGING SETUP ---
# Redirect all stdout and stderr to both /var/log/sts-agent-startup.log AND the system serial console
LOG_FILE="/var/log/sts-agent-startup.log"
mkdir -p $(dirname "${LOG_FILE}")
touch "${LOG_FILE}" && chmod 644 "${LOG_FILE}"
ln -sf "${LOG_FILE}" /root/script_log.txt
ln -sf "${LOG_FILE}" /var/log/script_log.txt

exec > >(tee -a "${LOG_FILE}") 2>&1

trap 'echo "=== ERROR: Startup script failed on line $LINENO at $(date -u) ==="' ERR

echo "=== [Bootstrap Started at $(date -u)] ==="
echo "Full execution log captured at: ${LOG_FILE} (and symlinked at /var/log/script_log.txt)"

# --- CONFIGURATION VARIABLES (Querying VM Metadata directly) ---
DEST_BUCKET_NAME="$(curl -s -f http://metadata.google.internal/computeMetadata/v1/instance/attributes/DEST_BUCKET_NAME -H 'Metadata-Flavor: Google' || echo "${DEST_BUCKET_NAME:-}")"
MOUNT_POINT="/mnt/gcs-destination"
AGENT_POOL_NAME="$(curl -s -f http://metadata.google.internal/computeMetadata/v1/instance/attributes/AGENT_POOL_NAME -H 'Metadata-Flavor: Google' || echo "${AGENT_POOL_NAME:-}")"
PROJECT_ID="$(curl -s -f http://metadata.google.internal/computeMetadata/v1/instance/attributes/PROJECT_ID -H 'Metadata-Flavor: Google' || echo "${PROJECT_ID:-}")"

if [ -z "${DEST_BUCKET_NAME}" ] || [ -z "${AGENT_POOL_NAME}" ] || [ -z "${PROJECT_ID}" ]; then
    echo "FATAL ERROR: DEST_BUCKET_NAME, AGENT_POOL_NAME, or PROJECT_ID metadata attributes are missing!"
    echo "You must pass --metadata=DEST_BUCKET_NAME=...,AGENT_POOL_NAME=...,PROJECT_ID=... when creating this VM."
    exit 1
fi
echo "Loaded configuration from VM metadata: DEST_BUCKET_NAME=${DEST_BUCKET_NAME}, AGENT_POOL_NAME=${AGENT_POOL_NAME}, PROJECT_ID=${PROJECT_ID}"

echo "=== [1/5] Updating and Installing System Packages ==="
# NOTE: All outbound HTTPS queries for *.googleapis.com and *.gcr.io are routed natively via Cloud NAT.
export DEBIAN_FRONTEND=noninteractive
echo "Updating package lists over Cloud NAT..."
apt-get update -y
echo "Installing system packages (curl, gnupg, lsb-release, fd-find, fuse, dnsutils)..."
apt-get install -y curl apt-transport-https ca-certificates gnupg lsb-release fd-find fuse dnsutils

# Symlink fd if needed (Ubuntu/Debian installs as fdfind)
if ! command -v fd &>/dev/null && command -v fdfind &>/dev/null; then
    ln -s $(command -v fdfind) /usr/local/bin/fd
fi

# Install official Google Cloud gcsfuse repository using modern keyring (apt-key deprecated in Debian 13/Trixie)
if ! command -v gcsfuse &>/dev/null; then
    echo "Installing gcsfuse via signed-by keyring..."
    export GCSFUSE_REPO="gcsfuse-$(lsb_release -c -s)"
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor --yes -o /etc/apt/keyrings/cloud.google.gpg
    echo "deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt ${GCSFUSE_REPO} main" | tee /etc/apt/sources.list.d/gcsfuse.list
    apt-get update -y && apt-get install -y gcsfuse
fi

# Install Docker Daemon if not present
if ! command -v docker &>/dev/null; then
    echo "Installing Docker over Cloud NAT..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
fi
systemctl enable docker --now

# Verify Cloud NAT DNS resolution before proceeding
echo "Verifying external DNS resolution for www.googleapis.com, gcr.io, and storage.apis-berlin-build0.goog over Cloud NAT:"
dig A www.googleapis.com +short || true
dig A gcr.io +short || true
dig A storage.apis-berlin-build0.goog +short || true

echo "=== [2/5] Preparing Credentials File (/opt/creds/key.json) ==="
mkdir -p /opt/creds

# Defensive cleanup: if /opt/creds/key.json was created as an empty directory by a previous failed docker run bind-mount, remove it
if [ -d /opt/creds/key.json ]; then
    echo "Cleaning up invalid directory at /opt/creds/key.json..."
    rm -rf /opt/creds/key.json
fi

if curl -s -f http://metadata.google.internal/computeMetadata/v1/instance/attributes/creds-json -H "Metadata-Flavor: Google" >/tmp/key.json 2>/dev/null; then
    mv -f /tmp/key.json /opt/creds/key.json
    chmod 600 /opt/creds/key.json
    echo "Credentials successfully written to /opt/creds/key.json from metadata."
elif [ ! -f /opt/creds/key.json ]; then
    echo "FATAL ERROR: /opt/creds/key.json not found and 'creds-json' metadata attribute is missing!"
    echo "You must pass ',creds-json=path/to/sts-agent-reader-key.json' in --metadata-from-file when creating this VM."
    exit 1
fi

echo "=== [3/5] Preparing and Mounting GCS Destination Directory ==="
mkdir -p "${MOUNT_POINT}"
mkdir -p /var/log/sts_agent_logs
chmod 755 /var/log/sts_agent_logs

# Ensure /etc/fuse.conf allows 'allow_other'
if grep -q "^#user_allow_other" /etc/fuse.conf; then
    sed -i 's/^#user_allow_other/user_allow_other/' /etc/fuse.conf
elif ! grep -q "^user_allow_other" /etc/fuse.conf; then
    echo "user_allow_other" >>/etc/fuse.conf
fi

# Idempotently mount GCS destination bucket with secure permissions using native VM metadata auth (no --key-file)
if ! mountpoint -q "${MOUNT_POINT}"; then
    echo "Mounting bucket '${DEST_BUCKET_NAME}' to '${MOUNT_POINT}' via Sovereign endpoint (storage.apis-berlin-build0.goog:443)..."
    gcsfuse --custom-endpoint=storage.apis-berlin-build0.goog:443 \
        --implicit-dirs \
        -o allow_other \
        --dir-mode=0755 \
        --file-mode=0644 \
        "${DEST_BUCKET_NAME}" "${MOUNT_POINT}"
else
    echo "Bucket is already mounted at ${MOUNT_POINT}."
fi

echo "=== [4/5] Launching Storage Transfer Agent Docker Container ==="
# Stop and clean up any failing/old containers
docker stop sts-agent 2>/dev/null || true
docker rm sts-agent 2>/dev/null || true

echo "Pulling tsop-agent image via Cloud NAT..."
docker pull gcr.io/cloud-ingest/tsop-agent:latest

echo "Starting tsop-agent container without undefined trailing flags..."
# NOTE: Single volume mount (-v /opt/creds/key.json:/opt/creds/key.json) is used because --creds-file=/opt/creds/key.json
# reads directly from /opt/creds.
# Do NOT mount inside /transfer_root as that crosses the gcsfuse boundary and triggers runc permission denied errors.
# NOTE: Do NOT pass --disable-upgrade, --stable-url, or --enable-mount-directory (prevents Exit Code 2 crash).
# NOTE: autoupdate.py natively downloads agent-linux_amd64.tar.gz via Cloud NAT / Private VIP over HTTPS on startup.
docker run -d --ulimit memlock=64000000 \
    --name sts-agent \
    --restart=always \
    --network host \
    -v /opt/creds/key.json:/opt/creds/key.json \
    -v "${MOUNT_POINT}:/transfer_root" \
    -v /var/log/sts_agent_logs:/agent_logs \
    gcr.io/cloud-ingest/tsop-agent:latest \
    --project-id="${PROJECT_ID}" \
    --creds-file=/opt/creds/key.json \
    --agent-pool="${AGENT_POOL_NAME}" \
    --hostname=$(hostname) \
    --log-dir=/agent_logs \
    --alsologtostderr \
    --v=2

echo "=== [5/5] Bootstrap Completed Successfully at $(date -u) ==="
