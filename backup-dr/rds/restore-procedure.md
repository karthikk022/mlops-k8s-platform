# RDS Restore Procedure

## Automated Snapshot → New Instance

```bash
# Find latest snapshot
SNAPSHOT=$(aws rds describe-db-snapshots \
  --query "sort_by(DBSnapshots[?DBInstanceIdentifier=='mlflow-prod'],&SnapshotCreateTime)[-1].DBSnapshotIdentifier" \
  --output text)

# Restore
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier mlflow-prod-restored \
  --db-snapshot-identifier "$SNAPSHOT" \
  --db-instance-class db.t3.medium \
  --region ap-south-1

# Wait for completion
aws rds wait db-instance-available --db-instance-identifier mlflow-prod-restored

# Update MLflow deployment to point to new RDS
kubectl set env deployment/mlflow -n mlops \
  MLFLOW_DB_HOST=mlflow-prod-restored.xxxxxx.ap-south-1.rds.amazonaws.com
```

## Cross-Region DR Promotion

```bash
# In DR region (ap-southeast-1)
DR_SNAPSHOT=$(aws rds describe-db-snapshots \
  --query "sort_by(DBSnapshots[?DBInstanceIdentifier=='mlflow-prod'],&SnapshotCreateTime)[-1].DBSnapshotIdentifier" \
  --output text \
  --region ap-southeast-1)

aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier mlflow-prod-dr \
  --db-snapshot-identifier "$DR_SNAPSHOT" \
  --db-instance-class db.t3.medium \
  --region ap-southeast-1
```

## RPO/RTO

| Tier | RPO | RTO | Method |
|------|-----|-----|--------|
| Automated backup | 1 hour | 30 min | RDS automated snapshots |
| Cross-region copy | 24 hours | 1 hour | Manual snapshot copy |
| Point-in-time recovery | 5 min | 45 min | RDS PITR (within retention) |
