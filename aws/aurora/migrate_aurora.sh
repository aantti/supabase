#!/bin/sh
set -eu

#######################################
# Used by both ami and docker builds to initialise database schema.
# Env vars:
#   POSTGRES_DB        defaults to postgres
#   POSTGRES_HOST      defaults to localhost
#   POSTGRES_PORT      defaults to 5432
#   POSTGRES_PASSWORD  defaults to ""
#   USE_DBMATE         defaults to ""
# Exit code:
#   0 if migration succeeds, non-zero on error.
#######################################

DEBUG=""

# Read the .env file and export the variables
# TODO: use `source` instead of `eval` when there's no unquoted variables in .env
test -f ../../.env && \
set -a && \
eval "$(egrep -v "^#|^$" ../../.env | sed 's/=\(.*[ ].*\)/=\"\1\"/')" && \
set +a

# POSTGRES_USER is used in one of the migration scripts
# For self-hosted PostgreSQL, it's supabase_admin as set here:
# https://github.com/supabase/postgres/blob/develop/Dockerfile-15#L208
if [ -z "${POSTGRES_USER:-}" ]; then
    POSTGRES_USER="supabase_admin"
fi

if [ -n "${DEBUG:-}" ]; then
    echo "POSTGRES_HOST=${POSTGRES_HOST}"
    echo "POSTGRES_DB=${POSTGRES_DB}"
    echo "POSTGRES_PORT=${POSTGRES_PORT}"
    echo "POSTGRES_USER=${POSTGRES_USER}"
    echo "POSTGRESS_PASSWORD=`echo ${POSTGRES_PASSWORD} | sed 's/.*\(...\)$/\*\1/'`"
fi

# POSTGRES_HOST for Aurora should be something like
# database-1-instance-1.cccdddeeefff.eu-central-1.rds.amazonaws.com
export PGHOST="${POSTGRES_HOST:-localhost}"
export PGDATABASE="${POSTGRES_DB:-postgres}"
export PGPORT="${POSTGRES_PORT:-5432}"
export PGUSER="${POSTGRES_USER:-supabase_admin}"
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
                echo "$0: using supabase_auth_admin for $filename"
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
