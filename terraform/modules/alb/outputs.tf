# terraform/modules/alb/outputs.tf
output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_zone_id" {
  value = aws_lb.this.zone_id
}

output "security_group_id" {
  value = aws_security_group.alb.id
}

output "api_target_group_arn" {
  value = aws_lb_target_group.api.arn
}

output "frontend_target_group_arn" {
  value = aws_lb_target_group.frontend.arn
}

output "grafana_target_group_arn" {
  value = aws_lb_target_group.grafana.arn
}
