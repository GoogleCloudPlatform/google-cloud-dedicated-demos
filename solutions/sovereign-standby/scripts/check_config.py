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
"""Validate terraform/envs/{gcp,gcd}/defaults.yaml for cross-universe consistency.

Usage: just check-config

Checks:
  * modules that need networking (cloudsql, app, sts) have it enabled;
  * networking is enabled in both universes or in neither;
  * BGP link-local addresses are valid /30 peers;
  * "local" values in one universe mirror "remote"/"peer" values in the other.
"""

import ipaddress
import sys

from env_utils import ENV_NAMES, ENVS_DIR, load_env_defaults

MODULES_REQUIRING_NETWORK = ("cloudsql", "app", "sts")

BGP_INTERFACES = [
    ("Interface 0", "bgp_cr_interface_0_ip", "bgp_peer_interface_0_ip"),
    ("Interface 1", "bgp_cr_interface_1_ip", "bgp_peer_interface_1_ip"),
]

# network.<a> in one universe must equal network.<b> in the other (checked both ways).
MIRRORED_NETWORK_KEYS = [
    ("local_subnet_cidr", "remote_subnet_cidr"),
    ("local_asn", "remote_asn"),
    ("bgp_cr_interface_0_ip", "bgp_peer_interface_0_ip"),
    ("bgp_cr_interface_1_ip", "bgp_peer_interface_1_ip"),
]


def validate_bgp_pair(env: str, label: str, cr: str | None, peer: str | None) -> list[str]:
    """Cloud Router and peer IPs must be distinct usable hosts of the same link-local /30."""
    prefix = f"[{env}] BGP {label}"
    if not cr or not peer:
        return [f"{prefix}: missing Cloud Router or peer IP"]
    try:
        cr_if = ipaddress.ip_interface(f"{cr}/30")
        peer_if = ipaddress.ip_interface(f"{peer}/30")
    except ValueError as exc:
        return [f"{prefix}: invalid IP ({exc})"]

    if cr_if.ip == peer_if.ip:
        return [f"{prefix}: Cloud Router and peer IP are identical ({cr})"]
    if not (cr_if.ip.is_link_local and peer_if.ip.is_link_local):
        return [f"{prefix}: IPs must be link-local 169.254.x.x (got {cr}, {peer})"]
    if cr_if.network != peer_if.network:
        return [f"{prefix}: {cr} and {peer} must be in the same /30"]

    net = cr_if.network
    reserved = (net.network_address, net.broadcast_address)
    return [f"{prefix}: {ip} is the network/broadcast address of {net}" for ip in (cr_if.ip, peer_if.ip) if ip in reserved]


def validate(envs: dict[str, dict]) -> list[str]:
    """Return a list of human-readable errors for the given {env_name: defaults.yaml} mapping."""
    errors = []

    for env, cfg in envs.items():
        if cfg.get("enable_network"):
            continue
        for module in MODULES_REQUIRING_NETWORK:
            if cfg.get(f"enable_{module}"):
                errors.append(f"[{env}] enable_{module} requires enable_network: true")

    network_enabled = {env: bool(cfg.get("enable_network")) for env, cfg in envs.items()}
    if len(set(network_enabled.values())) > 1:
        errors.append(f"enable_network must match in both universes (got {network_enabled})")
        return errors
    if len(envs) < 2 or not all(network_enabled.values()):
        return errors

    (env_a, cfg_a), (env_b, cfg_b) = envs.items()
    net = {env_a: cfg_a.get("network") or {}, env_b: cfg_b.get("network") or {}}

    for env, n in net.items():
        for label, cr_key, peer_key in BGP_INTERFACES:
            errors += validate_bgp_pair(env, label, n.get(cr_key), n.get(peer_key))

    for this, other in ((env_a, env_b), (env_b, env_a)):
        for local_key, remote_key in MIRRORED_NETWORK_KEYS:
            local_val, remote_val = net[this].get(local_key), net[other].get(remote_key)
            if local_val != remote_val:
                errors.append(f"Mismatch: {this}.network.{local_key} ({local_val}) != "
                              f"{other}.network.{remote_key} ({remote_val})")
    return errors


def main() -> None:
    missing = [env for env in ENV_NAMES if not (ENVS_DIR / env / "defaults.yaml").is_file()]
    if missing:
        sys.exit(f"[FAIL] Missing terraform/envs/{{{','.join(missing)}}}/defaults.yaml - run `just init-config` first.")

    errors = validate({env: load_env_defaults(env) for env in ENV_NAMES})
    for err in errors:
        print(f"[FAIL] {err}")
    if errors:
        sys.exit(1)
    print("[OK] Configuration validation passed.")


if __name__ == "__main__":
    main()
