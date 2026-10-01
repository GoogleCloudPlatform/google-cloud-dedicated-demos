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
"""Shared helpers for the sovereign-standby management scripts.

* ``get_env_config`` - a typed, merged view of ``defaults.yaml`` + Terraform outputs.
* ``run`` - subprocess wrapper with dry-run support and secret masking.
* CLI helpers - ``banner``, ``info``, ``warn``, ``die``, ``confirm``, ``add_dry_run_flag``.
* Kubernetes helpers - ``kubectl_json``, ``describe_kube_context``.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import shlex
import subprocess
import sys
from typing import NoReturn

import yaml

ROOT_DIR = Path(__file__).resolve().parent.parent
ENVS_DIR = ROOT_DIR / "terraform" / "envs"
ENV_NAMES = ("gcp", "gcd")

DEFAULT_CLUSTER_NAME = "federation-gke-cluster"
DEFAULT_DB_NAME = "bankofanthos"
DEFAULT_DB_USER = "bankuser"

# `key=value` arguments whose key contains one of these words are masked in logs.
_SECRET_KEY_WORDS = ("password", "secret", "token")
_MASK = "<secret>"


# --------------------------------------------------------------------------- #
# Console output                                                              #
# --------------------------------------------------------------------------- #


def banner(title: str) -> None:
    line = "=" * 73
    print(f"\n{line}\n=== {title}\n{line}")


def info(msg: str) -> None:
    print(f"[*] {msg}")


def success(msg: str) -> None:
    print(f"[SUCCESS] {msg}")


def warn(msg: str) -> None:
    print(f"[!] {msg}", file=sys.stderr)


def die(msg: str) -> NoReturn:
    print(f"[ERROR] {msg}", file=sys.stderr)
    sys.exit(1)


def confirm(question: str, default: bool = False) -> bool:
    """Ask a yes/no question. Non-interactive stdin (EOF) counts as 'no'."""
    suffix = "[Y/n]" if default else "[y/N]"
    try:
        answer = input(f"{question} {suffix}: ").strip().lower()
    except EOFError:
        print()
        return False
    if not answer:
        return default
    return answer in ("y", "yes")


# --------------------------------------------------------------------------- #
# CLI                                                                         #
# --------------------------------------------------------------------------- #


def add_dry_run_flag(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--dry",
        "--dry-run",
        "-d",
        dest="dry_run",
        action="store_true",
        help="Print the equivalent manual commands instead of executing them (codelab mode)",
    )


def add_env_argument(parser: argparse.ArgumentParser, **kwargs) -> None:
    parser.add_argument("env", choices=ENV_NAMES, help="Target universe", **kwargs)


# --------------------------------------------------------------------------- #
# Command execution                                                           #
# --------------------------------------------------------------------------- #


def _mask_secret(arg: str) -> str:
    key, sep, _ = arg.partition("=")
    if sep and any(word in key.lower() for word in _SECRET_KEY_WORDS):
        return f"{key}={_MASK}"
    return arg


def format_cmd(cmd: list[str], cwd: Path | None = None) -> str:
    """Render a command as a copy-pasteable shell line with secrets masked."""
    line = shlex.join(_mask_secret(arg) for arg in cmd)
    if cwd and cwd != ROOT_DIR:
        try:
            cwd_display = cwd.relative_to(ROOT_DIR)
        except ValueError:
            cwd_display = cwd
        line = f"(cd {shlex.quote(str(cwd_display))} && {line})"
    return line


def run(
    cmd: list[str],
    *,
    dry_run: bool = False,
    check: bool = False,
    capture: bool = False,
    stdin: str | None = None,
    cwd: Path | None = None,
    quiet: bool = False,
) -> subprocess.CompletedProcess:
    """Run a command (or just print it in dry-run mode).

    check=True aborts the script with a readable error instead of a traceback.
    capture=True captures stdout/stderr (text) instead of streaming them.
    quiet=True suppresses the "[EXEC] ..." log line.
    """
    display = format_cmd(cmd, cwd)
    if dry_run:
        print(display)
        return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

    if not quiet:
        print(f"[EXEC] {display}")
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd or ROOT_DIR,
            capture_output=capture,
            text=True,
            input=stdin,
            check=False,
        )
    except FileNotFoundError:
        die(f"'{cmd[0]}' not found in PATH. Run inside `nix develop` or install it.")

    if check and result.returncode != 0:
        details = (result.stderr or "").strip() if capture else ""
        die(f"Command failed (exit {result.returncode}): {display}" + (f"\n{details}" if details else ""))
    return result


def kubectl_json(args: list[str]) -> dict | None:
    """Run `kubectl <args> -o json` and parse the result; None on any failure."""
    res = run(["kubectl", *args, "-o", "json", "--request-timeout=15s"], capture=True, quiet=True)
    if res.returncode != 0:
        return None
    try:
        return json.loads(res.stdout or "{}")
    except json.JSONDecodeError:
        return None


# --------------------------------------------------------------------------- #
# Environment configuration                                                   #
# --------------------------------------------------------------------------- #


def load_env_defaults(env: str) -> dict:
    """Load terraform/envs/<env>/defaults.yaml (empty dict if missing)."""
    path = ENVS_DIR / env / "defaults.yaml"
    if not path.is_file():
        return {}
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as exc:
        die(f"Cannot parse {path.relative_to(ROOT_DIR)}: {exc}")


def has_terraform_state(env: str) -> bool:
    """True if the environment was initialised (local state file or .terraform dir)."""
    env_dir = ENVS_DIR / env
    return (env_dir / "terraform.tfstate").is_file() or (env_dir / ".terraform").is_dir()


def get_terraform_outputs(env: str) -> dict:
    """Return `terraform output -json` values, or {} if unavailable."""
    if not has_terraform_state(env):
        return {}
    try:
        res = subprocess.run(
            ["terraform", "output", "-json"],
            cwd=ENVS_DIR / env,
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        warn("terraform not found in PATH; using defaults.yaml values only.")
        return {}
    if res.returncode != 0:
        first_line = (res.stderr or "").strip().splitlines()[:1]
        warn(f"`terraform output` failed for '{env}' ({' '.join(first_line)}); using defaults.yaml only.")
        return {}
    try:
        return {key: item.get("value") for key, item in json.loads(res.stdout or "{}").items()}
    except (json.JSONDecodeError, AttributeError):
        warn(f"Unexpected `terraform output -json` format for '{env}'; using defaults.yaml only.")
        return {}


def _first(*values, default=""):
    """Return the first value that is neither None nor an empty string."""
    for value in values:
        if value not in (None, ""):
            return value
    return default


@dataclass(frozen=True)
class EnvConfig:
    """Merged configuration for one universe. Terraform outputs win over defaults.yaml."""

    name: str
    project_id: str
    region: str
    zone: str
    prefix: str
    cluster_name: str
    enable_app: bool
    enable_cloudsql: bool
    enable_network: bool
    db_host: str
    db_name: str
    db_user: str
    db_password: str
    db_admin_password: str

    @property
    def is_primary(self) -> bool:
        return self.name == "gcp"

    @property
    def db_flavor(self) -> str:
        return "cloudsql" if self.enable_cloudsql else "alloydb"


def get_env_config(env: str) -> EnvConfig:
    cfg = load_env_defaults(env)
    out = get_terraform_outputs(env)

    general = cfg.get("general") or {}
    network = cfg.get("network") or {}
    db = cfg.get("cloudsql_db") or {}
    gke = cfg.get("gke") or {}

    prefix = _first(out.get("prefix"), general.get("prefix"))
    cluster_name = _first(out.get("gke_cluster_name"), gke.get("cluster_name"), default=DEFAULT_CLUSTER_NAME)
    if prefix and not cluster_name.startswith(prefix):
        cluster_name = f"{prefix}{cluster_name}"

    return EnvConfig(
        name=env,
        project_id=_first(out.get("project_id"), general.get("project_id")),
        region=_first(out.get("region"), network.get("region")),
        zone=_first(out.get("zone"), network.get("zone")),
        prefix=prefix,
        cluster_name=cluster_name,
        enable_app=bool(cfg.get("enable_app", False)),
        enable_cloudsql=bool(cfg.get("enable_cloudsql", False)),
        enable_network=bool(cfg.get("enable_network", False)),
        db_host=_first(out.get("db_host"), db.get("psc_ip")),
        db_name=_first(out.get("db_name"), db.get("db_name"), default=DEFAULT_DB_NAME),
        db_user=_first(out.get("db_user"), db.get("db_user"), default=DEFAULT_DB_USER),
        db_password=_first(out.get("db_password"), db.get("repl_password")),
        db_admin_password=_first(out.get("db_admin_password"), db.get("admin_password")),
    )


# --------------------------------------------------------------------------- #
# Kubernetes context                                                          #
# --------------------------------------------------------------------------- #


def current_kube_context() -> str:
    res = run(["kubectl", "config", "current-context"], capture=True, quiet=True)
    return res.stdout.strip() if res.returncode == 0 else ""


def expected_kube_context(cfg: EnvConfig) -> str:
    """Context name created by `gcloud container clusters get-credentials` (see README)."""
    return f"gke_{cfg.project_id}_{cfg.region}_{cfg.cluster_name}"


def describe_kube_context(cfg: EnvConfig) -> None:
    """Print the active kubectl context and warn if it does not look like `cfg`'s cluster.

    GCP and GCD clusters share the same name, so the project/region part matters.
    Switching contexts (and gcloud universes) is intentionally left to the user.
    """
    current = current_kube_context() or "<none>"
    expected = expected_kube_context(cfg)
    print(f"kubectl ctx : {current}")
    if current != expected:
        warn(f"Active kubectl context does not match the {cfg.name.upper()} cluster (expected '{expected}'). "
             "See README 'kubectl Cluster Credentials Setup'.")
