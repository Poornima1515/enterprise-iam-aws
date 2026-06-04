#!/bin/bash
# Create RDS Instance for Project
ACCOUNT_ID=${1:-"745416886767"}
REGION="us-east-1"

echo "=== Creating RDS Instance ==="

# Create DB subnet group (uses default VPC subnets)
SUBNETS=$(aws ec2 describe-subnets \
  --filters "Name=defaultForAz,Values=true" \
  --query 'Subnets[].SubnetId' \
  --output text | tr '\t' ' ')

aws rds create-db-subnet-group \
  --db-subnet-group-name project-subnet-group \
  --db-subnet-group-description "Project RDS subnet group" \
  --subnet-ids $SUBNETS 2>/dev/null || echo "Subnet group exists"

# Create RDS instance (Free Tier: db.t3.micro, 20GB)
aws rds create-db-instance \
  --db-instance-identifier Project-RDS-DB \
  --db-instance-class db.t3.micro \
  --engine mysql \
  --master-username admin \
  --master-user-password 'SecureDB@2026!' \
  --allocated-storage 20 \
  --db-subnet-group-name project-subnet-group \
  --no-publicly-accessible \
  --backup-retention-period 1 \
  --tags Key=Project,Value=IAM-Project Key=Name,Value=Project-RDS-DB \
  --region $REGION 2>/dev/null || echo "RDS instance already exists or being created"

echo "✅ RDS instance creation initiated (takes ~5 mins)"
echo ""
echo "Check status:"
echo "aws rds describe-db-instances --db-instance-identifier Project-RDS-DB --query 'DBInstances[0].DBInstanceStatus'"

echo ""
echo "=== Test db-user access ==="
echo "aws rds describe-db-instances --profile db-user   <- Should SUCCEED"
echo "aws rds describe-db-instances --profile developer-user  <- Should FAIL"
