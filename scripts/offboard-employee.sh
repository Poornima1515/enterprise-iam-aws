#!/bin/bash
# =============================================================================
# offboard-employee.sh
# Enterprise IAM System — Employee Offboarding Script
# Module 2: Employee Offboarding / Access Revocation Workflow
#
# Usage: ./offboard-employee.sh <username> [--emergency]
# Example: ./offboard-employee.sh john.doe
# Example: ./offboard-employee.sh john.doe --emergency
#
# --emergency flag: Skips confirmation prompts for immediate revocation
# =============================================================================

set -e

USERNAME=${1}
MODE=${2}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEMP_DIR="$(pwd)/tmp"
mkdir -p "$TEMP_DIR"
LOG_FILE="$TEMP_DIR/offboarding_${USERNAME}_${TIMESTAMP}.log"

# Validate arguments
if [ -z "$USERNAME" ]; then
  echo "Usage: $0 <username> [--emergency]"
  echo "Example: $0 john.doe"
  echo "Example: $0 john.doe --emergency"
  exit 1
fi

# Logging function
log() {
  echo "$1" | tee -a "$LOG_FILE"
}

log "=============================================="
log " Employee Offboarding"
log " Username:  $USERNAME"
log " Mode:      ${MODE:-Standard}"
log " Date:      $(date)"
log " Log File:  $LOG_FILE"
log "=============================================="
log ""

# ------------------------------------------------------------------------------
# Verify user exists
# ------------------------------------------------------------------------------
if ! aws iam get-user --user-name "$USERNAME" &>/dev/null; then
  log "❌ User $USERNAME does not exist in IAM."
  exit 1
fi

log "  ✅ User $USERNAME found in IAM"

# ------------------------------------------------------------------------------
# Confirmation (skip in emergency mode)
# ------------------------------------------------------------------------------
if [ "$MODE" != "--emergency" ]; then
  log ""
  log "  Current User Details:"
  aws iam get-user --user-name "$USERNAME" \
    --query 'User.{Username:UserName,Created:CreateDate,ID:UserId}' \
    --output table | tee -a "$LOG_FILE"

  log ""
  log "  Current Group Membership:"
  aws iam list-groups-for-user --user-name "$USERNAME" \
    --query 'Groups[].GroupName' --output text | tee -a "$LOG_FILE"

  log ""
  echo -n "  ⚠️  Confirm offboarding of $USERNAME? (yes/no): "
  read CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    log "  Offboarding cancelled."
    exit 0
  fi
fi

log ""
log "  Starting offboarding process..."
log ""

# ------------------------------------------------------------------------------
# STEP 1: Disable Console Access
# ------------------------------------------------------------------------------
log "[1/7] Disabling console access..."

if aws iam get-login-profile --user-name "$USERNAME" &>/dev/null; then
  aws iam delete-login-profile --user-name "$USERNAME"
  log "  ✅ Console access disabled (login profile deleted)"
else
  log "  ℹ️  No console login profile found (already disabled)"
fi

# ------------------------------------------------------------------------------
# STEP 2: Deactivate All Access Keys
# ------------------------------------------------------------------------------
log ""
log "[2/7] Deactivating access keys..."

KEY_IDS=$(aws iam list-access-keys \
  --user-name "$USERNAME" \
  --query 'AccessKeyMetadata[].AccessKeyId' \
  --output text)

if [ -z "$KEY_IDS" ]; then
  log "  ℹ️  No access keys found"
else
  for KEY_ID in $KEY_IDS; do
    STATUS=$(aws iam list-access-keys \
      --user-name "$USERNAME" \
      --query "AccessKeyMetadata[?AccessKeyId=='$KEY_ID'].Status" \
      --output text)

    if [ "$STATUS" == "Active" ]; then
      aws iam update-access-key \
        --user-name "$USERNAME" \
        --access-key-id "$KEY_ID" \
        --status Inactive
      log "  ✅ Deactivated access key: $KEY_ID"
    else
      log "  ℹ️  Key already inactive: $KEY_ID"
    fi
  done
fi

# ------------------------------------------------------------------------------
# STEP 3: Remove from All Groups
# ------------------------------------------------------------------------------
log ""
log "[3/7] Removing from all IAM groups..."

GROUPS=$(aws iam list-groups-for-user \
  --user-name "$USERNAME" \
  --query 'Groups[].GroupName' \
  --output text)

if [ -z "$GROUPS" ]; then
  log "  ℹ️  User is not in any groups"
else
  for GROUP in $GROUPS; do
    aws iam remove-user-from-group \
      --user-name "$USERNAME" \
      --group-name "$GROUP"
    log "  ✅ Removed from group: $GROUP"
  done
fi

# Verify no groups remain
REMAINING_GROUPS=$(aws iam list-groups-for-user \
  --user-name "$USERNAME" \
  --query 'Groups[].GroupName' \
  --output text)

if [ -z "$REMAINING_GROUPS" ]; then
  log "  ✅ Confirmed: No group memberships remain"
else
  log "  ⚠️  Warning: Still in groups: $REMAINING_GROUPS"
fi

# ------------------------------------------------------------------------------
# STEP 4: Deactivate MFA Devices
# ------------------------------------------------------------------------------
log ""
log "[4/7] Deactivating MFA devices..."

MFA_DEVICES=$(aws iam list-mfa-devices \
  --user-name "$USERNAME" \
  --query 'MFADevices[].SerialNumber' \
  --output text)

if [ -z "$MFA_DEVICES" ]; then
  log "  ℹ️  No MFA devices found"
else
  for SERIAL in $MFA_DEVICES; do
    aws iam deactivate-mfa-device \
      --user-name "$USERNAME" \
      --serial-number "$SERIAL"
    log "  ✅ Deactivated MFA device: $SERIAL"

    # Delete virtual MFA devices
    if echo "$SERIAL" | grep -q "arn:aws:iam"; then
      aws iam delete-virtual-mfa-device \
        --serial-number "$SERIAL" 2>/dev/null \
        && log "  ✅ Deleted virtual MFA device: $SERIAL" \
        || log "  ⚠️  Could not delete virtual MFA device (may be hardware token)"
    fi
  done
fi

# ------------------------------------------------------------------------------
# STEP 5: Delete Access Keys (Permanent)
# ------------------------------------------------------------------------------
log ""
log "[5/7] Permanently deleting access keys..."

KEY_IDS=$(aws iam list-access-keys \
  --user-name "$USERNAME" \
  --query 'AccessKeyMetadata[].AccessKeyId' \
  --output text)

if [ -z "$KEY_IDS" ]; then
  log "  ℹ️  No access keys to delete"
else
  for KEY_ID in $KEY_IDS; do
    aws iam delete-access-key \
      --user-name "$USERNAME" \
      --access-key-id "$KEY_ID"
    log "  ✅ Deleted access key: $KEY_ID"
  done
fi

# ------------------------------------------------------------------------------
# STEP 6: Remove Inline Policies (if any)
# ------------------------------------------------------------------------------
log ""
log "[6/7] Removing inline policies..."

INLINE_POLICIES=$(aws iam list-user-policies \
  --user-name "$USERNAME" \
  --query 'PolicyNames[]' \
  --output text)

if [ -z "$INLINE_POLICIES" ]; then
  log "  ℹ️  No inline policies found"
else
  for POLICY in $INLINE_POLICIES; do
    aws iam delete-user-policy \
      --user-name "$USERNAME" \
      --policy-name "$POLICY"
    log "  ✅ Deleted inline policy: $POLICY"
  done
fi

# Detach managed policies (if directly attached)
ATTACHED_POLICIES=$(aws iam list-attached-user-policies \
  --user-name "$USERNAME" \
  --query 'AttachedPolicies[].PolicyArn' \
  --output text)

if [ -z "$ATTACHED_POLICIES" ]; then
  log "  ℹ️  No directly attached managed policies"
else
  for POLICY_ARN in $ATTACHED_POLICIES; do
    aws iam detach-user-policy \
      --user-name "$USERNAME" \
      --policy-arn "$POLICY_ARN"
    log "  ✅ Detached policy: $POLICY_ARN"
  done
fi

# ------------------------------------------------------------------------------
# STEP 7: Delete IAM User
# ------------------------------------------------------------------------------
log ""
log "[7/7] Deleting IAM user..."

aws iam delete-user --user-name "$USERNAME"
log "  ✅ IAM user deleted: $USERNAME"

# Verify deletion
if aws iam get-user --user-name "$USERNAME" &>/dev/null; then
  log "  ❌ ERROR: User still exists after deletion attempt!"
  exit 1
else
  log "  ✅ Confirmed: User $USERNAME no longer exists in IAM"
fi

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
log ""
log "=============================================="
log " ✅ Offboarding Complete"
log "=============================================="
log ""
log " Summary:"
log "   Employee:  $USERNAME"
log "   Date:      $(date)"
log "   Log:       $LOG_FILE"
log ""
log " Actions Taken:"
log "   ✅ Console access disabled"
log "   ✅ Access keys deactivated and deleted"
log "   ✅ Removed from all IAM groups"
log "   ✅ MFA devices deactivated and deleted"
log "   ✅ Inline/attached policies removed"
log "   ✅ IAM user deleted"
log ""
log " ⚠️  Verify in CloudTrail that all actions are logged."
log " ⚠️  Notify IT/Security team of offboarding completion."
log " ⚠️  Archive this log file: $LOG_FILE"
log "=============================================="

echo ""
echo "Offboarding log saved to: $LOG_FILE"
