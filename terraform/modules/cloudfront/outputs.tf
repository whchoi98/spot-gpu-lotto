# terraform/modules/cloudfront/outputs.tf
output "distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "distribution_domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "waf_web_acl_arn" {
  value = aws_wafv2_web_acl.this.arn
}
