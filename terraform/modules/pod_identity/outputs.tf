# terraform/modules/pod_identity/outputs.tf
output "api_server_role_arn" {
  value = aws_iam_role.api_server.arn
}

output "dispatcher_role_arn" {
  value = aws_iam_role.dispatcher.arn
}

output "price_watcher_role_arn" {
  value = aws_iam_role.price_watcher.arn
}

output "gpu_worker_role_arn" {
  value = aws_iam_role.gpu_worker.arn
}

output "lb_controller_role_arn" {
  value = var.enable_lb_controller ? aws_iam_role.lb_controller[0].arn : ""
}
