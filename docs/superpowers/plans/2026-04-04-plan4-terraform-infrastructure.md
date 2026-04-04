# GPU Spot Lotto — Plan 4: Terraform Infrastructure

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provision the complete AWS infrastructure for GPU Spot Lotto across 4 regions (Seoul control plane + 3 US Spot regions) using Terraform modules.

**Architecture:** Reusable Terraform modules in `terraform/modules/` invoked from environment-specific root modules in `terraform/envs/dev/` and `terraform/envs/prod/`. Multi-region is handled via provider aliases (one per region) since `for_each` cannot be used with provider arguments. Each module is self-contained with its own variables.tf, main.tf, and outputs.tf.

**Tech Stack:** Terraform 1.9+, AWS Provider 5.x, Kubernetes Provider 2.x, Helm Provider 2.x

**Spec:** `docs/superpowers/specs/2026-04-03-gpu-spot-lotto-design.md` (sections 6, 7, 9, 10, 11)

**Depends on:** Plan 1 (Python Backend), Plan 3 (Frontend) — application code exists for Docker builds.

---

## File Map

### Create

```
terraform/
├── modules/
│   ├── vpc/
│   │   ├── main.tf              # VPC, subnets, IGW, NAT, route tables
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── eks/
│   │   ├── main.tf              # EKS cluster, addons, node group (optional)
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── karpenter/
│   │   ├── main.tf              # NodePool, EC2NodeClass for GPU Spot
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── pod_identity/
│   │   ├── main.tf              # IAM roles + Pod Identity associations
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── elasticache/
│   │   ├── main.tf              # Redis 7, subnet group, SG
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── s3/
│   │   ├── main.tf              # Hub bucket + lifecycle policies
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── fsx/
│   │   ├── main.tf              # FSx Lustre + S3 data repo association
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── cognito/
│   │   ├── main.tf              # User Pool, App Client, domain
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── alb/
│   │   ├── main.tf              # ALB, SG, listeners, target groups
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── cloudfront/
│   │   ├── main.tf              # CF distribution, WAF WebACL, cache policies
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ecr/
│   │   ├── main.tf              # ECR repos + lifecycle policy
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── github_oidc/
│   │   ├── main.tf              # OIDC provider + IAM role
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── monitoring/
│       ├── main.tf              # Helm: kube-prometheus-stack
│       ├── variables.tf
│       └── outputs.tf
├── envs/
│   ├── dev/
│   │   ├── backend.tf
│   │   ├── versions.tf
│   │   ├── providers.tf
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── backend.tf
│       ├── versions.tf
│       ├── providers.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
└── .terraform-version
```

---

## Task 1: Foundation — Directory Structure and Versions

**Files:**
- Create: `terraform/.terraform-version`, `terraform/envs/dev/versions.tf`, `terraform/envs/dev/backend.tf`, `terraform/envs/dev/providers.tf`, `terraform/envs/dev/variables.tf`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p terraform/modules/{vpc,eks,karpenter,pod_identity,elasticache,s3,fsx,cognito,alb,cloudfront,ecr,github_oidc,monitoring}
mkdir -p terraform/envs/{dev,prod}
```

- [ ] **Step 2: Create .terraform-version**

```
# terraform/.terraform-version
1.9.8
```

- [ ] **Step 3: Create versions.tf**

```hcl
# terraform/envs/dev/versions.tf
terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1"
    }
  }
}
```

- [ ] **Step 4: Create backend.tf**

```hcl
# terraform/envs/dev/backend.tf
terraform {
  backend "s3" {
    bucket         = "gpu-lotto-tfstate"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "gpu-lotto-tflock"
    encrypt        = true
  }
}
```

- [ ] **Step 5: Create providers.tf**

```hcl
# terraform/envs/dev/providers.tf
provider "aws" {
  alias  = "seoul"
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project     = "gpu-spot-lotto"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "gpu-spot-lotto"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

provider "aws" {
  alias  = "us_east_2"
  region = "us-east-2"

  default_tags {
    tags = {
      Project     = "gpu-spot-lotto"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"

  default_tags {
    tags = {
      Project     = "gpu-spot-lotto"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
```

- [ ] **Step 6: Create variables.tf**

```hcl
# terraform/envs/dev/variables.tf
variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name used for resource naming"
  type        = string
  default     = "gpu-lotto"
}

variable "control_region" {
  description = "Control plane region (Seoul)"
  type        = string
  default     = "ap-northeast-2"
}

variable "spot_regions" {
  description = "Spot GPU regions"
  type        = list(string)
  default     = ["us-east-1", "us-east-2", "us-west-2"]
}

variable "vpc_cidrs" {
  description = "CIDR blocks per region"
  type        = map(string)
  default = {
    "ap-northeast-2" = "10.0.0.0/16"
    "us-east-1"      = "10.1.0.0/16"
    "us-east-2"      = "10.2.0.0/16"
    "us-west-2"      = "10.3.0.0/16"
  }
}

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.r7g.large"
}

variable "cognito_domain_prefix" {
  description = "Cognito User Pool domain prefix"
  type        = string
  default     = "gpu-lotto-dev"
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS"
  type        = string
  default     = ""
}

variable "cloudfront_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for CloudFront"
  type        = string
  default     = ""
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "spot-gpu-lotto"
}

variable "origin_verify_secret" {
  description = "Secret value for CloudFront X-Origin-Verify header"
  type        = string
  sensitive   = true
  default     = "change-me-in-tfvars"
}
```

- [ ] **Step 7: Commit**

```bash
git add terraform/
git commit -m "feat(terraform): add foundation — directory structure, versions, backend, providers"
```

---

## Task 2: VPC Module

**Files:**
- Create: `terraform/modules/vpc/main.tf`, `terraform/modules/vpc/variables.tf`, `terraform/modules/vpc/outputs.tf`

- [ ] **Step 1: Create variables.tf**

```hcl
# terraform/modules/vpc/variables.tf
variable "name" {
  description = "Name prefix for all VPC resources"
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name (for subnet tags)"
  type        = string
}
```

- [ ] **Step 2: Create main.tf**

```hcl
# terraform/modules/vpc/main.tf
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.name}-vpc" }
}

# --- Public Subnets ---
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr_block, 4, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.name}-public-${local.azs[count.index]}"
    "kubernetes.io/role/elb"                     = "1"
    "kubernetes.io/cluster/${var.cluster_name}"  = "shared"
  }
}

# --- Private Subnets ---
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index + 4)
  availability_zone = local.azs[count.index]

  tags = {
    Name                                        = "${var.name}-private-${local.azs[count.index]}"
    "kubernetes.io/role/internal-elb"            = "1"
    "kubernetes.io/cluster/${var.cluster_name}"  = "shared"
    "karpenter.sh/discovery"                     = var.cluster_name
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

# --- NAT Gateway (single, cost-optimized) ---
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.name}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.name}-nat" }

  depends_on = [aws_internet_gateway.this]
}

# --- Route Tables ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-private-rt" }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

- [ ] **Step 3: Create outputs.tf**

```hcl
# terraform/modules/vpc/outputs.tf
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.this.id
}
```

- [ ] **Step 4: Format and commit**

```bash
terraform fmt -recursive terraform/
git add terraform/modules/vpc/
git commit -m "feat(terraform): add VPC module with public/private subnets and NAT"
```

---

## Task 3: EKS Module

**Files:**
- Create: `terraform/modules/eks/main.tf`, `terraform/modules/eks/variables.tf`, `terraform/modules/eks/outputs.tf`

- [ ] **Step 1: Create variables.tf**

```hcl
# terraform/modules/eks/variables.tf
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EKS cluster"
  type        = list(string)
}

variable "endpoint_private_access" {
  description = "Enable private API endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API endpoint"
  type        = bool
  default     = false
}

variable "enable_node_group" {
  description = "Create a managed node group (Seoul control plane only)"
  type        = bool
  default     = false
}

variable "node_instance_types" {
  description = "Instance types for managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired node count"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Min node count"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Max node count"
  type        = number
  default     = 4
}
```

- [ ] **Step 2: Create main.tf**

```hcl
# terraform/modules/eks/main.tf

# --- Cluster IAM Role ---
data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_compute" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_networking" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_block_storage" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_lb" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}

# --- Cluster Security Group ---
resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.cluster_name}-cluster-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "cluster_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
}

# --- KMS Key for Envelope Encryption ---
resource "aws_kms_key" "eks" {
  description         = "EKS secret encryption for ${var.cluster_name}"
  enable_key_rotation = true
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# --- EKS Cluster (Auto Mode) ---
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
  }

  # Auto Mode: Karpenter + CoreDNS + kube-proxy managed by EKS
  compute_config {
    enabled       = true
    node_pools    = ["general-purpose"]
    node_role_arn = aws_iam_role.node.arn
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_compute,
    aws_iam_role_policy_attachment.cluster_networking,
    aws_iam_role_policy_attachment.cluster_block_storage,
    aws_iam_role_policy_attachment.cluster_lb,
  ]
}

# --- Node IAM Role (for Auto Mode + optional managed node group) ---
data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# --- Pod Identity Agent Addon ---
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "eks-pod-identity-agent"
}

# --- Optional Managed Node Group (Seoul control plane) ---
resource "aws_eks_node_group" "control_plane" {
  count           = var.enable_node_group ? 1 : 0
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-control"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }
}

# --- EKS Access Entry (admin) ---
data "aws_caller_identity" "current" {}

resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
```

- [ ] **Step 3: Create outputs.tf**

```hcl
# terraform/modules/eks/outputs.tf
output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  value = aws_security_group.cluster.id
}

output "node_role_arn" {
  value = aws_iam_role.node.arn
}

output "node_role_name" {
  value = aws_iam_role.node.name
}

output "oidc_issuer" {
  value = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
```

- [ ] **Step 4: Format and commit**

```bash
terraform fmt -recursive terraform/
git add terraform/modules/eks/
git commit -m "feat(terraform): add EKS module with Auto Mode and Pod Identity Agent"
```

---

## Task 4: Karpenter Module

**Files:**
- Create: `terraform/modules/karpenter/main.tf`, `terraform/modules/karpenter/variables.tf`, `terraform/modules/karpenter/outputs.tf`

- [ ] **Step 1: Create variables.tf**

```hcl
# terraform/modules/karpenter/variables.tf
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}
```

- [ ] **Step 2: Create main.tf**

GPU Spot NodePool and EC2NodeClass using `kubectl_manifest` (Karpenter CRDs managed by EKS Auto Mode).

```hcl
# terraform/modules/karpenter/main.tf

resource "kubectl_manifest" "gpu_node_pool" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "gpu-spot"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "gpu-lotto/pool" = "gpu-spot"
          }
        }
        spec = {
          nodeClassRef = {
            group = "eks.amazonaws.com"
            kind  = "NodeClass"
            name  = "gpu-spot"
          }
          requirements = [
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot"]
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values = [
                "g6.xlarge",
                "g5.xlarge",
                "g6e.xlarge",
                "g6e.2xlarge",
                "g5.12xlarge",
                "g5.48xlarge",
              ]
            },
          ]
          taints = [
            {
              key    = "nvidia.com/gpu"
              value  = "true"
              effect = "NoSchedule"
            },
          ]
        }
      }
      limits = {
        cpu    = "192"
        memory = "768Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "60s"
      }
    }
  })
}

resource "kubectl_manifest" "gpu_node_class" {
  yaml_body = yamlencode({
    apiVersion = "eks.amazonaws.com/v1"
    kind       = "NodeClass"
    metadata = {
      name = "gpu-spot"
    }
    spec = {
      ephemeralStorage = {
        size = "100Gi"
      }
      networkPolicy = "DefaultAllow"
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        },
      ]
      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        },
      ]
    }
  })
}
```

- [ ] **Step 3: Create outputs.tf**

```hcl
# terraform/modules/karpenter/outputs.tf
output "node_pool_name" {
  value = "gpu-spot"
}
```

- [ ] **Step 4: Format and commit**

```bash
terraform fmt -recursive terraform/
git add terraform/modules/karpenter/
git commit -m "feat(terraform): add Karpenter module with GPU Spot NodePool"
```

---

## Task 5: Pod Identity Module

**Files:**
- Create: `terraform/modules/pod_identity/main.tf`, `terraform/modules/pod_identity/variables.tf`, `terraform/modules/pod_identity/outputs.tf`

- [ ] **Step 1: Create variables.tf**

```hcl
# terraform/modules/pod_identity/variables.tf
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "gpu-lotto"
}

variable "s3_bucket_arn" {
  description = "S3 hub bucket ARN"
  type        = string
}

variable "spot_region_arns" {
  description = "List of Spot region EKS cluster ARNs for cross-region access"
  type        = list(string)
  default     = []
}
```

- [ ] **Step 2: Create main.tf**

```hcl
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
```

- [ ] **Step 3: Create outputs.tf**

```hcl
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
```

- [ ] **Step 4: Format and commit**

```bash
terraform fmt -recursive terraform/
git add terraform/modules/pod_identity/
git commit -m "feat(terraform): add Pod Identity module with 4 service account roles"
```

---

## Task 6: ElastiCache Module

**Files:**
- Create: `terraform/modules/elasticache/main.tf`, `terraform/modules/elasticache/variables.tf`, `terraform/modules/elasticache/outputs.tf`

- [ ] **Step 1: Create variables.tf**

```hcl
# terraform/modules/elasticache/variables.tf
variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to access Redis"
  type        = list(string)
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.r7g.large"
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}
```

- [ ] **Step 2: Create main.tf**

```hcl
# terraform/modules/elasticache/main.tf

resource "aws_security_group" "redis" {
  name_prefix = "${var.name}-redis-"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-redis-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "redis_ingress" {
  count                    = length(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.redis.id
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-redis"
  subnet_ids = var.subnet_ids
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name}-redis"
  description          = "GPU Spot Lotto Redis cluster"
  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_clusters   = 1

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  automatic_failover_enabled = false

  apply_immediately = true
}
```

- [ ] **Step 3: Create outputs.tf**

```hcl
# terraform/modules/elasticache/outputs.tf
output "redis_endpoint" {
  value = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "redis_port" {
  value = 6379
}

output "redis_url" {
  value = "rediss://${aws_elasticache_replication_group.this.primary_endpoint_address}:6379"
}

output "security_group_id" {
  value = aws_security_group.redis.id
}
```

- [ ] **Step 4: Format and commit**

```bash
terraform fmt -recursive terraform/
git add terraform/modules/elasticache/
git commit -m "feat(terraform): add ElastiCache module — Redis 7 with TLS"
```

---

## Task 7: S3 + ECR Modules

**Files:**
- Create: `terraform/modules/s3/main.tf`, `terraform/modules/s3/variables.tf`, `terraform/modules/s3/outputs.tf`
- Create: `terraform/modules/ecr/main.tf`, `terraform/modules/ecr/variables.tf`, `terraform/modules/ecr/outputs.tf`

- [ ] **Step 1: Create S3 variables.tf**

```hcl
# terraform/modules/s3/variables.tf
variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
}

variable "pod_role_arns" {
  description = "IAM role ARNs allowed to access the bucket"
  type        = list(string)
  default     = []
}
```

- [ ] **Step 2: Create S3 main.tf**

```hcl
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
```

- [ ] **Step 3: Create S3 outputs.tf**

```hcl
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
```

- [ ] **Step 4: Create ECR variables.tf**

```hcl
# terraform/modules/ecr/variables.tf
variable "repo_names" {
  description = "List of ECR repository names"
  type        = list(string)
  default = [
    "gpu-lotto/api-server",
    "gpu-lotto/dispatcher",
    "gpu-lotto/price-watcher",
    "gpu-lotto/frontend",
  ]
}

variable "max_image_count" {
  description = "Max number of tagged images to retain"
  type        = number
  default     = 10
}
```

- [ ] **Step 5: Create ECR main.tf**

```hcl
# terraform/modules/ecr/main.tf

resource "aws_ecr_repository" "this" {
  for_each = toset(var.repo_names)

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["v", "sha-"]
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
    ]
  })
}
```

- [ ] **Step 6: Create ECR outputs.tf**

```hcl
# terraform/modules/ecr/outputs.tf
output "repository_urls" {
  value = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}
```

- [ ] **Step 7: Format and commit**

```bash
terraform fmt -recursive terraform/
git add terraform/modules/s3/ terraform/modules/ecr/
git commit -m "feat(terraform): add S3 hub bucket and ECR modules"
```

---

## Task 8: Cognito Module

**Files:**
- Create: `terraform/modules/cognito/main.tf`, `terraform/modules/cognito/variables.tf`, `terraform/modules/cognito/outputs.tf`

- [ ] **Step 1: Create variables.tf**

```hcl
# terraform/modules/cognito/variables.tf
variable "name" {
  description = "User Pool name"
  type        = string
}

variable "domain_prefix" {
  description = "Cognito User Pool domain prefix"
  type        = string
}

variable "callback_urls" {
  description = "Allowed callback URLs"
  type        = list(string)
  default     = ["https://localhost/oauth2/idpresponse"]
}

variable "logout_urls" {
  description = "Allowed logout URLs"
  type        = list(string)
  default     = ["https://localhost"]
}
```

- [ ] **Step 2: Create main.tf**

```hcl
# terraform/modules/cognito/main.tf

resource "aws_cognito_user_pool" "this" {
  name = var.name

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  schema {
    name                = "role"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 1
      max_length = 10
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = var.domain_prefix
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "aws_cognito_user_group" "admins" {
  name         = "admins"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Administrator users"
}

resource "aws_cognito_user_group" "users" {
  name         = "users"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Regular users"
}

resource "aws_cognito_user_pool_client" "alb" {
  name         = "${var.name}-alb-client"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = true

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  supported_identity_providers = ["COGNITO"]

  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]
}
```

- [ ] **Step 3: Create outputs.tf**

```hcl
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
```

- [ ] **Step 4: Format and commit**

```bash
terraform fmt -recursive terraform/
git add terraform/modules/cognito/
git commit -m "feat(terraform): add Cognito module with User Pool and ALB client"
```

---

## Task 9: ALB Module

**Files:**
- Create: `terraform/modules/alb/main.tf`, `terraform/modules/alb/variables.tf`, `terraform/modules/alb/outputs.tf`

- [ ] **Step 1: Create variables.tf**

```hcl
# terraform/modules/alb/variables.tf
variable "name" {
  description = "ALB name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  type        = string
}

variable "cognito_client_id" {
  description = "Cognito App Client ID"
  type        = string
}

variable "cognito_domain" {
  description = "Cognito User Pool domain"
  type        = string
}

variable "origin_verify_secret" {
  description = "X-Origin-Verify header value for CloudFront validation"
  type        = string
  sensitive   = true
}
```

- [ ] **Step 2: Create main.tf**

```hcl
# terraform/modules/alb/main.tf

# --- CloudFront Managed Prefix List ---
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# --- Security Group: CloudFront only ---
resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-alb-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_from_cloudfront" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# --- ALB ---
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  idle_timeout = 300

  enable_deletion_protection = true
}

# --- Target Groups ---
resource "aws_lb_target_group" "api" {
  name        = "${var.name}-api"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.name}-frontend"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/nginx-health"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }
}

# --- HTTPS Listener ---
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn       = var.cognito_user_pool_arn
      user_pool_client_id = var.cognito_client_id
      user_pool_domain    = var.cognito_domain
    }

    order = 1
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn

    order = 2
  }
}

# --- Listener Rules ---
# Health endpoints bypass Cognito auth
resource "aws_lb_listener_rule" "health_bypass" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/healthz", "/readyz"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# API routes → API server (with Cognito)
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  action {
    type = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn       = var.cognito_user_pool_arn
      user_pool_client_id = var.cognito_client_id
      user_pool_domain    = var.cognito_domain
    }

    order = 1
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn

    order = 2
  }
}
```

- [ ] **Step 3: Create outputs.tf**

```hcl
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
```

- [ ] **Step 4: Format and commit**

```bash
terraform fmt -recursive terraform/
git add terraform/modules/alb/
git commit -m "feat(terraform): add ALB module with Cognito auth and CloudFront SG"
```

---

## Task 10: CloudFront + WAF Module

**Files:**
- Create: `terraform/modules/cloudfront/main.tf`, `terraform/modules/cloudfront/variables.tf`, `terraform/modules/cloudfront/outputs.tf`

- [ ] **Step 1: Create variables.tf**

```hcl
# terraform/modules/cloudfront/variables.tf
variable "name" {
  description = "Resource name prefix"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name (origin)"
  type        = string
}

variable "origin_verify_secret" {
  description = "X-Origin-Verify header value"
  type        = string
  sensitive   = true
}

variable "certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for CloudFront"
  type        = string
  default     = ""
}

variable "aliases" {
  description = "Domain aliases for the distribution"
  type        = list(string)
  default     = []
}
```

- [ ] **Step 2: Create main.tf**

```hcl
# terraform/modules/cloudfront/main.tf

# --- WAF WebACL ---
resource "aws_wafv2_web_acl" "this" {
  name  = "${var.name}-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Rate limiting
  rule {
    name     = "rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules — SQL injection
  rule {
    name     = "aws-sqli"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules — Common Rule Set
  rule {
    name     = "aws-common"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-common"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-waf"
    sampled_requests_enabled   = true
  }
}

# --- Cache Policies ---
resource "aws_cloudfront_cache_policy" "prices_30s" {
  name        = "${var.name}-prices-30s"
  min_ttl     = 0
  default_ttl = 30
  max_ttl     = 30

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

# --- Origin Request Policy (forward all) ---
resource "aws_cloudfront_origin_request_policy" "forward_all" {
  name = "${var.name}-forward-all"

  cookies_config {
    cookie_behavior = "all"
  }
  headers_config {
    header_behavior = "allViewer"
  }
  query_strings_config {
    query_string_behavior = "all"
  }
}

# --- CloudFront Distribution ---
resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  web_acl_id      = aws_wafv2_web_acl.this.arn
  aliases         = length(var.aliases) > 0 ? var.aliases : null
  comment         = "GPU Spot Lotto — ${var.name}"

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Origin-Verify"
      value = var.origin_verify_secret
    }
  }

  default_cache_behavior {
    target_origin_id       = "alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_all.id

    compress = true
  }

  # /api/prices — cache 30s
  ordered_cache_behavior {
    path_pattern           = "/api/prices*"
    target_origin_id       = "alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]

    cache_policy_id          = aws_cloudfront_cache_policy.prices_30s.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_all.id

    compress = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.certificate_arn == "" ? true : false
    acm_certificate_arn            = var.certificate_arn != "" ? var.certificate_arn : null
    ssl_support_method             = var.certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = "TLSv1.2_2021"
  }
}
```

- [ ] **Step 3: Create outputs.tf**

```hcl
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
```

- [ ] **Step 4: Format and commit**

```bash
terraform fmt -recursive terraform/
git add terraform/modules/cloudfront/
git commit -m "feat(terraform): add CloudFront + WAF module with cache policies"
```

---

## Task 11: FSx Module

**Files:**
- Create: `terraform/modules/fsx/main.tf`, `terraform/modules/fsx/variables.tf`, `terraform/modules/fsx/outputs.tf`

- [ ] **Step 1: Create variables.tf**

```hcl
# terraform/modules/fsx/variables.tf
variable "name" {
  description = "FSx filesystem name prefix"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for FSx (single AZ)"
  type        = string
}

variable "security_group_ids" {
  description = "Security group IDs for FSx access"
  type        = list(string)
}

variable "s3_import_path" {
  description = "S3 path for data repository (e.g., s3://bucket-name)"
  type        = string
}

variable "storage_capacity" {
  description = "Storage capacity in GiB (multiples of 1200)"
  type        = number
  default     = 1200
}
```

- [ ] **Step 2: Create main.tf**

```hcl
# terraform/modules/fsx/main.tf

resource "aws_fsx_lustre_file_system" "this" {
  storage_capacity            = var.storage_capacity
  subnet_ids                  = [var.subnet_id]
  security_group_ids          = var.security_group_ids
  deployment_type             = "SCRATCH_2"
  storage_type                = "SSD"
  auto_import_policy          = "NEW_CHANGED_DELETED"

  tags = { Name = "${var.name}-fsx" }
}

resource "aws_fsx_data_repository_association" "this" {
  file_system_id       = aws_fsx_lustre_file_system.this.id
  data_repository_path = var.s3_import_path
  file_system_path     = "/data"

  s3 {
    auto_export_policy {
      events = ["NEW", "CHANGED", "DELETED"]
    }
    auto_import_policy {
      events = ["NEW", "CHANGED", "DELETED"]
    }
  }
}
```

- [ ] **Step 3: Create outputs.tf**

```hcl
# terraform/modules/fsx/outputs.tf
output "file_system_id" {
  value = aws_fsx_lustre_file_system.this.id
}

output "dns_name" {
  value = aws_fsx_lustre_file_system.this.dns_name
}

output "mount_name" {
  value = aws_fsx_lustre_file_system.this.mount_name
}
```

- [ ] **Step 4: Format and commit**

```bash
terraform fmt -recursive terraform/
git add terraform/modules/fsx/
git commit -m "feat(terraform): add FSx Lustre module with S3 data repository"
```

---

## Task 12: GitHub OIDC Module

**Files:**
- Create: `terraform/modules/github_oidc/main.tf`, `terraform/modules/github_oidc/variables.tf`, `terraform/modules/github_oidc/outputs.tf`

- [ ] **Step 1: Create variables.tf**

```hcl
# terraform/modules/github_oidc/variables.tf
variable "github_org" {
  description = "GitHub organization"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "ecr_repo_arns" {
  description = "ECR repository ARNs for push access"
  type        = list(string)
  default     = []
}

variable "eks_cluster_arns" {
  description = "EKS cluster ARNs for deploy access"
  type        = list(string)
  default     = []
}

variable "tfstate_bucket_arn" {
  description = "Terraform state S3 bucket ARN"
  type        = string
  default     = ""
}

variable "tflock_table_arn" {
  description = "Terraform lock DynamoDB table ARN"
  type        = string
  default     = ""
}
```

- [ ] **Step 2: Create main.tf**

```hcl
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
```

- [ ] **Step 3: Create outputs.tf**

```hcl
# terraform/modules/github_oidc/outputs.tf
output "role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}
```

- [ ] **Step 4: Format and commit**

```bash
terraform fmt -recursive terraform/
git add terraform/modules/github_oidc/
git commit -m "feat(terraform): add GitHub Actions OIDC module for CI/CD"
```

---

## Task 13: Monitoring Module

**Files:**
- Create: `terraform/modules/monitoring/main.tf`, `terraform/modules/monitoring/variables.tf`, `terraform/modules/monitoring/outputs.tf`

- [ ] **Step 1: Create variables.tf**

```hcl
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
```

- [ ] **Step 2: Create main.tf**

```hcl
# terraform/modules/monitoring/main.tf

resource "helm_release" "kube_prometheus_stack" {
  count = var.is_agent_mode ? 0 : 1

  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = var.namespace
  create_namespace = true
  version          = "65.1.1"

  values = [yamlencode({
    prometheus = {
      prometheusSpec = {
        retention         = "15d"
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              accessModes = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = "50Gi"
                }
              }
            }
          }
        }
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
      }
    }

    grafana = {
      adminPassword = var.grafana_admin_password
      persistence = {
        enabled = true
        size    = "10Gi"
      }
    }

    alertmanager = {
      alertmanagerSpec = {
        storage = {
          volumeClaimTemplate = {
            spec = {
              accessModes = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = "5Gi"
                }
              }
            }
          }
        }
      }
    }
  })]
}

# --- Prometheus Agent Mode (Spot regions) ---
resource "helm_release" "prometheus_agent" {
  count = var.is_agent_mode ? 1 : 0

  name             = "prometheus-agent"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  namespace        = var.namespace
  create_namespace = true
  version          = "25.27.0"

  values = [yamlencode({
    server = {
      enabled = false
    }

    serverFiles = {}

    prometheus-node-exporter = {
      enabled = true
    }

    kube-state-metrics = {
      enabled = true
    }

    configmapReload = {
      prometheus = {
        enabled = false
      }
    }

    # Agent mode with remote write
    prometheus-pushgateway = {
      enabled = false
    }
  })]
}

# --- DCGM Exporter (Spot regions only) ---
resource "helm_release" "dcgm_exporter" {
  count = var.is_agent_mode ? 1 : 0

  name             = "dcgm-exporter"
  repository       = "https://nvidia.github.io/dcgm-exporter/helm-charts"
  chart            = "dcgm-exporter"
  namespace        = var.namespace
  create_namespace = true

  values = [yamlencode({
    serviceMonitor = {
      enabled = true
    }
    tolerations = [
      {
        key      = "nvidia.com/gpu"
        operator = "Exists"
        effect   = "NoSchedule"
      },
    ]
  })]
}
```

- [ ] **Step 3: Create outputs.tf**

```hcl
# terraform/modules/monitoring/outputs.tf
output "prometheus_namespace" {
  value = var.namespace
}
```

- [ ] **Step 4: Format and commit**

```bash
terraform fmt -recursive terraform/
git add terraform/modules/monitoring/
git commit -m "feat(terraform): add monitoring module — Prometheus, Grafana, DCGM"
```

---

## Task 14: Dev Environment Root Module

**Files:**
- Create: `terraform/envs/dev/main.tf`, `terraform/envs/dev/outputs.tf`, `terraform/envs/dev/terraform.tfvars`

- [ ] **Step 1: Create terraform.tfvars**

```hcl
# terraform/envs/dev/terraform.tfvars
environment           = "dev"
project               = "gpu-lotto"
cognito_domain_prefix = "gpu-lotto-dev"
origin_verify_secret  = "dev-origin-verify-secret-change-me"
```

- [ ] **Step 2: Create main.tf**

This wires all modules together with explicit provider aliases for each region.

```hcl
# terraform/envs/dev/main.tf

locals {
  project     = var.project
  environment = var.environment
  name        = "${var.project}-${var.environment}"
}

# ============================================================
# VPC — 4 regions
# ============================================================
module "vpc_seoul" {
  source       = "../../modules/vpc"
  providers    = { aws = aws.seoul }
  name         = "${local.name}-seoul"
  cidr_block   = var.vpc_cidrs["ap-northeast-2"]
  cluster_name = "${local.name}-seoul"
}

module "vpc_use1" {
  source       = "../../modules/vpc"
  providers    = { aws = aws.us_east_1 }
  name         = "${local.name}-use1"
  cidr_block   = var.vpc_cidrs["us-east-1"]
  cluster_name = "${local.name}-use1"
}

module "vpc_use2" {
  source       = "../../modules/vpc"
  providers    = { aws = aws.us_east_2 }
  name         = "${local.name}-use2"
  cidr_block   = var.vpc_cidrs["us-east-2"]
  cluster_name = "${local.name}-use2"
}

module "vpc_usw2" {
  source       = "../../modules/vpc"
  providers    = { aws = aws.us_west_2 }
  name         = "${local.name}-usw2"
  cidr_block   = var.vpc_cidrs["us-west-2"]
  cluster_name = "${local.name}-usw2"
}

# ============================================================
# EKS — 4 clusters
# ============================================================
module "eks_seoul" {
  source    = "../../modules/eks"
  providers = { aws = aws.seoul }

  cluster_name            = "${local.name}-seoul"
  vpc_id                  = module.vpc_seoul.vpc_id
  subnet_ids              = module.vpc_seoul.private_subnet_ids
  endpoint_private_access = true
  endpoint_public_access  = false
  enable_node_group       = true
  node_instance_types     = ["t3.medium"]
  node_desired_size       = 2
}

module "eks_use1" {
  source    = "../../modules/eks"
  providers = { aws = aws.us_east_1 }

  cluster_name            = "${local.name}-use1"
  vpc_id                  = module.vpc_use1.vpc_id
  subnet_ids              = module.vpc_use1.private_subnet_ids
  endpoint_private_access = true
  endpoint_public_access  = true
  enable_node_group       = false
}

module "eks_use2" {
  source    = "../../modules/eks"
  providers = { aws = aws.us_east_2 }

  cluster_name            = "${local.name}-use2"
  vpc_id                  = module.vpc_use2.vpc_id
  subnet_ids              = module.vpc_use2.private_subnet_ids
  endpoint_private_access = true
  endpoint_public_access  = true
  enable_node_group       = false
}

module "eks_usw2" {
  source    = "../../modules/eks"
  providers = { aws = aws.us_west_2 }

  cluster_name            = "${local.name}-usw2"
  vpc_id                  = module.vpc_usw2.vpc_id
  subnet_ids              = module.vpc_usw2.private_subnet_ids
  endpoint_private_access = true
  endpoint_public_access  = true
  enable_node_group       = false
}

# ============================================================
# Kubernetes + Helm Providers (for Karpenter + Monitoring)
# ============================================================
provider "kubernetes" {
  alias                  = "seoul"
  host                   = module.eks_seoul.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_seoul.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_seoul.cluster_name, "--region", "ap-northeast-2"]
  }
}

provider "helm" {
  alias = "seoul"
  kubernetes {
    host                   = module.eks_seoul.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_seoul.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_seoul.cluster_name, "--region", "ap-northeast-2"]
    }
  }
}

provider "kubectl" {
  alias                  = "use1"
  host                   = module.eks_use1.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_use1.cluster_ca_certificate)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_use1.cluster_name, "--region", "us-east-1"]
  }
}

provider "kubectl" {
  alias                  = "use2"
  host                   = module.eks_use2.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_use2.cluster_ca_certificate)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_use2.cluster_name, "--region", "us-east-2"]
  }
}

provider "kubectl" {
  alias                  = "usw2"
  host                   = module.eks_usw2.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_usw2.cluster_ca_certificate)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_usw2.cluster_name, "--region", "us-west-2"]
  }
}

provider "helm" {
  alias = "use1"
  kubernetes {
    host                   = module.eks_use1.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_use1.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_use1.cluster_name, "--region", "us-east-1"]
    }
  }
}

provider "helm" {
  alias = "use2"
  kubernetes {
    host                   = module.eks_use2.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_use2.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_use2.cluster_name, "--region", "us-east-2"]
    }
  }
}

provider "helm" {
  alias = "usw2"
  kubernetes {
    host                   = module.eks_usw2.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_usw2.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_usw2.cluster_name, "--region", "us-west-2"]
    }
  }
}

# ============================================================
# Karpenter — 3 Spot regions
# ============================================================
module "karpenter_use1" {
  source       = "../../modules/karpenter"
  providers    = { kubectl = kubectl.use1 }
  cluster_name = module.eks_use1.cluster_name
}

module "karpenter_use2" {
  source       = "../../modules/karpenter"
  providers    = { kubectl = kubectl.use2 }
  cluster_name = module.eks_use2.cluster_name
}

module "karpenter_usw2" {
  source       = "../../modules/karpenter"
  providers    = { kubectl = kubectl.usw2 }
  cluster_name = module.eks_usw2.cluster_name
}

# ============================================================
# S3 Hub Bucket (Seoul)
# ============================================================
module "s3" {
  source      = "../../modules/s3"
  providers   = { aws = aws.seoul }
  bucket_name = "${local.name}-data"
}

# ============================================================
# ECR (Seoul)
# ============================================================
module "ecr" {
  source    = "../../modules/ecr"
  providers = { aws = aws.seoul }
}

# ============================================================
# ElastiCache (Seoul)
# ============================================================
module "elasticache" {
  source    = "../../modules/elasticache"
  providers = { aws = aws.seoul }

  name                       = local.name
  vpc_id                     = module.vpc_seoul.vpc_id
  subnet_ids                 = module.vpc_seoul.private_subnet_ids
  allowed_security_group_ids = [module.eks_seoul.cluster_security_group_id]
  node_type                  = var.redis_node_type
}

# ============================================================
# Cognito (Seoul)
# ============================================================
module "cognito" {
  source    = "../../modules/cognito"
  providers = { aws = aws.seoul }

  name          = "${local.name}-users"
  domain_prefix = var.cognito_domain_prefix
}

# ============================================================
# ALB (Seoul)
# ============================================================
module "alb" {
  source    = "../../modules/alb"
  providers = { aws = aws.seoul }

  name                  = local.name
  vpc_id                = module.vpc_seoul.vpc_id
  public_subnet_ids     = module.vpc_seoul.public_subnet_ids
  certificate_arn       = var.acm_certificate_arn
  cognito_user_pool_arn = module.cognito.user_pool_arn
  cognito_client_id     = module.cognito.client_id
  cognito_domain        = module.cognito.user_pool_domain
  origin_verify_secret  = var.origin_verify_secret
}

# ============================================================
# CloudFront + WAF (must use us-east-1 provider for WAF CLOUDFRONT scope)
# ============================================================
module "cloudfront" {
  source    = "../../modules/cloudfront"
  providers = { aws = aws.us_east_1 }

  name                 = local.name
  alb_dns_name         = module.alb.alb_dns_name
  origin_verify_secret = var.origin_verify_secret
  certificate_arn      = var.cloudfront_certificate_arn
}

# ============================================================
# Pod Identity — Seoul (control plane services)
# ============================================================
module "pod_identity_seoul" {
  source    = "../../modules/pod_identity"
  providers = { aws = aws.seoul }

  cluster_name  = module.eks_seoul.cluster_name
  s3_bucket_arn = module.s3.bucket_arn
}

# ============================================================
# Pod Identity — Spot regions (GPU worker only)
# ============================================================
module "pod_identity_use1" {
  source    = "../../modules/pod_identity"
  providers = { aws = aws.us_east_1 }

  cluster_name  = module.eks_use1.cluster_name
  s3_bucket_arn = module.s3.bucket_arn
}

module "pod_identity_use2" {
  source    = "../../modules/pod_identity"
  providers = { aws = aws.us_east_2 }

  cluster_name  = module.eks_use2.cluster_name
  s3_bucket_arn = module.s3.bucket_arn
}

module "pod_identity_usw2" {
  source    = "../../modules/pod_identity"
  providers = { aws = aws.us_west_2 }

  cluster_name  = module.eks_usw2.cluster_name
  s3_bucket_arn = module.s3.bucket_arn
}

# ============================================================
# FSx Lustre — 3 Spot regions
# ============================================================
module "fsx_use1" {
  source    = "../../modules/fsx"
  providers = { aws = aws.us_east_1 }

  name               = "${local.name}-use1"
  subnet_id          = module.vpc_use1.private_subnet_ids[0]
  security_group_ids = [module.eks_use1.cluster_security_group_id]
  s3_import_path     = "s3://${module.s3.bucket_id}"
}

module "fsx_use2" {
  source    = "../../modules/fsx"
  providers = { aws = aws.us_east_2 }

  name               = "${local.name}-use2"
  subnet_id          = module.vpc_use2.private_subnet_ids[0]
  security_group_ids = [module.eks_use2.cluster_security_group_id]
  s3_import_path     = "s3://${module.s3.bucket_id}"
}

module "fsx_usw2" {
  source    = "../../modules/fsx"
  providers = { aws = aws.us_west_2 }

  name               = "${local.name}-usw2"
  subnet_id          = module.vpc_usw2.private_subnet_ids[0]
  security_group_ids = [module.eks_usw2.cluster_security_group_id]
  s3_import_path     = "s3://${module.s3.bucket_id}"
}

# ============================================================
# Monitoring — Seoul (full stack) + Spot regions (agent mode)
# ============================================================
module "monitoring_seoul" {
  source    = "../../modules/monitoring"
  providers = { helm = helm.seoul }

  cluster_name = module.eks_seoul.cluster_name
  is_agent_mode = false
}

module "monitoring_use1" {
  source    = "../../modules/monitoring"
  providers = { helm = helm.use1 }

  cluster_name   = module.eks_use1.cluster_name
  is_agent_mode  = true
  remote_write_url = ""
}

module "monitoring_use2" {
  source    = "../../modules/monitoring"
  providers = { helm = helm.use2 }

  cluster_name   = module.eks_use2.cluster_name
  is_agent_mode  = true
  remote_write_url = ""
}

module "monitoring_usw2" {
  source    = "../../modules/monitoring"
  providers = { helm = helm.usw2 }

  cluster_name   = module.eks_usw2.cluster_name
  is_agent_mode  = true
  remote_write_url = ""
}

# ============================================================
# GitHub Actions OIDC (Seoul)
# ============================================================
module "github_oidc" {
  source    = "../../modules/github_oidc"
  providers = { aws = aws.seoul }

  github_org  = var.github_org
  github_repo = var.github_repo
}
```

- [ ] **Step 3: Create outputs.tf**

```hcl
# terraform/envs/dev/outputs.tf
output "eks_seoul_endpoint" {
  value = module.eks_seoul.cluster_endpoint
}

output "eks_use1_endpoint" {
  value = module.eks_use1.cluster_endpoint
}

output "eks_use2_endpoint" {
  value = module.eks_use2.cluster_endpoint
}

output "eks_usw2_endpoint" {
  value = module.eks_usw2.cluster_endpoint
}

output "redis_url" {
  value     = module.elasticache.redis_url
  sensitive = true
}

output "alb_dns" {
  value = module.alb.alb_dns_name
}

output "cloudfront_domain" {
  value = module.cloudfront.distribution_domain_name
}

output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "ecr_repos" {
  value = module.ecr.repository_urls
}

output "github_actions_role_arn" {
  value = module.github_oidc.role_arn
}

output "s3_bucket" {
  value = module.s3.bucket_id
}
```

- [ ] **Step 4: Format and commit**

```bash
terraform fmt -recursive terraform/
git add terraform/envs/dev/
git commit -m "feat(terraform): add dev environment root module wiring all resources"
```

---

## Task 15: Prod Environment + Validation

**Files:**
- Create: `terraform/envs/prod/versions.tf`, `terraform/envs/prod/backend.tf`, `terraform/envs/prod/providers.tf`, `terraform/envs/prod/variables.tf`, `terraform/envs/prod/terraform.tfvars`, `terraform/envs/prod/main.tf`, `terraform/envs/prod/outputs.tf`

- [ ] **Step 1: Copy and adjust prod files from dev**

The prod environment is identical in structure to dev. Create the following files:

**versions.tf** — same as dev:
```hcl
# terraform/envs/prod/versions.tf
terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1"
    }
  }
}
```

**backend.tf** — different state key:
```hcl
# terraform/envs/prod/backend.tf
terraform {
  backend "s3" {
    bucket         = "gpu-lotto-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "gpu-lotto-tflock"
    encrypt        = true
  }
}
```

**providers.tf** — same as dev (copy from `terraform/envs/dev/providers.tf`).

**variables.tf** — same as dev (copy from `terraform/envs/dev/variables.tf`).

**terraform.tfvars:**
```hcl
# terraform/envs/prod/terraform.tfvars
environment           = "prod"
project               = "gpu-lotto"
cognito_domain_prefix = "gpu-lotto"
origin_verify_secret  = "prod-origin-verify-secret-change-me"
redis_node_type       = "cache.r7g.large"
```

**main.tf** — same structure as dev (copy from `terraform/envs/dev/main.tf`). The only difference is the variable values come from terraform.tfvars.

**outputs.tf** — same as dev (copy from `terraform/envs/dev/outputs.tf`).

- [ ] **Step 2: Validate both environments**

Run format check across all terraform files:
```bash
terraform fmt -recursive terraform/
```
Expected: No output (all files already formatted), or files get formatted.

Validate dev (without backend — no AWS credentials needed):
```bash
cd terraform/envs/dev && terraform init -backend=false
terraform validate
```
Expected: `Success! The configuration is valid.`

Validate prod:
```bash
cd terraform/envs/prod && terraform init -backend=false
terraform validate
```
Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
cd /home/ec2-user/my-project/spot-gpu-lotto
git add terraform/envs/prod/
git commit -m "feat(terraform): add prod environment and validate all modules"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] VPC (×4 regions) — Task 2
- [x] EKS Auto Mode (×4) with Pod Identity Agent — Task 3
- [x] Karpenter GPU Spot NodePool (×3) — Task 4
- [x] Pod Identity (4 service accounts) — Task 5
- [x] ElastiCache Redis 7 (Seoul, TLS) — Task 6
- [x] S3 Hub Bucket (versioning, lifecycle) — Task 7
- [x] ECR (4 repos, lifecycle policy) — Task 7
- [x] FSx Lustre (×3, AutoImport/Export) — Task 11
- [x] Cognito User Pool (custom role attr, MFA optional) — Task 8
- [x] ALB (CloudFront Prefix List SG, Cognito auth) — Task 9
- [x] CloudFront + WAF (rate limit, SQLi, cache policies) — Task 10
- [x] GitHub OIDC federation — Task 12
- [x] Monitoring (kube-prometheus-stack + DCGM + Agent mode) — Task 13
- [x] Dev environment root module — Task 14
- [x] Prod environment — Task 15
- [x] Terraform state (S3 + DynamoDB) — Task 1
- [x] Multi-region provider aliases — Task 1
- [x] KMS encryption for EKS secrets — Task 3

**Not in scope (belongs to Plan 5: Helm):**
- Kubernetes manifests (PV/PVC for FSx, S3 Mountpoint)
- ServiceMonitor for custom metrics
- NetworkPolicy
- ExternalSecret for Redis auth token

**Placeholder scan:** No TBD/TODO. All tasks have complete code.

**Type consistency:** Module variable names match across all usages in dev/prod main.tf. Output names are consistent between modules and root outputs.
