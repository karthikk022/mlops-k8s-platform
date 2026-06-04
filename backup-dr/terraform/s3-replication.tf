resource "aws_s3_bucket" "mlflow_artifacts" {
  bucket = "mlflow-artifacts-${var.environment}-${data.aws_caller_identity.current.account_id}"
  tags   = { Environment = var.environment, Service = "mlflow" }
}

resource "aws_s3_bucket_versioning" "mlflow_artifacts" {
  bucket = aws_s3_bucket.mlflow_artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket" "mlflow_artifacts_dr" {
  count  = var.environment == "prod" ? 1 : 0
  bucket = "mlflow-artifacts-${var.environment}-dr"
  provider = aws.dr
  tags   = { Environment = var.environment, Service = "mlflow-dr" }
}

resource "aws_s3_bucket_replication_configuration" "mlflow_crr" {
  count   = var.environment == "prod" ? 1 : 0
  bucket  = aws_s3_bucket.mlflow_artifacts.id
  role    = aws_iam_role.s3_replication[0].arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    filter {}

    destination {
      bucket        = aws_s3_bucket.mlflow_artifacts_dr[0].arn
      storage_class = "STANDARD_IA"
      replication_time {
        status = "Enabled"
        time {
          minutes = 15
        }
      }
      metrics {
        status = "Enabled"
        event_threshold {
          minutes = 15
        }
      }
    }

    delete_marker_replication { status = "Enabled" }
    source_selection_criteria {
      sse_kms_encrypted_objects { status = "Enabled" }
    }
  }
}

resource "aws_iam_role" "s3_replication" {
  count  = var.environment == "prod" ? 1 : 0
  name   = "mlflow-s3-replication-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.s3_replication_assume[0].json
}

data "aws_iam_policy_document" "s3_replication_assume" {
  count = var.environment == "prod" ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_s3_bucket" "models_dr" {
  count  = var.environment == "prod" ? 1 : 0
  bucket = "kserve-models-${var.environment}-dr"
  provider = aws.dr
  tags   = { Environment = var.environment, Service = "kserve-dr" }
}

data "aws_caller_identity" "current" {}
