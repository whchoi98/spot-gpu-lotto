# terraform/modules/github_oidc/variables.tf
variable "github_org" {
  description = "GitHub organization"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "ecr_repo_arns" {
  description = "ECR repository ARNs for push access"
  type        = list(string)
  default     = []
}

variable "eks_cluster_arns" {
  description = "EKS cluster ARNs for deploy access"
  type        = list(string)
  default     = []
}

variable "tfstate_bucket_arn" {
  description = "Terraform state S3 bucket ARN"
  type        = string
  default     = ""
}

variable "tflock_table_arn" {
  description = "Terraform lock DynamoDB table ARN"
  type        = string
  default     = ""
}
