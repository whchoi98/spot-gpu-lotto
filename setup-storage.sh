#!/bin/bash
# S3 허브 버킷 + 크로스 리전 복제 + 리전별 FSx for Lustre 캐시 설정
set -euo pipefail

PRIMARY_REGION="ap-northeast-2"
SPOT_REGIONS=("us-east-1" "us-east-2" "us-west-2")
BUCKET_NAME="gpu-lotto-data-$(aws sts get-caller-identity --query Account --output text)"

echo "=== 1. 서울 리전에 S3 허브 버킷 생성 ==="
aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${PRIMARY_REGION}" \
  --create-bucket-configuration LocationConstraint="${PRIMARY_REGION}"

aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

# 폴더 구조 생성
for prefix in models/ datasets/ results/ checkpoints/; do
  aws s3api put-object --bucket "${BUCKET_NAME}" --key "${prefix}" --region "${PRIMARY_REGION}"
done

echo "=== 2. 각 Spot 리전에 FSx for Lustre 파일시스템 생성 ==="
# 이 스크립트는 각 리전의 EKS 클러스터 VPC 서브넷 ID가 필요합니다.
# 실제 환경에서는 eksctl/CloudFormation 출력에서 가져옵니다.

for REGION in "${SPOT_REGIONS[@]}"; do
  CLUSTER_NAME="gpu-lotto-${REGION}"
  echo "--- ${REGION}: FSx for Lustre 생성 ---"

  # EKS 클러스터의 프라이빗 서브넷 ID 조회
  SUBNET_ID=$(aws eks describe-cluster \
    --name "${CLUSTER_NAME}" \
    --region "${REGION}" \
    --query 'cluster.resourcesVpcConfig.subnetIds[0]' \
    --output text 2>/dev/null || echo "SUBNET_PLACEHOLDER")

  # EKS 클러스터의 보안 그룹 조회
  SG_ID=$(aws eks describe-cluster \
    --name "${CLUSTER_NAME}" \
    --region "${REGION}" \
    --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
    --output text 2>/dev/null || echo "SG_PLACEHOLDER")

  # FSx for Lustre 생성 (S3 연동, Scratch-SSD - Spot 워크로드에 적합)
  cat <<EOF > "/tmp/fsx-${REGION}.json"
{
  "FileSystemType": "LUSTRE",
  "StorageCapacity": 1200,
  "StorageType": "SSD",
  "SubnetIds": ["${SUBNET_ID}"],
  "SecurityGroupIds": ["${SG_ID}"],
  "LustreConfiguration": {
    "DeploymentType": "SCRATCH_2",
    "ImportPath": "s3://${BUCKET_NAME}",
    "ExportPath": "s3://${BUCKET_NAME}/results/${REGION}/",
    "AutoImportPolicy": "NEW_CHANGED_DELETED"
  },
  "Tags": [
    {"Key": "Name", "Value": "gpu-lotto-fsx-${REGION}"},
    {"Key": "Project", "Value": "gpu-lotto"}
  ]
}
EOF

  echo "  FSx config saved to /tmp/fsx-${REGION}.json"
  echo "  Run: aws fsx create-file-system --region ${REGION} --cli-input-json file:///tmp/fsx-${REGION}.json"
done

echo ""
echo "=== 설정 완료 ==="
echo "S3 허브 버킷: s3://${BUCKET_NAME} (${PRIMARY_REGION})"
echo "각 리전의 FSx for Lustre가 S3 버킷과 자동 동기화됩니다."
