## Setting Up Containers

### Get the code

```
git clone --depth 1 https://github.com/supabase/supabase
```

### Make your new supabase project directory

```
mkdir supabase-aurora
```

### Copy the compose files over to your project

```
cp -rf supabase/docker/* supabase-aurora
```

### Copy example env vars

```
cp supabase/docker/.env.example supabase-aurora/.env
```

### Switch to your project directory

```
cd supabase-aurora
```

### Pull the latest images

```
docker compose pull
```

## Preparing Aurora Instance

### Creating an Aurora instance

[..]

### Initializing the database

```
(pushd aws/aurora && sh get_db_scripts.sh && sh migrate_aurora.sh)
```

## Start all Supabase services

```
docker compose up -d
```
