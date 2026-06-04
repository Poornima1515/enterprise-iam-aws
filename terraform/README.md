# Terraform - Enterprise IAM System

## Prerequisites
- Terraform installed: https://developer.hashicorp.com/terraform/install
- AWS CLI configured: aws configure

## Deploy
```bash
terraform init
terraform plan
terraform apply
```

## Destroy (cleanup)
```bash
terraform destroy
```

## What this creates
- IAM Groups (Admin, Developer, Tester, DatabaseAdmin, Auditor)
- IAM Policies with least privilege
- S3 Bucket with encryption + versioning
- CloudTrail with log file validation
- SNS Topic for security alerts
