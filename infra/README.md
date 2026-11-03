Provide common docker environment
- Database initialization script `./backups/backup.sql`
- Initialize Keycloak users and realm `./keycloak-data/import/`


`./backups/backup.sql` is applied automatically the first time `loci-db` starts with an empty volume.
To re-import it into an existing database, run `./scripts/migrate-db-import.sh`
(or reset with `docker compose down -v` and start again).


This setup is for local development only. Before deploying anywhere else, see [PRODUCTION.md](PRODUCTION.md).
