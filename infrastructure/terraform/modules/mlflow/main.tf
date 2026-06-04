resource "helm_release" "mlflow" {
  name       = "mlflow"
  namespace  = "mlops"
  chart      = "${path.module}/../../helm/mlflow"
  wait       = true
  timeout    = 300

  values = [
    yamlencode({
      environment = var.environment
      storage = {
        bucket = var.artifact_bucket
        region = var.region
      }
      postgres = {
        host     = var.database_host
        port     = var.database_port
        database = var.database_name
        username = var.database_user
        password = var.database_password
      }
      resources = {
        requests = { cpu = "500m", memory = "1Gi" }
        limits   = { cpu = "2", memory = "4Gi" }
      }
      ingress = {
        enabled  = var.environment != "dev"
        host     = "mlflow.${var.environment}.mlops.platform"
      }
    })
  ]
}

resource "aws_s3_bucket" "mlflow_artifacts" {
  bucket        = var.artifact_bucket
  force_destroy = var.environment != "prod"

  tags = { Environment = var.environment, Service = "mlflow" }
}

resource "aws_s3_bucket_versioning" "mlflow_artifacts" {
  bucket = aws_s3_bucket.mlflow_artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "mlflow_artifacts" {
  bucket = aws_s3_bucket.mlflow_artifacts.id

  rule {
    id     = "expire-old-artifacts"
    status = "Enabled"
    expiration { days = 90 }
  }
}
