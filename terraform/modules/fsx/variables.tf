# terraform/modules/fsx/variables.tf
variable "name" {
  description = "FSx filesystem name prefix"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for FSx (single AZ)"
  type        = string
}

variable "security_group_ids" {
  description = "Security group IDs for FSx access"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID for FSx security group"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR block of the VPC for Lustre LNET traffic"
  type        = string
}

variable "s3_import_path" {
  description = "S3 path for data repository (e.g., s3://bucket-name)"
  type        = string
}

variable "storage_capacity" {
  description = "Storage capacity in GiB (multiples of 1200)"
  type        = number
  default     = 1200
}
