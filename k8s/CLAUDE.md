# K8s Manifests Module

## Role
Kubernetes manifests for Karpenter NodePool and storage PersistentVolumes.
Applied directly (not via Helm) as cluster-level resources.

## Key Files
- `karpenter-gpu-spot.yaml` -- Karpenter NodePool for GPU Spot instances (g5, g6, g6e)
- `fsx-lustre-pv.yaml` -- FSx Lustre PV/PVC template (envsubst variables for per-region deploy)
- `s3-mountpoint-pv.yaml` -- S3 Mountpoint CSI PV/PVC (fallback storage mode)

## Rules
- Karpenter NodePool targets Spot instances only (capacity type: spot)
- FSx Lustre auto-import/export policies sync with Seoul S3 hub bucket
- PVs are per-region resources -- must be created in each spot region's EKS cluster
- `fsx-lustre-pv.yaml` uses envsubst templating: `envsubst < fsx-lustre-pv.yaml | kubectl apply -f -`
  - Required vars: `FSX_FILESYSTEM_ID`, `FSX_DNS_NAME`, `FSX_MOUNT_NAME` (from Terraform output)
