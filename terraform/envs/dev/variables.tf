variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name used for resource naming"
  type        = string
  default     = "gpu-lotto"
}

variable "control_region" {
  description = "Control plane region (Seoul)"
  type        = string
  default     = "ap-northeast-2"
}

variable "spot_regions" {
  description = "Spot GPU regions"
  type        = list(string)
  default     = ["us-east-1", "us-east-2", "us-west-2"]
}

variable "vpc_cidrs" {
  description = "CIDR blocks per region"
  type        = map(string)
  default = {
    "ap-northeast-2" = "10.0.0.0/16"
    "us-east-1"      = "10.1.0.0/16"
    "us-east-2"      = "10.2.0.0/16"
    "us-west-2"      = "10.3.0.0/16"
  }
}

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.r7g.large"
}

variable "cognito_domain_prefix" {
  description = "Cognito User Pool domain prefix"
  type        = string
  default     = "gpu-lotto-dev"
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS"
  type        = string
  default     = ""
}

variable "cloudfront_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for CloudFront"
  type        = string
  default     = ""
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "spot-gpu-lotto"
}

variable "eks_admin_principal_arn" {
  description = "Stable IAM role ARN for EKS admin access (set in tfvars)"
  type        = string
  default     = ""
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks allowed to access EKS public endpoints (set in tfvars)"
  type        = list(string)
  default     = []
}

variable "origin_verify_secret" {
  description = "Secret value for CloudFront X-Origin-Verify header"
  type        = string
  sensitive   = true
  default     = "change-me-in-tfvars"
}
