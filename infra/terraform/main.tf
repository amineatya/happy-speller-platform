terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# Create demo namespace
resource "kubernetes_namespace" "demo" {
  metadata {
    name = "demo"
    labels = {
      environment = "demo"
      managed-by  = "terraform"
    }
  }
}

# Create MinIO secrets
resource "kubernetes_secret" "minio_secrets" {
  metadata {
    name      = "minio-secrets"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }

  data = {
    access-key = var.minio_access_key
    secret-key = var.minio_secret_key
  }
}

# Optional: Deploy MinIO if not available
resource "helm_release" "minio" {
  count      = var.deploy_minio ? 1 : 0
  name       = "minio"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "minio"
  version    = "12.6.0"
  namespace  = kubernetes_namespace.demo.metadata[0].name

  set {
    name  = "auth.rootUser"
    value = var.minio_access_key
  }

  set {
    name  = "auth.rootPassword"
    value = var.minio_secret_key
  }

  set {
    name  = "defaultBuckets"
    value = "artifacts,logs,docs"
  }

  set {
    name  = "service.type"
    value = "NodePort"
  }
}

# Optional: Deploy Grafana if not available
resource "helm_release" "grafana" {
  count      = var.deploy_grafana ? 1 : 0
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "6.57.3"
  namespace  = kubernetes_namespace.demo.metadata[0].name

  set {
    name  = "admin.user"
    value = var.grafana_admin_user
  }

  set {
    name  = "admin.password"
    value = var.grafana_admin_password
  }

  set {
    name  = "service.type"
    value = "NodePort"
  }

  set {
    name  = "persistence.enabled"
    value = "true"
  }
}

# Create network policies for security
resource "kubernetes_network_policy" "happy_speller_network_policy" {
  count = var.enable_network_policies ? 1 : 0
  
  metadata {
    name      = "happy-speller-network-policy"
    namespace = kubernetes_namespace.demo.metadata[0].name
    labels = {
      app        = "happy-speller"
      managed-by = "terraform"
    }
  }

  spec {
    pod_selector {
      match_labels = {
        app = "happy-speller"
      }
    }
    
    policy_types = ["Ingress", "Egress"]
    
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.demo.metadata[0].name
          }
        }
      }
      
      ports {
        protocol = "TCP"
        port     = "8080"
      }
    }
    
    egress {
      # Allow DNS
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }
      
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }
    
    egress {
      # Allow outbound HTTPS for API calls
      ports {
        protocol = "TCP"
        port     = "443"
      }
    }
  }
}

# Create resource quotas
resource "kubernetes_resource_quota" "demo_quota" {
  count = var.enable_resource_quotas ? 1 : 0
  
  metadata {
    name      = "demo-quota"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }
  
  spec {
    hard = {
      "requests.cpu"    = var.resource_quota.requests_cpu
      "requests.memory" = var.resource_quota.requests_memory
      "limits.cpu"      = var.resource_quota.limits_cpu
      "limits.memory"   = var.resource_quota.limits_memory
      "pods"            = var.resource_quota.pods
      "services"        = var.resource_quota.services
      "persistentvolumeclaims" = var.resource_quota.pvc
    }
  }
}

# Create limit ranges
resource "kubernetes_limit_range" "demo_limit_range" {
  count = var.enable_limit_ranges ? 1 : 0
  
  metadata {
    name      = "demo-limit-range"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }
  
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = var.limit_range.default_cpu
        memory = var.limit_range.default_memory
      }
      default_request = {
        cpu    = var.limit_range.default_request_cpu
        memory = var.limit_range.default_request_memory
      }
    }
  }
}

# Create service monitor for Prometheus (if monitoring is enabled)
resource "kubernetes_manifest" "happy_speller_service_monitor" {
  count = var.enable_monitoring ? 1 : 0
  
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "happy-speller-service-monitor"
      namespace = kubernetes_namespace.demo.metadata[0].name
      labels = {
        app        = "happy-speller"
        managed-by = "terraform"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "happy-speller"
        }
      }
      endpoints = [{
        port     = "http"
        path     = "/healthz"
        interval = "30s"
      }]
    }
  }
}
