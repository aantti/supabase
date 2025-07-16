## Create Aurora DB cluster and DB instance

Below is the minimal list of tasks required to set up Aurora PostgreSQL for Supabase:

- Create custom cluster parameter group for Aurora PostgreSQL with `rds.logical_replication` enabled
- Create custom database parameter group for Aurora PostgreSQL to edit `shared_preload_libraries`
- Create Aurora PostgreSQL cluster with proper configuration
- Create Aurora PostgreSQL database instance with Serverless v2 configuration
- Apply custom parameter groups to cluster and instance
- Reboot database instance to apply parameter changes
- Configure security group to allow inbound traffic on port 5432
- Verify database connectivity and save endpoint hostname and security credentials

See detailed notes in [AURORA.md](AURORA.md)

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

## Prepare Aurora PostgreSQL to be used with Supabase

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
