# terraform/modules/cloudfront/variables.tf
variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name (origin)"
  type        = string
}

variable "origin_verify_secret" {
  description = "X-Origin-Verify header value"
  type        = string
  sensitive   = true
}

variable "certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for CloudFront"
  type        = string
  default     = ""
}

variable "aliases" {
  description = "Domain aliases for the distribution"
  type        = list(string)
  default     = []
}
