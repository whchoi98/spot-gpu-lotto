# terraform/modules/monitoring/variables.tf
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "remote_write_url" {
  description = "Prometheus remote-write URL (for Spot region agents)"
  type        = string
  default     = ""
}

variable "is_agent_mode" {
  description = "Deploy as Prometheus Agent (Spot regions) instead of full server"
  type        = bool
  default     = false
}
