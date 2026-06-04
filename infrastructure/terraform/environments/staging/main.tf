terraform {
  backend "s3" {
    bucket = "mlops-terraform-state"
    key    = "staging/terraform.tfstate"
    region = "ap-south-1"
  }
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    helm = { source = "hashicorp/helm", version = "~> 2.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.0" }
  }
}

provider "aws" {
  region = var.region
  default_tags { tags = { Environment = "staging", Project = "mlops-platform" } }
}

data "aws_eks_cluster" "cluster" { name = module.eks.cluster_name }
data "aws_eks_cluster_auth" "cluster" { name = module.eks.cluster_name }

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

module "eks" {
  source = "../../modules/eks"
  cluster_name        = "mlops-staging"
  environment         = "staging"
  kubernetes_version  = "1.30"
  vpc_cidr            = "10.1.0.0/16"
  private_subnets     = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnets      = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
  instance_types      = ["m6i.xlarge", "m6i.2xlarge"]
  node_group_desired  = 3
  node_group_min      = 2
  node_group_max      = 8
}

module "istio" {
  source      = "../../modules/istio"
  environment = "staging"
}

module "mlflow" {
  source         = "../../modules/mlflow"
  environment    = "staging"
  region         = var.region
  artifact_bucket = "mlflow-artifacts-staging-${data.aws_caller_identity.current.account_id}"
  database_host  = module.rds_proxy.address
  database_name  = "mlflow"
  database_user  = var.mlflow_db_user
  database_password = var.mlflow_db_password
  depends_on     = [module.eks, module.istio]
}

module "kserve" {
  source        = "../../modules/kserve"
  environment   = "staging"
  region        = var.region
  kubernetes_version = "1.30"
  model_bucket  = "kserve-models-staging-${data.aws_caller_identity.current.account_id}"
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key
  depends_on    = [module.eks, module.istio]
}

module "monitoring" {
  source       = "../../modules/monitoring"
  environment  = "staging"
  grafana_password = var.grafana_password
  slack_webhook    = var.slack_webhook
  depends_on_module = module.eks
}

data "aws_caller_identity" "current" {}
