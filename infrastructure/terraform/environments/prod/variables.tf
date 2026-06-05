variable "region" { type = string, default = "ap-south-1" }
variable "mlflow_db_user" { type = string, default = "mlflow" }
variable "mlflow_db_password" { type = string, sensitive = true }
variable "aws_access_key" { type = string, sensitive = true }
variable "aws_secret_key" { type = string, sensitive = true }
variable "grafana_password" { type = string, sensitive = true }
variable "slack_webhook" { type = string, sensitive = true }
