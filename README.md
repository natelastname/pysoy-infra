# pysoy-infra

Provider-agnostic runtime infrastructure for pySoy.

This repository assumes an ordinary Linux host with Docker Engine and the Docker Compose plugin. It owns deployment topology, PostgreSQL persistence, media/static volumes, TLS/reverse proxying, secrets, backups, restores, and operational scripts. Application code belongs in pysoy-web.
