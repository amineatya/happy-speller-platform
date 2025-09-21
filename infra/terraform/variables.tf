variable "minio_access_key" {
  description = "MinIO access key"
  type        = string
  sensitive   = true
}

variable "minio_secret_key" {
  description = "MinIO secret key"
  type        = string
  sensitive   = true
}

variable "deploy_minio" {
  description = "Whether to deploy MinIO"
  type        = bool
  default     = false
}

variable "deploy_grafana" {
  description = "Whether to deploy Grafana"
  type        = bool
  default     = false
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}
