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
POSTGRESQL_DIR = REPO_ROOT / "k3s-cluster/gitops/infrastructure/apps/postgresql"
DAGSTER_DIR = REPO_ROOT / "k3s-cluster/gitops/infrastructure/apps/dagster"
SEALED_DAGSTER_CNPG = POSTGRESQL_DIR / "sealed-dagster-cnpg-role.yaml"
SEALED_DAGSTER_DB = DAGSTER_DIR / "sealed-dagster-db.yaml"
SEALED_ICEBERG_CNPG = POSTGRESQL_DIR / "sealed-iceberg-cnpg-role.yaml"
SEALED_ICEBERG_CATALOG = DAGSTER_DIR / "sealed-iceberg-catalog.yaml"
LAKEKEEPER_DIR = REPO_ROOT / "k3s-cluster/gitops/infrastructure/apps/lakekeeper"
SEALED_LAKEKEEPER_CNPG = POSTGRESQL_DIR / "sealed-lakekeeper-cnpg-role.yaml"
SEALED_LAKEKEEPER_PG = LAKEKEEPER_DIR / "sealed-lakekeeper-pg.yaml"
SEALED_LAKEKEEPER_ENCRYPTION = LAKEKEEPER_DIR / "sealed-lakekeeper-encryption.yaml"
SEALED_OPENFGA_CNPG = POSTGRESQL_DIR / "sealed-openfga-cnpg-role.yaml"
SEALED_OPENFGA_DATASTORE = LAKEKEEPER_DIR / "sealed-openfga-datastore.yaml"

PG_HOST = "postgresql-rw.postgresql.svc.cluster.local:5432"
ICEBERG_CATALOG_HOST = PG_HOST

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

    print("Done. Commit and push both sealed secrets. Flux will apply them.")
    print(f"  {SEALED_DAGSTER_CNPG.relative_to(REPO_ROOT)}")
    print(f"  {SEALED_DAGSTER_DB.relative_to(REPO_ROOT)}")


def rotate_iceberg_db() -> None:
    password = gen_password()

    print("Sealing iceberg-cnpg-role (postgresql namespace)...")
    sealed = seal("iceberg-cnpg-role", "postgresql", password=password, username="iceberg")
    SEALED_ICEBERG_CNPG.write_text(sealed)

    print("Sealing iceberg-catalog (dagster namespace)...")
    uri = f"postgresql+psycopg2://iceberg:{password}@{ICEBERG_CATALOG_HOST}/iceberg"
    sealed = seal("iceberg-catalog", "dagster", ICEBERG_CATALOG_URI=uri)
    SEALED_ICEBERG_CATALOG.write_text(sealed)

    print("Done. Commit and push both sealed secrets. Flux will apply them.")
    print(f"  {SEALED_ICEBERG_CNPG.relative_to(REPO_ROOT)}")
    print(f"  {SEALED_ICEBERG_CATALOG.relative_to(REPO_ROOT)}")


def rotate_lakekeeper_db() -> None:
    password = gen_password()

    print("Sealing lakekeeper-cnpg-role (postgresql namespace)...")
    sealed = seal("lakekeeper-cnpg-role", "postgresql", password=password, username="lakekeeper")
    SEALED_LAKEKEEPER_CNPG.write_text(sealed)

    print("Sealing lakekeeper-pg (lakekeeper namespace)...")
    sealed = seal(
        "lakekeeper-pg", "lakekeeper",
        **{"postgresql-user": "lakekeeper", "postgresql-password": password},
    )
    SEALED_LAKEKEEPER_PG.write_text(sealed)

    print("Done. Commit and push both sealed secrets. Flux will apply them.")
    print(f"  {SEALED_LAKEKEEPER_CNPG.relative_to(REPO_ROOT)}")
    print(f"  {SEALED_LAKEKEEPER_PG.relative_to(REPO_ROOT)}")


def rotate_lakekeeper_encryption() -> None:
    # Encrypts warehouse storage credentials at rest in postgres. Back this up out of band.
    key = secrets.token_urlsafe(48)
    print("Sealing lakekeeper-encryption (lakekeeper namespace)...")
    sealed = seal("lakekeeper-encryption", "lakekeeper", encryptionKey=key)
    SEALED_LAKEKEEPER_ENCRYPTION.write_text(sealed)
    print("Done. Back up this key out of band; losing it orphans all warehouse credentials.")
    print(f"  {SEALED_LAKEKEEPER_ENCRYPTION.relative_to(REPO_ROOT)}")


def rotate_openfga_db() -> None:
    password = gen_password()

    print("Sealing openfga-cnpg-role (postgresql namespace)...")
    sealed = seal("openfga-cnpg-role", "postgresql", password=password, username="openfga")
    SEALED_OPENFGA_CNPG.write_text(sealed)

    print("Sealing openfga-datastore (lakekeeper namespace)...")
    uri = f"postgres://openfga:{password}@{PG_HOST}/openfga?sslmode=disable"
    sealed = seal("openfga-datastore", "lakekeeper", uri=uri)
    SEALED_OPENFGA_DATASTORE.write_text(sealed)

    print("Done. Commit and push both sealed secrets. Flux will apply them.")
    print(f"  {SEALED_OPENFGA_CNPG.relative_to(REPO_ROOT)}")
    print(f"  {SEALED_OPENFGA_DATASTORE.relative_to(REPO_ROOT)}")


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
    sub.add_parser("iceberg-db", help="Rotate CNPG iceberg DB password (role + catalog URI secrets)")
    sub.add_parser("lakekeeper-db", help="Rotate CNPG lakekeeper DB password (role + chart pg secret)")
    sub.add_parser("lakekeeper-encryption", help="Generate Lakekeeper secret-backend encryption key")
    sub.add_parser("openfga-db", help="Rotate CNPG openfga DB password (role + datastore uri secret)")

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
    elif args.cmd == "iceberg-db":
        rotate_iceberg_db()
    elif args.cmd == "lakekeeper-db":
        rotate_lakekeeper_db()
    elif args.cmd == "lakekeeper-encryption":
        rotate_lakekeeper_encryption()
    elif args.cmd == "openfga-db":
        rotate_openfga_db()
    elif args.cmd == "pve-passwords":
        rotate_pve_passwords(args.users)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        print(f"error: {e.stderr.strip()}", file=sys.stderr)
        sys.exit(1)
