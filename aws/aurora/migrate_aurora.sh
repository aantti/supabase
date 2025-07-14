#!/bin/sh
set -eu

test -f ../../.env && \
set -a && source ../../.env && set +a

# POSTGRES_HOST for Aurora should be something like
# database-1-instance-1.cccdddeeefff.eu-central-1.rds.amazonaws.com
export PGHOST="${POSTGRES_HOST:-localhost}"
export PGDATABASE="${POSTGRES_DB:-postgres}"
export PGPORT="${POSTGRES_PORT:-5432}"
export PGPASSWORD="${POSTGRES_PASSWORD:-}"

if [ -z "${PGPASSWORD:-}" ]; then
    echo "$0: PGPASSWORD is not set"
    exit 1
fi

#db=$( cd -- "$( dirname -- "$0" )" > /dev/null 2>&1 && pwd )
db="./initdb"
test -d "$db" || {
    echo "$0: initdb directory not found"
    exit 1
}

if true; then
    psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U supabase_admin <<EOSQL
do \$\$
begin
  -- supabase_admin role has to be created manually when setting up Aurora
  -- postgres role created here and granted rds_superuser
  if not exists (select from pg_roles where rolname = 'postgres') then
    create role postgres with createdb createrole login password '$PGPASSWORD';
    grant rds_superuser to postgres;
    alter database postgres owner to postgres;
  end if;
end \$\$
EOSQL
    # run init scripts as postgres user
    for sql in "$db"/init-scripts/*.sql; do
        echo "$0: running $sql"
        psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U postgres -f "$sql"
    done

    psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U postgres -c "ALTER USER supabase_admin WITH PASSWORD '$PGPASSWORD'"

    # run migrations as super user - postgres user demoted in post-setup
    for sql in "$db"/migrations/*.sql; do
        echo "$0: running $sql"

        filename=$(basename "$sql")
        case "$filename" in
            "20211115999999_update-auth-permissions_aurora.sql")
                psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U supabase_auth_admin -f "$sql"
                ;;
            *)
                psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U supabase_admin -f "$sql"
                ;;
        esac
    done

    # once done with everything, reset stats from init
    psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U supabase_admin -c 'SELECT extensions.pg_stat_statements_reset(); SELECT pg_stat_reset();' || true
fi

exit 0
