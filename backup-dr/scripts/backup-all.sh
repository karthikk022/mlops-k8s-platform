#!/bin/bash
set -euo pipefail

ENV="${1:-prod}"
REGION="${2:-ap-south-1}"
DR_REGION="${3:-ap-southeast-1}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== MLOps Full Backup: $TIMESTAMP ==="

echo "1. Trigger Velero K8s backup..."
velero backup create mlops-full-$TIMESTAMP \
  --include-namespaces mlops,monitoring \
  --default-volumes-to-restic \
  --wait

echo "2. Trigger RDS manual snapshot..."
aws rds create-db-snapshot \
  --db-instance-identifier mlflow-$ENV \
  --db-snapshot-identifier mlflow-$ENV-manual-$TIMESTAMP \
  --region $REGION

echo "3. Copy snapshot to DR region..."
SNAPSHOT_ARN=$(aws rds describe-db-snapshots \
  --db-snapshot-identifier mlflow-$ENV-manual-$TIMESTAMP \
  --query 'DBSnapshots[0].DBSnapshotArn' \
  --output text \
  --region $REGION)

aws rds copy-db-snapshot \
  --source-db-snapshot-identifier "$SNAPSHOT_ARN" \
  --target-db-snapshot-identifier mlflow-$ENV-dr-$TIMESTAMP \
  --source-region $REGION \
  --region $DR_REGION

echo "4. Verify S3 CRR status..."
aws s3api get-bucket-replication \
  --bucket "mlflow-artifacts-$ENV-$(aws sts get-caller-identity --query Account --output text)" \
  --region $REGION | jq '.ReplicationConfiguration.Rules[0].Status'

echo "5. Vault snapshot..."
kubectl exec -n vault vault-0 -- sh -c "
  vault operator raft snapshot save /tmp/vault-snapshot-$TIMESTAMP.snap
" 2>/dev/null || echo "Vault snapshot skipped (not running)"

echo "=== Backup complete: $TIMESTAMP ==="
