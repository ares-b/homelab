#!/usr/bin/env python3
"""Rotate homelab secrets.

Usage:
  rotate-secrets.py dagster-db            # rotate CNPG dagster DB password
  rotate-secrets.py pve-passwords         # rotate all PVE user passwords
  rotate-secrets.py pve-passwords --user ares packer
"""

import argparse
import getpass
import secrets
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CONFIG_SOPS = REPO_ROOT / "config.sops.yaml"
SEALED_DAGSTER_CNPG = REPO_ROOT / "k3s-cluster/gitops/infrastructure/apps/postgresql/sealed-dagster-cnpg-role.yaml"
SEALED_DAGSTER_DB = REPO_ROOT / "k3s-cluster/gitops/infrastructure/apps/dagster/sealed-dagster-db.yaml"

KUBESEAL_ARGS = [
    "kubeseal",
    "--controller-name=sealed-secrets-controller",
    "--controller-namespace=sealed-secrets",
    "-o", "yaml",
]


HUMAN_USERS = {"ares"}

def gen_password() -> str:
    return secrets.token_urlsafe(32)


def prompt_password(user: str) -> str:
    while True:
        pw = getpass.getpass(f"New password for {user}: ")
        if not pw:
            print("Password cannot be empty.", file=sys.stderr)
            continue
        confirm = getpass.getpass(f"Confirm password for {user}: ")
        if pw != confirm:
            print("Passwords do not match.", file=sys.stderr)
            continue
        return pw


def run(*args, input=None, check=True) -> str:
    result = subprocess.run(list(args), input=input, capture_output=True, text=True, check=check)
    return result.stdout


def seal(name: str, namespace: str, **literals) -> str:
    kubectl_args = [
        "kubectl", "create", "secret", "generic", name,
        f"--namespace={namespace}",
        "--dry-run=client", "-o", "yaml",
    ] + [f"--from-literal={k}={v}" for k, v in literals.items()]
    secret_yaml = run(*kubectl_args)
    return run(*KUBESEAL_ARGS, input=secret_yaml)


def sops_set(path: str, value: str) -> None:
    run("sops", "--set", f'{path} "{value}"', str(CONFIG_SOPS))


def rotate_dagster_db() -> None:
    password = gen_password()

    print("Sealing dagster-cnpg-role (postgresql namespace)...")
    sealed = seal("dagster-cnpg-role", "postgresql", password=password, username="dagster")
    SEALED_DAGSTER_CNPG.write_text(sealed)

    print("Sealing dagster-postgresql-secret (dagster namespace)...")
    sealed = seal("dagster-postgresql-secret", "dagster", **{"postgresql-password": password})
    SEALED_DAGSTER_DB.write_text(sealed)

    print("Done. Commit and push both sealed secrets — Flux will apply them.")
    print(f"  {SEALED_DAGSTER_CNPG.relative_to(REPO_ROOT)}")
    print(f"  {SEALED_DAGSTER_DB.relative_to(REPO_ROOT)}")


def rotate_pve_passwords(users: list[str]) -> None:
    for user in users:
        key = f"pve_secret_password_{user}"
        password = prompt_password(user) if user in HUMAN_USERS else gen_password()
        sops_set(f'["pve_bootstrap"]["{key}"]', password)
        print(f"Rotated {key}")

    print("Done. Run 'make bootstrap' in pve-bootstrap/ to apply.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Rotate homelab secrets")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("dagster-db", help="Rotate CNPG dagster DB password (both sealed secrets)")

    pve = sub.add_parser("pve-passwords", help="Rotate PVE user passwords in config.sops.yaml")
    pve.add_argument(
        "--user",
        nargs="+",
        dest="users",
        default=["ares", "packer", "terraform"],
        choices=["ares", "packer", "terraform"],
        metavar="USER",
        help="Users to rotate (default: all)",
    )

    args = parser.parse_args()

    if args.cmd == "dagster-db":
        rotate_dagster_db()
    elif args.cmd == "pve-passwords":
        rotate_pve_passwords(args.users)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        print(f"error: {e.stderr.strip()}", file=sys.stderr)
        sys.exit(1)
