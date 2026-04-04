# terraform/envs/prod/terraform.tfvars
environment           = "prod"
project               = "gpu-lotto"
cognito_domain_prefix = "gpu-lotto"
origin_verify_secret  = "prod-origin-verify-secret-change-me"
redis_node_type       = "cache.r7g.large"
