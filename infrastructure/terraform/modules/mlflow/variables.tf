variable "environment" { type = string }
variable "region" { type = string }
variable "artifact_bucket" { type = string }
variable "database_host" { type = string }
variable "database_port" { type = string, default = "5432" }
variable "database_name" { type = string, default = "mlflow" }
variable "database_user" { type = string }
variable "database_password" { type = string, sensitive = true }
