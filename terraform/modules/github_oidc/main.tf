# terraform/modules/github_oidc/main.tf

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-${var.github_repo}"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

data "aws_iam_policy_document" "github_actions" {
  # ECR push
  dynamic "statement" {
    for_each = length(var.ecr_repo_arns) > 0 ? [1] : []
    content {
      sid = "ECRPush"
      actions = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
      ]
      resources = ["*"]
    }
  }

  # EKS access
  dynamic "statement" {
    for_each = length(var.eks_cluster_arns) > 0 ? [1] : []
    content {
      sid = "EKSAccess"
      actions = [
        "eks:DescribeCluster",
        "eks:ListClusters",
      ]
      resources = var.eks_cluster_arns
    }
  }

  # Terraform state
  dynamic "statement" {
    for_each = var.tfstate_bucket_arn != "" ? [1] : []
    content {
      sid = "TFState"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
      ]
      resources = [
        var.tfstate_bucket_arn,
        "${var.tfstate_bucket_arn}/*",
      ]
    }
  }

  dynamic "statement" {
    for_each = var.tflock_table_arn != "" ? [1] : []
    content {
      sid = "TFLock"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
      ]
      resources = [var.tflock_table_arn]
    }
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "github-actions-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions.json
}
