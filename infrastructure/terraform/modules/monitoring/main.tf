resource "helm_release" "prometheus_stack" {
  name       = "prometheus-stack"
  namespace  = "monitoring"
  chart      = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  version    = "60.0.0"
  create_namespace = true
  wait       = true
  timeout    = 300

  values = [yamlencode({
    prometheus = {
      prometheusSpec = {
        retention = var.environment == "prod" ? "30d" : "7d"
        ruleSelectorNilUsesHelmValues = false
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues = false
        remoteWrite = var.environment == "prod" ? [{
          url = var.remote_write_url
        }] : []
      }
    }
    grafana = {
      adminPassword = var.grafana_password
      ingress = {
        enabled = var.environment != "dev"
        hosts   = ["grafana.${var.environment}.mlops.platform"]
      }
      dashboardProviders = {
        "dashboardproviders.yaml" = yamlencode({
          apiVersion = 1
          providers = [{
            name = "default"
            orgId = 1
            folder = ""
            type = "file"
            disableDeletion = false
            editable = true
            options = { path = "/var/lib/grafana/dashboards/default" }
          }]
        })
      }
    }
    alertmanager = {
      enabled = true
      config = {
        global = { resolve_timeout = "5m" }
        route = {
          group_by = ["namespace", "alertname"]
          group_wait = "30s"
          group_interval = "5m"
          repeat_interval = "12h"
          receiver = "slack"
        }
        receivers = [{
          name = "slack"
          slack_configs = [{
            api_url = var.slack_webhook
            channel = "#mlops-alerts"
            text = "{{ range .Alerts }}{{ .Annotations.summary }}\n{{ end }}"
          }]
        }]
      }
    }
  })]

  depends_on = [var.depends_on_module]
}

resource "helm_release" "evidently" {
  name      = "evidently"
  namespace = "monitoring"
  chart     = "${path.module}/../../helm/evidently"
  wait      = true
  timeout   = 180

  values = [yamlencode({
    environment = var.environment
    prometheus = {
      endpoint = "http://prometheus-stack-kube-prom-prometheus.monitoring:9090"
    }
  })]

  depends_on = [helm_release.prometheus_stack]
}
