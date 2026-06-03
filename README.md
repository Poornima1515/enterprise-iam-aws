# Enterprise Identity and Access Management (IAM) System Using AWS

## Project Overview

This mini-project demonstrates a secure, enterprise-level IAM system built on AWS.
It covers Role-Based Access Control (RBAC) and a complete Employee Lifecycle
(Onboarding → Promotion → Offboarding) workflow.

---

## Project Structure

```
iam-project/
├── README.md
├── architecture/
│   └── architecture-flow.md
├── module1-rbac/
│   ├── policies/
│   │   ├── admin-policy.json
│   │   ├── developer-policy.json
│   │   ├── tester-policy.json
│   │   ├── database-admin-policy.json
│   │   └── auditor-policy.json
│   ├── roles/
│   │   ├── admin-role.json
│   │   ├── developer-role.json
│   │   ├── tester-role.json
│   │   ├── database-admin-role.json
│   │   └── auditor-role.json
│   ├── permission-matrix.md
│   ├── implementation-procedure.md
│   └── testing-procedure.md
├── module2-workflow/
│   ├── onboarding.md
│   ├── promotion.md
│   ├── offboarding.md
│   ├── security-considerations.md
│   └── testing-scenarios.md
└── scripts/
    ├── setup-iam.sh
    ├── onboard-employee.sh
    ├── promote-employee.sh
    └── offboard-employee.sh
```

---

## AWS Services Used

| Service       | Purpose                                      |
|---------------|----------------------------------------------|
| IAM           | Users, Groups, Roles, Policies               |
| EC2           | Compute resource (EC2-ProjectServer)         |
| S3            | Object storage (Project-S3-Bucket)           |
| RDS           | Relational database (Project-RDS-DB)         |
| CloudTrail    | Audit logging of all API calls               |
| CloudWatch    | Monitoring and alerting                      |
| MFA           | Multi-Factor Authentication for all users    |

---

## Modules

- **Module 1** — Role-Based Access Control (RBAC)
- **Module 2** — Employee Onboarding and Access Revocation Workflow
