# Disaster recovery

A recovery is successful only when a blank compatible Linux host can be rebuilt from source, registry artifacts, and an off-host backup.

Minimum recovery material:

1. pysoy-infra source;
2. access to a pysoy-web image or the source needed to rebuild it;
3. a verified backup containing database.sql.gz, media.tar.gz, django_secret_key, and SHA256SUMS;
4. DNS/Cloudflare control for the site hostname.

On a new host, run init.sh to generate fresh deployment-local credentials, configure .env, place the selected backup under backups/, and run restore.sh. The restored Django secret key intentionally replaces the freshly generated one so existing anonymous deletion tokens remain valid.

Periodically test this process on a disposable host. A backup that has not been restored is not a verified recovery plan.
