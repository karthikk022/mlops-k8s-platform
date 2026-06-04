#!/bin/bash
set -euo pipefail

BACKUP_TIMESTAMP="${1:-latest}"
ENV="${2:-prod}"
REGION="${3:-ap-south-1}"
DR_REGION="${4:-ap-southeast-1}"
NAMESPACE="${5:-mlops}"

echo "=== MLOps Full Restore ==="
echo "Backup timestamp: $BACKUP_TIMESTAMP"
echo "Target environment: $ENV"

if [ "$BACKUP_TIMESTAMP" == "latest" ]; then
  echo "1. Finding latest Velero backup..."
  BACKUP_NAME=$(velero backup get --output json | \
    jq -r '.items | sort_by(.metadata.creationTimestamp) | last | .metadata.name')
  echo "   Latest backup: $BACKUP_NAME"
else
  BACKUP_NAME="mlops-full-$BACKUP_TIMESTAMP"
fi

echo "2. Restoring K8s resources..."
velero restore create --from-backup "$BACKUP_NAME" --wait || {
  echo "   WARNING: Velero restore had issues. Check velero logs."
}

echo "3. Finding latest RDS snapshot..."
SNAPSHOT_ID=$(aws rds describe-db-snapshots \
  --db-instance-identifier "mlflow-$ENV" \
  --query "sort_by(DBSnapments, &SnapshotCreateTime)[-1].DBSnapshotIdentifier" \
  --output text \
  --region "$REGION" 2>/dev/null || echo "")
# recreate typo above
SNAPSHOT_ID=$(aws rds describe-db-snapshots \
  --query "sort_by(DBSnapshots[?DBInstanceIdentifier=='mlflow-$ENV'], &SnapshotCreateTime)[-1].DBSnapshotIdentifier" \
  --output text \
  --region "$REGION")
echo "   Latest snapshot: $SNAPSHOT_ID"

echo "4. Restoring RDS from snapshot..."
if [ "$SNAPSHOT_ID" != "None" ] && [ -n "$SNAPSHOT_ID" ]; then
  aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier "mlflow-$ENV-restored" \
    --db-snapshot-identifier "$SNAPSHOT_ID" \
    --region "$REGION" || {
    echo "   WARNING: RDS restore failed. Manual intervention required."
  }
fi

echo "5. Verifying S3 CRR replication status..."
SRC_BUCKET="mlflow-artifacts-$ENV-$(aws sts get-caller-identity --query Account --output text)"
aws s3api get-bucket-replication \
  --bucket "$SRC_BUCKET" \
  --region "$REGION" 2>/dev/null && echo "   Replication config OK" || \
  echo "   No replication config on source bucket"

echo "6. Post-restore verification..."
echo "   Check pods:     kubectl get pods -n $NAMESPACE"
echo "   Check MLflow:   kubectl port-forward -n $NAMESPACE svc/mlflow 5000:5000"
echo "   Check KServe:   kubectl get inferenceservices -n $NAMESPACE"

echo "=== Restore complete ==="
