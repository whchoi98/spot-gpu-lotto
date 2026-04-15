# terraform/modules/pod_identity/main.tf
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# --- Shared trust policy for Pod Identity ---
data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# ============================================================
# API Server Role
# ============================================================
resource "aws_iam_role" "api_server" {
  name               = "${var.cluster_name}-api-server"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

data "aws_iam_policy_document" "api_server" {
  statement {
    sid = "S3Access"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*",
    ]
  }

  statement {
    sid = "EKSDescribe"
    actions = [
      "eks:DescribeCluster",
    ]
    resources = ["*"]
  }

  statement {
    sid = "STSCrossRegion"
    actions = [
      "sts:AssumeRole",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.cluster_name}-*",
    ]
  }

  statement {
    sid = "PresignedUploads"
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${var.s3_bucket_arn}/models/*",
      "${var.s3_bucket_arn}/datasets/*",
    ]
  }
}

resource "aws_iam_role_policy" "api_server" {
  name   = "api-server-policy"
  role   = aws_iam_role.api_server.id
  policy = data.aws_iam_policy_document.api_server.json
}

resource "aws_eks_pod_identity_association" "api_server" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "api-server"
  role_arn        = aws_iam_role.api_server.arn
}

# ============================================================
# Dispatcher Role
# ============================================================
resource "aws_iam_role" "dispatcher" {
  name               = "${var.cluster_name}-dispatcher"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

data "aws_iam_policy_document" "dispatcher" {
  statement {
    sid = "EKSAccess"
    actions = [
      "eks:DescribeCluster",
    ]
    resources = ["*"]
  }

  statement {
    sid = "STSCrossRegion"
    actions = [
      "sts:AssumeRole",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.cluster_name}-*",
    ]
  }

  statement {
    sid = "S3Read"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "dispatcher" {
  name   = "dispatcher-policy"
  role   = aws_iam_role.dispatcher.id
  policy = data.aws_iam_policy_document.dispatcher.json
}

resource "aws_eks_pod_identity_association" "dispatcher" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "dispatcher"
  role_arn        = aws_iam_role.dispatcher.arn
}

# ============================================================
# Price Watcher Role
# ============================================================
resource "aws_iam_role" "price_watcher" {
  name               = "${var.cluster_name}-price-watcher"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

data "aws_iam_policy_document" "price_watcher" {
  statement {
    sid = "SpotPriceHistory"
    actions = [
      "ec2:DescribeSpotPriceHistory",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "price_watcher" {
  name   = "price-watcher-policy"
  role   = aws_iam_role.price_watcher.id
  policy = data.aws_iam_policy_document.price_watcher.json
}

resource "aws_eks_pod_identity_association" "price_watcher" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "price-watcher"
  role_arn        = aws_iam_role.price_watcher.arn
}

# ============================================================
# GPU Worker Role
# ============================================================
resource "aws_iam_role" "gpu_worker" {
  name               = "${var.cluster_name}-gpu-worker"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

data "aws_iam_policy_document" "gpu_worker" {
  statement {
    sid = "S3ReadModels"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${var.s3_bucket_arn}/models/*",
      "${var.s3_bucket_arn}/datasets/*",
    ]
  }

  statement {
    sid = "S3WriteResults"
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${var.s3_bucket_arn}/results/*",
      "${var.s3_bucket_arn}/checkpoints/*",
    ]
  }
}

resource "aws_iam_role_policy" "gpu_worker" {
  name   = "gpu-worker-policy"
  role   = aws_iam_role.gpu_worker.id
  policy = data.aws_iam_policy_document.gpu_worker.json
}

resource "aws_eks_pod_identity_association" "gpu_worker" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "gpu-worker"
  role_arn        = aws_iam_role.gpu_worker.arn
}

# ============================================================
# AWS Load Balancer Controller Role (Seoul control plane only)
# ============================================================
resource "aws_iam_role" "lb_controller" {
  count              = var.enable_lb_controller ? 1 : 0
  name               = "${var.cluster_name}-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

data "aws_iam_policy_document" "lb_controller" {
  count = var.enable_lb_controller ? 1 : 0

  statement {
    sid = "ELBManagement"
    actions = [
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
    ]
    resources = ["*"]
  }

  statement {
    sid = "EC2Describe"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeCoipPools",
      "ec2:GetCoipPoolUsage",
    ]
    resources = ["*"]
  }

  statement {
    sid = "EC2SecurityGroupManagement"
    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:CreateTags",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:Vpc"
      values   = ["arn:aws:ec2:${data.aws_region.current.name}:${local.account_id}:vpc/${var.vpc_id}"]
    }
  }

  statement {
    sid = "EC2CreateTagsUnconditional"
    actions = [
      "ec2:CreateTags",
    ]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }
  }

  statement {
    sid = "IAMCreateServiceLinkedRole"
    actions = [
      "iam:CreateServiceLinkedRole",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }

  statement {
    sid = "WAFv2Regional"
    actions = [
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ShieldDescribe"
    actions = [
      "shield:GetSubscriptionState",
    ]
    resources = ["*"]
  }

  statement {
    sid = "CognitoDescribe"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ACMDescribe"
    actions = [
      "acm:ListCertificates",
      "acm:DescribeCertificate",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lb_controller" {
  count  = var.enable_lb_controller ? 1 : 0
  name   = "lb-controller-policy"
  role   = aws_iam_role.lb_controller[0].id
  policy = data.aws_iam_policy_document.lb_controller[0].json
}

resource "aws_eks_pod_identity_association" "lb_controller" {
  count           = var.enable_lb_controller ? 1 : 0
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lb_controller[0].arn
}
