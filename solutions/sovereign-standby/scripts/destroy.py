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
"""Tear down one universe: Kubernetes workloads first, then `terraform destroy`.

Usage:
  just destroy <gcp|gcd> [--k8s-only] [--dry]
  just destroy-k8s <gcp|gcd> [--dry]

Kubernetes cleanup order (each step unblocks the next one):
  1. Mark AlloyDB DBClusters as deleted and remove admission webhooks,
     so neither the operator nor webhooks block deletion.
  2. Strip finalizers from AlloyDB / cert-manager custom resources.
  3. Uninstall Helm releases.
  4. Delete ClusterIssuers and the demo namespaces (force-finalize if stuck).

--k8s-only is supported only for AlloyDB Omni: with Cloud SQL the database lives
outside Kubernetes and would be left in an inconsistent state.
"""

import argparse
import json
import shlex
import time

from env_utils import (
    ENVS_DIR,
    EnvConfig,
    add_dry_run_flag,
    add_env_argument,
    banner,
    confirm,
    describe_kube_context,
    die,
    get_env_config,
    has_terraform_state,
    info,
    kubectl_json,
    run,
    success,
    warn,
)

CUSTOM_RESOURCE_KINDS = [
    "instances.alloydbomni.internal.dbadmin.goog",
    "dbclusters.alloydbomni.dbadmin.goog",
    "replications.alloydbomni.dbadmin.goog",
    "certificaterequests.cert-manager.io",
    "certificates.cert-manager.io",
    "issuers.cert-manager.io",
    "clusterissuers.cert-manager.io",
]
DBCLUSTER_KIND = "dbclusters.alloydbomni.dbadmin.goog"

HELM_RELEASES = [  # (release, namespace), uninstalled in this order
    ("bank-of-anthos", "bank-of-anthos"),
    ("cloudsql-setup", "bank-of-anthos"),
    ("alloydb-replica", "alloydb"),
    ("alloydb-primary", "alloydb"),
    ("alloydb-operator", "alloydb-omni-system"),
    ("cert-manager", "cert-manager"),
]

NAMESPACES = ["bank-of-anthos", "alloydb", "alloydb-omni-system", "cert-manager"]

WEBHOOK_KINDS = ["validatingwebhookconfiguration", "mutatingwebhookconfiguration"]
WEBHOOK_NAME_TOKENS = ("alloydb", "cert-manager")

HELM_UNINSTALL_TIMEOUT = "120s"
NAMESPACE_DELETE_TIMEOUT = "180s"
LB_RELEASE_WAIT_SECONDS = 15
TF_DESTROY_ATTEMPTS = 3
TF_DESTROY_RETRY_DELAY_SECONDS = 15

PATCH_FINALIZERS = '{"metadata":{"finalizers":[]}}'
PATCH_IS_DELETED = '{"spec":{"isDeleted":true}}'


# --------------------------------------------------------------------------- #
# Kubernetes primitives                                                       #
# --------------------------------------------------------------------------- #


def patch_all(kind: str, patch: str, dry_run: bool, only_with_finalizers: bool = False) -> None:
    """Apply a merge patch to every object of `kind` in all namespaces."""
    if dry_run:
        # Runnable equivalent: "<namespace>/<name>" lines -> kubectl patch.
        jsonpath = '{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\\n"}{end}'
        print(
            f"kubectl get {kind} -A -o jsonpath={shlex.quote(jsonpath)} | "
            f'while IFS=/ read -r ns name; do kubectl patch {kind} "$name" ${{ns:+-n "$ns"}} '
            f"--type=merge -p {shlex.quote(patch)}; done"
        )
        return

    data = kubectl_json(["get", kind, "-A"])
    for item in (data or {}).get("items", []):
        meta = item.get("metadata", {})
        if only_with_finalizers and not meta.get("finalizers"):
            continue
        cmd = ["kubectl", "patch", kind, meta["name"], "--type=merge", "-p", patch]
        if meta.get("namespace"):
            cmd += ["-n", meta["namespace"]]
        res = run(cmd, capture=True)
        if res.returncode != 0:
            warn(f"Failed to patch {kind}/{meta['name']}: {res.stderr.strip()}")


def strip_custom_resource_finalizers(dry_run: bool) -> None:
    for kind in CUSTOM_RESOURCE_KINDS:
        patch_all(kind, PATCH_FINALIZERS, dry_run, only_with_finalizers=True)


def delete_webhooks(dry_run: bool) -> None:
    """Delete AlloyDB / cert-manager admission webhooks (matched by name)."""
    if dry_run:
        pattern = "|".join(WEBHOOK_NAME_TOKENS)
        print(f"kubectl get {','.join(WEBHOOK_KINDS)} -o name | grep -E {shlex.quote(pattern)} | xargs -r kubectl delete")
        return

    for kind in WEBHOOK_KINDS:
        for item in (kubectl_json(["get", kind]) or {}).get("items", []):
            name = item.get("metadata", {}).get("name", "")
            if any(token in name.lower() for token in WEBHOOK_NAME_TOKENS):
                run(["kubectl", "delete", kind, name, "--ignore-not-found=true"], capture=True)


def uninstall_helm_releases(dry_run: bool) -> None:
    for release, namespace in HELM_RELEASES:
        res = run(
            ["helm", "uninstall", release, "-n", namespace, "--ignore-not-found", "--timeout", HELM_UNINSTALL_TIMEOUT],
            capture=True,
            dry_run=dry_run,
        )
        if res.returncode != 0:
            warn(f"Failed to uninstall Helm release '{release}' in '{namespace}': {res.stderr.strip()}")


def force_finalize_namespace(namespace: str) -> None:
    """Clear finalizers of a namespace stuck in Terminating."""
    ns = kubectl_json(["get", "ns", namespace])
    if not ns or ns.get("status", {}).get("phase") != "Terminating":
        return
    warn(f"Namespace '{namespace}' is stuck in Terminating; forcing finalizer removal.")
    # Operators may have re-added finalizers while the namespace was draining.
    patch_all(DBCLUSTER_KIND, PATCH_IS_DELETED, dry_run=False)
    strip_custom_resource_finalizers(dry_run=False)
    ns.setdefault("spec", {})["finalizers"] = []
    ns.setdefault("metadata", {})["finalizers"] = []
    res = run(
        ["kubectl", "replace", "--raw", f"/api/v1/namespaces/{namespace}/finalize", "-f", "-"],
        stdin=json.dumps(ns),
        capture=True,
    )
    if res.returncode != 0:
        warn(f"Failed to finalize namespace '{namespace}': {res.stderr.strip()}")


def delete_namespaces(dry_run: bool) -> None:
    for namespace in NAMESPACES:
        res = run(
            ["kubectl", "delete", "ns", namespace, "--ignore-not-found=true", f"--timeout={NAMESPACE_DELETE_TIMEOUT}"],
            capture=True,
            dry_run=dry_run,
        )
        if dry_run:
            continue
        if res.returncode != 0:
            warn(f"Deleting namespace '{namespace}' did not finish cleanly: {res.stderr.strip()}")
        force_finalize_namespace(namespace)
    if dry_run:
        print("# If a namespace hangs in Terminating, clear its finalizers:")
        print("#   kubectl get ns <ns> -o json | jq '.spec.finalizers=[]' | "
              "kubectl replace --raw /api/v1/namespaces/<ns>/finalize -f -")


def is_cluster_reachable() -> bool:
    res = run(["kubectl", "cluster-info", "--request-timeout=15s"], capture=True, quiet=True)
    if res.returncode != 0:
        warn(f"Kubernetes API is not reachable: {res.stderr.strip() or 'kubectl cluster-info failed'}")
        return False
    return True


# --------------------------------------------------------------------------- #
# Teardown steps                                                              #
# --------------------------------------------------------------------------- #


def cleanup_kubernetes(cfg: EnvConfig, dry_run: bool) -> bool:
    """Return the cluster to its post-`terraform apply` state. False if unreachable."""
    if not dry_run and not is_cluster_reachable():
        return False

    step = (lambda msg: print(f"# {msg}")) if dry_run else info

    step("1/4 Unblocking deletion (AlloyDB isDeleted flag, admission webhooks)")
    patch_all(DBCLUSTER_KIND, PATCH_IS_DELETED, dry_run)
    delete_webhooks(dry_run)

    step("2/4 Stripping custom resource finalizers")
    strip_custom_resource_finalizers(dry_run)

    step("3/4 Uninstalling Helm releases")
    uninstall_helm_releases(dry_run)

    step("4/4 Deleting ClusterIssuers and namespaces")
    run(["kubectl", "delete", "clusterissuer", "--all", "--ignore-not-found=true"], capture=True, dry_run=dry_run)
    delete_namespaces(dry_run)
    return True


def terraform_destroy(env: str, dry_run: bool) -> bool:
    env_dir = ENVS_DIR / env
    cmd = ["terraform", "destroy", "-auto-approve"]
    if dry_run:
        run(cmd, cwd=env_dir, dry_run=True)
        return True
    if not has_terraform_state(env):
        info(f"No Terraform state for '{env}'; nothing to destroy.")
        return True

    for attempt in range(1, TF_DESTROY_ATTEMPTS + 1):
        info(f"terraform destroy (attempt {attempt}/{TF_DESTROY_ATTEMPTS})")
        if run(cmd, cwd=env_dir).returncode == 0:
            return True
        if attempt < TF_DESTROY_ATTEMPTS:
            warn(f"terraform destroy failed; retrying in {TF_DESTROY_RETRY_DELAY_SECONDS}s...")
            time.sleep(TF_DESTROY_RETRY_DELAY_SECONDS)
    return False


# --------------------------------------------------------------------------- #
# Entry point                                                                 #
# --------------------------------------------------------------------------- #


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    add_env_argument(parser)
    parser.add_argument(
        "--k8s-only", "-k", action="store_true", help="Only remove Kubernetes workloads; keep Terraform infrastructure"
    )
    add_dry_run_flag(parser)
    return parser.parse_args()


def print_plan(cfg: EnvConfig, k8s_only: bool) -> None:
    print(f"Environment : {cfg.name.upper()}")
    print(f"Project     : {cfg.project_id or 'unknown'}")
    print(f"Cluster     : {cfg.cluster_name}")
    if k8s_only:
        print(f"Scope       : Helm releases, custom resources and namespaces ({', '.join(NAMESPACES)}).")
        print("              Terraform infrastructure is kept.")
    else:
        print("Scope       : all Kubernetes workloads, then `terraform destroy` of the whole environment.")
    describe_kube_context(cfg)
    print()


def main() -> None:
    args = parse_args()
    cfg = get_env_config(args.env)
    env = cfg.name.upper()

    if args.k8s_only and cfg.enable_cloudsql:
        die(f"--k8s-only is not supported for Cloud SQL ({env} has enable_cloudsql: true): the external "
            f"database would be left inconsistent. Use a full teardown instead: just destroy {args.env}")

    clean_k8s = args.k8s_only or cfg.enable_app

    if args.dry_run:
        banner(f"[DRY-RUN] Manual teardown of {env}")
        if clean_k8s:
            print(f"# With kubectl pointed at the {env} cluster, run:")
            cleanup_kubernetes(cfg, dry_run=True)
        if not args.k8s_only:
            print()
            terraform_destroy(args.env, dry_run=True)
        return

    banner(f"Kubernetes cleanup of {env}" if args.k8s_only else f"Full destroy of {env}")
    print_plan(cfg, args.k8s_only)
    if not confirm(f"Proceed with {'Kubernetes cleanup' if args.k8s_only else 'DESTROY'} of {env}?"):
        info("Cancelled.")
        return

    if clean_k8s:
        banner(f"Step 1: Kubernetes cleanup ({env})")
        cleaned = cleanup_kubernetes(cfg, dry_run=False)
        if args.k8s_only:
            if not cleaned:
                die(f"Kubernetes cleanup of {env} failed: cluster unreachable.")
            success(f"Kubernetes workloads of {env} removed; cluster is back to its post-apply state.")
            return
        if cleaned:
            info(f"Waiting {LB_RELEASE_WAIT_SECONDS}s for cloud load balancers to be released...")
            time.sleep(LB_RELEASE_WAIT_SECONDS)
        else:
            warn("Skipping Kubernetes cleanup; continuing with terraform destroy.")

    banner(f"Step 2: terraform destroy ({env})")
    if not terraform_destroy(args.env, dry_run=False):
        die(f"terraform destroy failed for {env} after {TF_DESTROY_ATTEMPTS} attempts.")
    success(f"Environment {env} destroyed.")


if __name__ == "__main__":
    main()
