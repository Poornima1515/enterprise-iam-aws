# Module 2 — Employee Offboarding / Access Revocation Workflow

## Overview

When an employee leaves the organization (resignation, termination, or contract end),
their AWS access must be revoked immediately and completely. This document describes
the full offboarding procedure.

---

## Offboarding Workflow Diagram

```
Employee Exit Notification
           │
           ▼
┌──────────────────────────┐
│  Step 1                  │
│  Disable Console Access  │
│  (Immediate — Day 0)     │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Step 2                  │
│  Deactivate Access Keys  │
│  (Disable all API keys)  │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Step 3                  │
│  Remove from All Groups  │
│  (Revoke all permissions)│
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Step 4                  │
│  Deactivate MFA Device   │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Step 5                  │
│  Delete Access Keys      │
│  (Permanent removal)     │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Step 6                  │
│  Delete IAM User         │
│  (Final cleanup)         │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Step 7                  │
│  Audit & Verify          │
│  (CloudTrail review)     │
└──────────┬───────────────┘
           │
           ▼
   Offboarding Complete ✅
```

---

## Example: Offboarding john.doe (Developer)

---

## Step 1: Disable Console Access (Immediate)

This is the first and most critical step — prevents the employee from logging in.

### Via AWS Console:
1. Sign in as **admin-user** (with MFA)
2. Go to **IAM** → **Users** → `john.doe`
3. Click **Security credentials** tab
4. Under **Console password** → Click **Manage**
5. Select **Disable console access**
6. Click **Apply**

### Via AWS CLI:
```bash
# Delete the login profile (disables console access)
aws iam delete-login-profile --user-name john.doe

# Verify console access is disabled
aws iam get-login-profile --user-name john.doe
# Expected: NoSuchEntity error (login profile deleted)
```

---

## Step 2: Deactivate Access Keys

Immediately deactivate all programmatic access keys.

### Via AWS Console:
1. Go to **IAM** → **Users** → `john.doe`
2. Click **Security credentials** tab
3. Under **Access keys** → Click **Make inactive** for each key

### Via AWS CLI:
```bash
# List all access keys for the user
aws iam list-access-keys --user-name john.doe

# Deactivate each access key (replace AKIAIOSFODNN7EXAMPLE with actual key ID)
aws iam update-access-key \
  --user-name john.doe \
  --access-key-id AKIAIOSFODNN7EXAMPLE \
  --status Inactive

# Verify deactivation
aws iam list-access-keys --user-name john.doe
# Expected: Status = Inactive
```

---

## Step 3: Remove from All Groups

Removing from groups immediately revokes all permissions.

### Via AWS Console:
1. Go to **IAM** → **Users** → `john.doe`
2. Click **Groups** tab
3. Select all groups
4. Click **Remove user from groups**

### Via AWS CLI:
```bash
# First, list all groups the user belongs to
aws iam list-groups-for-user --user-name john.doe

# Remove from each group
aws iam remove-user-from-group \
  --user-name john.doe \
  --group-name Developer

# If user was in multiple groups, remove from each:
# aws iam remove-user-from-group --user-name john.doe --group-name Admin
# aws iam remove-user-from-group --user-name john.doe --group-name Tester

# Verify no groups remain
aws iam list-groups-for-user --user-name john.doe
# Expected: Empty groups list
```

---

## Step 4: Deactivate MFA Device

### Via AWS Console:
1. Go to **IAM** → **Users** → `john.doe`
2. Click **Security credentials** tab
3. Under **Multi-factor authentication (MFA)** → Click **Deactivate**
4. Confirm deactivation

### Via AWS CLI:
```bash
# List MFA devices
aws iam list-mfa-devices --user-name john.doe

# Deactivate MFA device
aws iam deactivate-mfa-device \
  --user-name john.doe \
  --serial-number arn:aws:iam::ACCOUNT_ID:mfa/john.doe-mfa

# Delete the virtual MFA device
aws iam delete-virtual-mfa-device \
  --serial-number arn:aws:iam::ACCOUNT_ID:mfa/john.doe-mfa
```

---

## Step 5: Delete Access Keys (Permanent)

After deactivating, permanently delete the access keys.

### Via AWS CLI:
```bash
# Delete access key permanently
aws iam delete-access-key \
  --user-name john.doe \
  --access-key-id AKIAIOSFODNN7EXAMPLE

# Verify deletion
aws iam list-access-keys --user-name john.doe
# Expected: Empty list
```

---

## Step 6: Delete IAM User

### Via AWS Console:
1. Go to **IAM** → **Users**
2. Select `john.doe`
3. Click **Delete**
4. Type the username to confirm
5. Click **Delete**

### Via AWS CLI:
```bash
# Delete the IAM user
aws iam delete-user --user-name john.doe

# Verify deletion
aws iam get-user --user-name john.doe
# Expected: NoSuchEntity error
```

---

## Step 7: Audit and Verify

### Verify in CloudTrail:
```bash
# Check all offboarding actions were logged
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=admin-user \
  --max-results 20

# Look for specific offboarding events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=DeleteLoginProfile

aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=DeleteUser
```

### Expected CloudTrail Events (in order):
```
1. DeleteLoginProfile    → Console access disabled
2. UpdateAccessKey       → Access key deactivated
3. RemoveUserFromGroup   → Removed from Developer group
4. DeactivateMFADevice   → MFA deactivated
5. DeleteAccessKey       → Access key deleted
6. DeleteVirtualMFADevice → MFA device deleted
7. DeleteUser            → User account deleted
```

---

## Offboarding Checklist

| Step | Task                                      | Completed | Timestamp | Admin |
|------|-------------------------------------------|-----------|-----------|-------|
| 1    | Console access disabled                   | ☐         |           |       |
| 2    | All access keys deactivated               | ☐         |           |       |
| 3    | Removed from all IAM groups               | ☐         |           |       |
| 4    | MFA device deactivated                    | ☐         |           |       |
| 5    | All access keys deleted                   | ☐         |           |       |
| 6    | IAM user deleted                          | ☐         |           |       |
| 7    | CloudTrail audit reviewed                 | ☐         |           |       |
| 8    | Credential report generated and archived  | ☐         |           |       |
| 9    | IT/Security team notified                 | ☐         |           |       |

---

## Emergency Offboarding (Immediate Termination)

For immediate termination (security incident, misconduct), execute all steps
in a single CLI script:

```bash
USERNAME="john.doe"
ACCOUNT_ID="123456789012"

echo "=== EMERGENCY OFFBOARDING: $USERNAME ==="

# 1. Disable console access
aws iam delete-login-profile --user-name $USERNAME 2>/dev/null
echo "✅ Console access disabled"

# 2. Deactivate all access keys
for KEY_ID in $(aws iam list-access-keys --user-name $USERNAME \
  --query 'AccessKeyMetadata[].AccessKeyId' --output text); do
  aws iam update-access-key \
    --user-name $USERNAME \
    --access-key-id $KEY_ID \
    --status Inactive
  echo "✅ Access key $KEY_ID deactivated"
done

# 3. Remove from all groups
for GROUP in $(aws iam list-groups-for-user --user-name $USERNAME \
  --query 'Groups[].GroupName' --output text); do
  aws iam remove-user-from-group \
    --user-name $USERNAME \
    --group-name $GROUP
  echo "✅ Removed from group: $GROUP"
done

echo "=== IMMEDIATE ACCESS REVOKED for $USERNAME ==="
echo "Complete deletion can be done after HR confirmation."
```
