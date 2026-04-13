# terraform/envs/prod/outputs.tf
output "eks_seoul_endpoint" {
  value = module.eks_seoul.cluster_endpoint
}

output "eks_use1_endpoint" {
  value = module.eks_use1.cluster_endpoint
}

output "eks_use2_endpoint" {
  value = module.eks_use2.cluster_endpoint
}

output "eks_usw2_endpoint" {
  value = module.eks_usw2.cluster_endpoint
}

output "redis_url" {
  value     = module.elasticache.redis_url
  sensitive = true
}

output "alb_dns" {
  value = module.alb.alb_dns_name
}

output "cloudfront_domain" {
  value = module.cloudfront.distribution_domain_name
}

output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "ecr_repos" {
  value = module.ecr.repository_urls
}

output "github_actions_role_arn" {
  value = module.github_oidc.role_arn
}

output "s3_bucket" {
  value = module.s3.bucket_id
}

# FSx Lustre — per-region outputs for K8s PV creation
output "fsx_use1" {
  value = {
    file_system_id = module.fsx_use1.file_system_id
    dns_name       = module.fsx_use1.dns_name
    mount_name     = module.fsx_use1.mount_name
  }
}

output "fsx_use2" {
  value = {
    file_system_id = module.fsx_use2.file_system_id
    dns_name       = module.fsx_use2.dns_name
    mount_name     = module.fsx_use2.mount_name
  }
}

output "fsx_usw2" {
  value = {
    file_system_id = module.fsx_usw2.file_system_id
    dns_name       = module.fsx_usw2.dns_name
    mount_name     = module.fsx_usw2.mount_name
  }
}
