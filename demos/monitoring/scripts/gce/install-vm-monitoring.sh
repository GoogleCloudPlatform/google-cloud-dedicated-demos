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
# install-vm-monitoring.sh
# Standalone GCE VM Logging & Monitoring Installer for Fluent Bit & OpenTelemetry Collector
# Collects system logs and stdout from CLI applications (/var/log/syslog, /var/log/auth.log)
# and exports them to Google Cloud Logging via OTel googlecloud exporter.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Fetch environment flags from GCE instance metadata if not set in shell
if [ -z "${UNIVERSE_DOMAIN:-}" ]; then
    UNIVERSE_DOMAIN=$(curl -sf -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/UNIVERSE_DOMAIN" 2>/dev/null || echo "googleapis.com")
fi

if [ -z "${ENABLE_DEMO_LOG_GENERATOR:-}" ]; then
    ENABLE_DEMO_LOG_GENERATOR=$(curl -sf -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ENABLE_DEMO_LOG_GENERATOR" 2>/dev/null || echo "false")
fi

# Helper function to fetch a file from local disk OR GCE instance metadata attribute
fetch_config_file() {
    local filename="$1"
    local metadata_attr="$2"
    local dest_path="$3"
    local file_perm="$4"

    mkdir -p "$(dirname "$dest_path")"

    # Search local candidate paths (same directory, sibling demo app dir, or full repo clone)
    local found=""
    local basename_file="$(basename "$filename")"
    for candidate in \
        "${SCRIPT_DIR}/${filename}" \
        "${SCRIPT_DIR}/${basename_file}" \
        "${SCRIPT_DIR}/../gce-demo-app/${basename_file}" \
        "${SCRIPT_DIR}/../../apps/gce-demo-app/${basename_file}" \
        "./${basename_file}" \
        "./gce-demo-app/${basename_file}"; do
        if [ -f "$candidate" ]; then
            found="$candidate"
            break
        fi
    done

    if [ -n "$found" ]; then
        echo "Copying ${found} to ${dest_path}..."
        cp "$found" "${dest_path}"
    else
        echo "Fetching ${metadata_attr} from GCE metadata server to ${dest_path}..."
        if ! curl -sf -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/${metadata_attr}" > "${dest_path}"; then
            echo "ERROR: Could not find '${filename}' locally or in GCE instance metadata ('${metadata_attr}')." >&2
            return 1
        fi
    fi
    chmod "${file_perm}" "${dest_path}"
}

echo "=== [1/6] Installing dependencies ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl gnupg2 ca-certificates apt-transport-https python3

echo "=== [2/6] Installing Fluent Bit ==="
curl -fsSL https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh || {
    echo "Fallback to apt repository for Fluent Bit..."
    curl -fsSL https://packages.fluentbit.io/fluentbit.key | gpg --dearmor -o /usr/share/keyrings/fluentbit-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/fluentbit-keyring.gpg] https://packages.fluentbit.io/debian/bookworm bookworm main" > /etc/apt/sources.list.d/fluent-bit.list
    apt-get update -y && apt-get install -y fluent-bit
}

echo "=== [3/6] Installing OpenTelemetry Collector Contrib ==="
OTEL_VERSION="0.108.0"
ARCH=$(dpkg --print-architecture)
curl -fsSL -o /tmp/otelcol-contrib.deb "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol-contrib_${OTEL_VERSION}_linux_${ARCH}.deb"
dpkg -i /tmp/otelcol-contrib.deb || {
    echo "Failed to install otelcol-contrib package. Trying apt install..."
    apt-get install -f -y
}
rm -f /tmp/otelcol-contrib.deb

echo "=== [4/6] Configuring Fluent Bit (/etc/fluent-bit/fluent-bit.conf) ==="
fetch_config_file "fluent-bit.conf" "fluent_bit_conf" "/etc/fluent-bit/fluent-bit.conf" "0644"

echo "=== [5/6] Configuring OpenTelemetry Collector (/etc/otelcol-contrib/config.yaml) ==="
fetch_config_file "otelcol-config.yaml" "otelcol_config_yaml" "/etc/otelcol-contrib/config.yaml" "0644"

# Support Sovereign Cloud Universe Domain
# (scoped strictly to otelcol-contrib systemd service)
if [ -n "${UNIVERSE_DOMAIN:-}" ] && [ "$UNIVERSE_DOMAIN" != "googleapis.com" ]; then
    echo "Configuring GOOGLE_CLOUD_UNIVERSE_DOMAIN=${UNIVERSE_DOMAIN} for otelcol-contrib.service..."
    mkdir -p /etc/systemd/system/otelcol-contrib.service.d
    cat << EOF > /etc/systemd/system/otelcol-contrib.service.d/10-universe-domain.conf
[Service]
Environment="GOOGLE_CLOUD_UNIVERSE_DOMAIN=${UNIVERSE_DOMAIN}"
EOF
fi

echo "=== [6/6] Enabling and starting logging services ==="
systemctl daemon-reload
systemctl enable fluent-bit otelcol-contrib
systemctl restart fluent-bit otelcol-contrib

# Optional: Install simple Python CLI demo app writing to stdout
if [ "${ENABLE_DEMO_LOG_GENERATOR:-false}" = "true" ]; then
    echo "=== Installing Demo Verification CLI App (vm-demo-app.service) ==="
    fetch_config_file "../../apps/gce-demo-app/vm-demo-app.py" "vm_demo_app_py" "/usr/local/bin/vm-demo-app.py" "0755"
    fetch_config_file "../../apps/gce-demo-app/vm-demo-app.service" "vm_demo_app_service" "/etc/systemd/system/vm-demo-app.service" "0644"
    systemctl daemon-reload
    systemctl enable --now vm-demo-app.service
fi

echo "=== Standalone GCE VM monitoring installation completed successfully! ==="
