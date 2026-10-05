#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -ne 1 ]]; then
  echo "usage: $0 backups/TIMESTAMP" >&2
  exit 2
fi

BACKUP="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
[[ -d "$BACKUP" ]] || { echo "backup not found: $BACKUP" >&2; exit 1; }

(
  cd "$BACKUP"
  sha256sum -c SHA256SUMS
)

[[ -f .env ]] || { echo "missing current .env" >&2; exit 1; }
set -a
# shellcheck disable=SC1091
source .env
set +a

read -r -p "Restore $BACKUP into this deployment? Type RESTORE: " answer
[[ "$answer" == "RESTORE" ]] || { echo "aborted"; exit 1; }

docker compose stop caddy web >/dev/null 2>&1 || true
docker compose up -d db

for _ in $(seq 1 30); do
  if docker compose exec -T db pg_isready -U "${POSTGRES_USER:-pysoy}" -d "${POSTGRES_DB:-pysoy}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

docker compose exec -T db sh -c 'PGPASSWORD="$(cat /run/secrets/postgres_password)" psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" "$POSTGRES_DB" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"'
gzip -dc "$BACKUP/database.sql.gz" | docker compose exec -T db sh -c 'PGPASSWORD="$(cat /run/secrets/postgres_password)" psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" "$POSTGRES_DB"'

docker run --rm \
  -v "${PYSOY_MEDIA_VOLUME:-pysoy_media}:/data" \
  -v "$BACKUP:/backup:ro" \
  alpine:3.22 sh -c 'find /data -mindepth 1 -maxdepth 1 -exec rm -rf {} +; tar -xzf /backup/media.tar.gz -C /data; chown -R 10001:10001 /data'

cp "$BACKUP/django_secret_key" secrets/django_secret_key
chmod 600 secrets/django_secret_key

docker compose run --rm volume-init
docker compose run --rm --no-deps web python config/manage.py migrate --noinput
docker compose run --rm --no-deps web python config/manage.py collectstatic --noinput
docker compose up -d web caddy

echo "Restore complete. Verify /_health/ready and a sample of media before considering recovery finished."
