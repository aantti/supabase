#!/bin/sh

# HEADS UP: This is work in progress.

# Create a publicly accessible Aurora cluster suitable for development:
#   - Parameter groups enable logical replication and required shared libraries for Supabase
#   - Serverless v2 scaling is configured with minimum 0.5 ACU and maximum 8 ACU
#   - Performance Insights is enabled with 7-day retention
#   - Security group to allow access from anywhere (0.0.0.0/0) is NOT configured here

CLUSTER_NAME="database-2"
DB_INSTANCE_NAME="${CLUSTER_NAME}-instance-1"
MASTER_USERNAME="supabase_admin"
MASTER_PASSWORD="${POSTGRES_PASSWORD:-your-secure-password}"
DB_NAME="postgres"
ENGINE_VERSION="16.6"
DB_CLUSTER_PARAMETER_GROUP="${CLUSTER_NAME}-cluster-aurora-postgres16"
DB_PARAMETER_GROUP="${CLUSTER_NAME}-aurora-postgresql16"
DB_PARAMETER_GROUP_FAMILY="aurora-postgresql16"
VPC_ID="vpc-xxxxxxxx"
SUBNET_GROUP_NAME="default-vpc-xxxxxxxx"
SECURITY_GROUP_ID="sg-xxxxxxxx"

create_aurora_postgres() {
    echo "Creating Aurora PostgreSQL cluster..."

    # Create custom cluster parameter group
    aws rds create-db-cluster-parameter-group \
        --db-cluster-parameter-group-name $DB_CLUSTER_PARAMETER_GROUP \
        --db-parameter-group-family $DB_PARAMETER_GROUP_FAMILY \
        --description "Custom cluster parameter group for $CLUSTER_NAME"

    # Enable logical replication
    aws rds modify-db-cluster-parameter-group \
        --db-cluster-parameter-group-name $DB_CLUSTER_PARAMETER_GROUP \
        --parameters "ParameterName=rds.logical_replication,ParameterValue=1,ApplyMethod=pending-reboot"

    # Create custom database parameter group
    aws rds create-db-parameter-group \
        --db-parameter-group-name $DB_PARAMETER_GROUP \
        --db-parameter-group-family $DB_PARAMETER_GROUP_FAMILY \
        --description "Custom database parameter group for $CLUSTER_NAME"

    # Configure shared preload libraries
    aws rds modify-db-parameter-group \
        --db-parameter-group-name $DB_PARAMETER_GROUP \
        --parameters "ParameterName=shared_preload_libraries,ParameterValue=pg_cron\\,pg_stat_statements,ApplyMethod=pending-reboot"

    # Create Aurora PostgreSQL cluster
    aws rds create-db-cluster \
        --db-cluster-identifier $CLUSTER_NAME \
        --engine aurora-postgresql \
        --engine-version $ENGINE_VERSION \
        --master-username $MASTER_USERNAME \
        --master-user-password $MASTER_PASSWORD \
        --database-name $DB_NAME \
        --db-cluster-parameter-group-name $DB_CLUSTER_PARAMETER_GROUP \
        --vpc-security-group-ids $SECURITY_GROUP_ID \
        --db-subnet-group-name $SUBNET_GROUP_NAME \
        --storage-type aurora \
        --publicly-accessible \
        --enable-performance-insights \
        --performance-insights-retention-period 7

    # Create Aurora database instance with Serverless v2
    aws rds create-db-instance \
        --db-instance-identifier $DB_INSTANCE_NAME \
        --db-instance-class db.serverless \
        --engine aurora-postgresql \
        --db-cluster-identifier $CLUSTER_NAME \
        --db-parameter-group-name $DB_PARAMETER_GROUP \
        --publicly-accessible \
        --enable-performance-insights \
        --performance-insights-retention-period 7

    # Configure Serverless v2 capacity
    aws rds modify-db-cluster \
        --db-cluster-identifier $CLUSTER_NAME \
        --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=8

    # Wait for cluster to be available
    aws rds wait db-cluster-available --db-cluster-identifier $CLUSTER_NAME

    # Wait for instance to be available
    aws rds wait db-instance-available --db-instance-identifier $DB_INSTANCE_NAME

    # Reboot the database instance to apply parameter changes
    aws rds reboot-db-instance \
        --db-instance-identifier $DB_INSTANCE_NAME

    # Wait for reboot to complete
    aws rds wait db-instance-available --db-instance-identifier $DB_INSTANCE_NAME

    # Verify setup and get connection details

    # Get cluster endpoint
    CLUSTER_ENDPOINT=$(aws rds describe-db-clusters \
        --db-cluster-identifier $CLUSTER_NAME \
        --query 'DBClusters[0].Endpoint' \
        --output text)

    # Get instance endpoint
    INSTANCE_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier $DB_INSTANCE_NAME \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text)

    echo "Cluster Endpoint: $CLUSTER_ENDPOINT"
    echo "Instance Endpoint: $INSTANCE_ENDPOINT"
    echo "Port: 5432"
    echo "Database: $DB_NAME"
    echo "Username: $MASTER_USERNAME"

    # Test connectivity (requires psql client)
    psql -h $CLUSTER_ENDPOINT -U $MASTER_USERNAME -d $DB_NAME -c "SELECT version();"

    echo "Update your .env file with the connection details:"

    echo "POSTGRES_HOST=$CLUSTER_ENDPOINT"
    echo "POSTGRES_PASSWORD=$MASTER_PASSWORD"
    echo "POSTGRES_DB=$DB_NAME"
    echo "POSTGRES_PORT=5432"
}

stop_aurora_postgres() {
    echo "Stopping Aurora PostgreSQL cluster..."
}

delete_aurora_postgres() {
    echo "Deleting Aurora PostgreSQL cluster..."

    # Delete instance first
    echo "Deleting instance..."
    aws rds delete-db-instance \
        --no-cli-pager \
        --db-instance-identifier $DB_INSTANCE_NAME \
        --skip-final-snapshot

    if [ $? -ne 0 ]; then
        echo "delete-db-instance failed."
        exit 1
    fi

    # Wait for instance deletion
    echo "Waiting for database instance deletion..."
    aws rds wait db-instance-deleted --db-instance-identifier $DB_INSTANCE_NAME

    # Delete cluster
    echo "Deleting cluster..."
    aws rds delete-db-cluster \
        --no-cli-pager \
        --db-cluster-identifier $CLUSTER_NAME \
        --skip-final-snapshot

    if [ $? -ne 0 ]; then
        echo "delete-db-cluster failed."
        exit 1
    fi

    # Wait for cluster deletion
    echo "Waiting for database cluster deletion..."
    aws rds wait db-cluster-deleted --db-cluster-identifier $CLUSTER_NAME

    # Delete parameter groups
    echo "Deleting parameter groups..."
    aws rds delete-db-cluster-parameter-group \
        --no-cli-pager \
        --db-cluster-parameter-group-name $DB_CLUSTER_PARAMETER_GROUP

    if [ $? -ne 0 ]; then
        echo "Failed to delete cluster parameter group."
        exit 1
    fi

    aws rds delete-db-parameter-group \
        --no-cli-pager \
        --db-parameter-group-name $DB_PARAMETER_GROUP

    if [ $? -ne 0 ]; then
        echo "Failed to delete database parameter group."
        exit 1
    fi

    echo "Aurora PostgreSQL cluster and parameter groups deleted successfully."
}

usage() {
    echo "Usage: $(basename $0) <create|stop|delete>"
    exit 1
}

check_aws_cli() {
    # Сheck if aws cli is installed
    if aws sts get-caller-identity --query Account --output text >/dev/null 2>&1; then
        echo "Found AWS CLI."
    else
        echo "AWS CLI is not installed or has invalid credentials."
        exit 1
    fi
}

main() {
    if [ $# -ne 1 ]; then
        usage
    fi

    check_aws_cli

    case $1 in
        create)
            create_aurora_postgres
            ;;
        stop)
            stop_aurora_postgres
            ;;
        delete)
            delete_aurora_postgres
            ;;
        *)
            usage
    esac
}

main "$@"
