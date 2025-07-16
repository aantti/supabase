# Usage:
# $ eval $(egrep -v '^#|^$' env_pgvars.sh)

export PGHOST="${POSTGRES_HOST:-localhost}"
export PGDATABASE="${POSTGRES_DB:-postgres}"
export PGPORT="${POSTGRES_PORT:-5432}"
export PGUSER="${POSTGRES_USER:-supabase_admin}"
export PGPASSWORD="${POSTGRES_PASSWORD:-}"
