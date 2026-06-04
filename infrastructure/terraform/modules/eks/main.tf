data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.available.names
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = var.environment != "prod"
  enable_dns_hostnames = true

  tags = { Environment = var.environment, ManagedBy = "terraform" }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = var.environment == "prod" ? false : true

  eks_managed_node_groups = {
    ml-compute = {
      desired_size = var.node_group_desired
      min_size     = var.node_group_min
      max_size     = var.node_group_max

      instance_types = var.instance_types

      block_device_mappings = {
        xvda = { device_name = "/dev/xvda", volume_size = 100, volume_type = "gp3" }
      }

      labels = {
        "nodegroup-type" = "ml-compute"
        "environment"    = var.environment
      }

      tags = { Environment = var.environment, NodeGroup = "ml-compute" }
    }
  }

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }

  tags = { Environment = var.environment, ManagedBy = "terraform" }
}

resource "kubernetes_namespace" "mlops" {
  metadata {
    name = "mlops"
    labels = {
      "istio-injection" = "enabled"
      environment       = var.environment
    }
  }
  depends_on = [module.eks]
}
