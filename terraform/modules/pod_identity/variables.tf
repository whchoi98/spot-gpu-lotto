# terraform/modules/pod_identity/variables.tf
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "gpu-lotto"
}

variable "s3_bucket_arn" {
  description = "S3 hub bucket ARN"
  type        = string
}

variable "spot_region_arns" {
  description = "List of Spot region EKS cluster ARNs for cross-region access"
  type        = list(string)
  default     = []
}
