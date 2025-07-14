## Set Up Supabase Containers

### Get the code

```
git clone --depth 1 --branch self-hosting/aws-aurora git@github.com:aantti/supabase.git
```

### Make a new Supabase Aurora project directory

```
mkdir supabase-aurora
```

### Copy the compose files over to your project

```
cp -rf supabase/docker/* supabase-aurora
```

### Copy from template and edit the .env file

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

## Prepare Aurora

### Create an Aurora instance

[..]

### Initialize the database

Make sure `POSTGRES_HOST` and `POSTGRES_PASSWORD` are configured in the `.env` file, then:

```
(pushd aws/aurora && sh get_db_scripts.sh && sh migrate_aurora.sh)
```

## Start all Supabase services

```
docker compose up -d
```
