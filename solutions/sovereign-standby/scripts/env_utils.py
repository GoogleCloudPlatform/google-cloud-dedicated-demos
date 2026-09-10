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
"""Utility functions for terraform outputs and defaults.yaml environment config parsing."""

import json
from pathlib import Path
import subprocess
import yaml

ENVS_DIR = Path(__file__).resolve().parent.parent / "terraform" / "envs"
SCRIPTS_DIR = Path(__file__).resolve().parent


def load_env_defaults(env_name: str) -> dict:
    """Load configuration from terraform/envs/<env_name>/defaults.yaml."""
    yaml_path = ENVS_DIR / env_name / "defaults.yaml"
    if not yaml_path.is_file():
        return {}
    with open(yaml_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def get_terraform_outputs(env_name: str) -> dict:
    """Run `terraform output -json` in terraform/envs/<env_name> if tfstate exists."""
    env_dir = ENVS_DIR / env_name
    tfstate = env_dir / "terraform.tfstate"
    if not tfstate.is_file():
        return {}
    res = subprocess.run(
        ["terraform", "output", "-json"],
        cwd=env_dir,
        capture_output=True,
        text=True,
    )
    if res.returncode != 0:
        return {}
    try:
        raw_outputs = json.loads(res.stdout)
        return {k: v.get("value") for k, v in raw_outputs.items()}
    except Exception:
        return {}


def get_env_config(env_name: str) -> dict:
    """Merge defaults.yaml and terraform outputs for a given environment."""
    cfg = load_env_defaults(env_name)
    outputs = get_terraform_outputs(env_name)

    gen = cfg.get("general", {})
    net = cfg.get("network", {})
    db = cfg.get("cloudsql_db", {})
    gke = cfg.get("gke", {})

    prefix = outputs.get("prefix") or gen.get("prefix", "")
    raw_cluster_name = outputs.get("gke_cluster_name") or gke.get("cluster_name", "federation-gke-cluster")
    if prefix and not raw_cluster_name.startswith(prefix):
        full_cluster_name = f"{prefix}{raw_cluster_name}"
    else:
        full_cluster_name = raw_cluster_name

    merged = {
        "env_name": env_name,
        "enable_cloudsql": cfg.get("enable_cloudsql", False),
        "enable_app": cfg.get("enable_app", False),
        "enable_network": cfg.get("enable_network", False),
        "project_id": outputs.get("project_id") or gen.get("project_id", ""),
        "zone": outputs.get("zone") or net.get("zone", ""),
        "region": outputs.get("region") or net.get("region", ""),
        "prefix": prefix,
        "db_host": outputs.get("db_host") or db.get("psc_ip", ""),
        "db_name": outputs.get("db_name") or db.get("db_name", "bankofanthos"),
        "db_user": outputs.get("db_user") or db.get("db_user", "bankuser"),
        "db_password": outputs.get("db_password") or db.get("repl_password", ""),
        "admin_password": outputs.get("admin_password") or db.get("admin_password", ""),
        "cluster_name": full_cluster_name,
    }
    return merged
