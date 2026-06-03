# Module 2 — Testing Scenarios

## Overview

These test scenarios validate the complete employee lifecycle workflow:
Onboarding → Promotion → Offboarding.

---

## Scenario 1: New Developer Onboarding

**Objective:** Verify that a newly onboarded developer gets correct access.

**Employee:** `alice.dev` | **Department:** Engineering | **Group:** Developer

### Pre-conditions:
- Admin user is logged in with MFA
- Developer group exists with DeveloperAccessPolicy attached

### Test Steps:

#### TS-1.1: Create User
```bash
aws iam create-user --user-name alice.dev \
  --tags Key=Department,Value=Engineering Key=EmployeeID,Value=EMP002

aws iam create-login-profile \
  --user-name alice.dev \
  --password "Welcome@Temp456!" \
  --password-reset-required
```
**Expected:** User created successfully, login profile created.

#### TS-1.2: Assign to Developer Group
```bash
aws iam add-user-to-group --user-name alice.dev --group-name Developer
aws iam list-groups-for-user --user-name alice.dev
```
**Expected:** Output shows `Developer` group.

#### TS-1.3: Enable MFA
```bash
aws iam create-virtual-mfa-device \
  --virtual-mfa-device-name alice.dev-mfa \
  --outfile /tmp/alice-mfa-qr.png \
  --bootstrap-method QRCodePNG

# After scanning QR and getting two codes:
aws iam enable-mfa-device \
  --user-name alice.dev \
  --serial-number arn:aws:iam::ACCOUNT_ID:mfa/alice.dev-mfa \
  --authentication-code1 <CODE1> \
  --authentication-code2 <CODE2>
```
**Expected:** MFA device listed for alice.dev.

#### TS-1.4: Verify Allowed Actions (as alice.dev)
```bash
# Should succeed
aws ec2 describe-instances
aws ec2 start-instances --instance-ids i-xxxxxxxxx
aws s3 ls s3://Project-S3-Bucket
aws s3 cp test.txt s3://Project-S3-Bucket/test.txt
```
**Expected:** All commands succeed.

#### TS-1.5: Verify Denied Actions (as alice.dev)
```bash
# Should fail with AccessDenied
aws ec2 terminate-instances --instance-ids i-xxxxxxxxx
aws s3 rm s3://Project-S3-Bucket/test.txt
aws rds describe-db-instances
aws iam list-users
```
**Expected:** All commands return `AccessDenied`.

### Pass Criteria:
- [ ] User created with correct tags
- [ ] Assigned to Developer group
- [ ] MFA enabled
- [ ] Allowed actions succeed
- [ ] Denied actions blocked
- [ ] CloudTrail shows all onboarding events

---

## Scenario 2: New Tester Onboarding

**Objective:** Verify that a newly onboarded tester gets read-only access.

**Employee:** `bob.test` | **Department:** QA | **Group:** Tester

### Test Steps:

#### TS-2.1: Create and Assign
```bash
aws iam create-user --user-name bob.test \
  --tags Key=Department,Value=QA Key=EmployeeID,Value=EMP003

aws iam create-login-profile \
  --user-name bob.test \
  --password "Welcome@Temp789!" \
  --password-reset-required

aws iam add-user-to-group --user-name bob.test --group-name Tester
```

#### TS-2.2: Verify Read-Only Access (as bob.test)
```bash
# Should succeed (read-only)
aws ec2 describe-instances
aws s3 ls s3://Project-S3-Bucket
aws s3 cp s3://Project-S3-Bucket/test.txt /tmp/downloaded.txt
```
**Expected:** All read operations succeed.

#### TS-2.3: Verify Write Operations Blocked (as bob.test)
```bash
# Should fail
aws ec2 start-instances --instance-ids i-xxxxxxxxx
aws s3 cp test.txt s3://Project-S3-Bucket/new-file.txt
aws rds describe-db-instances
```
**Expected:** All write/modify operations return `AccessDenied`.

### Pass Criteria:
- [ ] Read operations succeed
- [ ] Write/modify operations blocked
- [ ] MFA enforced

---

## Scenario 3: Developer → Admin Promotion

**Objective:** Verify that promoting alice.dev to Admin grants full access.

### Pre-conditions:
- alice.dev is in Developer group
- alice.dev cannot terminate EC2 or delete S3 objects

### Test Steps:

#### TS-3.1: Verify Current Limitations (as alice.dev — before promotion)
```bash
aws ec2 terminate-instances --instance-ids i-xxxxxxxxx
# Expected: AccessDenied

aws s3 rm s3://Project-S3-Bucket/test.txt
# Expected: AccessDenied
```

#### TS-3.2: Execute Promotion (as admin-user)
```bash
aws iam remove-user-from-group --user-name alice.dev --group-name Developer
aws iam add-user-to-group --user-name alice.dev --group-name Admin
```

#### TS-3.3: Verify New Permissions (as alice.dev — after promotion)
```bash
# These should now succeed
aws ec2 terminate-instances --instance-ids i-xxxxxxxxx
# Expected: Success

aws s3 rm s3://Project-S3-Bucket/test.txt
# Expected: Success

aws iam list-users
# Expected: Success

aws rds describe-db-instances
# Expected: Success
```

#### TS-3.4: Verify CloudTrail Captured Promotion
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RemoveUserFromGroup

aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AddUserToGroup
```
**Expected:** Both events logged with admin-user as the actor.

### Pass Criteria:
- [ ] Old permissions revoked immediately after group removal
- [ ] New permissions active immediately after group addition
- [ ] CloudTrail shows group change events
- [ ] No gap in access during transition

---

## Scenario 4: Employee Offboarding (Planned Exit)

**Objective:** Verify that all access is revoked when bob.test leaves.

### Test Steps:

#### TS-4.1: Disable Console Access
```bash
aws iam delete-login-profile --user-name bob.test
```
**Verify:** Try to log in as bob.test → Should fail with "User does not exist or password is incorrect."

#### TS-4.2: Deactivate Access Keys
```bash
KEY_ID=$(aws iam list-access-keys --user-name bob.test \
  --query 'AccessKeyMetadata[0].AccessKeyId' --output text)

aws iam update-access-key \
  --user-name bob.test \
  --access-key-id $KEY_ID \
  --status Inactive
```
**Verify:** CLI commands with bob.test credentials return `InvalidClientTokenId`.

#### TS-4.3: Remove from Groups
```bash
aws iam remove-user-from-group --user-name bob.test --group-name Tester
aws iam list-groups-for-user --user-name bob.test
```
**Expected:** Empty groups list.

#### TS-4.4: Delete Access Keys and User
```bash
aws iam delete-access-key --user-name bob.test --access-key-id $KEY_ID
aws iam delete-user --user-name bob.test
```
**Verify:** `aws iam get-user --user-name bob.test` returns `NoSuchEntity`.

### Pass Criteria:
- [ ] Console login fails after Step 1
- [ ] API calls fail after Step 2
- [ ] No group memberships after Step 3
- [ ] User completely removed after Step 4
- [ ] All steps logged in CloudTrail

---

## Scenario 5: Emergency Offboarding (Immediate Termination)

**Objective:** Verify that access can be revoked within 60 seconds.

### Test Steps:

#### TS-5.1: Run Emergency Script
```bash
USERNAME="alice.dev"

# Disable console
aws iam delete-login-profile --user-name $USERNAME

# Deactivate all keys
for KEY_ID in $(aws iam list-access-keys --user-name $USERNAME \
  --query 'AccessKeyMetadata[].AccessKeyId' --output text); do
  aws iam update-access-key --user-name $USERNAME \
    --access-key-id $KEY_ID --status Inactive
done

# Remove from all groups
for GROUP in $(aws iam list-groups-for-user --user-name $USERNAME \
  --query 'Groups[].GroupName' --output text); do
  aws iam remove-user-from-group --user-name $USERNAME --group-name $GROUP
done

echo "Access revoked for $USERNAME"
```

#### TS-5.2: Verify Immediate Revocation
```bash
# Attempt console login → Should fail
# Attempt CLI command → Should fail
aws ec2 describe-instances --profile alice-dev
# Expected: An error occurred (InvalidClientTokenId)
```

### Pass Criteria:
- [ ] All access revoked within 60 seconds
- [ ] Console login fails
- [ ] CLI access fails
- [ ] CloudTrail shows all revocation events

---

## Scenario 6: MFA Enforcement Test

**Objective:** Verify that users cannot access resources without MFA.

### Test Steps:

#### TS-6.1: Attempt Access Without MFA Session
```bash
# Configure AWS CLI with long-term credentials (no MFA session token)
aws configure --profile developer-no-mfa
# Enter developer-user's access key and secret

# Attempt to access EC2
aws ec2 describe-instances --profile developer-no-mfa
```
**Expected:** `AccessDenied` — MFA condition not satisfied.

#### TS-6.2: Access With MFA Session
```bash
# Get session token with MFA
aws sts get-session-token \
  --serial-number arn:aws:iam::ACCOUNT_ID:mfa/developer-user-mfa \
  --token-code 123456

# Configure profile with session token
aws configure set aws_session_token <SESSION_TOKEN> --profile developer-mfa

# Attempt to access EC2
aws ec2 describe-instances --profile developer-mfa
```
**Expected:** Success — MFA condition satisfied.

### Pass Criteria:
- [ ] Access denied without MFA session
- [ ] Access granted with valid MFA session
- [ ] CloudTrail shows `ConsoleLogin` with MFA status

---

## Test Summary Report Template

| Scenario | Description                    | Steps Passed | Steps Failed | Status |
|----------|--------------------------------|--------------|--------------|--------|
| 1        | Developer Onboarding           | /5           | /5           |        |
| 2        | Tester Onboarding              | /3           | /3           |        |
| 3        | Developer → Admin Promotion    | /4           | /4           |        |
| 4        | Planned Offboarding            | /4           | /4           |        |
| 5        | Emergency Offboarding          | /2           | /2           |        |
| 6        | MFA Enforcement                | /2           | /2           |        |
| **Total**|                                |              |              |        |
