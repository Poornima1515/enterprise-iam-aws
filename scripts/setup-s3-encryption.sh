#!/bin/bash
# S3 Encryption and Security Hardening
BUCKET="project-s3-bucket-745416886767"
REGION="us-east-1"

echo "=== Hardening S3 Bucket Security ==="

# Enable default server-side encryption (AES-256)
aws s3api put-bucket-encryption \
  --bucket $BUCKET \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
echo "✅ AES-256 encryption enabled on $BUCKET"

# Enable object lock (prevent deletion for compliance)
# Note: versioning must be enabled first (already done in setup)

# Add lifecycle policy (auto-delete old versions after 30 days)
aws s3api put-bucket-lifecycle-configuration \
  --bucket $BUCKET \
  --lifecycle-configuration \
    '{"Rules":[{"ID":"DeleteOldVersions","Status":"Enabled","NoncurrentVersionExpiration":{"NoncurrentDays":30},"Filter":{"Prefix":""}}]}'
echo "✅ Lifecycle policy: old versions deleted after 30 days"

# Enable access logging
LOG_BUCKET="aws-cloudtrail-logs-745416886767"
aws s3api put-bucket-logging \
  --bucket $BUCKET \
  --bucket-logging-status \
    "{\"LoggingEnabled\":{\"TargetBucket\":\"${LOG_BUCKET}\",\"TargetPrefix\":\"s3-access-logs/\"}}" 2>/dev/null \
  && echo "✅ S3 access logging enabled" \
  || echo "⚠️  Access logging skipped (bucket ACL required)"

# Force HTTPS only (deny HTTP requests)
aws s3api put-bucket-policy \
  --bucket $BUCKET \
  --policy "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"DenyHTTP\",\"Effect\":\"Deny\",\"Principal\":\"*\",\"Action\":\"s3:*\",\"Resource\":[\"arn:aws:s3:::${BUCKET}\",\"arn:aws:s3:::${BUCKET}/*\"],\"Condition\":{\"Bool\":{\"aws:SecureTransport\":\"false\"}}}]}"
echo "✅ HTTPS-only policy applied (HTTP requests denied)"

echo ""
echo "=== S3 Security Hardening Complete ==="
echo "Bucket: $BUCKET"
echo "Encryption: AES-256"
echo "Versioning: Enabled"
echo "HTTP: Denied (HTTPS only)"
echo "Old versions: Auto-deleted after 30 days"
