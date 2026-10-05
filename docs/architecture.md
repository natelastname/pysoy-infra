# Architecture

pySoy uses a conventional single-host starting point: Caddy, Django/Gunicorn, and PostgreSQL under Docker Compose. The application is stateless except for PostgreSQL and uploaded media.

The design intentionally leaves horizontal scaling for later. When one host is no longer enough, the same application image can move to multiple web nodes while PostgreSQL and media storage are externalized. No provider-specific APIs are required for the MVP.

Cloudflare is an edge layer, not an application runtime. The host remains independently recoverable from backups.
