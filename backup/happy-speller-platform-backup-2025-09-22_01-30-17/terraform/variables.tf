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

variable "enable_network_policies" {
  description = "Enable network policies for security"
  type        = bool
  default     = true
}

variable "enable_resource_quotas" {
  description = "Enable resource quotas for namespace"
  type        = bool
  default     = true
}

variable "enable_limit_ranges" {
  description = "Enable limit ranges for containers"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable monitoring with ServiceMonitor"
  type        = bool
  default     = false
}

variable "resource_quota" {
  description = "Resource quota configuration"
  type = object({
    requests_cpu    = string
    requests_memory = string
    limits_cpu      = string
    limits_memory   = string
    pods            = string
    services        = string
    pvc             = string
  })
  default = {
    requests_cpu    = "2"
    requests_memory = "4Gi"
    limits_cpu      = "4"
    limits_memory   = "8Gi"
    pods            = "10"
    services        = "5"
    pvc             = "5"
  }
}

variable "limit_range" {
  description = "Limit range configuration"
  type = object({
    default_cpu            = string
    default_memory         = string
    default_request_cpu    = string
    default_request_memory = string
  })
  default = {
    default_cpu            = "500m"
    default_memory         = "512Mi"
    default_request_cpu    = "100m"
    default_request_memory = "128Mi"
  }
}
