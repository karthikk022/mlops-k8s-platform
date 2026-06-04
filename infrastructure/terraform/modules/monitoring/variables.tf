variable "environment" { type = string }
variable "grafana_password" { type = string, sensitive = true }
variable "slack_webhook" { type = string, sensitive = true }
variable "remote_write_url" { type = string, default = "" }
variable "depends_on_module" { type = any, default = null }
