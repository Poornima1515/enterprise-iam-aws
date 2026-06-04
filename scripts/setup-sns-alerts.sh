#!/bin/bash
# SNS Email Alerts Setup for Unauthorized Access
ACCOUNT_ID=${1:-"745416886767"}
EMAIL=${2:-"your-email@gmail.com"}
REGION="us-east-1"

echo "=== Setting up SNS Alerts ==="

# Create SNS Topic
TOPIC_ARN=$(aws sns create-topic --name IAM-Security-Alerts --region $REGION --query 'TopicArn' --output text)
echo "✅ SNS Topic created: $TOPIC_ARN"

# Subscribe email
aws sns subscribe \
  --topic-arn $TOPIC_ARN \
  --protocol email \
  --notification-endpoint $EMAIL \
  --region $REGION
echo "✅ Email subscription created. Check $EMAIL to confirm."

# Create CloudWatch metric filter for unauthorized operations
aws logs put-metric-filter \
  --log-group-name CloudTrail/IAMProjectLogs \
  --filter-name UnauthorizedAccess \
  --filter-pattern '{ ($.errorCode = "AccessDenied") || ($.errorCode = "UnauthorizedOperation") }' \
  --metric-transformations \
    metricName=UnauthorizedAccessCount,metricNamespace=IAMProject,metricValue=1 \
  --region $REGION 2>/dev/null || echo "  Filter already exists"

# Create CloudWatch alarm → triggers SNS
aws cloudwatch put-metric-alarm \
  --alarm-name IAM-Unauthorized-Access-Alarm \
  --alarm-description "Alert: Unauthorized AWS access attempt detected" \
  --metric-name UnauthorizedAccessCount \
  --namespace IAMProject \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 \
  --alarm-actions $TOPIC_ARN \
  --region $REGION
echo "✅ CloudWatch Alarm created"

# Alarm for root account usage
aws cloudwatch put-metric-alarm \
  --alarm-name IAM-Root-Account-Usage \
  --alarm-description "CRITICAL: Root account was used" \
  --metric-name RootAccountUsageCount \
  --namespace IAMProject \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 \
  --alarm-actions $TOPIC_ARN \
  --region $REGION
echo "✅ Root account usage alarm created"

echo ""
echo "=== SNS Alerts Setup Complete ==="
echo "SNS Topic ARN: $TOPIC_ARN"
echo "⚠️  Confirm subscription email sent to: $EMAIL"
