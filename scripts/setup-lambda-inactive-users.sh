#!/bin/bash
# Lambda Auto-Disable Inactive Users Setup
ACCOUNT_ID=${1:-"745416886767"}
REGION="us-east-1"
LAMBDA_NAME="IAM-Auto-Disable-Inactive-Users"
ROLE_NAME="LambdaIAMRole"

echo "=== Setting up Lambda for Inactive User Detection ==="

# Create Lambda execution role
TRUST_DOC='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document "$TRUST_DOC" 2>/dev/null || echo "Role exists"

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/IAMReadOnlyAccess 2>/dev/null || true

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

# Add inline policy for disabling users
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name LambdaIAMInlinePolicy \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["iam:ListUsers","iam:GetLoginProfile","iam:UpdateLoginProfile","iam:ListAccessKeys","iam:UpdateAccessKey","iam:GenerateCredentialReport","iam:GetCredentialReport"],"Resource":"*"},{"Effect":"Allow","Action":["sns:Publish"],"Resource":"*"},{"Effect":"Allow","Action":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],"Resource":"*"}]}'

echo "✅ Lambda IAM role created"

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Create Lambda function zip
mkdir -p /tmp/lambda_pkg
cat > /tmp/lambda_pkg/lambda_function.py << 'PYEOF'
import boto3
import json
from datetime import datetime, timezone, timedelta

def lambda_handler(event, context):
    iam = boto3.client('iam')
    sns = boto3.client('sns')
    
    INACTIVE_DAYS = 90
    SNS_TOPIC = event.get('sns_topic', '')
    disabled_users = []
    
    iam.generate_credential_report()
    import time; time.sleep(5)
    
    report = iam.get_credential_report()
    content = report['Content'].decode('utf-8')
    lines = content.strip().split('\n')
    headers = lines[0].split(',')
    
    for line in lines[1:]:
        fields = dict(zip(headers, line.split(',')))
        username = fields.get('user', '')
        if username == '<root_account>':
            continue
        
        last_used = fields.get('password_last_used', 'N/A')
        if last_used in ('N/A', 'no_information', 'not_supported'):
            continue
        
        try:
            last_used_dt = datetime.fromisoformat(last_used.replace('Z', '+00:00'))
            days_inactive = (datetime.now(timezone.utc) - last_used_dt).days
            
            if days_inactive > INACTIVE_DAYS:
                # Disable all access keys
                keys = iam.list_access_keys(UserName=username)['AccessKeyMetadata']
                for key in keys:
                    if key['Status'] == 'Active':
                        iam.update_access_key(
                            UserName=username,
                            AccessKeyId=key['AccessKeyId'],
                            Status='Inactive'
                        )
                
                disabled_users.append({
                    'username': username,
                    'days_inactive': days_inactive
                })
                print(f"Disabled inactive user: {username} ({days_inactive} days inactive)")
        except Exception as e:
            print(f"Error processing {username}: {e}")
    
    if disabled_users and SNS_TOPIC:
        message = f"IAM Inactive User Report\n\nDisabled {len(disabled_users)} users:\n"
        for u in disabled_users:
            message += f"- {u['username']} ({u['days_inactive']} days inactive)\n"
        
        sns.publish(
            TopicArn=SNS_TOPIC,
            Subject='AWS IAM: Inactive Users Auto-Disabled',
            Message=message
        )
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'disabled_users': disabled_users,
            'count': len(disabled_users)
        })
    }
PYEOF

cd /tmp/lambda_pkg && zip -r lambda.zip lambda_function.py

sleep 10  # Wait for role to propagate

# Deploy Lambda
aws lambda create-function \
  --function-name $LAMBDA_NAME \
  --runtime python3.11 \
  --role $ROLE_ARN \
  --handler lambda_function.lambda_handler \
  --zip-file fileb:///tmp/lambda_pkg/lambda.zip \
  --timeout 60 \
  --description "Auto-disable inactive IAM users after 90 days" \
  --region $REGION 2>/dev/null || \
aws lambda update-function-code \
  --function-name $LAMBDA_NAME \
  --zip-file fileb:///tmp/lambda_pkg/lambda.zip \
  --region $REGION

echo "✅ Lambda function deployed"

# Schedule Lambda to run weekly via EventBridge
RULE_ARN=$(aws events put-rule \
  --name WeeklyInactiveUserCheck \
  --schedule-expression "rate(7 days)" \
  --state ENABLED \
  --region $REGION \
  --query 'RuleArn' --output text)

LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${LAMBDA_NAME}"

aws lambda add-permission \
  --function-name $LAMBDA_NAME \
  --statement-id EventBridgeInvoke \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn $RULE_ARN \
  --region $REGION 2>/dev/null || true

aws events put-targets \
  --rule WeeklyInactiveUserCheck \
  --targets "Id=1,Arn=$LAMBDA_ARN" \
  --region $REGION

echo "✅ EventBridge rule created - Lambda runs every 7 days"
echo ""
echo "=== Lambda Setup Complete ==="
echo "Lambda: $LAMBDA_NAME"
echo "Schedule: Every 7 days"
