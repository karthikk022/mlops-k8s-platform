output "cluster_id" { value = module.eks.cluster_id }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_certificate_authority_data" { value = module.eks.cluster_certificate_authority_data }
output "cluster_name" { value = module.eks.cluster_name }
output "vpc_id" { value = module.vpc.vpc_id }
output "private_subnet_ids" { value = module.vpc.private_subnets }
