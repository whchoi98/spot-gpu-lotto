# terraform/modules/alb/variables.tf
variable "name" {
  description = "ALB name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  type        = string
}

variable "cognito_client_id" {
  description = "Cognito App Client ID"
  type        = string
}

variable "cognito_domain" {
  description = "Cognito User Pool domain"
  type        = string
}

variable "origin_verify_secret" {
  description = "X-Origin-Verify header value for CloudFront validation"
  type        = string
  sensitive   = true
}
