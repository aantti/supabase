# Aurora - Notes on restrictions

## Roles

- Neither `supabase_admin` nor `postgres` can be superuser
- The "admin" role is `rds_superuser` but it’s still restricted (the actual superuser is `rdsadmin` and it’s accessible for AWS only)
- Instead of the standard `REPLICATION` attribute, Aurora uses the `rds_replication` role

Because there's no "real" superuser, using, e.g., `AUTHORIZATION` doesn't work:

```
-- CREATE SCHEMA pgbouncer AUTHORIZATION pgbouncer;
CREATE SCHEMA pgbouncer;
ALTER SCHEMA pgbouncer OWNER TO pgbouncer;
```

Similarly, `postgres` can't alter privileges for `supabase_admin`:

```
alter default privileges for user supabase_admin in schema public grant all
on sequences to postgres, anon, authenticated, service_role; -- using postgres roles this doesn't work
```

## Extensions

- `pg_net` not supported
- `pg_graphql` not supported
- `pgsodium` not supported
- `orioledb` not supported
- `pgmq` not supported
- `pgjwt` not supported

## Settings

- `session_preload_libraries` can’t be changed

```
psql:migrations/20220118070449_enable-safeupdate-postgrest.sql:2: ERROR:  permission denied to set parameter "session_preload_libraries"
```

- Changing `pg_catalog.lo_export` and `pg_catalog.lo_import` is not allowed
- No supported workaround to store and retrieve arbitrary key-value pairs as database parameters

```sql
ALTER DATABASE postgres SET "app.settings.jwt_secret" TO '';
psql:init-scripts/99-jwt.sql:4: ERROR:  permission denied to set parameter "app.settings.jwt_secret"
ALTER DATABASE postgres SET "app.settings.jwt_exp" TO '';
psql:init-scripts/99-jwt.sql:5: ERROR:  permission denied to set parameter "app.settings.jwt_exp"
```

## Workarounds

Changes to init and migration scripts partially fix the above (see [init-scripts.diff](https://github.com/aantti/supabase/blob/self-hosting/aws-aurora/aws/aurora/init-scripts.diff) and [migrations.diff](https://github.com/aantti/supabase/blob/self-hosting/aws-aurora/aws/aurora/migrations.diff).
