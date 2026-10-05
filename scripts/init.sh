#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  cp .env.example .env
  chmod 600 .env
  echo "Created .env; edit PYSOY_SITE_HOST and PYSOY_WEB_IMAGE before deployment."
fi

mkdir -p secrets backups
chmod 700 secrets

if [[ ! -s secrets/postgres_password ]]; then
  openssl rand -hex 32 > secrets/postgres_password
  chmod 600 secrets/postgres_password
  echo "Created PostgreSQL password."
fi

if [[ ! -s secrets/django_secret_key ]]; then
  openssl rand -base64 48 > secrets/django_secret_key
  chmod 600 secrets/django_secret_key
  echo "Created Django secret key."
fi
