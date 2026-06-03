# Module 2 — Employee Promotion Workflow

## Overview

When an employee is promoted or changes roles, their IAM group membership is
updated to reflect their new permissions. This document demonstrates the
Developer → Admin promotion scenario.

---

## Promotion Workflow Diagram

```
Promotion Approved (HR/Manager)
           │
           ▼
┌──────────────────────────┐
│  Step 1                  │
│  Verify Current Access   │
│  (Document existing      │
│   group memberships)     │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Step 2                  │
│  Remove from Old Group   │
│  (Developer group)       │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Step 3                  │
│  Add to New Group        │
│  (Admin group)           │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Step 4                  │
│  Verify New Permissions  │
│  (Test new access level) │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  Step 5                  │
│  Audit Log Review        │
│  (CloudTrail confirms    │
│   group change)          │
└──────────┬───────────────┘
           │
           ▼
   Promotion Complete ✅
```

---

## Example: Developer → Admin Promotion

**Employee:** `john.doe`
**Old Role:** Developer (Developer group)
**New Role:** Admin (Admin group)

---

## Step 1: Verify Current Access

```bash
# Check current group memberships
aws iam list-groups-for-user --user-name john.doe

# Expected output:
# Groups: [Developer]

# Check current permissions (what policies are applied)
aws iam list-attached-group-policies --group-name Developer
```

**Before Promotion — Permissions:**
- ✅ EC2: Start/Stop only
- ✅ S3: Upload/Read only
- ❌ EC2: Cannot terminate
- ❌ S3: Cannot delete
- ❌ RDS: No access
- ❌ IAM: No access

---

## Step 2: Remove from Old Group (Developer)

### Via AWS Console:
1. Sign in as **admin-user** (with MFA)
2. Go to **IAM** → **User Groups** → **Developer**
3. Click **Users** tab
4. Select `john.doe`
5. Click **Remove users from group**
6. Confirm removal

### Via AWS CLI:
```bash
aws iam remove-user-from-group \
  --user-name john.doe \
  --group-name Developer

# Verify removal
aws iam list-groups-for-user --user-name john.doe
# Expected: Developer group no longer listed
```

---

## Step 3: Add to New Group (Admin)

### Via AWS Console:
1. Go to **IAM** → **User Groups** → **Admin**
2. Click **Add Users**
3. Select `john.doe`
4. Click **Add Users**

### Via AWS CLI:
```bash
aws iam add-user-to-group \
  --user-name john.doe \
  --group-name Admin

# Verify addition
aws iam list-groups-for-user --user-name john.doe
# Expected: Admin group listed
```

---

## Step 4: Verify New Permissions

**After Promotion — Permissions:**
- ✅ EC2: Full access (start, stop, terminate, launch)
- ✅ S3: Full access (upload, download, delete)
- ✅ RDS: Full access
- ✅ IAM: Full access
- ✅ CloudTrail: Full access

### Test as john.doe (after promotion):
```bash
# Test 1: Terminate EC2 (was denied before, should work now)
aws ec2 terminate-instances --instance-ids i-xxxxxxxxx
# Expected: Success

# Test 2: Delete S3 object (was denied before, should work now)
aws s3 rm s3://Project-S3-Bucket/test-file.txt
# Expected: Success

# Test 3: List IAM users (was denied before, should work now)
aws iam list-users
# Expected: Success

# Test 4: Describe RDS (was denied before, should work now)
aws rds describe-db-instances
# Expected: Success
```

---

## Step 5: Audit Log Review

```bash
# Check CloudTrail for the group change event
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AddUserToGroup \
  --max-results 5

# Check CloudTrail for the removal event
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RemoveUserFromGroup \
  --max-results 5
```

### Expected CloudTrail Events:
```json
{
  "EventName": "RemoveUserFromGroup",
  "Username": "admin-user",
  "EventTime": "2024-01-20T09:00:00Z",
  "RequestParameters": {
    "userName": "john.doe",
    "groupName": "Developer"
  }
}
```
```json
{
  "EventName": "AddUserToGroup",
  "Username": "admin-user",
  "EventTime": "2024-01-20T09:01:00Z",
  "RequestParameters": {
    "userName": "john.doe",
    "groupName": "Admin"
  }
}
```

---

## Permission Change Summary

| Permission                  | Before (Developer) | After (Admin) |
|-----------------------------|-------------------|---------------|
| EC2 - Start/Stop            | ✅ Allowed        | ✅ Allowed    |
| EC2 - Terminate             | ❌ Denied         | ✅ Allowed    |
| EC2 - Launch                | ❌ Denied         | ✅ Allowed    |
| S3 - Upload                 | ✅ Allowed        | ✅ Allowed    |
| S3 - Delete                 | ❌ Denied         | ✅ Allowed    |
| RDS - Any action            | ❌ Denied         | ✅ Allowed    |
| IAM - Manage users          | ❌ Denied         | ✅ Allowed    |
| CloudTrail - View logs      | ❌ Denied         | ✅ Allowed    |

---

## Other Promotion Scenarios

| From          | To            | Action                                          |
|---------------|---------------|-------------------------------------------------|
| Tester        | Developer     | Remove from Tester, Add to Developer            |
| Developer     | Admin         | Remove from Developer, Add to Admin             |
| DatabaseAdmin | Admin         | Remove from DatabaseAdmin, Add to Admin         |
| Auditor       | Admin         | Remove from Auditor, Add to Admin               |
| Developer     | DatabaseAdmin | Remove from Developer, Add to DatabaseAdmin     |

---

## Security Note

- Promotions must be approved by a manager and executed by an admin
- All group changes are logged in CloudTrail
- The principle of least privilege means old group access is removed before new access is granted
- If the employee needs temporary elevated access, use **IAM Role assumption** with a time-limited session instead of permanent group change
