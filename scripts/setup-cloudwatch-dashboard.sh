#!/bin/bash
# Create CloudWatch Dashboard
REGION="us-east-1"
ACCOUNT_ID=${1:-"745416886767"}
INSTANCE_ID="i-01d8126e2fd04b0a1"

echo "=== Creating CloudWatch Dashboard ==="

DASHBOARD_BODY=$(cat << DASHEOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0, "y": 0, "width": 12, "height": 6,
      "properties": {
        "title": "Unauthorized Access Attempts",
        "metrics": [["IAMProject", "UnauthorizedAccessCount"]],
        "period": 300,
        "stat": "Sum",
        "view": "timeSeries",
        "region": "${REGION}"
      }
    },
    {
      "type": "metric",
      "x": 12, "y": 0, "width": 12, "height": 6,
      "properties": {
        "title": "EC2 CPU Utilization",
        "metrics": [["AWS/EC2", "CPUUtilization", "InstanceId", "${INSTANCE_ID}"]],
        "period": 300,
        "stat": "Average",
        "view": "timeSeries",
        "region": "${REGION}"
      }
    },
    {
      "type": "metric",
      "x": 0, "y": 6, "width": 12, "height": 6,
      "properties": {
        "title": "EC2 Network Traffic",
        "metrics": [
          ["AWS/EC2", "NetworkIn", "InstanceId", "${INSTANCE_ID}"],
          ["AWS/EC2", "NetworkOut", "InstanceId", "${INSTANCE_ID}"]
        ],
        "period": 300,
        "stat": "Average",
        "view": "timeSeries",
        "region": "${REGION}"
      }
    },
    {
      "type": "alarm",
      "x": 12, "y": 6, "width": 12, "height": 6,
      "properties": {
        "title": "Security Alarms",
        "alarms": [
          "arn:aws:cloudwatch:${REGION}:${ACCOUNT_ID}:alarm:IAM-Unauthorized-Access-Alarm",
          "arn:aws:cloudwatch:${REGION}:${ACCOUNT_ID}:alarm:IAM-Root-Account-Usage"
        ]
      }
    }
  ]
}
DASHEOF
)

aws cloudwatch put-dashboard \
  --dashboard-name IAM-Project-Dashboard \
  --dashboard-body "$DASHBOARD_BODY" \
  --region $REGION

echo "✅ CloudWatch Dashboard created"
echo "View at: https://${REGION}.console.aws.amazon.com/cloudwatch/home#dashboards:name=IAM-Project-Dashboard"
