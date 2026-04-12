#!/bin/bash
# 3개 리전에 EKS 클러스터 + Karpenter 설정을 배포하는 스크립트
set -euo pipefail

CLUSTER_PREFIX="gpu-lotto"
REGIONS=("us-east-1" "us-east-2" "us-west-2")
K8S_VERSION="1.31"

for REGION in "${REGIONS[@]}"; do
  CLUSTER_NAME="${CLUSTER_PREFIX}-${REGION}"
  echo "=== Creating cluster: ${CLUSTER_NAME} in ${REGION} ==="

  # 1. EKS 클러스터 생성 (Auto Mode - Karpenter 내장)
  eksctl create cluster \
    --name "${CLUSTER_NAME}" \
    --region "${REGION}" \
    --version "${K8S_VERSION}" \
    --enable-auto-mode

  # 2. kubeconfig 저장 (리전별 분리)
  aws eks update-kubeconfig \
    --name "${CLUSTER_NAME}" \
    --region "${REGION}" \
    --kubeconfig "${HOME}/.kube/config-${REGION}"

  export KUBECONFIG="${HOME}/.kube/config-${REGION}"

  # 3. GPU 작업용 네임스페이스
  kubectl create namespace gpu-jobs --dry-run=client -o yaml | kubectl apply -f -

  # 4. Karpenter GPU Spot NodePool 적용
  sed "s/\${CLUSTER_NAME}/${CLUSTER_NAME}/g" k8s/karpenter-gpu-spot.yaml | kubectl apply -f -

  # 5. NVIDIA device plugin (Bottlerocket에는 내장이지만 AL2023 사용 시 필요)
  # EKS Auto Mode + Bottlerocket은 자동 포함되므로 스킵

  echo "=== ${CLUSTER_NAME} ready ==="
done

echo ""
echo "All 3 clusters deployed. Kubeconfigs:"
for REGION in "${REGIONS[@]}"; do
  echo "  ${REGION}: ~/.kube/config-${REGION}"
done
