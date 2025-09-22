output "namespace" {
  description = "The namespace name"
  value       = kubernetes_namespace.demo.metadata[0].name
}

output "minio_endpoint" {
  description = "MinIO endpoint"
  value       = var.deploy_minio ? "http://minio.${kubernetes_namespace.demo.metadata[0].name}.svc.cluster.local:9000" : "http://192.168.68.58:9000"
}

output "grafana_endpoint" {
  description = "Grafana endpoint"
  value       = var.deploy_grafana ? "http://grafana.${kubernetes_namespace.demo.metadata[0].name}.svc.cluster.local:3000" : "http://grafana.local:3000"
}
