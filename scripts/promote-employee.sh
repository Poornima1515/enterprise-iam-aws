#!/bin/bash
# =============================================================================
# promote-employee.sh
# Enterprise IAM System — Employee Promotion Script
# Module 2: Employee Promotion Workflow
#
# Usage: ./promote-employee.sh <username> <old_group> <new_group>
# Example: ./promote-employee.sh john.doe Developer Admin
#
# Groups: Admin | Developer | Tester | DatabaseAdmin | Auditor
# =============================================================================

set -e

USERNAME=${1}
OLD_GROUP=${2}
NEW_GROUP=${3}

# Validate arguments
if [ -z "$USERNAME" ] || [ -z "$OLD_GROUP" ] || [ -z "$NEW_GROUP" ]; then
  echo "Usage: $0 <username> <old_group> <new_group>"
  echo "Example: $0 john.doe Developer Admin"
  echo "Groups: Admin | Developer | Tester | DatabaseAdmin | Auditor"
  exit 1
fi

if [ "$OLD_GROUP" == "$NEW_GROUP" ]; then
  echo "❌ Old group and new group are the same: $OLD_GROUP"
  exit 1
fi

echo "=============================================="
echo " Employee Promotion"
echo " Username:  $USERNAME"
echo " From:      $OLD_GROUP"
echo " To:        $NEW_GROUP"
echo " Date:      $(date)"
echo "=============================================="
echo ""

# ------------------------------------------------------------------------------
# STEP 1: Verify Current State
# ------------------------------------------------------------------------------
echo "[1/5] Verifying current group membership..."

CURRENT_GROUPS=$(aws iam list-groups-for-user \
  --user-name "$USERNAME" \
  --query 'Groups[].GroupName' \
  --output text)

echo "  Current groups: $CURRENT_GROUPS"

# Check if user is in the old group
if ! echo "$CURRENT_GROUPS" | grep -q "$OLD_GROUP"; then
  echo "  ❌ User $USERNAME is not in group $OLD_GROUP"
  echo "  Current groups: $CURRENT_GROUPS"
  exit 1
fi

echo "  ✅ Confirmed: $USERNAME is in $OLD_GROUP"

# ------------------------------------------------------------------------------
# STEP 2: Remove from Old Group
# ------------------------------------------------------------------------------
echo ""
echo "[2/5] Removing $USERNAME from $OLD_GROUP..."

aws iam remove-user-from-group \
  --user-name "$USERNAME" \
  --group-name "$OLD_GROUP"

echo "  ✅ Removed from $OLD_GROUP"

# Verify removal
GROUPS_AFTER_REMOVAL=$(aws iam list-groups-for-user \
  --user-name "$USERNAME" \
  --query 'Groups[].GroupName' \
  --output text)

echo "  Groups after removal: ${GROUPS_AFTER_REMOVAL:-'(none)'}"

# ------------------------------------------------------------------------------
# STEP 3: Add to New Group
# ------------------------------------------------------------------------------
echo ""
echo "[3/5] Adding $USERNAME to $NEW_GROUP..."

aws iam add-user-to-group \
  --user-name "$USERNAME" \
  --group-name "$NEW_GROUP"

echo "  ✅ Added to $NEW_GROUP"

# Verify addition
GROUPS_AFTER_PROMOTION=$(aws iam list-groups-for-user \
  --user-name "$USERNAME" \
  --query 'Groups[].GroupName' \
  --output text)

echo "  Groups after promotion: $GROUPS_AFTER_PROMOTION"

# ------------------------------------------------------------------------------
# STEP 4: Update User Tags
# ------------------------------------------------------------------------------
echo ""
echo "[4/5] Updating user tags..."

aws iam tag-user \
  --user-name "$USERNAME" \
  --tags \
    Key=Department,Value="$NEW_GROUP" \
    Key=PromotedFrom,Value="$OLD_GROUP" \
    Key=PromotionDate,Value="$(date +%Y-%m-%d)"

echo "  ✅ User tags updated"

# ------------------------------------------------------------------------------
# STEP 5: Verify and Summarize
# ------------------------------------------------------------------------------
echo ""
echo "[5/5] Final Verification..."

echo ""
echo "  User Details:"
aws iam get-user --user-name "$USERNAME" \
  --query 'User.{Username:UserName,Created:CreateDate}' \
  --output table

echo ""
echo "  Current Group Membership:"
aws iam list-groups-for-user --user-name "$USERNAME" \
  --query 'Groups[].{Group:GroupName}' \
  --output table

echo ""
echo "  Policies Now Applied:"
aws iam list-attached-group-policies \
  --group-name "$NEW_GROUP" \
  --query 'AttachedPolicies[].{PolicyName:PolicyName}' \
  --output table

echo ""
echo "=============================================="
echo " ✅ Promotion Complete"
echo "=============================================="
echo ""
echo " Summary:"
echo "   Employee:  $USERNAME"
echo "   Old Role:  $OLD_GROUP"
echo "   New Role:  $NEW_GROUP"
echo "   Date:      $(date)"
echo ""
echo " Permission Changes:"

case "$NEW_GROUP" in
  "Admin")
    echo "   + Full AWS access granted"
    echo "   + EC2 terminate/launch access granted"
    echo "   + S3 delete access granted"
    echo "   + RDS management access granted"
    echo "   + IAM management access granted"
    ;;
  "Developer")
    echo "   + EC2 start/stop access granted"
    echo "   + S3 upload access granted"
    echo "   - Delete permissions still restricted"
    ;;
  "Tester")
    echo "   + EC2 read-only access"
    echo "   + S3 read-only access"
    echo "   - No write permissions"
    ;;
  "DatabaseAdmin")
    echo "   + Full RDS management access"
    echo "   - EC2/S3/IAM access restricted"
    ;;
  "Auditor")
    echo "   + CloudTrail read access"
    echo "   + CloudWatch read access"
    echo "   - No resource modification access"
    ;;
esac

echo ""
echo " ⚠️  Note: CloudTrail has logged this group change."
echo " ⚠️  Notify the employee of their new permissions."
echo "=============================================="
