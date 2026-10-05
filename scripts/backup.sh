#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

[[ -f .env ]] || { echo "missing .env" >&2; exit 1; }
set -a
# shellcheck disable=SC1091
source .env
set +a

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="$ROOT_DIR/backups/$STAMP"
mkdir -p "$DEST"
chmod 700 "$DEST"

web_was_running=0
caddy_was_running=0
if [[ -n "$(docker compose ps -q web 2>/dev/null)" ]]; then web_was_running=1; fi
if [[ -n "$(docker compose ps -q caddy 2>/dev/null)" ]]; then caddy_was_running=1; fi

cleanup() {
  if [[ "$web_was_running" -eq 1 ]]; then docker compose start web >/dev/null 2>&1 || true; fi
  if [[ "$caddy_was_running" -eq 1 ]]; then docker compose start caddy >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

docker compose stop caddy web >/dev/null 2>&1 || true
docker compose up -d db >/dev/null

for _ in $(seq 1 30); do
  if docker compose exec -T db pg_isready -U "${POSTGRES_USER:-pysoy}" -d "${POSTGRES_DB:-pysoy}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

docker compose exec -T db sh -c 'PGPASSWORD="$(cat /run/secrets/postgres_password)" pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' | gzip -9 > "$DEST/database.sql.gz"

docker run --rm \
  -v "${PYSOY_MEDIA_VOLUME:-pysoy_media}:/data:ro" \
  alpine:3.22 tar -czf - -C /data . > "$DEST/media.tar.gz"

cp secrets/django_secret_key "$DEST/django_secret_key"
chmod 600 "$DEST/django_secret_key"
cp .env "$DEST/deployment.env"
chmod 600 "$DEST/deployment.env"

(
  cd "$DEST"
  sha256sum database.sql.gz media.tar.gz django_secret_key deployment.env > SHA256SUMS
)

cat > "$DEST/metadata.txt" <<META
created_at=$STAMP
web_image=${PYSOY_WEB_IMAGE:-unknown}
site_host=${PYSOY_SITE_HOST:-unknown}
META

trap - EXIT
cleanup

echo "$DEST"
