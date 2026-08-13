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
"""Interactive configurator for GCP and GCD defaults.yaml files."""

from pathlib import Path
import yaml

ENVS_DIR = Path(__file__).resolve().parent.parent / "terraform" / "envs"


def prompt_str(text: str, default: str = "") -> str:
    res = input(f"{text} [{default}]: ").strip()
    return res if res else default


def prompt_bool(text: str, default: bool = True) -> bool:
    default_str = "yes" if default else "no"
    res = input(f"{text} (yes/no) [default: {default_str}]: ").strip().lower()
    if not res:
        return default
    return res in ("y", "yes", "true", "1")


def create_env_config(
    universe_domain: str,
    org_id: str,
    project_id: str,
    prefix: str,
    region: str,
    zone: str,
    local_subnet_cidr: str,
    remote_subnet_cidr: str,
    local_asn: int,
    remote_asn: int,
    shared_ike_key: str,
    bgp_cr_0: str,
    bgp_peer_0: str,
    bgp_cr_1: str,
    bgp_peer_1: str,
    allowed_ssh_source_ip: str,
    psc_ip: str,
    admin_password: str,
    repl_password: str,
    db_role: str,
    create_test_vm: bool,
    federated_user_email: str,
    idp_metadata_xml_file: str,
    source_bucket_name: str,
    dest_bucket_name: str,
    agent_pool_name: str,
    transfer_job_name: str,
    sts_agent_vm_name: str,
    google_apis_psc_ip: str,
    gcp_project_id: str = "",
    enable_auth: bool = False,
    enable_network: bool = True,
    enable_sts: bool = False,
    enable_cloudsql: bool = True,
    enable_app: bool = True,
    enable_monitoring: bool = False,
    enable_psc_outbound: bool = False,
) -> dict:
    is_gcp = "googleapis" in universe_domain
    config = {
        "enable_auth": enable_auth,
        "enable_network": enable_network,
        "enable_sts": enable_sts,
        "enable_cloudsql": enable_cloudsql,
        "enable_app": enable_app,
        "enable_monitoring": enable_monitoring,
        "enable_psc_outbound": enable_psc_outbound,
        "general": {
            "universe_domain": universe_domain,
            "org_id": org_id,
            "project_id": project_id,
            "prefix": prefix,
            "is_gcp": is_gcp,
        },
    }
    if enable_auth:
        config["auth"] = {
            "pool_id": "federation-demo-pool",
            "provider_id": "keycloak-provider",
            "federated_user_email": federated_user_email,
            "idp_metadata_xml_file": idp_metadata_xml_file,
        }
    config["network"] = {
        "region": region,
        "zone": zone,
        "local_subnet_cidr": local_subnet_cidr,
        "remote_subnet_cidr": remote_subnet_cidr,
        "local_asn": local_asn,
        "remote_asn": remote_asn,
        "shared_ike_key": shared_ike_key,
        "create_test_vm": create_test_vm,
        "vm_machine_type": (
            "n1-standard-1" if is_gcp else "c3-standard-4"
        ),
        "vm_image": (
            "debian-cloud/debian-12"
            if is_gcp
            else "eu0-system:debian-cloud/debian-12"
        ),
        "bgp_cr_interface_0_ip": bgp_cr_0,
        "bgp_peer_interface_0_ip": bgp_peer_0,
        "bgp_cr_interface_1_ip": bgp_cr_1,
        "bgp_peer_interface_1_ip": bgp_peer_1,
        "allowed_ssh_source_ip": allowed_ssh_source_ip,
        "google_apis_psc_ip": google_apis_psc_ip,
        "remote_vpn_interface_0_ip": "",
        "remote_vpn_interface_1_ip": "",
        "secondary_ip_ranges": [
            {
                "range_name": "pods",
                "ip_cidr_range": "10.101.0.0/16" if is_gcp else "10.105.0.0/16",
            },
            {
                "range_name": "services",
                "ip_cidr_range": "10.102.0.0/20" if is_gcp else "10.103.0.0/20",
            },
        ],
    }
    if enable_sts:
        if is_gcp:
            config["gcs"] = {
                "source_bucket_name": source_bucket_name,
                "agent_pool_name": agent_pool_name,
                "transfer_job_name": transfer_job_name,
            }
        else:
            config["gcs"] = {
                "gcp_project_id": gcp_project_id,
                "dest_bucket_name": dest_bucket_name,
                "dest_bucket_location": region,
                "agent_pool_name": agent_pool_name,
                "sts_agent_vm_name": sts_agent_vm_name,
            }
    if enable_cloudsql:
        config["cloudsql_db"] = {
            "db_tier": (
                "db-custom-2-7680"
                if is_gcp
                else "db-perf-optimized-C-4"
            ),
            "psc_ip": psc_ip,
            "admin_password": admin_password,
            "repl_password": repl_password,
            "db_name": "bankofanthos",
            "db_user": "bankuser",
            "db_role": db_role,
        }
    if enable_app:
        config["gke"] = {"cluster_name": "federation-gke-cluster"}
    return config


def save_defaults_yaml(env_name: str, config_data: dict):
    env_dir = ENVS_DIR / env_name
    env_dir.mkdir(parents=True, exist_ok=True)
    yaml_path = env_dir / "defaults.yaml"
    with open(yaml_path, "w") as f:
        yaml.dump(config_data, f, sort_keys=False, default_flow_style=False)


def main():
    print("==========================================================")
    print(" Federation Demo Environment Interactive Configurator")
    print("==========================================================\n")

    # STEP 1: Module Selection
    print("--- Step 1: Module Selection ---")
    enable_network = prompt_bool("Enable Networking (VPC, HA VPN)", default=True)
    enable_app = prompt_bool("Enable Application?", default=True)

    enable_cloudsql = False

    if enable_app:
        flavor = prompt_str("Select database flavour (cloudsql/alloydb)", default="cloudsql").strip().lower()
        if flavor != "alloydb":
            enable_cloudsql = True

    enable_auth = prompt_bool("Enable WIF Auth", default=False)
    enable_sts = prompt_bool("Enable STS Storage Transfer", default=False)
    enable_monitoring = prompt_bool(
        "Enable Monitoring Dashboard (GCP only)", default=False
    )

    if (enable_cloudsql or enable_app) and not enable_network:
        print(
            "\n[NOTE] App and CloudSQL modules require Networking. Automatically enabling Networking module."
        )
        enable_network = True

    # STEP 2: General Module Parameters
    print("\n--- Step 2: General Parameters ---")
    prefix = prompt_str("Resource Prefix (e.g. 'alice-' or 'dev-')", default="")

    shared_ike_key = "REPLACE_ME"
    allowed_ssh_source_ip = "REPLACE_ME"
    create_test_vm = "REPLACE_ME"
    if enable_network:
        shared_ike_key = prompt_str(
            "Shared IKE Key for HA VPN", default="REPLACE_ME"
        )
        allowed_ssh_source_ip = prompt_str(
            "Allowed SSH Source IP for Test VM", default="REPLACE_ME"
        )
        create_test_vm = prompt_bool(
            "Create Ping Test VM in VPCs (requires external IP)?", default=False
        )

    admin_password = "REPLACE_ME"  # pragma: allowlist secret
    repl_password = "REPLACE_ME"  # pragma: allowlist secret
    if enable_cloudsql:
        admin_password = prompt_str("CloudSQL Admin Password", default="REPLACE_ME")
        repl_password = prompt_str(
            "CloudSQL Replication Password", default="REPLACE_ME"
        )

    federated_user_email = "myuser@federationtesting.com"
    if enable_auth:
        federated_user_email = prompt_str(
            "Federated User Email", default="myuser@federationtesting.com"
        )

    idp_metadata_xml_file = "descriptor.xml"
    if enable_auth:
        idp_metadata_xml_file = prompt_str(
            "IDP Metadata XML Filename", default="descriptor.xml"
        )

    source_bucket_name = "source-bucket-name"
    dest_bucket_name = "destination-bucket-name"
    agent_pool_name = "agent-pool-name"
    transfer_job_name = "gcs-to-gcs-over-posix-on-demand"
    sts_agent_vm_name = "sts-agent-vm"
    google_apis_psc_ip = "10.100.100.1"

    if enable_sts:
        source_bucket_name = prompt_str(
            "GCS Source Bucket Name (GCP)", default="source-bucket"
        )
        dest_bucket_name = prompt_str(
            "GCS Destination Bucket Name (GCD)", default="destination-bucket"
        )
        agent_pool_name = prompt_str(
            "STS Agent Pool Name", default="sts-agent-pool"
        )
        transfer_job_name = prompt_str(
            "Storage Transfer Job Name", default="gcs-to-gcs-over-posix-on-demand"
        )
        sts_agent_vm_name = prompt_str(
            "STS Agent VM Name (GCD)", default="sts-agent-vm"
        )
        google_apis_psc_ip = prompt_str(
            "Google APIs PSC IP (outside subnets)", default="10.100.100.1"
        )

    # STEP 3: GCP Setup
    print("\n==========================================================")
    print(" Step 3: GCP Environment Setup")
    print("==========================================================")
    gcp_project = prompt_str("Project ID for gcp", default="")
    gcp_org_id = prompt_str("GCP Organization ID for gcp", default="")
    gcp_region = prompt_str("Region for gcp", default="europe-west1")
    gcp_zone = prompt_str("Zone for gcp", default="europe-west1-b")

    gcp_subnet_cidr = "10.0.1.0/24"
    gcp_asn = 64514
    gcp_bgp_cr_0 = "169.254.1.1"
    gcp_bgp_cr_1 = "169.254.2.1"
    if enable_network:
        gcp_subnet_cidr = prompt_str("Subnet CIDR for gcp", default="10.0.1.0/24")
        gcp_asn = int(prompt_str("BGP ASN for gcp", default="64514"))
        gcp_bgp_cr_0 = prompt_str("BGP CR Interface 0 IP for gcp", default="169.254.1.1")
        gcp_bgp_cr_1 = prompt_str("BGP CR Interface 1 IP for gcp", default="169.254.2.1")

    gcp_psc_ip = "10.0.1.100"
    if enable_cloudsql:
        gcp_psc_ip = prompt_str("CloudSQL PSC IP for gcp", default="10.0.1.100")

    # STEP 4: GCD Setup
    print("\n==========================================================")
    print(" Step 4: GCD Environment Setup")
    print("==========================================================")
    gcd_universe_domain = prompt_str(
        "Universe Domain for gcd", default="apis-berlin-build0.goog"
    )
    gcd_project = prompt_str("Project ID for gcd", default="")
    gcd_org_id = prompt_str("GCP Organization ID for gcd", default="")
    gcd_region = prompt_str("Region for gcd", default="u-germany-northeast1")
    gcd_zone = prompt_str("Zone for gcd", default="u-germany-northeast1-a")

    gcd_subnet_cidr = "10.0.2.0/24"
    gcd_asn = 64515
    gcd_bgp_cr_0 = "169.254.1.2"
    gcd_bgp_cr_1 = "169.254.2.2"
    if enable_network:
        gcd_subnet_cidr = prompt_str("Subnet CIDR for gcd", default="10.0.2.0/24")
        gcd_asn = int(prompt_str("BGP ASN for gcd", default="64515"))
        gcd_bgp_cr_0 = prompt_str("BGP CR Interface 0 IP for gcd", default="169.254.1.2")
        gcd_bgp_cr_1 = prompt_str("BGP CR Interface 1 IP for gcd", default="169.254.2.2")

    gcd_psc_ip = "10.0.2.100"
    if enable_cloudsql:
        gcd_psc_ip = prompt_str("CloudSQL PSC IP for gcd", default="10.0.2.100")

    # Peer IPs are automatically derived from the other universe's local CR IPs
    gcp_bgp_peer_0 = gcd_bgp_cr_0
    gcp_bgp_peer_1 = gcd_bgp_cr_1
    gcd_bgp_peer_0 = gcp_bgp_cr_0
    gcd_bgp_peer_1 = gcp_bgp_cr_1

    gcp_config = create_env_config(
        universe_domain="googleapis.com",
        org_id=gcp_org_id,
        project_id=gcp_project,
        prefix=prefix,
        region=gcp_region,
        zone=gcp_zone,
        local_subnet_cidr=gcp_subnet_cidr,
        remote_subnet_cidr=gcd_subnet_cidr,
        local_asn=gcp_asn,
        remote_asn=gcd_asn,
        shared_ike_key=shared_ike_key,
        bgp_cr_0=gcp_bgp_cr_0,
        bgp_peer_0=gcp_bgp_peer_0,
        bgp_cr_1=gcp_bgp_cr_1,
        bgp_peer_1=gcp_bgp_peer_1,
        allowed_ssh_source_ip=allowed_ssh_source_ip,
        psc_ip=gcp_psc_ip,
        admin_password=admin_password,
        repl_password=repl_password,
        db_role="primary",
        create_test_vm=create_test_vm,
        federated_user_email=federated_user_email,
        idp_metadata_xml_file=idp_metadata_xml_file,
        source_bucket_name=source_bucket_name,
        dest_bucket_name=dest_bucket_name,
        agent_pool_name=agent_pool_name,
        transfer_job_name=transfer_job_name,
        sts_agent_vm_name=sts_agent_vm_name,
        google_apis_psc_ip=google_apis_psc_ip,
        enable_auth=enable_auth,
        enable_network=enable_network,
        enable_sts=enable_sts,
        enable_cloudsql=enable_cloudsql,
        enable_app=enable_app,
        enable_monitoring=enable_monitoring,
    )

    gcd_config = create_env_config(
        universe_domain=gcd_universe_domain,
        org_id=gcd_org_id,
        project_id=gcd_project,
        prefix=prefix,
        region=gcd_region,
        zone=gcd_zone,
        local_subnet_cidr=gcd_subnet_cidr,
        remote_subnet_cidr=gcp_subnet_cidr,
        local_asn=gcd_asn,
        remote_asn=gcp_asn,
        shared_ike_key=shared_ike_key,
        bgp_cr_0=gcd_bgp_cr_0,
        bgp_peer_0=gcd_bgp_peer_0,
        bgp_cr_1=gcd_bgp_cr_1,
        bgp_peer_1=gcd_bgp_peer_1,
        allowed_ssh_source_ip=allowed_ssh_source_ip,
        psc_ip=gcd_psc_ip,
        admin_password=admin_password,
        repl_password=repl_password,
        db_role="replica",
        create_test_vm=create_test_vm,
        federated_user_email=federated_user_email,
        idp_metadata_xml_file=idp_metadata_xml_file,
        source_bucket_name=source_bucket_name,
        dest_bucket_name=dest_bucket_name,
        agent_pool_name=agent_pool_name,
        transfer_job_name=transfer_job_name,
        sts_agent_vm_name=sts_agent_vm_name,
        google_apis_psc_ip=google_apis_psc_ip,
        gcp_project_id=gcp_project,
        enable_auth=enable_auth,
        enable_network=enable_network,
        enable_sts=enable_sts,
        enable_cloudsql=enable_cloudsql,
        enable_app=enable_app,
        enable_monitoring=False,
    )

    save_defaults_yaml("gcp", gcp_config)
    save_defaults_yaml("gcd", gcd_config)

    print("\n==========================================================")
    print(" Configuration successfully generated!")
    print(" - terraform/envs/gcp/defaults.yaml")
    print(" - terraform/envs/gcd/defaults.yaml")
    print("==========================================================")


if __name__ == "__main__":
    main()
