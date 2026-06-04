"""
AWS Lambda Function: Auto-Disable Inactive IAM Users
Triggered weekly by EventBridge
Disables users inactive for 90+ days and sends SNS alert
"""
import boto3
import json
import time
from datetime import datetime, timezone

INACTIVE_THRESHOLD_DAYS = 90

def lambda_handler(event, context):
    iam = boto3.client('iam')
    sns_client = boto3.client('sns')
    
    sns_topic_arn = event.get('sns_topic_arn', '')
    disabled = []
    skipped = []
    
    print(f"Starting inactive user check (threshold: {INACTIVE_THRESHOLD_DAYS} days)")
    
    # Generate credential report
    iam.generate_credential_report()
    time.sleep(5)
    
    report = iam.get_credential_report()
    content = report['Content'].decode('utf-8')
    lines = content.strip().split('\n')
    headers = lines[0].split(',')
    
    for line in lines[1:]:
        fields = dict(zip(headers, line.split(',')))
        username = fields.get('user', '')
        
        # Skip root account
        if username == '<root_account>':
            continue
        
        password_last_used = fields.get('password_last_used', 'N/A')
        
        if password_last_used in ('N/A', 'no_information', 'not_supported', ''):
            skipped.append(username)
            continue
        
        try:
            last_used = datetime.fromisoformat(password_last_used.replace('Z', '+00:00'))
            days_inactive = (datetime.now(timezone.utc) - last_used).days
            
            print(f"User: {username}, Days inactive: {days_inactive}")
            
            if days_inactive > INACTIVE_THRESHOLD_DAYS:
                # Disable all active access keys
                keys_response = iam.list_access_keys(UserName=username)
                for key in keys_response['AccessKeyMetadata']:
                    if key['Status'] == 'Active':
                        iam.update_access_key(
                            UserName=username,
                            AccessKeyId=key['AccessKeyId'],
                            Status='Inactive'
                        )
                        print(f"  Deactivated key: {key['AccessKeyId']}")
                
                disabled.append({
                    'username': username,
                    'days_inactive': days_inactive,
                    'last_used': password_last_used
                })
                
        except Exception as e:
            print(f"Error processing {username}: {str(e)}")
    
    # Send SNS notification
    if disabled and sns_topic_arn:
        message_lines = [
            "=== IAM Inactive User Report ===",
            f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M UTC')}",
            f"Threshold: {INACTIVE_THRESHOLD_DAYS} days",
            f"\nDisabled {len(disabled)} user(s):",
        ]
        for u in disabled:
            message_lines.append(
                f"  - {u['username']} (inactive {u['days_inactive']} days, last used: {u['last_used']})"
            )
        
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=f'AWS IAM: {len(disabled)} Inactive Users Auto-Disabled',
            Message='\n'.join(message_lines)
        )
        print(f"SNS notification sent for {len(disabled)} users")
    
    result = {
        'statusCode': 200,
        'disabled_count': len(disabled),
        'disabled_users': disabled,
        'skipped_users': skipped
    }
    print(f"\nResult: {json.dumps(result, indent=2)}")
    return result
