#!/bin/sh

# HEADS UP: This is work in progress.

# Create a publicly accessible Aurora cluster suitable for development:
#   - Parameter groups enable logical replication and required shared libraries for Supabase
#   - Serverless v2 scaling is configured with minimum 0.5 ACU and maximum 8 ACU
#   - Performance Insights is enabled with 7-day retention
#   - Not configured here: Security group to allow access from anywhere (0.0.0.0/0)

set -e

CLUSTER_NAME="database-2"
DB_INSTANCE_NAME="${CLUSTER_NAME}-instance-1"
MASTER_USERNAME="supabase_admin"
MASTER_PASSWORD="${POSTGRES_PASSWORD}"
DB_NAME="postgres"
ENGINE_VERSION="16.6"
DB_CLUSTER_PARAMETER_GROUP="${CLUSTER_NAME}-cluster-aurora-postgres16"
DB_PARAMETER_GROUP="${CLUSTER_NAME}-aurora-postgresql16"
DB_PARAMETER_GROUP_FAMILY="aurora-postgresql16"
VPC_ID="${AWS_VPC_ID:-vpc-xxxxxxxx}"
SUBNET_GROUP_NAME="${AWS_SUBNET_GROUP_NAME:-default-vpc-xxxxxxxx}"
SECURITY_GROUP_ID="${AWS_SECURITY_GROUP_ID:-sg-xxxxxxxx}"

export AWS_PAGER=""

create_custom_parameter_groups() {
    echo "===> Creating Aurora PostgreSQL parameter groups..."

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
}

create_db_cluster_and_instance() {
    echo "===> Creating Aurora PostgreSQL cluster and instance..."

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
        --enable-performance-insights \
        --performance-insights-retention-period 7 \
        --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=8

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
}

wait_for_cluster_ready() {
    echo "===> Waiting for resources to be ready..."
    {
        aws rds wait db-cluster-available --db-cluster-identifier $CLUSTER_NAME
        aws rds wait db-instance-available --db-instance-identifier $DB_INSTANCE_NAME
    } || { echo "Resources failed to become available"; exit 1; }
}

create_aurora_postgres() {
    echo "===> Creating Aurora PostgreSQL..."

    create_custom_parameter_groups || { echo "Failed to create custom parameter groups"; exit 1; }
    create_db_cluster_and_instance || { echo "Failed to create database cluster and instance"; exit 1; }

    wait_for_cluster_ready

    # Reboot the database instance to apply parameter changes
    echo "===> Rebooting database instance to apply parameter changes..."

    aws rds reboot-db-instance \
        --db-instance-identifier $DB_INSTANCE_NAME

    wait_for_cluster_ready
}

start_aurora_postgres() {
    echo "===> Starting Aurora PostgreSQL cluster..."

    aws rds start-db-cluster --db-cluster-identifier $CLUSTER_NAME || { echo "start-db-cluster failed."; exit 1; }
    wait_for_cluster_ready

    echo "Aurora PostgreSQL cluster started successfully."
}

stop_aurora_postgres() {
    echo "===> Stopping Aurora PostgreSQL cluster..."

    # TODO: Wait for cluster to be stopped?
    aws rds stop-db-cluster --db-cluster-identifier $CLUSTER_NAME || { echo "stop-db-cluster failed."; exit 1; }

    echo "Aurora PostgreSQL cluster stopped successfully."
}

delete_aurora_postgres() {
    echo "===> Deleting Aurora PostgreSQL cluster..."

    # Delete instance first
    echo "===> Deleting instance..."
    aws rds delete-db-instance \
        --db-instance-identifier $DB_INSTANCE_NAME \
        --skip-final-snapshot || { echo "delete-db-instance failed."; exit 1; }

    # Wait for instance deletion
    echo "===> Waiting for database instance deletion..."
    aws rds wait db-instance-deleted --db-instance-identifier $DB_INSTANCE_NAME

    # Delete cluster
    echo "===> Deleting cluster..."
    aws rds delete-db-cluster \
        --db-cluster-identifier $CLUSTER_NAME \
        --skip-final-snapshot || { echo "delete-db-cluster failed."; exit 1; }

    # Wait for cluster deletion
    echo "===> Waiting for database cluster deletion..."
    aws rds wait db-cluster-deleted --db-cluster-identifier $CLUSTER_NAME

    aws rds delete-db-parameter-group \
        --db-parameter-group-name $DB_PARAMETER_GROUP || {
            echo "Failed to delete database parameter group."; exit 1;
        }

    # Delete parameter groups
    echo "===> Deleting parameter groups..."
    aws rds delete-db-cluster-parameter-group \
        --db-cluster-parameter-group-name $DB_CLUSTER_PARAMETER_GROUP || {
            echo "Failed to delete cluster parameter group.";
            exit 1;
        }

    echo "Aurora PostgreSQL cluster and parameter groups deleted successfully."
}

verify_setup() {
    echo "===> Verifying setup and getting connection details..."

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

    echo "===> Connection details:"
    echo "Cluster Endpoint: $CLUSTER_ENDPOINT"
    echo "Instance Endpoint: $INSTANCE_ENDPOINT"
    echo "Port: 5432"
    echo "Database: $DB_NAME"
    echo "Username: $MASTER_USERNAME"
    echo ""

    export PGPASSWORD=${MASTER_PASSWORD}
    echo "===> Testing connection to the database..."
    if ! psql --no-password -h $INSTANCE_ENDPOINT -U $MASTER_USERNAME -d $DB_NAME -c "SELECT version();"; then
        echo "===> Failed to connect to the database."
        exit 1
    fi

    echo "===> Update your .env file with the connection details:"

    echo "POSTGRES_HOST=${INSTANCE_ENDPOINT}"
    echo "POSTGRES_PASSWORD=${MASTER_PASSWORD}"
    echo "POSTGRES_DB=${DB_NAME}"
    echo "POSTGRES_PORT=5432"
    echo ""
}

usage() {
    echo ""
    echo "Usage: $(basename $0) <create|start|stop|delete>"
    echo ""
    exit 1
}

check_aws_cli() {
    # Сheck if aws cli is installed
    if aws sts get-caller-identity --query Account --output text >/dev/null 2>&1; then
        echo "===> Found AWS CLI."
    else
        echo "===> AWS CLI is not installed or has invalid credentials."
        exit 1
    fi
}

main() {
    if [ $# -ne 1 ]; then
        usage
    fi

    if [ -z "$MASTER_PASSWORD" ]; then
        echo "===> POSTGRES_PASSWORD is not set. Please set the POSTGRES_PASSWORD environment variable."
        exit 1
    fi

    check_aws_cli

    case $1 in
        create)
            create_aurora_postgres
            verify_setup
            ;;
        start)
            start_aurora_postgres
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
