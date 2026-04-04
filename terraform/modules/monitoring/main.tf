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
        retention = "15d"
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
