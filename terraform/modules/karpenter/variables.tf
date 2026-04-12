# terraform/modules/karpenter/variables.tf
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "node_role_name" {
  description = "IAM role name for Karpenter-provisioned nodes"
  type        = string
}
