# Security Incident Response Runbook

## Incident: Unauthorized Access Detected

### Immediate Steps (< 5 minutes)
1. Identify the user from CloudTrail
2. Disable console access
3. Deactivate access keys
4. Remove from all groups

### Commands
```bash
# Step 1: Identify
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=UnauthorizedOperation \
  --max-results 10

# Step 2: Disable
aws iam delete-login-profile --user-name SUSPECT_USER

# Step 3: Deactivate keys
aws iam list-access-keys --user-name SUSPECT_USER
aws iam update-access-key --user-name SUSPECT_USER --access-key-id KEY_ID --status Inactive

# Step 4: Remove groups
aws iam remove-user-from-group --user-name SUSPECT_USER --group-name GROUP_NAME
```

## Incident: Root Account Used
1. Check CloudTrail immediately
2. Verify it was authorized
3. If unauthorized - change root password immediately
4. Enable MFA on root if not already done
5. Delete root access keys

## Weekly Security Checklist
- [ ] Review CloudTrail for unauthorized access
- [ ] Check IAM Access Analyzer findings
- [ ] Verify all users have MFA active
- [ ] Review inactive users report from Lambda
- [ ] Rotate access keys older than 90 days
