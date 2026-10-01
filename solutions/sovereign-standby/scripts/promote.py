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
"""Promote the GCD replica database to a standalone primary (Cloud SQL or AlloyDB Omni).

Usage: just promote [--dry]

The database flavor is detected from terraform/envs/gcd/defaults.yaml.
Before running: disconnect the VPN between GCP and GCD (README section 6) and
point kubectl at the GCD cluster (README "kubectl Cluster Credentials Setup").
"""

import argparse

from env_utils import (
    EnvConfig,
    add_dry_run_flag,
    banner,
    confirm,
    describe_kube_context,
    die,
    get_env_config,
    info,
    run,
    success,
)

PROMOTE_COMMANDS = {
    # Runs the pglogical promotion script shipped with the cloudsql-setup chart.
    "cloudsql": [
        "kubectl", "exec", "deployment/cloudsql-admin", "-n", "bank-of-anthos", "--", "/scripts/promote.sh",
    ],
    # Asks the AlloyDB Omni operator to promote the downstream replica.
    "alloydb": [
        "kubectl", "patch", "replication", "alloydb-omni-replica-replication", "-n", "alloydb",
        "--type=merge", "-p", '{"spec":{"downstream":{"control":"promote"}}}',
    ],
}


def print_plan(cfg: EnvConfig) -> None:
    print("Environment : GCD")
    print(f"Project     : {cfg.project_id}")
    print(f"Cluster     : {cfg.cluster_name}")
    print(f"DB flavor   : {cfg.db_flavor}")
    print(f"DB host     : {cfg.db_host or 'n/a'}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    add_dry_run_flag(parser)
    args = parser.parse_args()

    cfg = get_env_config("gcd")
    cmd = PROMOTE_COMMANDS[cfg.db_flavor]

    if args.dry_run:
        banner("[DRY-RUN] Manual replica promotion on GCD")
        print_plan(cfg)
        print("\n# With kubectl pointed at the GCD cluster, run:")
        run(cmd, dry_run=True)
        return

    banner("Replica promotion on GCD")
    print_plan(cfg)
    describe_kube_context(cfg)
    print()
    if not confirm("Promote the GCD replica to a standalone primary? This cannot be undone."):
        info("Promotion cancelled.")
        return

    info(f"Promoting {cfg.db_flavor} replica...")
    res = run(cmd)
    if res.returncode != 0:
        die(f"Promotion command failed (exit {res.returncode}).")
    success(f"GCD {cfg.db_flavor} replica promoted to primary.")


if __name__ == "__main__":
    main()
