# terraform/envs/dev/main.tf

locals {
  project     = var.project
  environment = var.environment
  name        = "${var.project}-${var.environment}"
}

# ============================================================
# VPC — 4 regions
# ============================================================
module "vpc_seoul" {
  source       = "../../modules/vpc"
  providers    = { aws = aws.seoul }
  name         = "${local.name}-seoul"
  cidr_block   = var.vpc_cidrs["ap-northeast-2"]
  cluster_name = "${local.name}-seoul"
}

module "vpc_use1" {
  source       = "../../modules/vpc"
  providers    = { aws = aws.us_east_1 }
  name         = "${local.name}-use1"
  cidr_block   = var.vpc_cidrs["us-east-1"]
  cluster_name = "${local.name}-use1"
}

module "vpc_use2" {
  source       = "../../modules/vpc"
  providers    = { aws = aws.us_east_2 }
  name         = "${local.name}-use2"
  cidr_block   = var.vpc_cidrs["us-east-2"]
  cluster_name = "${local.name}-use2"
}

module "vpc_usw2" {
  source       = "../../modules/vpc"
  providers    = { aws = aws.us_west_2 }
  name         = "${local.name}-usw2"
  cidr_block   = var.vpc_cidrs["us-west-2"]
  cluster_name = "${local.name}-usw2"
}

# ============================================================
# EKS — 4 clusters
# ============================================================
module "eks_seoul" {
  source    = "../../modules/eks"
  providers = { aws = aws.seoul }

  cluster_name            = "${local.name}-seoul"
  vpc_id                  = module.vpc_seoul.vpc_id
  subnet_ids              = module.vpc_seoul.private_subnet_ids
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = var.eks_public_access_cidrs
  admin_principal_arn     = var.eks_admin_principal_arn
  enable_node_group       = false
}

module "eks_use1" {
  source    = "../../modules/eks"
  providers = { aws = aws.us_east_1 }

  cluster_name            = "${local.name}-use1"
  vpc_id                  = module.vpc_use1.vpc_id
  subnet_ids              = module.vpc_use1.private_subnet_ids
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = var.eks_public_access_cidrs
  admin_principal_arn     = var.eks_admin_principal_arn
  enable_node_group       = false
}

module "eks_use2" {
  source    = "../../modules/eks"
  providers = { aws = aws.us_east_2 }

  cluster_name            = "${local.name}-use2"
  vpc_id                  = module.vpc_use2.vpc_id
  subnet_ids              = module.vpc_use2.private_subnet_ids
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = var.eks_public_access_cidrs
  admin_principal_arn     = var.eks_admin_principal_arn
  enable_node_group       = false
}

module "eks_usw2" {
  source    = "../../modules/eks"
  providers = { aws = aws.us_west_2 }

  cluster_name            = "${local.name}-usw2"
  vpc_id                  = module.vpc_usw2.vpc_id
  subnet_ids              = module.vpc_usw2.private_subnet_ids
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = var.eks_public_access_cidrs
  admin_principal_arn     = var.eks_admin_principal_arn
  enable_node_group       = false
}

# ============================================================
# Kubernetes + Helm Providers (for Karpenter + Monitoring)
# ============================================================
provider "kubernetes" {
  alias                  = "seoul"
  host                   = module.eks_seoul.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_seoul.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_seoul.cluster_name, "--region", "ap-northeast-2"]
  }
}

provider "helm" {
  alias = "seoul"
  kubernetes {
    host                   = module.eks_seoul.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_seoul.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_seoul.cluster_name, "--region", "ap-northeast-2"]
    }
  }
}

provider "kubectl" {
  alias                  = "use1"
  host                   = module.eks_use1.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_use1.cluster_ca_certificate)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_use1.cluster_name, "--region", "us-east-1"]
  }
}

provider "kubectl" {
  alias                  = "use2"
  host                   = module.eks_use2.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_use2.cluster_ca_certificate)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_use2.cluster_name, "--region", "us-east-2"]
  }
}

provider "kubectl" {
  alias                  = "usw2"
  host                   = module.eks_usw2.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_usw2.cluster_ca_certificate)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_usw2.cluster_name, "--region", "us-west-2"]
  }
}

provider "helm" {
  alias = "use1"
  kubernetes {
    host                   = module.eks_use1.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_use1.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_use1.cluster_name, "--region", "us-east-1"]
    }
  }
}

provider "helm" {
  alias = "use2"
  kubernetes {
    host                   = module.eks_use2.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_use2.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_use2.cluster_name, "--region", "us-east-2"]
    }
  }
}

provider "helm" {
  alias = "usw2"
  kubernetes {
    host                   = module.eks_usw2.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_usw2.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_usw2.cluster_name, "--region", "us-west-2"]
    }
  }
}

# ============================================================
# Karpenter — 3 Spot regions (disabled for dev — enable in prod)
# ============================================================
module "karpenter_use1" {
  source         = "../../modules/karpenter"
  providers      = { kubectl = kubectl.use1 }
  cluster_name   = module.eks_use1.cluster_name
  node_role_name = module.eks_use1.node_role_name
}

module "karpenter_use2" {
  source         = "../../modules/karpenter"
  providers      = { kubectl = kubectl.use2 }
  cluster_name   = module.eks_use2.cluster_name
  node_role_name = module.eks_use2.node_role_name
}

module "karpenter_usw2" {
  source         = "../../modules/karpenter"
  providers      = { kubectl = kubectl.usw2 }
  cluster_name   = module.eks_usw2.cluster_name
  node_role_name = module.eks_usw2.node_role_name
}

# ============================================================
# S3 Hub Bucket (Seoul)
# ============================================================
module "s3" {
  source      = "../../modules/s3"
  providers   = { aws = aws.seoul }
  bucket_name = "${local.name}-data"
}

# ============================================================
# ECR (Seoul)
# ============================================================
module "ecr" {
  source    = "../../modules/ecr"
  providers = { aws = aws.seoul }
}

# ============================================================
# ElastiCache (Seoul)
# ============================================================
module "elasticache" {
  source    = "../../modules/elasticache"
  providers = { aws = aws.seoul }

  name                       = local.name
  vpc_id                     = module.vpc_seoul.vpc_id
  subnet_ids                 = module.vpc_seoul.private_subnet_ids
  allowed_security_group_ids = [module.eks_seoul.eks_managed_security_group_id]
  node_type                  = var.redis_node_type
}

# ============================================================
# Cognito (Seoul)
# ============================================================
module "cognito" {
  source    = "../../modules/cognito"
  providers = { aws = aws.seoul }

  name          = "${local.name}-users"
  domain_prefix = var.cognito_domain_prefix
}

# ============================================================
# ALB (Seoul)
# ============================================================
module "alb" {
  source    = "../../modules/alb"
  providers = { aws = aws.seoul }

  name                  = local.name
  vpc_id                = module.vpc_seoul.vpc_id
  public_subnet_ids     = module.vpc_seoul.public_subnet_ids
  certificate_arn       = var.acm_certificate_arn
  cognito_user_pool_arn = module.cognito.user_pool_arn
  cognito_client_id     = module.cognito.client_id
  cognito_domain        = module.cognito.user_pool_domain
  origin_verify_secret  = var.origin_verify_secret
}

# ALB → EKS node SG rules (target group uses IP target type)
resource "aws_security_group_rule" "alb_to_eks_frontend" {
  provider                 = aws.seoul
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = module.alb.security_group_id
  security_group_id        = module.eks_seoul.eks_managed_security_group_id
}

resource "aws_security_group_rule" "alb_to_eks_api" {
  provider                 = aws.seoul
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = module.alb.security_group_id
  security_group_id        = module.eks_seoul.eks_managed_security_group_id
}

resource "aws_security_group_rule" "alb_to_eks_grafana" {
  provider                 = aws.seoul
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = module.alb.security_group_id
  security_group_id        = module.eks_seoul.eks_managed_security_group_id
}

# ============================================================
# CloudFront + WAF (must use us-east-1 provider for WAF CLOUDFRONT scope)
# ============================================================
module "cloudfront" {
  source    = "../../modules/cloudfront"
  providers = { aws = aws.us_east_1 }

  name                 = local.name
  alb_dns_name         = module.alb.alb_dns_name
  origin_verify_secret = var.origin_verify_secret
  certificate_arn      = var.cloudfront_certificate_arn
}

# ============================================================
# Pod Identity — Seoul (control plane services)
# ============================================================
module "pod_identity_seoul" {
  source    = "../../modules/pod_identity"
  providers = { aws = aws.seoul }

  cluster_name         = module.eks_seoul.cluster_name
  s3_bucket_arn        = module.s3.bucket_arn
  enable_lb_controller = true
  vpc_id               = module.vpc_seoul.vpc_id
}

# ============================================================
# Pod Identity — Spot regions (GPU worker only)
# ============================================================
module "pod_identity_use1" {
  source    = "../../modules/pod_identity"
  providers = { aws = aws.us_east_1 }

  cluster_name  = module.eks_use1.cluster_name
  s3_bucket_arn = module.s3.bucket_arn
}

module "pod_identity_use2" {
  source    = "../../modules/pod_identity"
  providers = { aws = aws.us_east_2 }

  cluster_name  = module.eks_use2.cluster_name
  s3_bucket_arn = module.s3.bucket_arn
}

module "pod_identity_usw2" {
  source    = "../../modules/pod_identity"
  providers = { aws = aws.us_west_2 }

  cluster_name  = module.eks_usw2.cluster_name
  s3_bucket_arn = module.s3.bucket_arn
}

# ============================================================
# FSx Lustre — 3 Spot regions
# ============================================================
module "fsx_use1" {
  source    = "../../modules/fsx"
  providers = { aws = aws.us_east_1 }
  name               = "${local.name}-use1"
  vpc_id             = module.vpc_use1.vpc_id
  subnet_id          = module.vpc_use1.private_subnet_ids[0]
  subnet_cidr        = var.vpc_cidrs["us-east-1"]
  security_group_ids = [module.eks_use1.cluster_security_group_id]
  s3_import_path     = "s3://${module.s3.bucket_id}"
}

module "fsx_use2" {
  source    = "../../modules/fsx"
  providers = { aws = aws.us_east_2 }
  name               = "${local.name}-use2"
  vpc_id             = module.vpc_use2.vpc_id
  subnet_id          = module.vpc_use2.private_subnet_ids[0]
  subnet_cidr        = var.vpc_cidrs["us-east-2"]
  security_group_ids = [module.eks_use2.cluster_security_group_id]
  s3_import_path     = "s3://${module.s3.bucket_id}"
}

module "fsx_usw2" {
  source    = "../../modules/fsx"
  providers = { aws = aws.us_west_2 }
  name               = "${local.name}-usw2"
  vpc_id             = module.vpc_usw2.vpc_id
  subnet_id          = module.vpc_usw2.private_subnet_ids[0]
  subnet_cidr        = var.vpc_cidrs["us-west-2"]
  security_group_ids = [module.eks_usw2.cluster_security_group_id]
  s3_import_path     = "s3://${module.s3.bucket_id}"
}

# ============================================================
# Monitoring — disabled for dev (enable in prod)
# ============================================================
# module "monitoring_seoul" {
#   source    = "../../modules/monitoring"
#   providers = { helm = helm.seoul }
#   cluster_name  = module.eks_seoul.cluster_name
#   is_agent_mode = false
# }
#
# module "monitoring_use1" {
#   source    = "../../modules/monitoring"
#   providers = { helm = helm.use1 }
#   cluster_name     = module.eks_use1.cluster_name
#   is_agent_mode    = true
#   remote_write_url = ""
# }
#
# module "monitoring_use2" {
#   source    = "../../modules/monitoring"
#   providers = { helm = helm.use2 }
#   cluster_name     = module.eks_use2.cluster_name
#   is_agent_mode    = true
#   remote_write_url = ""
# }
#
# module "monitoring_usw2" {
#   source    = "../../modules/monitoring"
#   providers = { helm = helm.usw2 }
#   cluster_name     = module.eks_usw2.cluster_name
#   is_agent_mode    = true
#   remote_write_url = ""
# }

# ============================================================
# GitHub Actions OIDC (Seoul)
# ============================================================
module "github_oidc" {
  source    = "../../modules/github_oidc"
  providers = { aws = aws.seoul }

  github_org  = var.github_org
  github_repo = var.github_repo
}
