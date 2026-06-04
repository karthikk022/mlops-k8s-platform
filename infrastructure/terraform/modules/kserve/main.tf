resource "helm_release" "kserve" {
  name       = "kserve"
  namespace  = "mlops"
  chart      = "kserve"
  repository = "https://kserve.github.io/helm-charts"
  version    = "0.13.0"
  wait       = true
  timeout    = 300

  values = [yamlencode({
    kversion = var.kubernetes_version

    inferenceService = {
      defaultDeploymentMode = "Serverless"
      defaultServiceType    = "ClusterIP"
    }

    storage = {
      s3 = {
        enabled          = true
        s3_region        = var.region
        s3_access_key_id = var.aws_access_key
        s3_secret_key    = var.aws_secret_key
        default_bucket   = var.model_bucket
      }
    }
  })]
}

resource "aws_s3_bucket" "models" {
  bucket        = var.model_bucket
  force_destroy = var.environment != "prod"
  tags = { Environment = var.environment, Service = "kserve" }
}

resource "aws_s3_bucket_versioning" "models" {
  bucket = aws_s3_bucket.models.id
  versioning_configuration { status = "Enabled" }
}
