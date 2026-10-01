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
"""Interactively generate terraform/envs/{gcp,gcd}/defaults.yaml.

Usage: just init-config [--dry]

With --dry the generated YAML is printed instead of written to disk.
"""

import argparse
import getpass
import sys

import yaml

from check_config import validate
from env_utils import ENV_NAMES, ENVS_DIR, ROOT_DIR, add_dry_run_flag, banner, confirm, die

# Per-universe defaults. The "gcd" side is the Google Cloud Dedicated (Berlin) test universe.
UNIVERSE_DEFAULTS = {
    "gcp": {
        "universe_domain": "googleapis.com",
        "region": "europe-west1",
        "zone": "europe-west1-b",
        "subnet_cidr": "10.0.1.0/24",
        "asn": 64514,
        "bgp_cr_0": "169.254.1.1",
        "bgp_cr_1": "169.254.2.1",
        "psc_ip": "10.0.1.100",
        "vm_machine_type": "n1-standard-1",
        "vm_image": "debian-cloud/debian-12",
        "pods_cidr": "10.101.0.0/16",
        "services_cidr": "10.102.0.0/20",
        "db_tier": "db-custom-2-7680",
        "db_role": "primary",
    },
    "gcd": {
        "universe_domain": "apis-berlin-build0.goog",
        "region": "u-germany-northeast1",
        "zone": "u-germany-northeast1-a",
        "subnet_cidr": "10.0.2.0/24",
        "asn": 64515,
        "bgp_cr_0": "169.254.1.2",
        "bgp_cr_1": "169.254.2.2",
        "psc_ip": "10.0.2.100",
        "vm_machine_type": "c3-standard-4",
        "vm_image": "eu0-system:debian-cloud/debian-12",
        "pods_cidr": "10.105.0.0/16",
        "services_cidr": "10.103.0.0/20",
        "db_tier": "db-perf-optimized-C-4",
        "db_role": "replica",
    },
}


def peer_of(env: str) -> str:
    return "gcd" if env == "gcp" else "gcp"


# --------------------------------------------------------------------------- #
# Prompts                                                                     #
# --------------------------------------------------------------------------- #


def _ask(label: str, secret: bool = False) -> str:
    try:
        if secret and sys.stdin.isatty():
            return getpass.getpass(label).strip()
        return input(label).strip()
    except EOFError:
        die("Input aborted.")


def prompt_str(text: str, default: str = "") -> str:
    return _ask(f"{text} [{default}]: ") or default


def prompt_secret(text: str, default: str = "") -> str:
    return _ask(f"{text} [{'****' if default else ''}]: ", secret=True) or default


def prompt_bool(text: str, default: bool) -> bool:
    while True:
        answer = _ask(f"{text} (yes/no) [{'yes' if default else 'no'}]: ").lower()
        if not answer:
            return default
        if answer in ("y", "yes", "true", "1"):
            return True
        if answer in ("n", "no", "false", "0"):
            return False
        print("  Please answer 'yes' or 'no'.")


def prompt_int(text: str, default: int) -> int:
    while True:
        answer = prompt_str(text, str(default))
        try:
            return int(answer)
        except ValueError:
            print(f"  '{answer}' is not a number.")


# --------------------------------------------------------------------------- #
# Interview                                                                   #
# --------------------------------------------------------------------------- #


def ask_modules() -> dict:
    print("--- Step 1: Modules ---")
    modules = {"network": prompt_bool("Enable networking (VPC, HA VPN)", True)}
    modules["app"] = prompt_bool("Enable application (GKE + Bank of Anthos)", True)
    modules["cloudsql"] = modules["app"] and (
        prompt_str("Database flavor (cloudsql/alloydb)", "cloudsql").lower() != "alloydb"
    )
    modules["auth"] = prompt_bool("Enable WIF auth", False)
    modules["sts"] = prompt_bool("Enable STS storage transfer", False)
    modules["monitoring"] = prompt_bool("Enable monitoring dashboard (GCP only)", False)

    if not modules["network"] and (modules["app"] or modules["sts"]):
        print("[NOTE] App, Cloud SQL and STS require networking - enabling it.")
        modules["network"] = True
    return modules


def ask_shared(modules: dict) -> dict:
    print("\n--- Step 2: Shared parameters ---")
    shared = {"prefix": prompt_str("Resource prefix (e.g. 'alice-')", "")}

    if modules["auth"]:
        shared["federated_user_email"] = prompt_str("Federated user email", "myuser@federationtesting.com")
        shared["idp_metadata_xml_file"] = prompt_str("IdP metadata XML filename", "descriptor.xml")

    if modules["cloudsql"]:
        shared["admin_password"] = prompt_secret("Cloud SQL admin password", "REPLACE_ME")
        shared["repl_password"] = prompt_secret("Cloud SQL replication password", "REPLACE_ME")

    if modules["sts"]:
        shared["source_bucket_name"] = prompt_str("GCS source bucket (GCP)", "source-bucket")
        shared["dest_bucket_name"] = prompt_str("GCS destination bucket (GCD)", "destination-bucket")
        shared["agent_pool_name"] = prompt_str("STS agent pool name", "sts-agent-pool")
        shared["transfer_job_name"] = prompt_str("STS transfer job name", "gcs-to-gcs-over-posix-on-demand")
        shared["sts_agent_vm_name"] = prompt_str("STS agent VM name (GCD)", "sts-agent-vm")

    if modules["network"]:
        shared["shared_ike_key"] = prompt_secret("Shared IKE key for HA VPN", "REPLACE_ME")
        shared["allowed_ssh_source_ip"] = prompt_str("Allowed SSH source IP for test VM", "REPLACE_ME")
        shared["create_test_vm"] = prompt_bool("Create ping test VMs (requires external IP)", False)
        shared["google_apis_psc_ip"] = prompt_str("Google APIs PSC IP (outside subnets)", "10.100.100.1")
    return shared


def ask_universe(env: str, step: int, modules: dict) -> dict:
    defaults = UNIVERSE_DEFAULTS[env]
    banner(f"Step {step}: {env.upper()} environment")
    u = {"universe_domain": defaults["universe_domain"]}
    if env != "gcp":
        u["universe_domain"] = prompt_str(f"Universe domain for {env}", defaults["universe_domain"])
    u["project_id"] = prompt_str(f"Project ID for {env}", "")
    u["org_id"] = prompt_str(f"Organization ID for {env}", "")

    if modules["network"]:
        for key, label in [("region", "Region"), ("zone", "Zone"), ("subnet_cidr", "Subnet CIDR")]:
            u[key] = prompt_str(f"{label} for {env}", defaults[key])
        u["asn"] = prompt_int(f"BGP ASN for {env}", defaults["asn"])
        u["bgp_cr_0"] = prompt_str(f"BGP Cloud Router interface 0 IP for {env}", defaults["bgp_cr_0"])
        u["bgp_cr_1"] = prompt_str(f"BGP Cloud Router interface 1 IP for {env}", defaults["bgp_cr_1"])

    if modules["cloudsql"]:
        u["psc_ip"] = prompt_str(f"Cloud SQL PSC IP for {env}", defaults["psc_ip"])
    return u


# --------------------------------------------------------------------------- #
# defaults.yaml builder                                                       #
# --------------------------------------------------------------------------- #


def build_env_config(env: str, universes: dict, shared: dict, modules: dict) -> dict:
    """Build defaults.yaml content for `env`; peer values come from the other universe."""
    is_gcp = env == "gcp"
    me, peer = universes[env], universes[peer_of(env)]
    defaults = UNIVERSE_DEFAULTS[env]

    config = {
        "enable_auth": modules["auth"],
        "enable_network": modules["network"],
        "enable_sts": modules["sts"],
        "enable_cloudsql": modules["cloudsql"],
        "enable_app": modules["app"],
        "enable_monitoring": modules["monitoring"] and is_gcp,
        "enable_psc_outbound": False,  # switched on in deployment step 2 (see README)
        "general": {
            "universe_domain": me["universe_domain"],
            "org_id": me["org_id"],
            "project_id": me["project_id"],
            "prefix": shared["prefix"],
            "is_gcp": is_gcp,
        },
    }

    if modules["auth"]:
        config["auth"] = {
            "pool_id": "federation-demo-pool",
            "provider_id": "keycloak-provider",
            "federated_user_email": shared["federated_user_email"],
            "idp_metadata_xml_file": shared["idp_metadata_xml_file"],
        }

    if modules["network"]:
        config["network"] = {
            "region": me["region"],
            "zone": me["zone"],
            "local_subnet_cidr": me["subnet_cidr"],
            "remote_subnet_cidr": peer["subnet_cidr"],
            "local_asn": me["asn"],
            "remote_asn": peer["asn"],
            "shared_ike_key": shared["shared_ike_key"],
            "create_test_vm": shared["create_test_vm"],
            "vm_machine_type": defaults["vm_machine_type"],
            "vm_image": defaults["vm_image"],
            "bgp_cr_interface_0_ip": me["bgp_cr_0"],
            "bgp_peer_interface_0_ip": peer["bgp_cr_0"],
            "bgp_cr_interface_1_ip": me["bgp_cr_1"],
            "bgp_peer_interface_1_ip": peer["bgp_cr_1"],
            "allowed_ssh_source_ip": shared["allowed_ssh_source_ip"],
            "google_apis_psc_ip": shared["google_apis_psc_ip"],
            # Filled in after the peer's baseline `terraform apply` (README step 2).
            "remote_vpn_interface_0_ip": "",
            "remote_vpn_interface_1_ip": "",
            "secondary_ip_ranges": [
                {"range_name": "pods", "ip_cidr_range": defaults["pods_cidr"]},
                {"range_name": "services", "ip_cidr_range": defaults["services_cidr"]},
            ],
        }

    if modules["sts"]:
        if is_gcp:
            config["gcs"] = {
                "source_bucket_name": shared["source_bucket_name"],
                "agent_pool_name": shared["agent_pool_name"],
                "transfer_job_name": shared["transfer_job_name"],
            }
        else:
            config["gcs"] = {
                "gcp_project_id": peer["project_id"],
                "dest_bucket_name": shared["dest_bucket_name"],
                "dest_bucket_location": me.get("region", defaults["region"]),
                "agent_pool_name": shared["agent_pool_name"],
                "sts_agent_vm_name": shared["sts_agent_vm_name"],
            }

    if modules["cloudsql"]:
        config["cloudsql_db"] = {
            "db_tier": defaults["db_tier"],
            "psc_ip": me["psc_ip"],
            "admin_password": shared["admin_password"],
            "repl_password": shared["repl_password"],
            "db_name": "bankofanthos",
            "db_user": "bankuser",
            "db_role": defaults["db_role"],
        }

    if modules["app"]:
        config["gke"] = {"cluster_name": "federation-gke-cluster"}

    return config


def to_yaml(config: dict) -> str:
    return yaml.safe_dump(config, sort_keys=False, default_flow_style=False)


# --------------------------------------------------------------------------- #
# Entry point                                                                 #
# --------------------------------------------------------------------------- #


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    add_dry_run_flag(parser)
    args = parser.parse_args()

    banner("Sovereign standby configurator" + (" [DRY-RUN]" if args.dry_run else ""))
    modules = ask_modules()
    shared = ask_shared(modules)
    universes = {env: ask_universe(env, step, modules) for step, env in enumerate(ENV_NAMES, start=3)}
    configs = {env: build_env_config(env, universes, shared, modules) for env in ENV_NAMES}

    errors = validate(configs)
    if errors:
        print("\n[WARN] The generated configuration has problems:")
        for err in errors:
            print(f"  - {err}")

    paths = {env: ENVS_DIR / env / "defaults.yaml" for env in ENV_NAMES}

    if args.dry_run:
        banner("[DRY-RUN] Manual configuration steps")
        for env, path in paths.items():
            print(f"# {path.relative_to(ROOT_DIR)}\n---\n{to_yaml(configs[env])}")
        print("Validate with: just check-config")
        return

    if errors and not confirm("Save anyway?"):
        die("Aborted; nothing was written.")

    existing = [str(p.relative_to(ROOT_DIR)) for p in paths.values() if p.exists()]
    if existing and not confirm(f"Overwrite existing {', '.join(existing)} (VPN peer IPs will be reset)?"):
        die("Aborted; nothing was written.")

    for env, path in paths.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(to_yaml(configs[env]), encoding="utf-8")
        print(f"[+] Wrote {path.relative_to(ROOT_DIR)}")
    print("\nNext step: just check-config")


if __name__ == "__main__":
    main()
