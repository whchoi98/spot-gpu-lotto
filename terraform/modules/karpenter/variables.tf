# terraform/modules/karpenter/variables.tf
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}
