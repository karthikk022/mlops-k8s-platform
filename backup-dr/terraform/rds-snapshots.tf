resource "aws_db_instance" "mlflow" {
  identifier     = "mlflow-${var.environment}"
  engine         = "postgres"
  engine_version = "16.3"
  instance_class = "db.t3.medium"

  allocated_storage     = 20
  storage_type          = "gp3"
  storage_encrypted     = true
  deletion_protection   = var.environment == "prod"

  db_name  = "mlflow"
  username = "mlflow"
  password = random_password.mlflow_db.result

  backup_retention_period = var.environment == "prod" ? 30 : 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = { Name = "mlflow-${var.environment}", Environment = var.environment }
}

resource "random_password" "mlflow_db" {
  length  = 24
  special = false
}

resource "aws_db_instance_automated_backups_replication" "mlflow_cross_region" {
  count                   = var.environment == "prod" ? 1 : 0
  source_db_instance_arn  = aws_db_instance.mlflow.arn
  source_region           = var.primary_region
  kms_key_id              = aws_kms_key.cross_region.arn
  preserve_default_tags   = true
}

resource "aws_kms_key" "cross_region" {
  count                   = var.environment == "prod" ? 1 : 0
  description             = "KMS key for cross-region RDS backup replication"
  deletion_window_in_days = 30
  multi_region            = true
}

resource "aws_db_snapshot" "mlflow_weekly" {
  db_instance_identifier = aws_db_instance.mlflow.id
  db_snapshot_identifier = "mlflow-${var.environment}-weekly-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
}

resource "aws_db_snapshot_copy" "mlflow_cross_region_weekly" {
  count                    = var.environment == "prod" ? 1 : 0
  source_db_snapshot_identifier = aws_db_snapshot.mlflow_weekly.id
  source_region            = var.primary_region
  target_db_snapshot_identifier = "mlflow-${var.environment}-dr-${formatdate("YYYY-MM-DD", timestamp())}"
  kms_key_id              = aws_kms_key.cross_region[0].arn
  destination_region      = var.dr_region
}
