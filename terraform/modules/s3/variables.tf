# terraform/modules/s3/variables.tf
variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
}

variable "pod_role_arns" {
  description = "IAM role ARNs allowed to access the bucket"
  type        = list(string)
  default     = []
}
