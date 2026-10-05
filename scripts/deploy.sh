#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

./scripts/doctor.sh

set -a
# shellcheck disable=SC1091
source .env
set +a

if [[ -n "$(docker compose ps -q web 2>/dev/null)" ]]; then
  echo "Creating pre-deploy backup..."
  ./scripts/backup.sh >/dev/null
fi

echo "Pulling images..."
docker compose pull

echo "Preparing persistent volumes and PostgreSQL..."
docker compose run --rm volume-init
docker compose up -d db

for _ in $(seq 1 30); do
  if docker compose exec -T db pg_isready -U "${POSTGRES_USER:-pysoy}" -d "${POSTGRES_DB:-pysoy}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "Applying migrations and static files..."
docker compose run --rm --no-deps web python config/manage.py migrate --noinput
docker compose run --rm --no-deps web python config/manage.py collectstatic --noinput
docker compose run --rm --no-deps web python config/manage.py bootstrap_mvp

echo "Starting application and gateway..."
docker compose up -d web

for _ in $(seq 1 30); do
  if docker compose exec -T web python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/_health/ready', timeout=3).read()" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

docker compose up -d caddy

docker compose ps
