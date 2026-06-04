variable "environment" { type = string }
variable "region" { type = string }
variable "kubernetes_version" { type = string }
variable "model_bucket" { type = string }
variable "aws_access_key" { type = string, sensitive = true }
variable "aws_secret_key" { type = string, sensitive = true }
