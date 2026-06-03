# Module 1 — RBAC Testing Procedure

## Testing Strategy

Each user is tested by logging in with their credentials and attempting actions
that should be allowed and actions that should be denied. All results are verified
in CloudTrail.

---

## Test Environment Setup

Before testing, note down:
- AWS Account ID: `ACCOUNT_ID`
- AWS Console URL: `https://ACCOUNT_ID.signin.aws.amazon.com/console`
- EC2 Instance ID: `i-xxxxxxxxxxxxxxxxx` (EC2-ProjectServer)
- S3 Bucket: `Project-S3-Bucket`
- RDS Instance: `Project-RDS-DB`

---

## Test Case 1: Admin User (admin-user)

**Login:** Use admin-user credentials + MFA

### TC-1.1: EC2 Full Access
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| List all EC2 instances      | ✅ Success      |               |           |
| Start EC2-ProjectServer     | ✅ Success      |               |           |
| Stop EC2-ProjectServer      | ✅ Success      |               |           |
| Terminate EC2-ProjectServer | ✅ Success      |               |           |
| Launch new EC2 instance     | ✅ Success      |               |           |

### TC-1.2: S3 Full Access
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| List Project-S3-Bucket      | ✅ Success      |               |           |
| Upload file to bucket       | ✅ Success      |               |           |
| Download file from bucket   | ✅ Success      |               |           |
| Delete file from bucket     | ✅ Success      |               |           |

### TC-1.3: RDS Full Access
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| Describe RDS instances      | ✅ Success      |               |           |
| Create RDS snapshot         | ✅ Success      |               |           |

### TC-1.4: IAM Access
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| List IAM users              | ✅ Success      |               |           |
| Create a test IAM user      | ✅ Success      |               |           |
| Delete the test IAM user    | ✅ Success      |               |           |

---

## Test Case 2: Developer User (developer-user)

**Login:** Use developer-user credentials + MFA

### TC-2.1: EC2 Allowed Actions
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| List EC2 instances          | ✅ Success      |               |           |
| Start EC2-ProjectServer     | ✅ Success      |               |           |
| Stop EC2-ProjectServer      | ✅ Success      |               |           |

### TC-2.2: EC2 Denied Actions
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| Terminate EC2-ProjectServer | ❌ AccessDenied |               |           |
| Launch new EC2 instance     | ❌ AccessDenied |               |           |

### TC-2.3: S3 Allowed Actions
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| List Project-S3-Bucket      | ✅ Success      |               |           |
| Upload file to bucket       | ✅ Success      |               |           |
| Download file from bucket   | ✅ Success      |               |           |

### TC-2.4: S3 Denied Actions
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| Delete file from bucket     | ❌ AccessDenied |               |           |
| Delete the bucket           | ❌ AccessDenied |               |           |

### TC-2.5: RDS Access (should be denied)
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| Describe RDS instances      | ❌ AccessDenied |               |           |
| Modify RDS instance         | ❌ AccessDenied |               |           |

### TC-2.6: IAM Access (should be denied)
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| List IAM users              | ❌ AccessDenied |               |           |
| Create IAM user             | ❌ AccessDenied |               |           |

---

## Test Case 3: Tester User (tester-user)

**Login:** Use tester-user credentials + MFA

### TC-3.1: EC2 Read-Only
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| List EC2 instances          | ✅ Success      |               |           |
| Describe instance details   | ✅ Success      |               |           |
| Start EC2-ProjectServer     | ❌ AccessDenied |               |           |
| Stop EC2-ProjectServer      | ❌ AccessDenied |               |           |
| Terminate EC2-ProjectServer | ❌ AccessDenied |               |           |

### TC-3.2: S3 Read-Only
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| List Project-S3-Bucket      | ✅ Success      |               |           |
| Download file from bucket   | ✅ Success      |               |           |
| Upload file to bucket       | ❌ AccessDenied |               |           |
| Delete file from bucket     | ❌ AccessDenied |               |           |

### TC-3.3: RDS Access (should be denied)
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| Describe RDS instances      | ❌ AccessDenied |               |           |

---

## Test Case 4: Database Admin User (db-user)

**Login:** Use db-user credentials + MFA

### TC-4.1: RDS Full Access
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| Describe RDS instances      | ✅ Success      |               |           |
| Create RDS snapshot         | ✅ Success      |               |           |
| Modify RDS instance         | ✅ Success      |               |           |
| Stop RDS instance           | ✅ Success      |               |           |
| Start RDS instance          | ✅ Success      |               |           |

### TC-4.2: EC2 Access (should be denied)
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| List EC2 instances          | ❌ AccessDenied |               |           |
| Start EC2 instance          | ❌ AccessDenied |               |           |

### TC-4.3: S3 Access (should be denied)
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| List S3 buckets             | ❌ AccessDenied |               |           |
| Upload to S3                | ❌ AccessDenied |               |           |

---

## Test Case 5: Auditor User (auditor-user)

**Login:** Use auditor-user credentials + MFA

### TC-5.1: CloudTrail Read-Only
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| Describe CloudTrail trails  | ✅ Success      |               |           |
| Lookup CloudTrail events    | ✅ Success      |               |           |
| Stop CloudTrail logging     | ❌ AccessDenied |               |           |
| Delete CloudTrail trail     | ❌ AccessDenied |               |           |

### TC-5.2: CloudWatch Read-Only
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| List CloudWatch metrics     | ✅ Success      |               |           |
| View CloudWatch logs        | ✅ Success      |               |           |
| Create CloudWatch alarm     | ❌ AccessDenied |               |           |

### TC-5.3: EC2/S3/RDS Access (should be denied)
| Test                        | Expected Result | Actual Result | Pass/Fail |
|-----------------------------|-----------------|---------------|-----------|
| List EC2 instances          | ❌ AccessDenied |               |           |
| List S3 buckets             | ❌ AccessDenied |               |           |
| Describe RDS instances      | ❌ AccessDenied |               |           |

---

## Test Case 6: MFA Enforcement

### TC-6.1: Access Without MFA
| Test                                    | Expected Result | Actual Result | Pass/Fail |
|-----------------------------------------|-----------------|---------------|-----------|
| admin-user accesses EC2 without MFA     | ❌ AccessDenied |               |           |
| developer-user accesses S3 without MFA  | ❌ AccessDenied |               |           |

### How to Test Without MFA:
Use AWS CLI with long-term credentials (no session token) and attempt an action.
The policy condition `"aws:MultiFactorAuthPresent": "true"` will deny the request.

```bash
# This should fail for admin-user without MFA session
aws ec2 describe-instances --profile admin-user-no-mfa
# Expected: An error occurred (AccessDenied)
```

---

## Test Case 7: CloudTrail Audit Verification

After running all tests, verify that CloudTrail captured the events:

```bash
# Look up recent events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=developer-user \
  --max-results 10

# Look for denied events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=TerminateInstances \
  --max-results 5
```

### Expected CloudTrail Output for a Denied Action:
```json
{
  "EventName": "TerminateInstances",
  "Username": "developer-user",
  "EventTime": "2024-01-15T10:30:00Z",
  "ErrorCode": "Client.UnauthorizedOperation",
  "ErrorMessage": "You are not authorized to perform this operation."
}
```

---

## Expected Test Summary

| User           | Allowed Actions Passed | Denied Actions Blocked | MFA Enforced |
|----------------|------------------------|------------------------|--------------|
| admin-user     | All ✅                 | N/A                    | ✅           |
| developer-user | EC2 start/stop, S3 ✅  | Delete, Terminate ✅   | ✅           |
| tester-user    | EC2/S3 read ✅         | All writes ✅          | ✅           |
| db-user        | RDS full ✅            | EC2, S3, IAM ✅        | ✅           |
| auditor-user   | CloudTrail/CW read ✅  | All writes ✅          | ✅           |
