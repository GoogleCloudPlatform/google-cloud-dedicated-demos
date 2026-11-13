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
#!/usr/bin/env python3
"""Build Grafana Helm values from the 'grafana' section of defaults.yaml.

Usage: grafana_values.py <defaults.yaml> > grafana-values.json

Checks the admin credentials and, when OAuth is enabled, the OAuth settings.
On a problem it prints an [ERROR] message to stderr and exits with status 1,
so deploy_app_gke.sh stops before anything is installed.
Values are written as a Helm values file (JSON), so passwords and secrets
never appear on a command line and characters like ',', '"' or '$' are safe.
"""
import json
import sys

import yaml

# Placeholder values from defaults.yaml.example that must be replaced when OAuth is enabled.
OAUTH_PLACEHOLDERS = {
    "client_id": "iam-client-id",
    "client_secret": "iam-client-secret",
    "provider_url": "iam-oauth-provider-url",
}


def fail(message):
    print(f"[ERROR] {message}", file=sys.stderr)
    sys.exit(1)


def as_flag(value):
    """Return true/false as a boolean (as 'helm --set' did before); other values unchanged."""
    text = str(value)
    return text.lower() == "true" if text.lower() in ("true", "false") else text


def main(defaults_file):
    try:
        with open(defaults_file) as f:
            cfg = yaml.safe_load(f) or {}
    except FileNotFoundError:
        fail(f"Configuration file '{defaults_file}' not found.")

    grafana = cfg.get("grafana") or {}
    oauth = grafana.get("oauth") or {}

    for key in ("admin_user", "admin_password"):
        if not grafana.get(key):
            fail(f"'grafana.{key}' is missing or empty in {defaults_file}.")

    oauth_enabled = as_flag(oauth.get("enable", True))
    oauth_settings = {key: str(oauth.get(key) or "") for key in OAUTH_PLACEHOLDERS}
    if oauth_enabled is True:
        for key, placeholder in OAUTH_PLACEHOLDERS.items():
            if oauth_settings[key] in ("", placeholder):
                fail(f"OAuth is enabled but 'grafana.oauth.{key}' is missing or unset in {defaults_file}.")

    provider_url = oauth_settings["provider_url"]
    values = {
        "grafana": {
            "adminUser": str(grafana["admin_user"]),
            "adminPassword": str(grafana["admin_password"]),
            "env": {
                "GF_AUTH_DISABLE_LOGIN_FORM": as_flag(grafana.get("disable_login_form", True)),
                "GF_AUTH_GENERIC_OAUTH_ENABLED": oauth_enabled,
                "GF_AUTH_GENERIC_OAUTH_CLIENT_ID": oauth_settings["client_id"],
                "GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET": oauth_settings["client_secret"],
                "GF_AUTH_GENERIC_OAUTH_AUTH_URL": f"{provider_url}/protocol/openid-connect/auth",
                "GF_AUTH_GENERIC_OAUTH_TOKEN_URL": f"{provider_url}/protocol/openid-connect/token",
                "GF_AUTH_GENERIC_OAUTH_API_URL": f"{provider_url}/protocol/openid-connect/userinfo",
            },
        }
    }
    json.dump(values, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        fail("Usage: grafana_values.py <defaults.yaml>")
    main(sys.argv[1])
