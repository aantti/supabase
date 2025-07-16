#!/bin/sh
set -e

echo "$0: Collecting database scripts from supabase/postgres image"

# 1. Pull supabase/postgres image and create a temporary container
docker pull supabase/postgres:15.8.1.060
docker create --name supabase-db-tmp supabase/postgres:15.8.1.060

# 2. Copy init and migrations scripts to a local directory
docker cp supabase-db-tmp:/docker-entrypoint-initdb.d ./initdb

# 3. Remove the container
docker rm supabase-db-tmp

echo "$0: Copying additional scripts from supabase/docker/volumes/db"

# 4. Copy additional scripts from [..]/supabase/docker/volumes/db
cp -p ../../volumes/db/webhooks.sql \
      ./initdb/init-scripts/98-webhooks.sql
cp -p ../../volumes/db/jwt.sql ./initdb/init-scripts/99-jwt.sql
cp -p ../../volumes/db/roles.sql ./initdb/init-scripts/99-roles.sql

cp -p ../../volumes/db/_supabase.sql \
      ./initdb/migrations/97-_supabase.sql
cp -p ../../volumes/db/logs.sql ./initdb/migrations/99-logs.sql
cp -p ../../volumes/db/pooler.sql ./initdb/migrations/99-pooler.sql
cp -p ../../volumes/db/realtime.sql ./initdb/migrations/99-realtime.sql

cp -p ./00-alter-supabase_admin.sql \
      ./initdb/migrations/00-alter-supabase_admin.sql
cp -p ./20211115999999_update-auth-permissions_aurora.sql \
      ./initdb/migrations/20211115999999_update-auth-permissions_aurora.sql

echo "$0: Applying init and migration diffs for Aurora"

# 5. Apply diffs
(cd initdb/init-scripts && patch -p1 < ../../init-scripts.diff)
(cd initdb/migrations && patch -p1 < ../../migrations.diff)

echo "$0: done."
