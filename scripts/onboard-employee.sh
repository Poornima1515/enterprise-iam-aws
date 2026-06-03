#!/bin/bash
# =============================================================================
# onboard-employee.sh
# Enterprise IAM System — Employee Onboarding Script
# Module 2: Employee Onboarding Workflow
#
# Usage: ./onboard-employee.sh <username> <department> <employee_id>
# Example: ./onboard-employee.sh john.doe Developer EMP001
#
# Departments: Admin | Developer | Tester | DatabaseAdmin | Auditor
# =============================================================================

set -e

USERNAME=${1}
DEPARTMENT=${2}
EMPLOYEE_ID=${3}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TEMP_PASSWORD="Welcome@$(date +%Y)!"
TEMP_DIR="$(pwd)/tmp"
mkdir -p "$TEMP_DIR"

# Validate arguments
if [ -z "$USERNAME" ] || [ -z "$DEPARTMENT" ] || [ -z "$EMPLOYEE_ID" ]; then
  echo "Usage: $0 <username> <department> <employee_id>"
  echo "Example: $0 john.doe Developer EMP001"
  echo "Departments: Admin | Developer | Tester | DatabaseAdmin | Auditor"
  exit 1
fi

# Validate department
VALID_DEPARTMENTS=("Admin" "Developer" "Tester" "DatabaseAdmin" "Auditor")
VALID=false
for dept in "${VALID_DEPARTMENTS[@]}"; do
  if [ "$DEPARTMENT" == "$dept" ]; then
    VALID=true
    break
  fi
done

if [ "$VALID" == "false" ]; then
  echo "❌ Invalid department: $DEPARTMENT"
  echo "Valid departments: Admin | Developer | Tester | DatabaseAdmin | Auditor"
  exit 1
fi

echo "=============================================="
echo " Employee Onboarding"
echo " Username:    $USERNAME"
echo " Department:  $DEPARTMENT"
echo " Employee ID: $EMPLOYEE_ID"
echo "=============================================="
echo ""

# ------------------------------------------------------------------------------
# STEP 1: Create IAM User
# ------------------------------------------------------------------------------
echo "[1/5] Creating IAM User: $USERNAME..."

aws iam create-user \
  --user-name "$USERNAME" \
  --tags \
    Key=Department,Value="$DEPARTMENT" \
    Key=EmployeeID,Value="$EMPLOYEE_ID" \
    Key=JoinDate,Value="$(date +%Y-%m-%d)" \
    Key=Project,Value=IAM-Project \
    Key=Status,Value=Active

echo "  ✅ IAM user created: $USERNAME"

# Create console login profile
aws iam create-login-profile \
  --user-name "$USERNAME" \
  --password "$TEMP_PASSWORD" \
  --password-reset-required

echo "  ✅ Console login profile created"

# ------------------------------------------------------------------------------
# STEP 2: Assign to Department Group
# ------------------------------------------------------------------------------
echo ""
echo "[2/5] Assigning $USERNAME to $DEPARTMENT group..."

aws iam add-user-to-group \
  --user-name "$USERNAME" \
  --group-name "$DEPARTMENT"

# Verify
GROUPS=$(aws iam list-groups-for-user \
  --user-name "$USERNAME" \
  --query 'Groups[].GroupName' \
  --output text)

echo "  ✅ Added to group: $GROUPS"

# ------------------------------------------------------------------------------
# STEP 3: Create Access Keys (if needed for CLI access)
# ------------------------------------------------------------------------------
echo ""
echo "[3/5] Generating programmatic access credentials..."

ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "$USERNAME")
ACCESS_KEY_ID=$(echo $ACCESS_KEY_OUTPUT | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['AccessKey']['AccessKeyId'])")
SECRET_KEY=$(echo $ACCESS_KEY_OUTPUT | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['AccessKey']['SecretAccessKey'])")

echo "  ✅ Access keys generated"
echo "  ⚠️  Store these securely — Secret Key shown only once!"
echo ""
echo "  Access Key ID:     $ACCESS_KEY_ID"
echo "  Secret Access Key: [REDACTED — see /tmp/${USERNAME}-credentials.txt]"

# Save credentials to temp file (in production, use Secrets Manager)
cat > "$TEMP_DIR/${USERNAME}-credentials.txt" << EOF
=== AWS Credentials for $USERNAME ===
Generated: $(date)
Employee ID: $EMPLOYEE_ID
Department: $DEPARTMENT

Console URL: https://${ACCOUNT_ID}.signin.aws.amazon.com/console
Username: $USERNAME
Temporary Password: $TEMP_PASSWORD
(User must reset password on first login)

Programmatic Access:
AWS Access Key ID: $ACCESS_KEY_ID
AWS Secret Access Key: $SECRET_KEY

MFA: REQUIRED — Set up before accessing any resources
MFA Setup: Login to console → IAM → Users → $USERNAME → Security credentials → Assign MFA device

IMPORTANT: Delete this file after delivering credentials securely!
EOF

echo "  ✅ Credentials saved to $TEMP_DIR/${USERNAME}-credentials.txt"

# ------------------------------------------------------------------------------
# STEP 4: MFA Setup Instructions
# ------------------------------------------------------------------------------
echo ""
echo "[4/5] MFA Setup..."
echo "  ⚠️  MFA must be configured by the employee on first login."
echo ""
echo "  Instructions for $USERNAME:"
echo "  1. Log in at: https://${ACCOUNT_ID}.signin.aws.amazon.com/console"
echo "  2. Go to: IAM → Users → $USERNAME → Security credentials"
echo "  3. Click 'Assign MFA device'"
echo "  4. Choose 'Authenticator app'"
echo "  5. Scan QR code with Google Authenticator or Authy"
echo "  6. Enter two consecutive OTP codes to confirm"
echo ""

# Create virtual MFA device (admin pre-creates it)
aws iam create-virtual-mfa-device \
  --virtual-mfa-device-name "${USERNAME}-mfa" \
  --outfile "$TEMP_DIR/${USERNAME}-mfa-qr.png" \
  --bootstrap-method QRCodePNG 2>/dev/null \
  && echo "  ✅ MFA QR code saved to $TEMP_DIR/${USERNAME}-mfa-qr.png" \
  || echo "  ⚠️  MFA device creation requires employee to complete setup in console"

# ------------------------------------------------------------------------------
# STEP 5: Verify Access
# ------------------------------------------------------------------------------
echo ""
echo "[5/5] Verifying Setup..."

echo ""
echo "  User Details:"
aws iam get-user --user-name "$USERNAME" \
  --query 'User.{Username:UserName,Created:CreateDate,ID:UserId}' \
  --output table

echo ""
echo "  Group Membership:"
aws iam list-groups-for-user --user-name "$USERNAME" \
  --query 'Groups[].{Group:GroupName}' \
  --output table

echo ""
echo "  Access Keys:"
aws iam list-access-keys --user-name "$USERNAME" \
  --query 'AccessKeyMetadata[].{KeyId:AccessKeyId,Status:Status,Created:CreateDate}' \
  --output table

echo ""
echo "=============================================="
echo " ✅ Onboarding Complete for $USERNAME"
echo "=============================================="
echo ""
echo " Next Steps:"
echo " 1. Deliver credentials from $TEMP_DIR/${USERNAME}-credentials.txt securely"
echo " 2. Employee must set up MFA on first login"
echo " 3. Employee must reset temporary password"
echo " 4. Delete /tmp/${USERNAME}-credentials.txt after delivery"
echo " 5. Verify employee can access resources per their role"
echo "=============================================="
