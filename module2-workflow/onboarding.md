# Module 2 — Employee Onboarding Workflow

## Overview

This document describes the complete step-by-step process for onboarding a new
employee into the AWS IAM system, from account creation to verified access.

---

## Onboarding Workflow Diagram

```
New Employee Joins
        │
        ▼
┌───────────────────┐
│  Step 1           │
│  Create IAM User  │
│  (username based  │
│   on employee ID) │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│  Step 2           │
│  Assign to        │
│  Department Group │
│  (based on role)  │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│  Step 3           │
│  Enable MFA       │
│  (Virtual/HW      │
│   Authenticator)  │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│  Step 4           │
│  Generate         │
│  Credentials      │
│  (Temp password + │
│   Access Keys)    │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│  Step 5           │
│  Verify Access    │
│  (Test login +    │
│   permissions)    │
└────────┬──────────┘
         │
         ▼
   Employee Active ✅
```

---

## Step 1: Create IAM User

### Naming Convention
- Format: `firstname.lastname` or `department-empID`
- Example: `john.doe` or `dev-emp001`

### Via AWS Console:
1. Sign in as **admin-user** (with MFA)
2. Navigate to **IAM** → **Users** → **Add Users**
3. Enter username (e.g., `john.doe`)
4. Select **AWS Management Console access**
5. Set **Custom password** (temporary)
6. Check **User must create a new password at next sign-in**
7. Click **Next: Permissions** (do NOT assign permissions here — use groups)
8. Add tags:
   - `Department` = `Engineering`
   - `EmployeeID` = `EMP001`
   - `JoinDate` = `2024-01-15`
   - `Project` = `IAM-Project`
9. Click **Create User**

### Via AWS CLI:
```bash
# Create the IAM user
aws iam create-user \
  --user-name john.doe \
  --tags \
    Key=Department,Value=Engineering \
    Key=EmployeeID,Value=EMP001 \
    Key=JoinDate,Value=2024-01-15 \
    Key=Project,Value=IAM-Project

# Create console login profile
aws iam create-login-profile \
  --user-name john.doe \
  --password "Welcome@Temp123!" \
  --password-reset-required
```

---

## Step 2: Assign Department-Based Group

Map the employee's department to the correct IAM group:

| Department       | IAM Group     | Policy Applied          |
|------------------|---------------|-------------------------|
| IT / DevOps      | Admin         | AdminFullAccessPolicy   |
| Engineering      | Developer     | DeveloperAccessPolicy   |
| QA / Testing     | Tester        | TesterReadOnlyPolicy    |
| Database / DBA   | DatabaseAdmin | DatabaseAdminPolicy     |
| Compliance / Sec | Auditor       | AuditorReadOnlyPolicy   |

### Example: New Developer (john.doe → Developer group)

### Via AWS Console:
1. Go to **IAM** → **User Groups** → **Developer**
2. Click **Add Users**
3. Select `john.doe`
4. Click **Add Users**

### Via AWS CLI:
```bash
aws iam add-user-to-group \
  --user-name john.doe \
  --group-name Developer
```

### Verify Group Assignment:
```bash
aws iam list-groups-for-user --user-name john.doe
```

---

## Step 3: Enable MFA

MFA is mandatory for all users. The policy conditions enforce MFA presence.

### Via AWS Console:
1. Go to **IAM** → **Users** → `john.doe`
2. Click **Security credentials** tab
3. Under **Multi-factor authentication (MFA)** → **Assign MFA device**
4. Device name: `john.doe-mfa`
5. Select **Authenticator app**
6. Show QR code → Employee scans with Google Authenticator / Authy
7. Enter **MFA code 1** and **MFA code 2** (two consecutive codes)
8. Click **Add MFA**

### Via AWS CLI:
```bash
# Step 1: Create virtual MFA device
aws iam create-virtual-mfa-device \
  --virtual-mfa-device-name john.doe-mfa \
  --outfile /tmp/john-doe-mfa-qr.png \
  --bootstrap-method QRCodePNG

# Step 2: Employee scans QR code and provides two consecutive OTP codes
# Step 3: Enable MFA device
aws iam enable-mfa-device \
  --user-name john.doe \
  --serial-number arn:aws:iam::ACCOUNT_ID:mfa/john.doe-mfa \
  --authentication-code1 <CODE1> \
  --authentication-code2 <CODE2>
```

### Verify MFA:
```bash
aws iam list-mfa-devices --user-name john.doe
```

---

## Step 4: Generate Credentials

### Console Access Credentials:
- Already created in Step 1 (temporary password)
- Employee must reset on first login

### Programmatic Access (CLI/SDK) — if required for the role:
```bash
# Create access keys (only if the role requires CLI/SDK access)
aws iam create-access-key --user-name john.doe
```

**Important:** Store the `SecretAccessKey` securely — it is shown only once.
Deliver credentials via a secure channel (encrypted email, password manager, etc.)

### Credential Delivery Checklist:
- [ ] Console URL: `https://ACCOUNT_ID.signin.aws.amazon.com/console`
- [ ] Username: `john.doe`
- [ ] Temporary password: (delivered securely)
- [ ] MFA device: configured (employee has authenticator app set up)
- [ ] Access Key ID + Secret (if applicable): delivered via secure channel

---

## Step 5: Verify Access

### Employee First Login Test:
1. Employee logs in at `https://ACCOUNT_ID.signin.aws.amazon.com/console`
2. Enters username and temporary password
3. Prompted to set new password
4. Prompted for MFA code
5. Successfully lands on AWS Console

### Admin Verification (run as admin-user):
```bash
# Check user exists and is active
aws iam get-user --user-name john.doe

# Verify group membership
aws iam list-groups-for-user --user-name john.doe

# Verify MFA is enabled
aws iam list-mfa-devices --user-name john.doe

# Check last login (after employee logs in)
aws iam get-user --user-name john.doe --query 'User.PasswordLastUsed'
```

### Permission Verification (run as john.doe):
```bash
# Test allowed action — list EC2 instances
aws ec2 describe-instances

# Test allowed action — list S3 bucket
aws s3 ls s3://Project-S3-Bucket

# Test denied action — should return AccessDenied
aws ec2 terminate-instances --instance-ids i-xxxxxxxxx
```

---

## Onboarding Checklist

| Step | Task                                    | Completed | Notes |
|------|-----------------------------------------|-----------|-------|
| 1    | IAM user created                        | ☐         |       |
| 2    | Assigned to correct department group    | ☐         |       |
| 3    | MFA device enabled                      | ☐         |       |
| 4    | Temporary credentials delivered securely| ☐         |       |
| 5    | Employee completed first login          | ☐         |       |
| 6    | Employee reset password                 | ☐         |       |
| 7    | Permission verification passed          | ☐         |       |
| 8    | CloudTrail shows successful login       | ☐         |       |
| 9    | Employee briefed on security policies   | ☐         |       |
