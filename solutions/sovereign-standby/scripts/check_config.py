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
"""Validation script for Federation Demo environment configurations."""

import sys
from pathlib import Path
import ipaddress
import yaml

ENVS_DIR = Path(__file__).resolve().parent.parent / "terraform" / "envs"


def validate_bgp_ip_pair(env_name: str, interface_name: str, cr_ip_str: str, peer_ip_str: str) -> list:
    """Validates BGP CR and Peer IPs: format, link-local range, same /30 subnet, distinct IPs, and usable hosts."""
    errors = []
    try:
        cr_ip = ipaddress.ip_address(cr_ip_str)
        peer_ip = ipaddress.ip_address(peer_ip_str)

        if cr_ip == peer_ip:
            errors.append(f"[{env_name}] BGP CR IP and Peer IP for {interface_name} cannot be the same ({cr_ip_str})")
            return errors

        if not (cr_ip.is_link_local and peer_ip.is_link_local):
            errors.append(f"[{env_name}] BGP IPs for {interface_name} must be link-local (169.254.x.x). Got CR: {cr_ip_str}, Peer: {peer_ip_str}")
            return errors

        # Check if they share a /30 subnet
        if1 = ipaddress.ip_interface(f"{cr_ip_str}/30")
        if2 = ipaddress.ip_interface(f"{peer_ip_str}/30")
        if if1.network != if2.network:
            errors.append(f"[{env_name}] BGP IP {cr_ip_str} and Peer IP {peer_ip_str} for {interface_name} must be in the same /30 subnet")

        # Ensure they are not network or broadcast addresses
        if cr_ip == if1.network.network_address or cr_ip == if1.network.broadcast_address:
            errors.append(f"[{env_name}] BGP CR IP {cr_ip_str} for {interface_name} cannot be network or broadcast address of /30")
        if peer_ip == if2.network.network_address or peer_ip == if2.network.broadcast_address:
            errors.append(f"[{env_name}] BGP Peer IP {peer_ip_str} for {interface_name} cannot be network or broadcast address of /30")

    except ValueError as e:
        errors.append(f"[{env_name}] Invalid IP format for {interface_name}: {e}")
    return errors


def main():
    envs = {}
    for p in ENVS_DIR.glob("*/defaults.yaml"):
        with open(p) as f:
            envs[p.parent.name] = yaml.safe_load(f)

    if not envs:
        sys.exit("ERROR: No environments found in terraform/envs/")

    errors = []

    # 2. Module dependency check (Networking required for CloudSQL and App)
    for env_name, env_cfg in envs.items():
        has_cloudsql = env_cfg.get("enable_cloudsql", False)
        has_app = env_cfg.get("enable_app", False)
        if has_cloudsql and not env_cfg.get("enable_network"):
            errors.append(
                f"[{env_name}] CloudSQL module is enabled (enable_cloudsql = true), but network module is disabled (enable_network = false). Network is required for CloudSQL."
            )
        if has_app and not env_cfg.get("enable_network"):
            errors.append(
                f"[{env_name}] App module is enabled (enable_app = true), but network module is disabled (enable_network = false). Network is required for App."
            )

    # 3. Network matching check (local/remote CIDRs match across environments)
    net_envs = [list(envs.items())[i] for i in range(len(envs)) if envs[list(envs.keys())[i]].get("enable_network")]
    if len(net_envs) >= 2:
        (name1, e1), (name2, e2) = net_envs[0], net_envs[1]
        n1, n2 = e1.get("network", {}), e2.get("network", {})

        if n1.get("local_subnet_cidr") != n2.get("remote_subnet_cidr"):
            errors.append(
                f"CIDR mismatch: {name1}.local_subnet_cidr ({n1.get('local_subnet_cidr')}) != {name2}.remote_subnet_cidr ({n2.get('remote_subnet_cidr')})"
            )
        if n2.get("local_subnet_cidr") != n1.get("remote_subnet_cidr"):
            errors.append(
                f"CIDR mismatch: {name2}.local_subnet_cidr ({n2.get('local_subnet_cidr')}) != {name1}.remote_subnet_cidr ({n1.get('remote_subnet_cidr')})"
            )

        # Internal Subnet / Format Checks for each env
        for name, env_cfg in net_envs:
            n = env_cfg.get("network", {})
            errors.extend(validate_bgp_ip_pair(name, "Interface 0", n.get("bgp_cr_interface_0_ip"), n.get("bgp_peer_interface_0_ip")))
            errors.extend(validate_bgp_ip_pair(name, "Interface 1", n.get("bgp_cr_interface_1_ip"), n.get("bgp_peer_interface_1_ip")))

        # Cross-Environment BGP IP matching checks
        # Interface 0 cross check
        if n1.get("bgp_cr_interface_0_ip") != n2.get("bgp_peer_interface_0_ip"):
            errors.append(
                f"BGP IP mismatch: {name1}.bgp_cr_interface_0_ip ({n1.get('bgp_cr_interface_0_ip')}) != {name2}.bgp_peer_interface_0_ip ({n2.get('bgp_peer_interface_0_ip')})"
            )
        if n1.get("bgp_peer_interface_0_ip") != n2.get("bgp_cr_interface_0_ip"):
            errors.append(
                f"BGP IP mismatch: {name1}.bgp_peer_interface_0_ip ({n1.get('bgp_peer_interface_0_ip')}) != {name2}.bgp_cr_interface_0_ip ({n2.get('bgp_cr_interface_0_ip')})"
            )

        # Interface 1 cross check
        if n1.get("bgp_cr_interface_1_ip") != n2.get("bgp_peer_interface_1_ip"):
            errors.append(
                f"BGP IP mismatch: {name1}.bgp_cr_interface_1_ip ({n1.get('bgp_cr_interface_1_ip')}) != {name2}.bgp_peer_interface_1_ip ({n2.get('bgp_peer_interface_1_ip')})"
            )
        if n1.get("bgp_peer_interface_1_ip") != n2.get("bgp_cr_interface_1_ip"):
            errors.append(
                f"BGP IP mismatch: {name1}.bgp_peer_interface_1_ip ({n1.get('bgp_peer_interface_1_ip')}) != {name2}.bgp_cr_interface_1_ip ({n2.get('bgp_cr_interface_1_ip')})"
            )

    if errors:
        for err in errors:
            print(f"[FAIL] {err}")
        sys.exit(1)

    print("[OK] Configuration validation passed successfully.")


if __name__ == "__main__":
    main()
