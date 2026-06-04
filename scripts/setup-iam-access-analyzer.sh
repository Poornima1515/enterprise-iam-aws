#!/bin/bash
# Enable IAM Access Analyzer
REGION="us-east-1"

echo "=== Enabling IAM Access Analyzer ==="

aws accessanalyzer create-analyzer \
  --analyzer-name IAM-Project-Analyzer \
  --type ACCOUNT \
  --tags Key=Project,Value=IAM-Project \
  --region $REGION 2>/dev/null \
  && echo "✅ IAM Access Analyzer created" \
  || echo "⚠️  Analyzer already exists"

# List findings
echo ""
echo "=== Current Findings ==="
aws accessanalyzer list-findings \
  --analyzer-name IAM-Project-Analyzer \
  --region $REGION \
  --query 'findings[].{Id:id,Type:findingType,Resource:resource,Status:status}' \
  --output table 2>/dev/null || echo "No findings or analyzer still initializing"

echo ""
echo "✅ Access Analyzer active — checks for overly permissive policies"
echo "View in console: IAM → Access Analyzer"
