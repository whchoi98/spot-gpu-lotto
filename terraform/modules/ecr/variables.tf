# terraform/modules/ecr/variables.tf
variable "repo_names" {
  description = "List of ECR repository names"
  type        = list(string)
  default = [
    "gpu-lotto/api-server",
    "gpu-lotto/dispatcher",
    "gpu-lotto/price-watcher",
    "gpu-lotto/frontend",
  ]
}

variable "max_image_count" {
  description = "Max number of tagged images to retain"
  type        = number
  default     = 10
}
