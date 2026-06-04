# Terraform - Enterprise IAM System
# Run: terraform init && terraform apply

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "us-east-1"
}

variable "account_id" {
  default = "745416886767"
}

variable "project_tag" {
  default = "IAM-Project"
}

# ===== IAM GROUPS =====
resource "aws_iam_group" "admin" { name = "Admin" }
resource "aws_iam_group" "developer" { name = "Developer" }
resource "aws_iam_group" "tester" { name = "Tester" }
resource "aws_iam_group" "database_admin" { name = "DatabaseAdmin" }
resource "aws_iam_group" "auditor" { name = "Auditor" }

# ===== IAM POLICIES =====
resource "aws_iam_policy" "admin_policy" {
  name        = "AdminFullAccessPolicy-TF"
  description = "Full AWS access with MFA required (Terraform managed)"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AdminFullAccess"
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
      Condition = {
        Bool = { "aws:MultiFactorAuthPresent" = "true" }
      }
    }]
  })
  tags = { Project = var.project_tag, ManagedBy = "Terraform" }
}

resource "aws_iam_policy" "developer_policy" {
  name        = "DeveloperAccessPolicy-TF"
  description = "EC2 start/stop and S3 upload, no delete (Terraform managed)"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Access"
        Effect = "Allow"
        Action = ["ec2:StartInstances","ec2:StopInstances","ec2:RebootInstances","ec2:Describe*"]
        Resource = "*"
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = ["s3:PutObject","s3:GetObject","s3:ListBucket","s3:GetBucketLocation"]
        Resource = [
          "arn:aws:s3:::project-s3-bucket-${var.account_id}",
          "arn:aws:s3:::project-s3-bucket-${var.account_id}/*"
        ]
      },
      {
        Sid    = "DenyDelete"
        Effect = "Deny"
        Action = ["s3:DeleteObject","s3:DeleteBucket","ec2:TerminateInstances",
                  "rds:DeleteDBInstance","iam:DeleteUser"]
        Resource = "*"
      }
    ]
  })
  tags = { Project = var.project_tag, ManagedBy = "Terraform" }
}

resource "aws_iam_policy" "auditor_policy" {
  name        = "AuditorReadOnlyPolicy-TF"
  description = "Read-only CloudTrail and CloudWatch (Terraform managed)"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["cloudtrail:*","cloudwatch:Describe*","cloudwatch:Get*",
                    "cloudwatch:List*","logs:Describe*","logs:Get*","logs:FilterLogEvents"]
        Resource = "*"
      },
      {
        Effect   = "Deny"
        Action   = ["cloudtrail:DeleteTrail","cloudtrail:StopLogging","ec2:*","s3:*","rds:*"]
        Resource = "*"
      }
    ]
  })
  tags = { Project = var.project_tag, ManagedBy = "Terraform" }
}

# ===== ATTACH POLICIES TO GROUPS =====
resource "aws_iam_group_policy_attachment" "developer_attach" {
  group      = aws_iam_group.developer.name
  policy_arn = aws_iam_policy.developer_policy.arn
}

resource "aws_iam_group_policy_attachment" "auditor_attach" {
  group      = aws_iam_group.auditor.name
  policy_arn = aws_iam_policy.auditor_policy.arn
}

# ===== S3 BUCKET =====
resource "aws_s3_bucket" "project_bucket" {
  bucket = "project-s3-bucket-tf-${var.account_id}"
  tags   = { Project = var.project_tag, ManagedBy = "Terraform" }
}

resource "aws_s3_bucket_versioning" "project_bucket_versioning" {
  bucket = aws_s3_bucket.project_bucket.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "project_bucket_encryption" {
  bucket = aws_s3_bucket.project_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "project_bucket_public_access" {
  bucket                  = aws_s3_bucket.project_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ===== CLOUDTRAIL =====
resource "aws_cloudtrail" "iam_trail" {
  name                          = "IAM-Project-Trail-TF"
  s3_bucket_name                = "aws-cloudtrail-logs-${var.account_id}"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  tags = { Project = var.project_tag, ManagedBy = "Terraform" }
}

# ===== SNS TOPIC =====
resource "aws_sns_topic" "security_alerts" {
  name = "IAM-Security-Alerts-TF"
  tags = { Project = var.project_tag, ManagedBy = "Terraform" }
}

# ===== OUTPUTS =====
output "developer_policy_arn" {
  value = aws_iam_policy.developer_policy.arn
}

output "auditor_policy_arn" {
  value = aws_iam_policy.auditor_policy.arn
}

output "s3_bucket_name" {
  value = aws_s3_bucket.project_bucket.bucket
}

output "sns_topic_arn" {
  value = aws_sns_topic.security_alerts.arn
}
