# terraform/modules/s3/main.tf

resource "aws_s3_bucket" "hub" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "hub" {
  bucket = aws_s3_bucket.hub.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "hub" {
  bucket = aws_s3_bucket.hub.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "hub" {
  bucket                  = aws_s3_bucket.hub.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "hub" {
  bucket = aws_s3_bucket.hub.id

  rule {
    id     = "results-to-glacier"
    status = "Enabled"
    filter {
      prefix = "results/"
    }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "checkpoints-cleanup"
    status = "Enabled"
    filter {
      prefix = "checkpoints/"
    }
    expiration {
      days = 7
    }
  }
}

resource "aws_s3_bucket_policy" "hub" {
  count  = length(var.pod_role_arns) > 0 ? 1 : 0
  bucket = aws_s3_bucket.hub.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PodIdentityAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.pod_role_arns
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
        ]
        Resource = [
          aws_s3_bucket.hub.arn,
          "${aws_s3_bucket.hub.arn}/*",
        ]
      },
    ]
  })
}
