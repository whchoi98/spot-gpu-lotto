#!/bin/bash
# 3개 리전에 EKS 클러스터 + Karpenter + FSx 스토리지를 배포하는 스크립트
set -euo pipefail

CLUSTER_PREFIX="gpu-lotto"
REGIONS=("us-east-1" "us-east-2" "us-west-2")
REGION_SHORT=("use1" "use2" "usw2")
K8S_VERSION="1.35"
TF_DIR="terraform/envs/dev"

for i in "${!REGIONS[@]}"; do
  REGION="${REGIONS[$i]}"
  SHORT="${REGION_SHORT[$i]}"
  CLUSTER_NAME="${CLUSTER_PREFIX}-${SHORT}"
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
  sed "s/\${CLUSTER_NAME}/${CLUSTER_NAME}/g" \
    k8s/karpenter-gpu-spot.yaml | kubectl apply -f -

  # 5. FSx CSI driver addon 설치
  echo "  Installing FSx CSI driver addon..."
  aws eks create-addon \
    --cluster-name "${CLUSTER_NAME}" \
    --addon-name aws-fsx-csi-driver \
    --region "${REGION}" \
    --resolve-conflicts OVERWRITE 2>/dev/null || \
    echo "  FSx CSI driver addon already exists, skipping."

  # 6. FSx Lustre PV/PVC 적용 (Terraform output에서 값 추출)
  echo "  Applying FSx Lustre PV/PVC..."
  FSX_OUT=$(cd "${TF_DIR}" && terraform output -json "fsx_${SHORT}" 2>/dev/null) || true
  if [ -n "${FSX_OUT}" ] && [ "${FSX_OUT}" != "null" ]; then
    export FSX_FILESYSTEM_ID
    export FSX_DNS_NAME
    export FSX_MOUNT_NAME
    FSX_FILESYSTEM_ID=$(echo "${FSX_OUT}" | jq -r '.file_system_id')
    FSX_DNS_NAME=$(echo "${FSX_OUT}" | jq -r '.dns_name')
    FSX_MOUNT_NAME=$(echo "${FSX_OUT}" | jq -r '.mount_name')
    envsubst < k8s/fsx-lustre-pv.yaml | kubectl apply -f -
    echo "  FSx PV/PVC applied (${FSX_FILESYSTEM_ID})"
  else
    echo "  [SKIP] FSx not yet provisioned for ${SHORT}. Run terraform apply first."
  fi

  echo "=== ${CLUSTER_NAME} ready ==="
done

echo ""
echo "All 3 clusters deployed. Kubeconfigs:"
for REGION in "${REGIONS[@]}"; do
  echo "  ${REGION}: ~/.kube/config-${REGION}"
done
