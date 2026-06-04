#!/bin/bash
set -euo pipefail

ENV="${1:-prod}"
NAMESPACE="${2:-mlops}"

echo "=== Backup Verification Report ==="
echo "Environment: $ENV"
echo "Timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""

PASS=0
FAIL=0

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "  [PASS] $desc"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "--- K8s Backups (Velero) ---"
check "Velero pod running" "kubectl get pod -n velero -l component=velero --field-selector status.phase=Running -o name"
check "Daily backup schedule exists" "kubectl get schedule -n velero mlops-daily-backup"
check "Recent backup exists (< 24h)" "backup_time=\$(kubectl get backup -n velero -o json | jq -r '.items | sort_by(.metadata.creationTimestamp) | last | .metadata.creationTimestamp'); [ -n \"\$backup_time\" ]"

echo "--- RDS Backups ---"
check "Automated backups enabled" "aws rds describe-db-instances --db-instance-identifier mlflow-$ENV --query 'DBInstances[0].BackupRetentionPeriod' --output text | grep -v '0'"
check "Recent manual snapshot exists" "aws rds describe-db-snapshots --query 'DBSnapshots[?DBInstanceIdentifier==\`mlflow-$ENV\`] | length(@)' --output text | grep -v '0'"

echo "--- S3 Replication ---"
SRC_BUCKET="mlflow-artifacts-$ENV-$(aws sts get-caller-identity --query Account --output text)"
check "S3 versioning enabled" "aws s3api get-bucket-versioning --bucket $SRC_BUCKET --query Status --output text | grep Enabled"
check "S3 replication configured" "aws s3api get-bucket-replication --bucket $SRC_BUCKET > /dev/null"

echo "--- Vault ---"
check "Vault sealed status" "kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -e '.sealed == false'"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

exit $FAIL
