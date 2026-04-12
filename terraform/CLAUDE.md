# Terraform Module

## Role
Infrastructure as Code for GPU Spot Lotto on AWS.
13 modules covering networking, compute, storage, auth, and observability.

## Modules
- `modules/vpc` -- VPC with public/private subnets
- `modules/eks` -- EKS cluster (Auto Mode)
- `modules/karpenter` -- Karpenter NodePool for GPU Spot provisioning
- `modules/elasticache` -- ElastiCache Redis 7 with TLS
- `modules/cognito` -- Cognito User Pool for JWT auth
- `modules/alb` -- Application Load Balancer with target groups
- `modules/cloudfront` -- CloudFront distribution + WAF
- `modules/ecr` -- ECR repositories (immutable tags)
- `modules/fsx` -- FSx Lustre filesystems (auto-import/export to S3)
- `modules/s3` -- S3 hub bucket (models, datasets, checkpoints, results)
- `modules/pod_identity` -- EKS Pod Identity for service accounts
- `modules/github_oidc` -- GitHub Actions OIDC provider
- `modules/monitoring` -- Prometheus + Grafana stack

## Environments
- `envs/dev/` -- Dev environment (Seoul, ap-northeast-2)
- `envs/prod/` -- Prod environment

## Rules
- State stored in S3 backend with DynamoDB locking
- All modules use variable inputs -- no hardcoded values
- `terraform destroy` is denied in `.claude/settings.json`
- Changes should be planned and reviewed before apply
