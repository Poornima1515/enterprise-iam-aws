# Architecture Flow — Enterprise IAM System

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        AWS Account                                  │
│                                                                     │
│  ┌──────────┐    ┌──────────────┐    ┌──────────┐                  │
│  │ IAM User │───▶│  IAM Group   │───▶│ IAM Role │                  │
│  └──────────┘    └──────────────┘    └──────────┘                  │
│       │                │                   │                        │
│       │           IAM Policy          IAM Policy                   │
│       │                │                   │                        │
│       ▼                ▼                   ▼                        │
│  ┌─────────────────────────────────────────────────────────┐       │
│  │                   AWS Resources                          │       │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │       │
│  │  │     EC2      │  │      S3      │  │     RDS      │  │       │
│  │  │ ProjectServer│  │Project-Bucket│  │  Project-DB  │  │       │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │       │
│  └─────────────────────────────────────────────────────────┘       │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │                  Audit & Monitoring                       │      │
│  │         CloudTrail (API Logs)  +  CloudWatch             │      │
│  └──────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Detailed Flow

### 1. Authentication Layer
```
Employee → AWS Console / CLI
              │
              ▼
         IAM User Login
              │
              ▼
         MFA Challenge  ──── FAIL ──▶ Access Denied
              │
             PASS
              │
              ▼
         Session Token Issued
```

### 2. Authorization Layer
```
Authenticated User
        │
        ▼
  IAM Group Lookup
        │
        ▼
  Attached Group Policy evaluated
        │
        ├── Allow? ──▶ Access Granted to Resource
        │
        └── Deny?  ──▶ Access Denied (logged in CloudTrail)
```

### 3. Resource Access Flow
```
Users          Groups            Policies              Resources
──────         ──────            ────────              ─────────
admin-user  ──▶ Admin      ──▶ AdminFullAccess    ──▶ EC2, S3, RDS (Full)
developer   ──▶ Developer  ──▶ DeveloperPolicy    ──▶ EC2 (start/stop), S3 (upload)
tester      ──▶ Tester     ──▶ TesterPolicy       ──▶ EC2, S3 (read-only)
db-user     ──▶ DatabaseAdmin ▶ DBAdminPolicy     ──▶ RDS (full manage)
auditor     ──▶ Auditor    ──▶ AuditorPolicy      ──▶ CloudTrail, CloudWatch (read)
```

### 4. Audit Flow
```
Any API Call
     │
     ▼
CloudTrail captures event
     │
     ▼
Stored in S3 (audit-logs bucket)
     │
     ▼
CloudWatch Alarm (on suspicious activity)
     │
     ▼
SNS Notification → Security Team
```

---

## IAM Entity Relationships

```
IAM User
  └── belongs to ──▶ IAM Group
                          └── has attached ──▶ IAM Policy
                                                    └── grants/denies ──▶ Actions on Resources

IAM Role
  └── assumed by ──▶ IAM User / AWS Service
                          └── has attached ──▶ IAM Policy
```

---

## AWS Resources Summary

| Resource Name       | Type | Purpose                          |
|---------------------|------|----------------------------------|
| EC2-ProjectServer   | EC2  | Application server               |
| Project-S3-Bucket   | S3   | File/object storage              |
| Project-RDS-DB      | RDS  | Relational database (MySQL/PG)   |
| CloudTrail-Log      | CT   | API audit trail                  |
