#!/bin/bash
# =============================================================================
# setup-iam.sh
# Enterprise IAM System — Full Setup Script
# Module 1: RBAC System Setup
#
# Usage: ./setup-iam.sh <ACCOUNT_ID>
# Example: ./setup-iam.sh 745416886767
# =============================================================================

set -e

ACCOUNT_ID=${1:-"REPLACE_WITH_YOUR_ACCOUNT_ID"}
REGION="us-east-1"
PROJECT_TAG="IAM-Project"

echo "=============================================="
echo " Enterprise IAM System — Setup Script"
echo " Account ID: $ACCOUNT_ID"
echo " Region: $REGION"
echo "=============================================="
echo ""

# ------------------------------------------------------------------------------
# STEP 1: Enable CloudTrail
# ------------------------------------------------------------------------------
echo "[1/9] Setting up CloudTrail..."

TRAIL_BUCKET="aws-cloudtrail-logs-${ACCOUNT_ID}"

aws s3api create-bucket \
  --bucket $TRAIL_BUCKET \
  --region $REGION 2>/dev/null || echo "  Bucket already exists, continuing..."

# Pass policy as inline JSON string (avoids file path issues on Windows)
TRAIL_POLICY="{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"AWSCloudTrailAclCheck\",\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"cloudtrail.amazonaws.com\"},\"Action\":\"s3:GetBucketAcl\",\"Resource\":\"arn:aws:s3:::${TRAIL_BUCKET}\"},{\"Sid\":\"AWSCloudTrailWrite\",\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"cloudtrail.amazonaws.com\"},\"Action\":\"s3:PutObject\",\"Resource\":\"arn:aws:s3:::${TRAIL_BUCKET}/AWSLogs/${ACCOUNT_ID}/*\",\"Condition\":{\"StringEquals\":{\"s3:x-amz-acl\":\"bucket-owner-full-control\"}}}]}"

aws s3api put-bucket-policy \
  --bucket $TRAIL_BUCKET \
  --policy "$TRAIL_POLICY"

aws cloudtrail create-trail \
  --name IAM-Project-Trail \
  --s3-bucket-name $TRAIL_BUCKET \
  --include-global-service-events \
  --is-multi-region-trail \
  --enable-log-file-validation 2>/dev/null || echo "  Trail already exists, continuing..."

aws cloudtrail start-logging --name IAM-Project-Trail
echo "  ✅ CloudTrail enabled"

# ------------------------------------------------------------------------------
# STEP 2: Create IAM Policies (inline JSON — no file paths)
# ------------------------------------------------------------------------------
echo ""
echo "[2/9] Creating IAM Policies..."

create_policy() {
  local name=$1
  local doc=$2
  local desc=$3
  aws iam create-policy \
    --policy-name "$name" \
    --policy-document "$doc" \
    --description "$desc" 2>/dev/null \
    && echo "  ✅ Created policy: $name" \
    || echo "  ⚠️  Policy already exists: $name"
}

# Admin Policy
create_policy "AdminFullAccessPolicy" \
  '{"Version":"2012-10-17","Statement":[{"Sid":"AdminFullAccess","Effect":"Allow","Action":"*","Resource":"*","Condition":{"Bool":{"aws:MultiFactorAuthPresent":"true"}}}]}' \
  "Full AWS access for Admin group with MFA required"

# Developer Policy
create_policy "DeveloperAccessPolicy" \
  '{"Version":"2012-10-17","Statement":[{"Sid":"EC2StartStop","Effect":"Allow","Action":["ec2:StartInstances","ec2:StopInstances","ec2:RebootInstances","ec2:DescribeInstances","ec2:DescribeInstanceStatus","ec2:Describe*"],"Resource":"*"},{"Sid":"S3UploadFiles","Effect":"Allow","Action":["s3:PutObject","s3:GetObject","s3:ListBucket","s3:GetBucketLocation","s3:ListAllMyBuckets"],"Resource":["arn:aws:s3:::Project-S3-Bucket","arn:aws:s3:::Project-S3-Bucket/*"]},{"Sid":"DenyDeleteActions","Effect":"Deny","Action":["s3:DeleteObject","s3:DeleteBucket","ec2:TerminateInstances","rds:DeleteDBInstance","iam:DeleteUser","iam:DeleteRole","iam:DeletePolicy"],"Resource":"*"}]}' \
  "EC2 start/stop and S3 upload. No delete permissions."

# Tester Policy
create_policy "TesterReadOnlyPolicy" \
  '{"Version":"2012-10-17","Statement":[{"Sid":"EC2ReadOnly","Effect":"Allow","Action":["ec2:Describe*","ec2:GetConsoleOutput"],"Resource":"*"},{"Sid":"S3ReadOnly","Effect":"Allow","Action":["s3:GetObject","s3:ListBucket","s3:GetBucketLocation","s3:ListAllMyBuckets"],"Resource":["arn:aws:s3:::Project-S3-Bucket","arn:aws:s3:::Project-S3-Bucket/*"]},{"Sid":"DenyAllWrite","Effect":"Deny","Action":["ec2:StartInstances","ec2:StopInstances","ec2:TerminateInstances","s3:PutObject","s3:DeleteObject","rds:*","iam:*"],"Resource":"*"}]}' \
  "Read-only access to EC2 and S3"

# DatabaseAdmin Policy
create_policy "DatabaseAdminPolicy" \
  '{"Version":"2012-10-17","Statement":[{"Sid":"RDSFullManagement","Effect":"Allow","Action":["rds:CreateDBInstance","rds:DeleteDBInstance","rds:ModifyDBInstance","rds:RebootDBInstance","rds:StartDBInstance","rds:StopDBInstance","rds:CreateDBSnapshot","rds:DeleteDBSnapshot","rds:RestoreDBInstanceFromDBSnapshot","rds:Describe*","rds:List*","rds:AddTagsToResource"],"Resource":"*"},{"Sid":"DenyNonRDS","Effect":"Deny","Action":["ec2:*","s3:*","iam:*","cloudtrail:*"],"Resource":"*"}]}' \
  "Full RDS management, no access to other services"

# Auditor Policy
create_policy "AuditorReadOnlyPolicy" \
  '{"Version":"2012-10-17","Statement":[{"Sid":"CloudTrailRead","Effect":"Allow","Action":["cloudtrail:GetTrail","cloudtrail:GetTrailStatus","cloudtrail:DescribeTrails","cloudtrail:LookupEvents","cloudtrail:ListTrails"],"Resource":"*"},{"Sid":"CloudWatchRead","Effect":"Allow","Action":["cloudwatch:Describe*","cloudwatch:Get*","cloudwatch:List*","logs:Describe*","logs:Get*","logs:FilterLogEvents"],"Resource":"*"},{"Sid":"IAMReadOnly","Effect":"Allow","Action":["iam:GenerateCredentialReport","iam:GetCredentialReport","iam:ListUsers","iam:ListGroups","iam:ListRoles","iam:GetUser","iam:GetGroup","iam:GetRole"],"Resource":"*"},{"Sid":"DenyAllWrite","Effect":"Deny","Action":["cloudtrail:DeleteTrail","cloudtrail:StopLogging","cloudtrail:UpdateTrail","iam:CreateUser","iam:DeleteUser","ec2:*","s3:PutObject","s3:DeleteObject","rds:*"],"Resource":"*"}]}' \
  "Read-only access to CloudTrail and CloudWatch"

# ------------------------------------------------------------------------------
# STEP 3: Create IAM Groups
# ------------------------------------------------------------------------------
echo ""
echo "[3/9] Creating IAM Groups..."

create_group() {
  local group=$1
  local policy_arn=$2

  aws iam create-group --group-name "$group" 2>/dev/null \
    && echo "  ✅ Created group: $group" \
    || echo "  ⚠️  Group already exists: $group"

  aws iam attach-group-policy \
    --group-name "$group" \
    --policy-arn "$policy_arn" 2>/dev/null \
    && echo "  ✅ Attached policy to $group" \
    || echo "  ⚠️  Policy already attached to $group"
}

create_group "Admin"         "arn:aws:iam::${ACCOUNT_ID}:policy/AdminFullAccessPolicy"
create_group "Developer"     "arn:aws:iam::${ACCOUNT_ID}:policy/DeveloperAccessPolicy"
create_group "Tester"        "arn:aws:iam::${ACCOUNT_ID}:policy/TesterReadOnlyPolicy"
create_group "DatabaseAdmin" "arn:aws:iam::${ACCOUNT_ID}:policy/DatabaseAdminPolicy"
create_group "Auditor"       "arn:aws:iam::${ACCOUNT_ID}:policy/AuditorReadOnlyPolicy"

# ------------------------------------------------------------------------------
# STEP 4: Create IAM Users
# ------------------------------------------------------------------------------
echo ""
echo "[4/9] Creating IAM Users..."

TEMP_PASSWORD="TempPass@123!"

create_user() {
  local username=$1
  local group=$2

  aws iam create-user \
    --user-name "$username" \
    --tags Key=Project,Value=$PROJECT_TAG Key=Group,Value=$group 2>/dev/null \
    && echo "  ✅ Created user: $username" \
    || echo "  ⚠️  User already exists: $username"

  aws iam create-login-profile \
    --user-name "$username" \
    --password "$TEMP_PASSWORD" \
    --password-reset-required 2>/dev/null \
    && echo "  ✅ Login profile created for: $username" \
    || echo "  ⚠️  Login profile already exists for: $username"

  aws iam add-user-to-group \
    --user-name "$username" \
    --group-name "$group" 2>/dev/null \
    && echo "  ✅ Added $username to $group group" \
    || echo "  ⚠️  $username already in $group group"
}

create_user "admin-user"     "Admin"
create_user "developer-user" "Developer"
create_user "tester-user"    "Tester"
create_user "db-user"        "DatabaseAdmin"
create_user "auditor-user"   "Auditor"

# ------------------------------------------------------------------------------
# STEP 5: Create IAM Roles (inline trust policies)
# ------------------------------------------------------------------------------
echo ""
echo "[5/9] Creating IAM Roles..."

create_role() {
  local role_name=$1
  local username=$2
  local policy_arn=$3

  local trust_doc="{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"AWS\":\"arn:aws:iam::${ACCOUNT_ID}:user/${username}\"},\"Action\":\"sts:AssumeRole\",\"Condition\":{\"Bool\":{\"aws:MultiFactorAuthPresent\":\"true\"}}}]}"

  aws iam create-role \
    --role-name "$role_name" \
    --assume-role-policy-document "$trust_doc" 2>/dev/null \
    && echo "  ✅ Created role: $role_name" \
    || echo "  ⚠️  Role already exists: $role_name"

  aws iam attach-role-policy \
    --role-name "$role_name" \
    --policy-arn "$policy_arn" 2>/dev/null \
    && echo "  ✅ Attached policy to role: $role_name" \
    || echo "  ⚠️  Policy already attached to role: $role_name"
}

create_role "AdminRole"         "admin-user"     "arn:aws:iam::${ACCOUNT_ID}:policy/AdminFullAccessPolicy"
create_role "DeveloperRole"     "developer-user" "arn:aws:iam::${ACCOUNT_ID}:policy/DeveloperAccessPolicy"
create_role "TesterRole"        "tester-user"    "arn:aws:iam::${ACCOUNT_ID}:policy/TesterReadOnlyPolicy"
create_role "DatabaseAdminRole" "db-user"        "arn:aws:iam::${ACCOUNT_ID}:policy/DatabaseAdminPolicy"
create_role "AuditorRole"       "auditor-user"   "arn:aws:iam::${ACCOUNT_ID}:policy/AuditorReadOnlyPolicy"

# ------------------------------------------------------------------------------
# STEP 6: Enforce Password Policy
# ------------------------------------------------------------------------------
echo ""
echo "[6/9] Enforcing IAM Password Policy..."

aws iam update-account-password-policy \
  --minimum-password-length 12 \
  --require-symbols \
  --require-numbers \
  --require-uppercase-characters \
  --require-lowercase-characters \
  --allow-users-to-change-password \
  --max-password-age 90 \
  --password-reuse-prevention 5 \
  --hard-expiry
echo "  ✅ Password policy enforced"

# ------------------------------------------------------------------------------
# STEP 7: Create S3 Bucket
# ------------------------------------------------------------------------------
echo ""
echo "[7/9] Creating S3 Bucket (Project-S3-Bucket)..."

aws s3api create-bucket \
  --bucket project-s3-bucket-${ACCOUNT_ID} \
  --region $REGION 2>/dev/null || echo "  ⚠️  Bucket already exists"

aws s3api put-bucket-versioning \
  --bucket project-s3-bucket-${ACCOUNT_ID} \
  --versioning-configuration Status=Enabled
echo "  ✅ Versioning enabled"

aws s3api put-public-access-block \
  --bucket project-s3-bucket-${ACCOUNT_ID} \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
echo "  ✅ Public access blocked"

# ------------------------------------------------------------------------------
# STEP 8: Create CloudWatch Log Group
# ------------------------------------------------------------------------------
echo ""
echo "[8/9] Setting up CloudWatch..."

aws logs create-log-group \
  --log-group-name CloudTrail/IAMProjectLogs 2>/dev/null \
  && echo "  ✅ CloudWatch log group created" \
  || echo "  ⚠️  Log group already exists"

echo "  ✅ CloudWatch setup done"

# ------------------------------------------------------------------------------
# STEP 9: Verification
# ------------------------------------------------------------------------------
echo ""
echo "[9/9] Verifying Setup..."

echo ""
echo "  IAM Users:"
aws iam list-users --query 'Users[].UserName' --output table

echo ""
echo "  IAM Groups:"
aws iam list-groups --query 'Groups[].GroupName' --output table

echo ""
echo "  CloudTrail Status:"
aws cloudtrail get-trail-status --name IAM-Project-Trail \
  --query '{IsLogging:IsLogging}' --output table

echo ""
echo "=============================================="
echo " ✅ IAM System Setup Complete!"
echo "=============================================="
echo ""
echo " Console URL: https://${ACCOUNT_ID}.signin.aws.amazon.com/console"
echo " Temp Password for all users: $TEMP_PASSWORD"
echo ""
echo " Users created:"
echo "   admin-user     → Admin group"
echo "   developer-user → Developer group"
echo "   tester-user    → Tester group"
echo "   db-user        → DatabaseAdmin group"
echo "   auditor-user   → Auditor group"
echo ""
echo " ⚠️  Each user must set up MFA on first login!"
echo "=============================================="
