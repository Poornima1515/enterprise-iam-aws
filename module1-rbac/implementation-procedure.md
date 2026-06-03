# Module 1 — RBAC Implementation Procedure

## Prerequisites

- AWS Account with root access (for initial setup only)
- AWS CLI installed and configured
- Replace `ACCOUNT_ID` with your actual 12-digit AWS Account ID throughout

---

## Step 1: Enable CloudTrail (Audit Logging)

Before creating any IAM resources, enable CloudTrail so all actions are logged.

### Via AWS Console:
1. Go to **CloudTrail** → **Create Trail**
2. Trail name: `IAM-Project-Trail`
3. Storage location: Create new S3 bucket → `aws-cloudtrail-logs-ACCOUNT_ID`
4. Enable **Log file validation**
5. Enable **CloudWatch Logs** integration
6. Click **Create Trail**

### Via AWS CLI:
```bash
aws cloudtrail create-trail \
  --name IAM-Project-Trail \
  --s3-bucket-name aws-cloudtrail-logs-ACCOUNT_ID \
  --include-global-service-events \
  --is-multi-region-trail \
  --enable-log-file-validation

aws cloudtrail start-logging --name IAM-Project-Trail
```

---

## Step 2: Create IAM Policies

Create each custom policy from the JSON files in `module1-rbac/policies/`.

### Via AWS Console:
1. Go to **IAM** → **Policies** → **Create Policy**
2. Select **JSON** tab
3. Paste the content of each policy file
4. Name and create each policy:

| Policy File                  | Policy Name               |
|------------------------------|---------------------------|
| admin-policy.json            | AdminFullAccessPolicy     |
| developer-policy.json        | DeveloperAccessPolicy     |
| tester-policy.json           | TesterReadOnlyPolicy      |
| database-admin-policy.json   | DatabaseAdminPolicy       |
| auditor-policy.json          | AuditorReadOnlyPolicy     |

### Via AWS CLI:
```bash
# Admin Policy
aws iam create-policy \
  --policy-name AdminFullAccessPolicy \
  --policy-document file://module1-rbac/policies/admin-policy.json \
  --description "Full AWS access for Admin group with MFA required"

# Developer Policy
aws iam create-policy \
  --policy-name DeveloperAccessPolicy \
  --policy-document file://module1-rbac/policies/developer-policy.json \
  --description "EC2 start/stop and S3 upload. No delete permissions."

# Tester Policy
aws iam create-policy \
  --policy-name TesterReadOnlyPolicy \
  --policy-document file://module1-rbac/policies/tester-policy.json \
  --description "Read-only access to EC2 and S3"

# DatabaseAdmin Policy
aws iam create-policy \
  --policy-name DatabaseAdminPolicy \
  --policy-document file://module1-rbac/policies/database-admin-policy.json \
  --description "Full RDS management, no access to other services"

# Auditor Policy
aws iam create-policy \
  --policy-name AuditorReadOnlyPolicy \
  --policy-document file://module1-rbac/policies/auditor-policy.json \
  --description "Read-only access to CloudTrail and CloudWatch"
```

---

## Step 3: Create IAM Groups

### Via AWS Console:
1. Go to **IAM** → **User Groups** → **Create Group**
2. Create each group and attach the corresponding policy:

| Group Name    | Attach Policy             |
|---------------|---------------------------|
| Admin         | AdminFullAccessPolicy     |
| Developer     | DeveloperAccessPolicy     |
| Tester        | TesterReadOnlyPolicy      |
| DatabaseAdmin | DatabaseAdminPolicy       |
| Auditor       | AuditorReadOnlyPolicy     |

### Via AWS CLI:
```bash
# Create Groups
aws iam create-group --group-name Admin
aws iam create-group --group-name Developer
aws iam create-group --group-name Tester
aws iam create-group --group-name DatabaseAdmin
aws iam create-group --group-name Auditor

# Attach Policies to Groups
aws iam attach-group-policy \
  --group-name Admin \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/AdminFullAccessPolicy

aws iam attach-group-policy \
  --group-name Developer \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/DeveloperAccessPolicy

aws iam attach-group-policy \
  --group-name Tester \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/TesterReadOnlyPolicy

aws iam attach-group-policy \
  --group-name DatabaseAdmin \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/DatabaseAdminPolicy

aws iam attach-group-policy \
  --group-name Auditor \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/AuditorReadOnlyPolicy
```

---

## Step 4: Create IAM Users

### Via AWS Console:
1. Go to **IAM** → **Users** → **Add Users**
2. For each user, enable **AWS Management Console access**
3. Set a temporary password and require password reset on first login

### Via AWS CLI:
```bash
# Create Users
aws iam create-user --user-name admin-user --tags Key=Project,Value=IAM-Project
aws iam create-user --user-name developer-user --tags Key=Project,Value=IAM-Project
aws iam create-user --user-name tester-user --tags Key=Project,Value=IAM-Project
aws iam create-user --user-name db-user --tags Key=Project,Value=IAM-Project
aws iam create-user --user-name auditor-user --tags Key=Project,Value=IAM-Project

# Create Console Login Profiles (with temporary passwords)
aws iam create-login-profile \
  --user-name admin-user \
  --password "TempPass@123!" \
  --password-reset-required

aws iam create-login-profile \
  --user-name developer-user \
  --password "TempPass@123!" \
  --password-reset-required

aws iam create-login-profile \
  --user-name tester-user \
  --password "TempPass@123!" \
  --password-reset-required

aws iam create-login-profile \
  --user-name db-user \
  --password "TempPass@123!" \
  --password-reset-required

aws iam create-login-profile \
  --user-name auditor-user \
  --password "TempPass@123!" \
  --password-reset-required
```

---

## Step 5: Add Users to Groups

### Via AWS Console:
1. Go to **IAM** → **User Groups** → Select group → **Add Users**

### Via AWS CLI:
```bash
aws iam add-user-to-group --user-name admin-user --group-name Admin
aws iam add-user-to-group --user-name developer-user --group-name Developer
aws iam add-user-to-group --user-name tester-user --group-name Tester
aws iam add-user-to-group --user-name db-user --group-name DatabaseAdmin
aws iam add-user-to-group --user-name auditor-user --group-name Auditor
```

---

## Step 6: Create IAM Roles

### Via AWS CLI:
```bash
# Admin Role
aws iam create-role \
  --role-name AdminRole \
  --assume-role-policy-document file://module1-rbac/roles/admin-role.json \
  --description "Admin role with full access, MFA required"

aws iam attach-role-policy \
  --role-name AdminRole \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/AdminFullAccessPolicy

# Developer Role
aws iam create-role \
  --role-name DeveloperRole \
  --assume-role-policy-document file://module1-rbac/roles/developer-role.json \
  --description "Developer role with EC2/S3 limited access"

aws iam attach-role-policy \
  --role-name DeveloperRole \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/DeveloperAccessPolicy

# Tester Role
aws iam create-role \
  --role-name TesterRole \
  --assume-role-policy-document file://module1-rbac/roles/tester-role.json \
  --description "Tester role with read-only access"

aws iam attach-role-policy \
  --role-name TesterRole \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/TesterReadOnlyPolicy

# DatabaseAdmin Role
aws iam create-role \
  --role-name DatabaseAdminRole \
  --assume-role-policy-document file://module1-rbac/roles/database-admin-role.json \
  --description "Database admin role for RDS management"

aws iam attach-role-policy \
  --role-name DatabaseAdminRole \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/DatabaseAdminPolicy

# Auditor Role
aws iam create-role \
  --role-name AuditorRole \
  --assume-role-policy-document file://module1-rbac/roles/auditor-role.json \
  --description "Auditor role with read-only CloudTrail/CloudWatch access"

aws iam attach-role-policy \
  --role-name AuditorRole \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/AuditorReadOnlyPolicy
```

---

## Step 7: Enable MFA for All Users

### Via AWS Console (per user):
1. Go to **IAM** → **Users** → Select user
2. Click **Security credentials** tab
3. Under **Multi-factor authentication (MFA)** → **Assign MFA device**
4. Choose **Authenticator app** (Google Authenticator / Authy)
5. Scan QR code and enter two consecutive OTP codes
6. Click **Add MFA**

### Via AWS CLI (Virtual MFA):
```bash
# Step 1: Create virtual MFA device
aws iam create-virtual-mfa-device \
  --virtual-mfa-device-name admin-user-mfa \
  --outfile /tmp/admin-mfa-qr.png \
  --bootstrap-method QRCodePNG

# Step 2: Enable MFA (requires two consecutive TOTP codes)
aws iam enable-mfa-device \
  --user-name admin-user \
  --serial-number arn:aws:iam::ACCOUNT_ID:mfa/admin-user-mfa \
  --authentication-code1 123456 \
  --authentication-code2 789012
```

Repeat for all users: developer-user, tester-user, db-user, auditor-user.

---

## Step 8: Create AWS Resources

### EC2 Instance (EC2-ProjectServer)
```bash
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --instance-type t2.micro \
  --key-name MyKeyPair \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=EC2-ProjectServer},{Key=Project,Value=IAM-Project}]' \
  --count 1
```

### S3 Bucket (Project-S3-Bucket)
```bash
aws s3api create-bucket \
  --bucket Project-S3-Bucket \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket Project-S3-Bucket \
  --versioning-configuration Status=Enabled

# Block public access
aws s3api put-public-access-block \
  --bucket Project-S3-Bucket \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### RDS Instance (Project-RDS-DB)
```bash
aws rds create-db-instance \
  --db-instance-identifier Project-RDS-DB \
  --db-instance-class db.t3.micro \
  --engine mysql \
  --master-username admin \
  --master-user-password "SecureDBPass@123" \
  --allocated-storage 20 \
  --tags Key=Project,Value=IAM-Project Key=Name,Value=Project-RDS-DB
```

---

## Step 9: Enforce IAM Password Policy

```bash
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
```

---

## Step 10: Verify Setup

```bash
# List all users
aws iam list-users

# List all groups
aws iam list-groups

# Verify group memberships
aws iam get-group --group-name Admin
aws iam get-group --group-name Developer
aws iam get-group --group-name Tester
aws iam get-group --group-name DatabaseAdmin
aws iam get-group --group-name Auditor

# List attached policies per group
aws iam list-attached-group-policies --group-name Admin
aws iam list-attached-group-policies --group-name Developer

# Verify CloudTrail is active
aws cloudtrail get-trail-status --name IAM-Project-Trail
```
