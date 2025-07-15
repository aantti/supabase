# Create an Aurora PostreSQL instance

## Using AWS Console

### Create database cluster and database instance

- Go to Aurora and RDS in the AWS console
- Click "Create database"
- Choose a database creation method: Standard create
- In "Engine options" select:
  - Engine type: Aurora (PostgreSQL Compatible)
  - Available versions: Aurora PostgreSQL (Compatible with PostgreSQL 16.6) - default for major version 16
- In Templates:
  - Choose a sample template to meet your use case: Dev/Test
- In Settings:
  - DB cluster identifier: database-2
  - Credentials Settings:
    - Master username: **supabase_admin** (!!!)
    - Credentials management: Self managed
    - Master password: [set master password]
- Cluster storage configuration
  - Configuration options: Aurora Standard
- Instance configuration
  - DB instance class: Serverless v2
  - Capacity range: [adjust "Maximum capacity (ACUs)"]
- Availability & durability
  - Multi-AZ deployment: Don't create an Aurora Replica
- Connectivity
  - Compute resource: Don't connect to an EC2 compute resource
  - Network type: IPv4
  - Virtual private cloud (VPC): [select VPC, or leave default]
  - DB subnet group: [select subnet group, or leave default]
  - Public access: Yes
  - VPC security group (firewall): Choose existing
  - Availability zone: [select AZ]
  - RDS Proxy: [leave "Create RDS Proxy" unchecked]
[.. leave other options as-is ..]
- Monitoring
  - Database Insights - Standard
  - Performance Insights: Enable Performance insights
- Additional configuration
  - Database options
    - Initial database name: **postgres** (!!!)
- Click "Create database" at the bottom
- Don't pick any "add-ons"
- Check if you see "Successfully created database database-2"
- Click "View connection details" and write down the database endpoint hostname

### Configure inbound rules

- In Aurora and RDS > Databases click on database-2-instance-1
- Check "Connectivity & security" tab
- Find Security > VPC security groups
- Click on the security group
- Check "Inbound rules"
- Create a rule to allow inbound traffic to port 5432
  - Type: PostgreSQL
  - Protocol: TCP
  - Port range: 5432
  - Source: 0.0.0.0/0 (Anywhere/IPv4)
  - Description: Postgres

### Configure parameter groups

**Create custom cluster parameter group**

- In Aurora and RDS > Parameter groups
- Click "Create parameter group"
  - Parameter group name: database-2-cluster-aurora-postgres16
  - Description: Custom cluster parameter group for database 2
  - Engine type: Aurora PostgreSQL
  - Parameter group family: aurora-postgresql16
  - Type: DB Cluster Parameter Group
- Click on database-2-cluster-aurora-postgres16
  - Click Edit
  - Type `rds.logical_replication` in the search field
  - Set the `rds.logical_replication` value to `1`
  - Click "Save Changes"

**Create custom database parameter group**

- In Aurora and RDS > Parameter groups
- Click "Create parameter group"
  - Parameter group name: database-2-aurora-postgresql16
  - Description: Custom database parameter group for database 2
  - Engine type: Aurora PostgreSQL
  - Parameter group family: aurora-postgresql16
  - Type: DB Parameter Group
- Click on database-2-aurora-postgres16
  - Click Edit
  - Type `shared_preload_libraries` in the search field
  - Set `shared_preload_libraries` to `pg_cron,pg_stat_statements`
  - Click "Save Changes"

**Change default parameter groups to custom groups**

- Go to Aurora and RDS > Databases
- Select database-2
- Click Modify
- Find "Additional configuration" at the bottom of the page
- Change "DB cluster parameter group" to database-2-cluster-aurora-postgres16
- Click Continue at the bottom and select "Apply immediately"
- Click "Modify cluster"

- Go back to Aurora and RDS > Databases
- Select database-2-instance-1
- Click Modify
- Find "Additional configuration" at the bottom of the page
- Change "DB parameter group" to database-2-aurora-postgres16
- Click Continue at the bottom and select "Apply immediately"
- Click "Modify DB instance"

**Reboot database**

- Go back to Aurora and RDS > Databases
- Wait until the status of the cluster and database instance changes from "Modifying" to "Available"
- Select database-2-instance-1, click Actions and reboot the database

## Using AWS CLI

[..]
