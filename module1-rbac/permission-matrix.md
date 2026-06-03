# Permission Matrix — RBAC System

## Overview

This matrix maps each IAM Group/Role to specific actions on each AWS resource.

Legend:
- ✅ Full Access
- 🔵 Read Only
- 🟡 Limited (specific actions only)
- ❌ No Access / Explicitly Denied

---

## Permission Matrix Table

| Action                        | Admin | Developer | Tester | DatabaseAdmin | Auditor |
|-------------------------------|-------|-----------|--------|---------------|---------|
| **EC2**                       |       |           |        |               |         |
| EC2 - Describe/List           | ✅    | ✅        | 🔵     | ❌            | ❌      |
| EC2 - Start Instance          | ✅    | ✅        | ❌     | ❌            | ❌      |
| EC2 - Stop Instance           | ✅    | ✅        | ❌     | ❌            | ❌      |
| EC2 - Reboot Instance         | ✅    | ✅        | ❌     | ❌            | ❌      |
| EC2 - Launch Instance         | ✅    | ❌        | ❌     | ❌            | ❌      |
| EC2 - Terminate Instance      | ✅    | ❌        | ❌     | ❌            | ❌      |
| EC2 - Modify Security Groups  | ✅    | ❌        | ❌     | ❌            | ❌      |
| **S3**                        |       |           |        |               |         |
| S3 - List Bucket              | ✅    | ✅        | 🔵     | ❌            | ❌      |
| S3 - Get Object               | ✅    | ✅        | 🔵     | ❌            | ❌      |
| S3 - Put Object (Upload)      | ✅    | ✅        | ❌     | ❌            | ❌      |
| S3 - Delete Object            | ✅    | ❌        | ❌     | ❌            | ❌      |
| S3 - Delete Bucket            | ✅    | ❌        | ❌     | ❌            | ❌      |
| S3 - Manage Bucket Policy     | ✅    | ❌        | ❌     | ❌            | ❌      |
| **RDS**                       |       |           |        |               |         |
| RDS - Describe Instances      | ✅    | ❌        | ❌     | ✅            | ❌      |
| RDS - Start/Stop DB           | ✅    | ❌        | ❌     | ✅            | ❌      |
| RDS - Create DB Instance      | ✅    | ❌        | ❌     | ✅            | ❌      |
| RDS - Delete DB Instance      | ✅    | ❌        | ❌     | ✅            | ❌      |
| RDS - Create Snapshot         | ✅    | ❌        | ❌     | ✅            | ❌      |
| RDS - Restore from Snapshot   | ✅    | ❌        | ❌     | ✅            | ❌      |
| RDS - Modify DB Parameters    | ✅    | ❌        | ❌     | ✅            | ❌      |
| **CloudTrail / Monitoring**   |       |           |        |               |         |
| CloudTrail - View Logs        | ✅    | ❌        | ❌     | ❌            | 🔵      |
| CloudTrail - Lookup Events    | ✅    | ❌        | ❌     | ❌            | 🔵      |
| CloudTrail - Stop Logging     | ✅    | ❌        | ❌     | ❌            | ❌      |
| CloudWatch - View Metrics     | ✅    | ❌        | ❌     | ❌            | 🔵      |
| CloudWatch - Create Alarms    | ✅    | ❌        | ❌     | ❌            | ❌      |
| **IAM**                       |       |           |        |               |         |
| IAM - Create User             | ✅    | ❌        | ❌     | ❌            | ❌      |
| IAM - Delete User             | ✅    | ❌        | ❌     | ❌            | ❌      |
| IAM - Manage Groups           | ✅    | ❌        | ❌     | ❌            | ❌      |
| IAM - Manage Policies         | ✅    | ❌        | ❌     | ❌            | ❌      |
| IAM - View Users/Groups       | ✅    | ❌        | ❌     | ❌            | 🔵      |
| IAM - Generate Credential Rpt | ✅    | ❌        | ❌     | ❌            | 🔵      |
| **MFA**                       |       |           |        |               |         |
| MFA Required                  | ✅    | ✅        | ✅     | ✅            | ✅      |

---

## Resource-Level Permissions Summary

### EC2-ProjectServer (Instance ARN)
| Group         | Allowed Actions                          |
|---------------|------------------------------------------|
| Admin         | All EC2 actions                          |
| Developer     | StartInstances, StopInstances, Describe* |
| Tester        | Describe*, GetConsoleOutput              |
| DatabaseAdmin | None                                     |
| Auditor       | None                                     |

### Project-S3-Bucket
| Group         | Allowed Actions                          |
|---------------|------------------------------------------|
| Admin         | All S3 actions                           |
| Developer     | PutObject, GetObject, ListBucket         |
| Tester        | GetObject, ListBucket                    |
| DatabaseAdmin | None                                     |
| Auditor       | None (only audit log buckets)            |

### Project-RDS-DB
| Group         | Allowed Actions                          |
|---------------|------------------------------------------|
| Admin         | All RDS actions                          |
| Developer     | None                                     |
| Tester        | None                                     |
| DatabaseAdmin | Full RDS management                      |
| Auditor       | None                                     |

---

## Least Privilege Principle Applied

Each group has the minimum permissions required to perform their job function:

- **Admin**: Full access — only for system administrators
- **Developer**: Can work with EC2 and S3 but cannot delete anything
- **Tester**: Read-only — can verify deployments without modifying anything
- **DatabaseAdmin**: Scoped entirely to RDS — cannot touch EC2, S3, or IAM
- **Auditor**: Read-only on audit services — cannot modify any resource
