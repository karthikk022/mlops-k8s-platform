resource "helm_release" "istio_base" {
  name       = "istio-base"
  namespace  = "istio-system"
  chart      = "base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  version    = "1.21.0"
  create_namespace = true
  wait       = true
  timeout    = 180
}

resource "helm_release" "istiod" {
  name       = "istiod"
  namespace  = "istio-system"
  chart      = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  version    = "1.21.0"
  wait       = true
  timeout    = 180

  values = [yamlencode({
    meshConfig = {
      enableTracing = true
      defaultConfig = {
        proxyMetadata = {}
      }
      extensionProviders = [{
        name = "prometheus"
        prometheus = { port = 9090 }
      }]
    }
  })]

  depends_on = [helm_release.istio_base]
}

resource "helm_release" "istio_ingress" {
  count      = var.environment != "dev" ? 1 : 0
  name       = "istio-ingress"
  namespace  = "istio-system"
  chart      = "gateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  version    = "1.21.0"
  wait       = true
  timeout    = 180

  values = [yamlencode({
    service = {
      type = "LoadBalancer"
      ports = [
        { port = 80, targetPort = 8080, name = "http" },
        { port = 443, targetPort = 8443, name = "https" }
      ]
    }
    labels = { "istio" = "ingressgateway" }
  })]

  depends_on = [helm_release.istiod]
}

resource "kubernetes_namespace" "mlops_istio" {
  metadata {
    name = "mlops"
    labels = { "istio-injection" = "enabled" }
  }
  depends_on = [helm_release.istiod]
}
