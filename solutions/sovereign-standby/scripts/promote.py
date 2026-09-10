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
"""Script for promoting the replica database to standalone primary (supports cloudsql and alloydb)."""

from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

from env_utils import get_env_config


def detect_flavor(gcd_cfg: dict) -> str:
    """Automatically determine the database flavor (cloudsql or alloydb)."""
    if gcd_cfg.get("enable_cloudsql", False):
        return "cloudsql"
    return "alloydb"


def confirm_gcd_universe(env_cfg: dict) -> bool:
    """Prompt user for confirmation that kubectl CLI is configured for the GCD cluster."""
    project_id = env_cfg.get("project_id", "GCD project")
    cluster_name = env_cfg.get("cluster_name", "GCD cluster")
    db_host = env_cfg.get("db_host", "N/A")

    print("\n=========================================================================")
    print("=== REPLICA PROMOTION CONFIRMATION ===")
    print("=========================================================================")
    print(f"Target Environment : GCD ({env_cfg['env_name']})")
    print(f"Target Project ID   : {project_id}")
    print(f"Target Cluster      : {cluster_name}")
    print(f"Target DB Host      : {db_host}")
    print("=========================================================================\n")

    prompt = (
        f"Please confirm that your kubectl is configured and connected to the\n"
        f"GCD cluster ('{cluster_name}'). Continue with promotion? [y/N]: "
    )
    answer = input(prompt).strip().lower()
    return answer in ("y", "yes")


def promote_cloudsql(gcd_cfg: dict) -> bool:
    """Promote CloudSQL PostgreSQL replica to primary via kubectl exec on cloudsql-admin pod."""
    print("[*] Running CloudSQL replica promotion script on cloudsql-admin pod...")
    for ns in ("bank-of-anthos", "default"):
        cmd = [
            "kubectl",
            "exec",
            "deployment/cloudsql-admin",
            "-n",
            ns,
            "--",
            "/scripts/promote.sh",
        ]
        res = subprocess.run(cmd)
        if res.returncode == 0:
            print(
                f"[SUCCESS] CloudSQL replica database in namespace '{ns}' successfully promoted to primary!"
            )
            return True

    print("[-] Failed to execute promotion script on cloudsql-admin pod.")
    return False


def promote_alloydb(gcd_cfg: dict) -> bool:
    """Promote AlloyDB Omni replica on GKE cluster context."""
    print("[*] Promoting AlloyDB Omni replica via Kubernetes Custom Resource...")
    last_err = ""
    for ns in ("alloydb", "default"):
        patch_cmd = [
            "kubectl",
            "patch",
            "replication",
            "alloydb-omni-replica-replication",
            "-n",
            ns,
            "--type=merge",
            "-p",
            '{"spec":{"downstream":{"control":"promote"}}}',
        ]
        res_patch = subprocess.run(patch_cmd, capture_output=True, text=True)
        if res_patch.returncode == 0:
            print(res_patch.stdout)
            print(f"[SUCCESS] AlloyDB Omni replica in namespace '{ns}' successfully promoted to primary!")
            return True
        last_err = res_patch.stderr.strip()

    print(f"[-] Failed to patch AlloyDB Omni replication CR:\n{last_err}")
    return False


def main():
    gcd_cfg = get_env_config("gcd")
    flavor = detect_flavor(gcd_cfg)
    print(f"[+] Automatically detected database flavor: '{flavor.upper()}'")

    if not confirm_gcd_universe(gcd_cfg):
        print("[!] Promotion operation cancelled by user.")
        sys.exit(0)

    if flavor == "cloudsql":
        success = promote_cloudsql(gcd_cfg)
    else:
        success = promote_alloydb(gcd_cfg)

    if not success:
        sys.exit(1)


if __name__ == "__main__":
    main()
