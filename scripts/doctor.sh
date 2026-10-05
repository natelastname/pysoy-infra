#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "error: $*" >&2
  exit 1
}

command -v docker >/dev/null || fail "docker is not installed"
docker compose version >/dev/null 2>&1 || fail "Docker Compose plugin is not available"
command -v openssl >/dev/null || fail "openssl is not installed"
command -v gzip >/dev/null || fail "gzip is not installed"
command -v sha256sum >/dev/null || fail "sha256sum is not installed"

[[ -f .env ]] || fail "missing .env; run ./scripts/init.sh"
[[ -s secrets/postgres_password ]] || fail "missing secrets/postgres_password"
[[ -s secrets/django_secret_key ]] || fail "missing secrets/django_secret_key"

set -a
# shellcheck disable=SC1091
source .env
set +a

[[ -n "${PYSOY_SITE_HOST:-}" ]] || fail "PYSOY_SITE_HOST is empty"
[[ -n "${PYSOY_WEB_IMAGE:-}" ]] || fail "PYSOY_WEB_IMAGE is empty"
[[ "$PYSOY_WEB_IMAGE" != *":latest" ]] || fail "pin PYSOY_WEB_IMAGE to a release tag or digest, not latest"

docker compose config --quiet

echo "pySoy infrastructure looks consistent."
