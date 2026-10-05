# pysoy-infra

Provider-agnostic single-host infrastructure for pySoy.

The deployment contract is deliberately small: provide a Linux machine with Docker Engine, the Docker Compose plugin, ports 80/443, DNS, and operator SSH access. This repository turns that host into pySoy. It contains no OVH, Hetzner, AWS, or other provider-specific provisioning.

## Topology

    Internet
       |
       v
    Cloudflare (recommended edge)
       |
       v
    Caddy :80/:443
       |
       v
    Django/Gunicorn
       |
       +---- PostgreSQL
       |
       +---- persistent media volume

Static and media files are served directly by Caddy. PostgreSQL and the media volume are the durable application state. Django application code and its container image come from pysoy-web.

## Host requirements

- Linux
- Docker Engine and Docker Compose plugin
- bash, openssl, gzip, sha256sum
- ports 80/tcp, 443/tcp, and 443/udp available
- DNS for the chosen hostname pointing at the host
- registry access for the selected pysoy-web image

No host Python, PostgreSQL, Gunicorn, or Caddy installation is required.

## First deployment

    git clone https://github.com/natelastname/pysoy-infra.git
    cd pysoy-infra
    ./scripts/init.sh

Edit .env and set at least PYSOY_SITE_HOST and PYSOY_WEB_IMAGE. Pin the image to a release tag or immutable digest; doctor.sh rejects latest.

Then:

    ./scripts/doctor.sh
    ./scripts/deploy.sh

Create the first staff user with:

    docker compose run --rm --no-deps web python config/manage.py createsuperuser

Cloudflare should use Full (strict) TLS when proxying the hostname.

## Routine deployment

Change PYSOY_WEB_IMAGE in .env to the desired release and run:

    ./scripts/deploy.sh

When an existing web service is present, deployment takes a quiesced backup before migrations. Migrations and collectstatic complete before the public gateway is converged.

## Backups

    ./scripts/backup.sh

A timestamped backup contains:

- a compressed PostgreSQL dump;
- the persistent media volume;
- the Django secret key, because anonymous post-deletion HMACs depend on it;
- a deployment configuration snapshot;
- SHA-256 checksums and metadata.

Local backups are intentionally simple and are not encrypted. Copy them to encrypted, access-controlled storage outside this server/provider. The PostgreSQL password is not part of the recovery contract and can be regenerated on a new host.

Restore with:

    ./scripts/restore.sh backups/TIMESTAMP

Restore verifies checksums, replaces the database and media state, restores the Django identity secret, reapplies migrations/static files, and starts the services.

## Persistent state

| State | Durable | Backup |
| --- | --- | --- |
| PostgreSQL volume | yes | logical dump |
| media volume | yes | tar archive |
| Django secret key | yes | copied into backup |
| static volume | reconstructible | no |
| Caddy certificates/state | reconstructible | no |
| container images | reconstructible from registry | no |

## Cloudflare boundary

Cloudflare is recommended for DNS, proxying, WAF/rate controls, and CDN caching, but Django does not run on Cloudflare and the deployment does not use Cloudflare-specific APIs. The origin remains a normal HTTPS server and can move to a different edge provider without an application rewrite.
