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

### Copy Aurora specific setup scripts

```
cp -rfp supabase/aws supabase-aurora
```

### Switch to the new project directory

```
cd supabase-aurora
```

### Pull the latest images

```
docker compose pull
```

## Prepare Aurora

### Create Aurora DB cluster and DB instance

[..]

### Initialize the database

Make sure `POSTGRES_HOST` and `POSTGRES_PASSWORD` for Aurora are configured in the `.env` file, then:

```
(pushd aws/aurora && sh get_db_scripts.sh && sh migrate_aurora.sh)
```

### Update docker-compose.yml to use remote database

```
patch -b < aws/aurora/docker-compose.yml.diff
```

## Start all Supabase services

```
docker compose up -d
```
