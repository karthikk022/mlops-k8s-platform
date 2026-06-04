variable "cluster_name" { type = string }
variable "environment" { type = string }
variable "kubernetes_version" { type = string, default = "1.30" }
variable "vpc_cidr" { type = string }
variable "private_subnets" { type = list(string) }
variable "public_subnets" { type = list(string) }
variable "instance_types" { type = list(string) }
variable "node_group_desired" { type = number }
variable "node_group_min" { type = number }
variable "node_group_max" { type = number }
