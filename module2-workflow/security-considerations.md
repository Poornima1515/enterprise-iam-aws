# Security Considerations — Enterprise IAM System

## 1. Principle of Least Privilege

**Definition:** Every user, role, and service should have only the minimum permissions
required to perform their specific job function.

### Implementation in This Project:

| Role          | Principle Applied                                              |
|---------------|----------------------------------------------------------------|
| Admin         | Full access — only for designated system administrators        |
| Developer     | EC2 start/stop + S3 upload only — no delete, no RDS, no IAM   |
| Tester        | Read-only — cannot modify any resource                         |
| DatabaseAdmin | RDS only — completely isolated from EC2, S3, IAM               |
| Auditor       | CloudTrail/CloudWatch read-only — cannot modify audit logs     |

### Key Practices:
- Use explicit `Deny` statements for critical actions (delete, terminate)
- Scope resource ARNs to specific resources, not `*` where possible
- Regularly review and remove unused permissions (access advisor)

---

## 2. Multi-Factor Authentication (MFA)

**Why MFA is Critical:**
- Passwords alone can be phished, brute-forced, or leaked
- MFA adds a second factor (something you have) that attackers cannot easily steal
- AWS policies can enforce MFA using the `aws:MultiFactorAuthPresent` condition

### MFA Policy Condition Used:
```json
"Condition": {
  "Bool": {
    "aws:MultiFactorAuthPresent": "true"
  }
}
```

### MFA Best Practices:
- Use hardware MFA tokens (YubiKey) for admin accounts
- Use virtual MFA (Google Authenticator, Authy) for standard users
- Never share MFA devices between users
- Immediately deactivate MFA when an employee leaves
- Enforce MFA for all console and CLI access

---

## 3. IAM Password Policy

The account-level password policy enforces strong passwords:

| Setting                    | Value    | Reason                                    |
|----------------------------|----------|-------------------------------------------|
| Minimum length             | 12 chars | Longer passwords are harder to brute-force|
| Require uppercase          | Yes      | Increases character space                 |
| Require lowercase          | Yes      | Increases character space                 |
| Require numbers            | Yes      | Increases character space                 |
| Require symbols            | Yes      | Increases character space                 |
| Password expiry            | 90 days  | Limits exposure window if compromised     |
| Password reuse prevention  | 5        | Prevents cycling back to old passwords    |
| Allow user to change       | Yes      | Empowers users to manage their own access |

---

## 4. CloudTrail Auditing

**Why CloudTrail is Essential:**
- Records every API call made in the AWS account
- Provides who, what, when, and from where for every action
- Enables forensic investigation after a security incident
- Detects unauthorized access attempts

### CloudTrail Configuration:
- Multi-region trail (captures all regions)
- Log file validation enabled (detects tampering)
- CloudWatch Logs integration (real-time alerting)
- S3 bucket with versioning and MFA delete protection

### Key Events to Monitor:
```
ConsoleLogin          → Track all login attempts
UnauthorizedOperation → Detect permission violations
DeleteUser            → Alert on user deletions
StopLogging           → Alert if someone tries to disable CloudTrail
CreateAccessKey       → Track new credential creation
AttachUserPolicy      → Track direct policy attachments (bypass groups)
```

### CloudWatch Alarm for Unauthorized Access:
```bash
# Create metric filter for unauthorized operations
aws logs put-metric-filter \
  --log-group-name CloudTrail/IAMProjectLogs \
  --filter-name UnauthorizedOperations \
  --filter-pattern '{ ($.errorCode = "AccessDenied") || ($.errorCode = "UnauthorizedOperation") }' \
  --metric-transformations \
    metricName=UnauthorizedOperationCount,metricNamespace=IAMProject,metricValue=1

# Create alarm
aws cloudwatch put-metric-alarm \
  --alarm-name UnauthorizedAccessAlarm \
  --metric-name UnauthorizedOperationCount \
  --namespace IAMProject \
  --statistic Sum \
  --period 300 \
  --threshold 3 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:us-east-1:ACCOUNT_ID:SecurityAlerts
```

---

## 5. Resource-Level Permissions

Instead of granting access to all resources of a type, scope permissions to
specific resource ARNs.

### Example — Developer can only manage the project EC2 instance:
```json
"Resource": "arn:aws:ec2:*:*:instance/*",
"Condition": {
  "StringEquals": {
    "ec2:ResourceTag/Project": "IAM-Project"
  }
}
```

### Example — Developer can only access the project S3 bucket:
```json
"Resource": [
  "arn:aws:s3:::Project-S3-Bucket",
  "arn:aws:s3:::Project-S3-Bucket/*"
]
```

---

## 6. Access Key Security

### Best Practices:
- Rotate access keys every 90 days
- Never embed access keys in code or commit to version control
- Use IAM roles for EC2 instances instead of access keys
- Use AWS Secrets Manager or Parameter Store for storing credentials
- Monitor for unused access keys (disable after 90 days of inactivity)

### Detect Old Access Keys:
```bash
# Generate credential report
aws iam generate-credential-report
aws iam get-credential-report --query 'Content' --output text | base64 -d

# List access keys with last used date
aws iam list-access-keys --user-name john.doe
aws iam get-access-key-last-used --access-key-id AKIAIOSFODNN7EXAMPLE
```

---

## 7. S3 Bucket Security

### Project-S3-Bucket Security Configuration:
- Block all public access (enabled)
- Bucket versioning (enabled — protects against accidental deletion)
- Server-side encryption (SSE-S3 or SSE-KMS)
- Bucket policy restricts access to specific IAM principals only

### Bucket Policy (restrict to project users only):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::Project-S3-Bucket",
        "arn:aws:s3:::Project-S3-Bucket/*"
      ],
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalArn": [
            "arn:aws:iam::ACCOUNT_ID:user/admin-user",
            "arn:aws:iam::ACCOUNT_ID:user/developer-user",
            "arn:aws:iam::ACCOUNT_ID:user/tester-user"
          ]
        }
      }
    }
  ]
}
```

---

## 8. RDS Security

### Project-RDS-DB Security Configuration:
- Not publicly accessible (VPC only)
- Encrypted at rest (AWS KMS)
- Encrypted in transit (SSL/TLS enforced)
- Credentials stored in AWS Secrets Manager
- Automated backups enabled (7-day retention)
- Multi-AZ deployment (for production)

---

## 9. IAM Role vs. IAM User — When to Use Each

| Scenario                              | Use IAM User | Use IAM Role |
|---------------------------------------|--------------|--------------|
| Human employee needing console access | ✅           | ❌           |
| EC2 instance accessing S3             | ❌           | ✅           |
| Lambda function accessing DynamoDB    | ❌           | ✅           |
| Cross-account access                  | ❌           | ✅           |
| Temporary elevated access             | ❌           | ✅           |
| CI/CD pipeline                        | ❌           | ✅           |

---

## 10. Security Incident Response

### If Credentials Are Compromised:
1. **Immediately** disable the IAM user's console access
2. **Immediately** deactivate all access keys
3. Review CloudTrail for unauthorized actions in the last 24-48 hours
4. Rotate any secrets or credentials the user had access to
5. Notify the security team
6. Investigate the root cause
7. Create a new user account with fresh credentials after investigation

### Useful Commands for Incident Response:
```bash
# Get all recent actions by a user
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=compromised-user \
  --start-time 2024-01-01T00:00:00Z

# Check what resources were accessed
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=compromised-user \
  --query 'Events[].{Event:EventName,Time:EventTime,Resource:Resources[0].ResourceName}'
```
