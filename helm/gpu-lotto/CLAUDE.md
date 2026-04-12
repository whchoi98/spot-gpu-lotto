# Helm Chart Module

## Role
Helm 3 chart for deploying GPU Spot Lotto to EKS.
Manages api-server, dispatcher, price-watcher, frontend, and monitoring stack.

## Key Files
- `Chart.yaml` -- Chart metadata (name: gpu-lotto)
- `values.yaml` -- Default values
- `values-dev.yaml` -- Dev overrides (dry-run mode, single replicas, auth disabled)
- `values-prod.yaml` -- Prod overrides (live mode, HPA, auth enabled)
- `templates/configmap.yaml` -- Shared ConfigMap (REDIS_URL, K8S_MODE, etc.)
- `templates/networkpolicy.yaml` -- Network isolation rules
- `templates/api-server/` -- Deployment, Service, SA, HPA
- `templates/dispatcher/` -- Deployment, SA, PDB
- `templates/price-watcher/` -- Deployment, SA
- `templates/frontend/` -- Deployment, Service
- `templates/monitoring/` -- ServiceMonitor for Prometheus

## Rules
- Image tags are immutable in ECR -- always increment version
- `values-dev.yaml` overrides `global.image.tag` for all backend services
- Frontend has its own `frontend.image.tag` (separate build pipeline)
- ConfigMap changes require `kubectl rollout restart` to take effect
- ALB uses IP target type -- Pod IP must be re-registered after restart
