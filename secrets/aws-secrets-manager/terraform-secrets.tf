resource "aws_secretsmanager_secret" "mlflow_rds_password" {
  name                    = "mlflow/rds/master-password"
  description             = "MLflow RDS master password"
  rotation_rules {
    automatically_after_days = 30
  }
  tags = { Service = "mlflow", ManagedBy = "terraform" }
}

resource "aws_secretsmanager_secret_version" "mlflow_rds_password" {
  secret_id     = aws_secretsmanager_secret.mlflow_rds_password.id
  secret_string = var.mlflow_db_password
}

resource "aws_secretsmanager_secret" "grafana_password" {
  name = "mlflow/grafana/admin-password"
  tags = { Service = "grafana", ManagedBy = "terraform" }
}

resource "aws_secretsmanager_secret_version" "grafana_password" {
  secret_id     = aws_secretsmanager_secret.grafana_password.id
  secret_string = var.grafana_password
}

resource "aws_secretsmanager_secret" "slack_webhook" {
  name = "mlflow/slack/webhook"
  tags = { Service = "monitoring", ManagedBy = "terraform" }
}

resource "aws_secretsmanager_secret_version" "slack_webhook" {
  secret_id     = aws_secretsmanager_secret.slack_webhook.id
  secret_string = var.slack_webhook
}

resource "aws_secretsmanager_secret" "aws_access_key" {
  name = "mlflow/aws/access-key"
  tags = { Service = "mlflow", ManagedBy = "terraform" }
}

resource "aws_secretsmanager_secret" "aws_secret_key" {
  name = "mlflow/aws/secret-key"
  tags = { Service = "mlflow", ManagedBy = "terraform" }
}

resource "aws_iam_policy" "secrets_manager_read" {
  name        = "mlops-secrets-manager-read"
  description = "Allow reading MLOps secrets from AWS Secrets Manager"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = [
        aws_secretsmanager_secret.mlflow_rds_password.arn,
        aws_secretsmanager_secret.grafana_password.arn,
        aws_secretsmanager_secret.slack_webhook.arn,
        aws_secretsmanager_secret.aws_access_key.arn,
        aws_secretsmanager_secret.aws_secret_key.arn,
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_manager_eks" {
  policy_arn = aws_iam_policy.secrets_manager_read.arn
  role       = var.eks_node_role_name
}
