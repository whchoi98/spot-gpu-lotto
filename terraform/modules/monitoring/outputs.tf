# terraform/modules/monitoring/outputs.tf
output "prometheus_namespace" {
  value = var.namespace
}
