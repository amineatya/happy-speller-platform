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
