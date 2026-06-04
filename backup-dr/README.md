# Backup & Disaster Recovery

| Component | Backup Method | RPO | RTO | 
|-----------|--------------|-----|-----|
| MLflow RDS | Automated snapshots + cross-region | 1 hour | 30 min |
| S3 artifacts | Cross-region replication | 15 min | 1 hour |
| K8s resources | Velero + S3 backup | 4 hours | 1 hour |
| Vault Raft | Integrated snapshots + S3 | 1 hour | 15 min |
| ML models | MLflow registry + S3 versioning | Immediate | 5 min |
