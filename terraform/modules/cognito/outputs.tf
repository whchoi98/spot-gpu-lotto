# terraform/modules/cognito/outputs.tf
output "user_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.this.arn
}

output "user_pool_domain" {
  value = aws_cognito_user_pool_domain.this.domain
}

output "client_id" {
  value = aws_cognito_user_pool_client.alb.id
}

output "client_secret" {
  value     = aws_cognito_user_pool_client.alb.client_secret
  sensitive = true
}
