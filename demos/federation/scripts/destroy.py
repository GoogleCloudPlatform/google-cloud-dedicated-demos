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
"""Script for destroying resources in a single targeted environment (gcd or gcp).

Supports full infrastructure destruction as well as Kubernetes-only workload cleanup (--k8s-only).
"""

import json
from pathlib import Path
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))

from env_utils import (
    ENVS_DIR,
    get_env_config,
)


def parse_args():
    """Parse CLI arguments for target environment and --k8s-only flag."""
    k8s_only = False
    target_env = None

    for arg in sys.argv[1:]:
        arg_clean = arg.strip().lower()
        if arg_clean in ("--k8s-only", "--k8s", "-k"):
            k8s_only = True
        elif arg_clean in ("gcd", "gcp") and not target_env:
            target_env = arg_clean

    if not target_env:
        target_env = prompt_select_environment()

    return target_env, k8s_only


def prompt_select_environment() -> str:
    """Prompt user interactively to select target environment."""
    print("\nSelect environment:")
    print(" 1) gcd (Google Cloud Dedicated)")
    print(" 2) gcp (Google Cloud Platform)")
    choice = input("Enter choice (gcd/gcp) [gcd]: ").strip().lower()
    if choice in ("2", "gcp"):
        return "gcp"
    return "gcd"


def confirm_action(target_env: str, env_cfg: dict, k8s_only: bool) -> bool:
    """Prompt user for confirmation before performing cleanup or full destroy."""
    project_id = env_cfg.get("project_id", "Unknown project")
    cluster_name = env_cfg.get("cluster_name", "Unknown cluster")

    print("\n=========================================================================")
    if k8s_only:
        print("=== KUBERNETES WORKLOAD CLEANUP (K8S ONLY) ===")
    else:
        print("=== SINGLE ENVIRONMENT DESTROY CONFIRMATION ===")
    print("=========================================================================")
    print(f"Target Environment : {target_env.upper()}")
    print(f"Target Project ID   : {project_id}")
    print(f"Target Cluster      : {cluster_name}")
    if k8s_only:
        print("Scope               : Delete Helm releases, custom resources, and namespaces")
        print("                      (bank-of-anthos, alloydb, alloydb-omni-system, cert-manager).")
        print("                      Terraform infrastructure will remain INTACT.")
    else:
        print("Scope               : Delete all Kubernetes workloads, followed by full Terraform destroy.")
    print("=========================================================================\n")

    if k8s_only:
        prompt = (
            f"Please confirm that your kubectl CLI is connected to '{target_env.upper()}' ({cluster_name}).\n"
            f"Reset all Kubernetes workloads for environment '{target_env}'? [y/N]: "
        )
    else:
        prompt = (
            f"Please confirm that your gcloud CLI is authenticated for '{target_env.upper()}' ({project_id}).\n"
            f"Destroy all resources in environment '{target_env}'? [y/N]: "
        )
    answer = input(prompt).strip().lower()
    return answer in ("y", "yes")


def remove_cr_finalizers(kind: str):
    """Strip finalizers from custom resources to prevent hanging deletions."""
    res = subprocess.run(
        ["kubectl", "get", kind, "-A", "-o", "json"],
        capture_output=True,
        text=True,
    )
    if res.returncode != 0:
        return
    try:
        items = json.loads(res.stdout).get("items", [])
        for item in items:
            name = item["metadata"]["name"]
            ns = item["metadata"].get("namespace")
            cmd = ["kubectl", "patch", kind, name, "--type=merge", "-p", '{"metadata":{"finalizers":[]}}']
            if ns:
                cmd.extend(["-n", ns])
            subprocess.run(cmd, capture_output=True, text=True)
    except Exception:
        pass


def remove_namespace_finalizers(namespace: str):
    """Force remove finalizers from a stuck namespace if it remains in Terminating state."""
    res = subprocess.run(
        ["kubectl", "get", "ns", namespace, "-o", "json"],
        capture_output=True,
        text=True,
    )
    if res.returncode != 0:
        return
    try:
        ns_json = json.loads(res.stdout)
        if ns_json.get("status", {}).get("phase") == "Terminating":
            ns_json["spec"]["finalizers"] = []
            subprocess.run(
                ["kubectl", "replace", "--raw", f"/api/v1/namespaces/{namespace}/finalize", "-f", "-"],
                input=json.dumps(ns_json),
                capture_output=True,
                text=True,
            )
    except Exception:
        pass


def cleanup_k8s_workloads(env_cfg: dict):
    """Uninstall Helm charts and delete K8s namespaces/resources to return cluster to clean post-TF state."""
    cluster_name = env_cfg.get("cluster_name")
    env_name = env_cfg.get("env_name", "target")

    print(f"[*] Cleaning up Kubernetes resources in {env_name} cluster '{cluster_name}'...")

    # 1. Strip finalizers from AlloyDB and cert-manager custom resources
    custom_resource_types = [
        "instances.alloydbomni.internal.dbadmin.goog",
        "dbclusters.alloydbomni.dbadmin.goog",
        "replications.alloydbomni.dbadmin.goog",
        "certificaterequests.cert-manager.io",
        "certificates.cert-manager.io",
        "issuers.cert-manager.io",
        "clusterissuers.cert-manager.io",
    ]
    for cr in custom_resource_types:
        remove_cr_finalizers(cr)

    # 2. Uninstall Helm releases in all relevant namespaces
    helm_releases = [
        ("bank-of-anthos", "bank-of-anthos"),
        ("bank-of-anthos", "default"),
        ("alloydb-replica", "alloydb"),
        ("alloydb-replica", "default"),
        ("alloydb-primary", "alloydb"),
        ("alloydb-primary", "default"),
        ("cloudsql-setup", "bank-of-anthos"),
        ("cloudsql-setup", "default"),
        ("alloydb-operator", "alloydb-omni-system"),
        ("cert-manager", "cert-manager"),
    ]

    for release, namespace in helm_releases:
        subprocess.run(
            ["helm", "uninstall", release, "-n", namespace],
            capture_output=True,
            text=True,
        )

    # 3. Delete cluster-scoped issuers and webhooks
    subprocess.run(
        ["kubectl", "delete", "clusterissuer", "--all", "--ignore-not-found=true"],
        capture_output=True,
        text=True,
    )
    webhooks = [
        ("validatingwebhookconfiguration", "cert-manager-webhook"),
        ("validatingwebhookconfiguration", "alloydb-omni-operator-validating-webhook-configuration"),
        ("mutatingwebhookconfiguration", "cert-manager-webhook"),
        ("mutatingwebhookconfiguration", "alloydb-omni-operator-mutating-webhook-configuration"),
    ]
    for kind, name in webhooks:
        subprocess.run(
            ["kubectl", "delete", kind, name, "--ignore-not-found=true"],
            capture_output=True,
            text=True,
        )

    # 4. Delete dedicated namespaces (cascades to secrets, PVCs, services, certs, pods)
    namespaces_to_delete = [
        "bank-of-anthos",
        "alloydb",
        "alloydb-omni-system",
        "cert-manager",
    ]
    for ns in namespaces_to_delete:
        print(f"[*] Deleting namespace '{ns}' (if exists)...")
        subprocess.run(
            ["kubectl", "delete", "ns", ns, "--ignore-not-found=true", "--timeout=30s"],
            capture_output=True,
            text=True,
        )
        remove_namespace_finalizers(ns)

    # 5. Delete remaining LoadBalancer services and PVCs in default namespace
    subprocess.run(
        ["kubectl", "delete", "svc", "--all", "-n", "default", "--ignore-not-found=true"],
        capture_output=True,
        text=True,
    )
    subprocess.run(
        ["kubectl", "delete", "pvc", "--all", "-n", "default", "--ignore-not-found=true"],
        capture_output=True,
        text=True,
    )

    print(f"[+] Kubernetes cleanup finished for {env_name}.")


def run_terraform_destroy(env_name: str) -> bool:
    """Run `terraform destroy -auto-approve` in terraform/envs/<env_name> with retries."""
    env_dir = ENVS_DIR / env_name
    if not env_dir.is_dir():
        print(f"[-] Environment directory {env_dir} does not exist.")
        return False

    tfstate = env_dir / "terraform.tfstate"
    if not tfstate.is_file():
        print(f"[*] No state file found for '{env_name}', skipping terraform destroy.")
        return True

    max_attempts = 3
    for attempt in range(1, max_attempts + 1):
        print(f"\n[*] Running terraform destroy in {env_dir} (attempt {attempt}/{max_attempts})...")
        res = subprocess.run(
            ["terraform", "destroy", "-auto-approve"],
            cwd=env_dir,
        )
        if res.returncode == 0:
            print(f"[+] Successfully destroyed resources in {env_name}.")
            return True

        if attempt < max_attempts:
            print(f"[-] Terraform destroy hit an error for {env_name}. Waiting 15s for GCP backend (e.g. PSC NetworkAttachment release) before retry...")
            time.sleep(15)

    return False


def main():
    target_env, k8s_only = parse_args()
    env_cfg = get_env_config(target_env)

    # Validate --k8s-only compatibility with database flavor
    if k8s_only and env_cfg.get("enable_cloudsql", False):
        print("\n=========================================================================")
        print(" [!] CANNOT RUN '--k8s-only' WITH CLOUDSQL")
        print("=========================================================================")
        print(" The '--k8s-only' option is only supported for AlloyDB Omni (where the database")
        print(" runs entirely inside Kubernetes).")
        print(f"\n Environment '{target_env.upper()}' is configured with Cloud SQL. Cloud SQL database instances,")
        print(" schemas, users, and pglogical replication state reside outside of Kubernetes.")
        print(" Resetting only Kubernetes workloads leaves the external database in an inconsistent state.")
        print("=========================================================================\n")

        prompt = (
            f"Would you like to run a FULL destroy for '{target_env.upper()}' instead? [y/N]: "
        )
        answer = input(prompt).strip().lower()
        if answer in ("y", "yes"):
            k8s_only = False
        else:
            print(f"\n[!] Operation aborted. To completely reset this Cloud SQL environment, run:\n")
            print(f"        just destroy {target_env}\n")
            sys.exit(0)

    if not confirm_action(target_env, env_cfg, k8s_only):
        print("[!] Operation cancelled by user.")
        sys.exit(0)

    # Step 1: Kubernetes Services, Workloads, & Namespaces Cleanup
    if env_cfg.get("enable_app"):
        print("\n=========================================================================")
        print(f"=== Step 1: Kubernetes Workload & Namespace Cleanup ({target_env.upper()}) ===")
        print("=========================================================================")
        cleanup_k8s_workloads(env_cfg)
        print("[*] Waiting 10 seconds for cloud load balancers to release...")
        time.sleep(10)

    if k8s_only:
        print("\n=========================================================================")
        print(f"[SUCCESS] Kubernetes workloads and namespaces for '{target_env.upper()}' cleaned up cleanly.")
        print("          Cluster is now in a pristine state (as right after terraform apply).")
        print("=========================================================================")
        sys.exit(0)

    # Step 2: Terraform Destroy
    print("\n=========================================================================")
    print(f"=== Step 2: Terraform Destroy ({target_env.upper()}) ===")
    print("=========================================================================")
    success = run_terraform_destroy(target_env)

    if success:
        print("\n=========================================================================")
        print(f"[SUCCESS] Environment '{target_env.upper()}' destroyed cleanly.")
        print("=========================================================================")
    else:
        print(f"\n[-] Errors occurred during terraform destroy for '{target_env}'.")
        sys.exit(1)


if __name__ == "__main__":
    main()
