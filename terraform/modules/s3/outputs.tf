# terraform/modules/s3/outputs.tf
output "bucket_id" {
  value = aws_s3_bucket.hub.id
}

output "bucket_arn" {
  value = aws_s3_bucket.hub.arn
}

output "bucket_domain_name" {
  value = aws_s3_bucket.hub.bucket_domain_name
}
