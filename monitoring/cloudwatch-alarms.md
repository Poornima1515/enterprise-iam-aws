# CloudWatch Alarms — Enterprise IAM System

## Alarms Created

### 1. IAM-Unauthorized-Access-Alarm
- Trigger: >= 1 unauthorized operation in 5 minutes
- Action: SNS email alert to security team
- Metric: UnauthorizedAccessCount (custom)

### 2. IAM-Root-Account-Usage
- Trigger: Root account used for any API call
- Action: CRITICAL SNS email alert
- Metric: RootAccountUsageCount (custom)

## Setup Commands
```bash
./scripts/setup-sns-alerts.sh 745416886767 your-email@gmail.com
./scripts/setup-cloudwatch-dashboard.sh 745416886767
```

## View Dashboard
https://us-east-1.console.aws.amazon.com/cloudwatch/home#dashboards:name=IAM-Project-Dashboard
